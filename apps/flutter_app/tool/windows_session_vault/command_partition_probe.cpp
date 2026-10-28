// TEST ONLY synthetic namespaces/opaque bytes. No learner or hosted Auth proof.
#include "pending_command_partition.h"
#include "pending_command_protection.h"
#ifdef _WIN32
#include <windows.h>
#include <sddl.h>
#include <array>
#include <iostream>
#include <stdexcept>
void VerifyCommandPostDecryptGuard(const std::wstring& root,
    const std::string& target, const std::wstring& directory);
namespace {
void Check(bool value) {
  if (!value) throw std::runtime_error("command partition probe failed");
}
// TEST ONLY explicit modes, no target/payload arguments or shell.
void ProtectedChild(const std::wstring& root, const std::wstring& mode, DWORD expected) {
  Check(mode == L"write-min" || mode == L"write-max" ||
        mode == L"read-min" || mode == L"read-max");
  wchar_t executable[32768]{};
  const DWORD length = GetModuleFileNameW(nullptr, executable, 32768);
  Check(length > 0 && length < 32768);
  auto command = L"\"" + std::wstring(executable) +
      L"\" --protected-command-child \"" + root + L"\" " + mode;
  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  PROCESS_INFORMATION process{};
  Check(CreateProcessW(nullptr, command.data(), nullptr, nullptr, FALSE,
      CREATE_NO_WINDOW, nullptr, nullptr, &startup, &process) != FALSE);
  const DWORD waited = WaitForSingleObject(process.hProcess, 10000);
  DWORD code = 5;
  const bool exited = waited == WAIT_OBJECT_0 &&
      GetExitCodeProcess(process.hProcess, &code) != FALSE;
  if (!exited) {
    TerminateProcess(process.hProcess, 5);
    WaitForSingleObject(process.hProcess, 5000);
  }
  const bool threadClosed = CloseHandle(process.hThread) != FALSE;
  const bool processClosed = CloseHandle(process.hProcess) != FALSE;
  Check(exited && threadClosed && processClosed && code == expected);
}
}  // namespace
int ProtectedCommandChild(const std::wstring& root, const std::wstring& mode) {
  if (mode != L"write-min" && mode != L"write-max" &&
      mode != L"read-min" && mode != L"read-max") return 5;
  try {
    const std::string target = "NihongoDaily.ConversationReceipt.v1|https://partition-a.invalid|11111111-1111-4111-8111-111111111111";
    const bool writing = mode == L"write-min" || mode == L"write-max";
    const bool maximum = mode == L"write-max" || mode == L"read-max";
    const std::vector<unsigned char> expectedBytes(maximum ? 32768 : 1, 0x91);
    auto partition = nihongo::ProtectedPendingCommandPartition::Acquire(root, target);
    if (!partition) return 3; // Explicit contention result, never success.
    if (writing) {
      const auto empty = partition->ReadRecovery(target);
      if (empty.state != nihongo::PendingCommandCandidateState::absent ||
          !empty.plaintext.empty() || !partition->Stage(target, expectedBytes) ||
          !partition->Publish(target)) return 5;
      ExitProcess(0); // Actual abrupt writer exit: no C++ destructor/lease release.
    }
    const auto decoded = partition->ReadRecovery(target);
    if (decoded.state != nihongo::PendingCommandCandidateState::present ||
        decoded.plaintext != expectedBytes) return 5;
    partition->Revoke();
    const auto denied = partition->ReadRecovery(target);
    if (denied.state != nihongo::PendingCommandCandidateState::unavailable ||
        !denied.plaintext.empty()) return 5;
    return 0;
  } catch (...) { return 5; } // No path, scope, payload or OS diagnostics.
}
bool ProbeCommandPartition(const std::wstring& root, const std::wstring& user) {
  using Partition = nihongo::PendingCommandPartition;
  using State = nihongo::PendingCommandCandidateState;
  const auto base = root + L"\\scoped";
  const auto version = base + L"\\pending-command-v1";
  const std::array<std::string, 3> targets = {
      "NihongoDaily.ConversationReceipt.v1|https://partition-a.invalid|11111111-1111-4111-8111-111111111111",
      "NihongoDaily.ConversationReceipt.v1|https://partition-a.invalid|22222222-2222-4222-8222-222222222222",
      "NihongoDaily.ConversationReceipt.v1|https://partition-b.invalid|11111111-1111-4111-8111-111111111111"};
  // Independent Python hashlib SHA256 known answers, not the production resolver.
  const std::array<std::wstring, 3> keys = {
      L"bc0232dc847d5294acbf15acf03f831aea3674b95be126b27deb7bf5c60290ca",
      L"af68999521a78f7fdbeb8d8b476bed7197ac8c990cc65bfc238bb4df9d3524f0",
      L"e938cc1065905bd4b615dfe53721953cedb6b82217c71a2855a2a4aa066aac84"};
  std::array<std::wstring, 3> paths;
  std::array<std::unique_ptr<Partition>, 3> partitions;
  const std::array<std::vector<unsigned char>, 3> values = {
      std::vector<unsigned char>(64, 0xa1), std::vector<unsigned char>(64, 0xb2),
      std::vector<unsigned char>(64, 0xc3)};
  struct Security {
    PSECURITY_DESCRIPTOR value = nullptr;
    ~Security() { if (value) LocalFree(value); }
  } folder, file;
  const auto descriptor = [&](Security& out, const std::wstring& flags) {
    const auto sddl = L"O:" + user + L"D:P(A;" + flags + L";FA;;;" + user + L")" +
        (user == L"S-1-5-18" ? L"" : L"(A;" + flags + L";FA;;;SY)");
    Check(ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl.c_str(),
        SDDL_REVISION_1, &out.value, nullptr) != FALSE);
  };
  bool passed = false;
  try {
    descriptor(folder, L"OICI");
    descriptor(file, L"");
    SECURITY_ATTRIBUTES attributes{sizeof(SECURITY_ATTRIBUTES), folder.value, FALSE};
    Check(CreateDirectoryW(base.c_str(), &attributes) != FALSE);
    Check(CreateDirectoryW(version.c_str(), &attributes) != FALSE);
    // Invalid canonical scopes cannot create a leaf or fall back to this root.
    for (const auto& bad : {std::string(), std::string("OtherApplication|scope"),
        targets[0] + "/../other", targets[0] + std::string(1, '\0')})
      Check(!Partition::Acquire(base, bad));
    for (const auto& bad : {L"", L"relative", L"C:\\safe\\..", L"\\\\server\\path"})
      Check(!Partition::Acquire(bad, targets[0]));
    Check(!Partition::Acquire(std::wstring(137, L'x'), targets[0]));
    Check(GetFileAttributesW((base + L"\\pending-command.lock").c_str()) == INVALID_FILE_ATTRIBUTES);
    for (size_t i = 0; i < paths.size(); ++i) {
      paths[i] = version + L"\\" + keys[i];
      // Resolver must NOT create missing directories or use a different partition.
      Check(!Partition::Acquire(base, targets[i]));
      Check(GetFileAttributesW(paths[i].c_str()) == INVALID_FILE_ATTRIBUTES);
      Check(CreateDirectoryW(paths[i].c_str(), &attributes) != FALSE);
      SECURITY_ATTRIBUTES lockAttributes{sizeof(SECURITY_ATTRIBUTES), file.value, FALSE};
      const auto lock = CreateFileW((paths[i] + L"\\pending-command.lock").c_str(),
          GENERIC_WRITE, 0, &lockAttributes, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr);
      Check(lock != INVALID_HANDLE_VALUE);
      Check(CloseHandle(lock) != FALSE);
      partitions[i] = Partition::Acquire(base, targets[i]);
      Check(partitions[i] != nullptr);
      Check(!Partition::Acquire(base, targets[i])); // Same-scope contention.
      Check(partitions[i]->ReadRecoveryCiphertextCandidate(targets[i]).state == State::absent);
      Check(partitions[i]->StageCiphertextCandidate(targets[i], values[i]));
      Check(partitions[i]->PublishStagedCiphertextCandidate(targets[i]));
    }
    // Different account AND project coexist under separate held leases/data.
    for (size_t i = 0; i < paths.size(); ++i) {
      const auto result = partitions[i]->ReadRecoveryCiphertextCandidate(targets[i]);
      Check(result.state == State::present && result.bytes == values[i]);
      partitions[i].reset();
      Check(DeleteFileW((paths[i] + L"\\pending-command.bin").c_str()) != FALSE);
      partitions[i] = Partition::Acquire(base, targets[i]);
      Check(partitions[i] != nullptr);
    }
    Check(partitions[0]->StageCiphertextCandidate(targets[0], values[0]));
    Check(partitions[0]->PublishStagedCiphertextCandidate(targets[0]));
    Check(partitions[2]->StageCiphertextCandidate(targets[2], values[2]));
    const auto wrongRead = partitions[0]->ReadRecoveryCiphertextCandidate(targets[1]);
    Check(wrongRead.state == State::unavailable && wrongRead.bytes.empty());
    Check(!partitions[1]->StageCiphertextCandidate(targets[0], values[0]));
    Check(!partitions[2]->PublishStagedCiphertextCandidate(targets[0]));
    for (size_t i = 0; i < paths.size(); ++i) {
      const auto blocked = partitions[i]->ReadRecoveryCiphertextCandidate(targets[i]);
      Check(blocked.state == State::unavailable && blocked.bytes.empty());
      Check(!partitions[i]->StageCiphertextCandidate(targets[i], values[i]));
      Check(!partitions[i]->PublishStagedCiphertextCandidate(targets[i]));
      partitions[i].reset();
      auto raw = nihongo::PendingCommandFileLease::Acquire(paths[i]);
      Check(raw && raw->CheckPrivateAccessPolicy());
      const auto original = raw->ReadCiphertextCandidate();
      Check(original.state == (i == 0 ? State::present : State::absent));
      Check(original.bytes == (i == 0 ? values[0] : std::vector<unsigned char>{}));
      if (i != 2)
        Check(GetFileAttributesW((paths[i] + L"\\pending-command.stage").c_str()) == INVALID_FILE_ATTRIBUTES);
    }
    // Wrong-scope publish must leave the complete original stage unpromoted.
    const auto stage = CreateFileW((paths[2] + L"\\pending-command.stage").c_str(),
        GENERIC_READ, 0, nullptr, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
    Check(stage != INVALID_HANDLE_VALUE);
    std::vector<unsigned char> bytes(64);
    DWORD count = 0;
    const bool read = ReadFile(stage, bytes.data(), 64, &count, nullptr) != FALSE && count == 64;
    unsigned char extra = 0;
    const bool eof = ReadFile(stage, &extra, 1, &count, nullptr) != FALSE && count == 0;
    const bool closed = CloseHandle(stage) != FALSE;
    Check(read && eof && closed && bytes == values[2]);
    auto unresolved = Partition::Acquire(base, targets[2]);
    Check(unresolved != nullptr);
    const auto uncertain = unresolved->ReadRecoveryCiphertextCandidate(targets[2]);
    Check(uncertain.state == State::unavailable && uncertain.bytes.empty());
    Check(DeleteFileW((paths[2] + L"\\pending-command.stage").c_str()) != FALSE);
    const auto stillBlocked = unresolved->ReadRecoveryCiphertextCandidate(targets[2]);
    Check(stillBlocked.state == State::unavailable && stillBlocked.bytes.empty());
    Check(!unresolved->StageCiphertextCandidate(targets[2], values[2]));
    Check(!unresolved->PublishStagedCiphertextCandidate(targets[2]));
    // Reopening is a clean object/data snapshot, never permission to redispatch.
    auto reopened = Partition::Acquire(base, targets[0]);
    Check(reopened != nullptr);
    const auto restored = reopened->ReadRecoveryCiphertextCandidate(targets[0]);
    Check(restored.state == State::present && restored.bytes == values[0]);
    // Revoke empty, staged and published partitions without releasing ownership.
    reopened.reset();
    unresolved.reset();
    for (size_t i = 0; i < paths.size(); ++i) {
      partitions[i] = Partition::Acquire(base, targets[i]);
      Check(partitions[i] != nullptr);
    }
    Check(partitions[2]->StageCiphertextCandidate(targets[2], values[2]));
    for (size_t i = 0; i < paths.size(); ++i) {
      partitions[i]->Revoke();
      partitions[i]->Revoke(); // Idempotent and terminal for the captured object.
      const auto denied = partitions[i]->ReadRecoveryCiphertextCandidate(targets[i]);
      Check(denied.state == State::unavailable && denied.bytes.empty());
      Check(!partitions[i]->StageCiphertextCandidate(targets[i], values[i]));
      Check(!partitions[i]->PublishStagedCiphertextCandidate(targets[i]));
      Check(!Partition::Acquire(base, targets[i])); // Revocation must NOT release lease.
      if (i == 0) { // Revoking A does not revoke the independently owned B partition.
        const auto other = partitions[1]->ReadRecoveryCiphertextCandidate(targets[1]);
        Check(other.state == State::absent && other.bytes.empty());
      }
      partitions[i].reset();
      auto raw = nihongo::PendingCommandFileLease::Acquire(paths[i]);
      Check(raw && raw->CheckPrivateAccessPolicy());
      const auto preserved = raw->ReadCiphertextCandidate();
      Check(preserved.state == (i == 0 ? State::present : State::absent));
      Check(preserved.bytes == (i == 0 ? values[0] : std::vector<unsigned char>{}));
      if (i != 2)
        Check(GetFileAttributesW((paths[i] + L"\\pending-command.stage").c_str()) == INVALID_FILE_ATTRIBUTES);
    }
    // Independently inspect the unpromoted stage after revocation/destruction.
    std::vector<unsigned char> retainedBytes(65);
    const auto retained = CreateFileW((paths[2] + L"\\pending-command.stage").c_str(),
        GENERIC_READ, 0, nullptr, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
    Check(retained != INVALID_HANDLE_VALUE);
    DWORD retainedCount = 0;
    const bool retainedRead = ReadFile(retained, retainedBytes.data(), 65, &retainedCount, nullptr) != FALSE;
    const bool retainedClosed = CloseHandle(retained) != FALSE;
    retainedBytes.resize(retainedCount <= 65 ? retainedCount : 65);
    Check(retainedRead && retainedClosed && retainedCount == 64 && retainedBytes == values[2]);
    // Compose real user-context DPAPI and real scoped file storage, synthetic only.
    using Protected = nihongo::ProtectedPendingCommandPartition;
    for (const auto& path : paths) {
      DeleteFileW((path + L"\\pending-command.bin").c_str());
      DeleteFileW((path + L"\\pending-command.stage").c_str());
    }
    for (unsigned mode = 0; mode < 13; ++mode) {
      // min/max roundtrip, empty/oversize, foreign/corrupt ciphertext, wrong
      // scope, explicit revoke, unresolved stage suppression, and account/project
      // read/publish mismatch with real ciphertext preservation.
      const std::vector<unsigned char> plain(mode == 1 ? 32768 : mode == 2 ? 0 :
          mode == 3 ? 32769 : 1, 0x91);
      std::vector<unsigned char> originalCipher;
      if (mode == 4 || mode == 5 || mode == 9 || mode == 10) {
        auto encoded = nihongo::ProtectPendingCommand(mode == 4 ? targets[1] : targets[0], plain);
        Check(encoded.status == nihongo::CommandProtectionStatus::success);
        if (mode == 5) encoded.bytes[encoded.bytes.size() / 2] ^= 1;
        originalCipher = encoded.bytes;
        auto fixture = Partition::Acquire(base, targets[0]);
        Check(fixture && fixture->StageCiphertextCandidate(targets[0], originalCipher));
        Check(fixture->PublishStagedCiphertextCandidate(targets[0]));
      }
      auto protectedPartition = Protected::Acquire(base, targets[0]);
      Check(protectedPartition != nullptr);
      if (mode < 2 || mode == 8 || mode == 11 || mode == 12) {
        const auto empty = protectedPartition->ReadRecovery(targets[0]);
        Check(empty.state == State::absent && empty.plaintext.empty());
        Check(protectedPartition->Stage(targets[0], plain));
        if (mode < 2) {
          Check(protectedPartition->Publish(targets[0]));
          protectedPartition.reset();
          { // Inspect actual persisted bytes without a decrypting facade.
            auto raw = Partition::Acquire(base, targets[0]);
            Check(raw != nullptr);
            const auto cipher = raw->ReadRecoveryCiphertextCandidate(targets[0]);
            Check(cipher.state == State::present && cipher.bytes != plain &&
                !cipher.bytes.empty() && cipher.bytes.size() <= 65536);
            originalCipher = cipher.bytes;
          }
          protectedPartition = Protected::Acquire(base, targets[0]);
          Check(protectedPartition != nullptr);
          const auto protectedRestored = protectedPartition->ReadRecovery(targets[0]);
          Check(protectedRestored.state == State::present && protectedRestored.plaintext == plain);
          protectedPartition->Revoke();
        }
        if (mode == 11 || mode == 12) {
          Check(!protectedPartition->Publish(targets[mode == 11 ? 1 : 2]));
        }
      } else if (mode == 2 || mode == 3) {
        Check(!protectedPartition->Stage(targets[0], plain));
      } else if (mode == 6) {
        Check(!protectedPartition->Stage(targets[1], plain));
      } else if (mode == 7) {
        protectedPartition->Revoke();
        protectedPartition->Revoke();
      }
      if (mode == 9 || mode == 10) {
        const auto wrongScope = protectedPartition->ReadRecovery(targets[mode == 9 ? 1 : 2]);
        Check(wrongScope.state == State::unavailable && wrongScope.plaintext.empty());
      }
      const auto denied = protectedPartition->ReadRecovery(targets[0]);
      Check(denied.state == State::unavailable && denied.plaintext.empty());
      Check(!protectedPartition->Stage(targets[0], plain));
      Check(!protectedPartition->Publish(targets[0]));
      Check(!Protected::Acquire(base, targets[0])); // Failure/revoke retains lease.
      protectedPartition.reset();
      {
        auto raw = nihongo::PendingCommandFileLease::Acquire(paths[0]);
        Check(raw && raw->CheckPrivateAccessPolicy());
        const auto preserved = raw->ReadCiphertextCandidate();
        Check(preserved.state == (originalCipher.empty() ? State::absent : State::present));
        Check(preserved.bytes == originalCipher); // Corrupt/foreign bytes also preserved.
      }
      if (mode == 8 || mode == 11 || mode == 12) {
        // Staged ciphertext remains decryptable but is never adopted/published.
        std::vector<unsigned char> staged(65537);
        const auto fileHandle = CreateFileW((paths[0] + L"\\pending-command.stage").c_str(),
            GENERIC_READ, 0, nullptr, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
        Check(fileHandle != INVALID_HANDLE_VALUE);
        DWORD got = 0;
        const bool readStage = ReadFile(fileHandle, staged.data(), 65537, &got, nullptr) != FALSE;
        const bool closedStage = CloseHandle(fileHandle) != FALSE;
        Check(readStage && closedStage && got > 0 && got <= 65536);
        staged.resize(got);
        const auto decoded = nihongo::UnprotectPendingCommand(targets[0], staged);
        Check(decoded.status == nihongo::CommandProtectionStatus::success && decoded.bytes == plain);
        Check(DeleteFileW((paths[0] + L"\\pending-command.stage").c_str()) != FALSE);
      } else {
        Check(GetFileAttributesW((paths[0] + L"\\pending-command.stage").c_str()) == INVALID_FILE_ATTRIBUTES);
      }
      if (!originalCipher.empty())
        Check(DeleteFileW((paths[0] + L"\\pending-command.bin").c_str()) != FALSE);
    }
    VerifyCommandPostDecryptGuard(base, targets[0], paths[0]);
    // Actual writer ExitProcess -> parent restore -> independent reader process.
    for (unsigned boundary = 0; boundary < 2; ++boundary) {
      const auto writeMode = boundary == 0 ? L"write-min" : L"write-max";
      const auto readMode = boundary == 0 ? L"read-min" : L"read-max";
      const std::vector<unsigned char> expectedBytes(boundary == 0 ? 1 : 32768, 0x91);
      ProtectedChild(base, writeMode, 0);
      std::vector<unsigned char> beforeRead;
      {
        auto raw = Partition::Acquire(base, targets[0]);
        Check(raw != nullptr);
        const auto stored = raw->ReadRecoveryCiphertextCandidate(targets[0]);
        Check(stored.state == State::present && !stored.bytes.empty() &&
            stored.bytes.size() <= 65536 && stored.bytes != expectedBytes);
        beforeRead = stored.bytes;
      }
      {
        auto owner = Protected::Acquire(base, targets[0]);
        Check(owner != nullptr);
        const auto recovered = owner->ReadRecovery(targets[0]);
        Check(recovered.state == State::present && recovered.plaintext == expectedBytes);
        ProtectedChild(base, readMode, 3); // Real child cannot bypass held lease.
      }
      ProtectedChild(base, readMode, 0); // Fresh process, real DPAPI user context.
      {
        auto raw = Partition::Acquire(base, targets[0]);
        Check(raw != nullptr);
        const auto afterRead = raw->ReadRecoveryCiphertextCandidate(targets[0]);
        Check(afterRead.state == State::present && afterRead.bytes == beforeRead);
      }
      Check(GetFileAttributesW((paths[0] + L"\\pending-command.stage").c_str()) == INVALID_FILE_ATTRIBUTES);
      Check(DeleteFileW((paths[0] + L"\\pending-command.bin").c_str()) != FALSE);
    }
    passed = true;
  } catch (...) { /* Fixed failure only; clean our explicit synthetic names. */ }
  for (auto& partition : partitions) partition.reset();
  bool cleaned = true;
  for (const auto& path : paths) {
    if (path.empty()) continue;
    DeleteFileW((path + L"\\pending-command.bin").c_str());
    DeleteFileW((path + L"\\pending-command.stage").c_str());
    DeleteFileW((path + L"\\pending-command.lock").c_str());
    cleaned = RemoveDirectoryW(path.c_str()) != FALSE && cleaned;
  }
  cleaned = RemoveDirectoryW(version.c_str()) != FALSE && cleaned;
  cleaned = RemoveDirectoryW(base.c_str()) != FALSE && cleaned;
  if (passed && cleaned)
    std::cout << "PASS: Windows command partition account/project isolation/scope fence/preservation (TEST ONLY)" << std::endl;
  if (passed && cleaned)
    std::cout << "PASS: Windows command partition revoke/retain-lease/preserve/isolate (TEST ONLY)" << std::endl;
  if (passed && cleaned)
    std::cout << "PASS: Windows protected command partition DPAPI/disk/restore/rejection/preservation (TEST ONLY)" << std::endl;
  if (passed && cleaned)
    std::cout << "PASS: Windows protected command abrupt writer/fresh reader/lease/preservation (TEST ONLY)" << std::endl;
  if (passed && cleaned)
    std::cout << "PASS: Windows protected command account/project read-publish scope fence (TEST ONLY)" << std::endl;
  if (passed && cleaned)
    std::cout << "PASS: Windows protected command post-decrypt recheck/stage/replacement/preserve (TEST ONLY)" << std::endl;
  if (passed && cleaned)
    std::cout << "PASS: Windows protected command post-decrypt deletion/sharing-denial/terminal (TEST ONLY)" << std::endl;
  return passed && cleaned;
}
#endif
