// TEST ONLY: rename the unchanged partition implementation, injecting AFTER
// real DPAPI decode. Never linked into the app runner; no production test hook.
#ifdef _WIN32
#include <windows.h>
#include <functional>
#include <stdexcept>
#include "pending_command_protection.h"
namespace {
std::function<void()> afterDecode;
void CheckPostDecrypt(bool value) {
  if (!value) throw std::runtime_error("command post-decrypt probe failed");
}
void WriteProbeFile(const std::wstring& path,
    const std::vector<unsigned char>& bytes, DWORD disposition) {
  const auto file = CreateFileW(path.c_str(), GENERIC_WRITE, 0, nullptr,
      disposition, FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
  CheckPostDecrypt(file != INVALID_HANDLE_VALUE);
  DWORD written = 0;
  const bool wrote = WriteFile(file, bytes.data(), static_cast<DWORD>(bytes.size()),
      &written, nullptr) != FALSE;
  const bool ended = SetEndOfFile(file) != FALSE;
  const bool flushed = FlushFileBuffers(file) != FALSE;
  const bool closed = CloseHandle(file) != FALSE;
  CheckPostDecrypt(wrote && written == bytes.size() && ended && flushed && closed);
}
}
namespace nihongo {
CommandProtectionResult ProbeUnprotectPendingCommand(const std::string& target,
    const std::vector<uint8_t>& bytes);
}
#define PendingCommandPartition PostDecryptPendingCommandPartition
#define ProtectedPendingCommandPartition PostDecryptProtectedPendingCommandPartition
#define UnprotectPendingCommand ProbeUnprotectPendingCommand
#include "../../windows/runner/pending_command_partition.cpp"
#undef UnprotectPendingCommand
#undef ProtectedPendingCommandPartition
#undef PendingCommandPartition
namespace nihongo {
CommandProtectionResult ProbeUnprotectPendingCommand(const std::string& target,
    const std::vector<uint8_t>& bytes) {
  auto result = UnprotectPendingCommand(target, bytes); // Actual user DPAPI.
  CheckPostDecrypt(result.status == CommandProtectionStatus::success);
  if (afterDecode) afterDecode();
  return result;
}
}
void VerifyCommandPostDecryptGuard(const std::wstring& root,
    const std::string& target, const std::wstring& directory) {
  using Owner = nihongo::PostDecryptProtectedPendingCommandPartition;
  using State = nihongo::PendingCommandCandidateState;
  struct ResetCallback { ~ResetCallback() { afterDecode = {}; } } resetCallback;
  const auto dataPath = directory + L"\\pending-command.bin";
  const auto stagePath = directory + L"\\pending-command.stage";
  const std::vector<unsigned char> plain(64, 0x91);
  const auto replacement = nihongo::ProtectPendingCommand(target,
      std::vector<unsigned char>(64, 0x92));
  CheckPostDecrypt(replacement.status == nihongo::CommandProtectionStatus::success);
  for (unsigned mode = 0; mode < 5; ++mode) {
    auto owner = Owner::Acquire(root, target);
    CheckPostDecrypt(owner && owner->Stage(target, plain) && owner->Publish(target));
    owner.reset();
    std::vector<unsigned char> originalCipher;
    {
      auto raw = nihongo::PendingCommandFileLease::Acquire(directory);
      CheckPostDecrypt(raw && raw->CheckPrivateAccessPolicy());
      const auto original = raw->ReadRecoveryCiphertextCandidate();
      CheckPostDecrypt(original.state == State::present);
      originalCipher = original.bytes;
    }
    owner = Owner::Acquire(root, target);
    CheckPostDecrypt(owner != nullptr);
    unsigned callbacks = 0;
    bool mutationSucceeded = false;
    struct HeldFile {
      HANDLE value = INVALID_HANDLE_VALUE;
      ~HeldFile() { if (value != INVALID_HANDLE_VALUE) CloseHandle(value); }
    } heldFile;
    afterDecode = [&]() {
      ++callbacks;
      if (mode == 1) WriteProbeFile(stagePath, replacement.bytes, CREATE_NEW);
      if (mode == 2) WriteProbeFile(dataPath, replacement.bytes, OPEN_EXISTING);
      if (mode == 3) CheckPostDecrypt(DeleteFileW(dataPath.c_str()) != FALSE);
      if (mode == 4) {
        heldFile.value = CreateFileW(dataPath.c_str(), GENERIC_READ, 0, nullptr,
            OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
        CheckPostDecrypt(heldFile.value != INVALID_HANDLE_VALUE);
      }
      mutationSucceeded = true;
    };
    const auto recovered = owner->ReadRecovery(target);
    CheckPostDecrypt(callbacks == 1 && mutationSucceeded);
    if (mode == 0) {
      CheckPostDecrypt(recovered.state == State::present && recovered.plaintext == plain);
      owner->Revoke();
    } else {
      CheckPostDecrypt(recovered.state == State::unavailable && recovered.plaintext.empty());
    }
    afterDecode = {};
    const auto denied = owner->ReadRecovery(target);
    CheckPostDecrypt(denied.state == State::unavailable && denied.plaintext.empty());
    CheckPostDecrypt(!owner->Stage(target, plain) && !owner->Publish(target));
    CheckPostDecrypt(!Owner::Acquire(root, target)); // Rejection retains the lease.
    owner.reset();
    if (heldFile.value != INVALID_HANDLE_VALUE) {
      const bool closed = CloseHandle(heldFile.value) != FALSE;
      heldFile.value = INVALID_HANDLE_VALUE;
      CheckPostDecrypt(closed);
    }
    { // Independent raw read checks the exact bytes; never adopt unresolved stage.
      auto raw = nihongo::PendingCommandFileLease::Acquire(directory);
      CheckPostDecrypt(raw && raw->CheckPrivateAccessPolicy());
      const auto stored = raw->ReadCiphertextCandidate();
      if (mode == 3) {
        CheckPostDecrypt(stored.state == State::absent && stored.bytes.empty());
      } else {
        CheckPostDecrypt(stored.state == State::present);
      }
      if (mode == 2) CheckPostDecrypt(stored.bytes == replacement.bytes);
      else if (mode != 3) {
        CheckPostDecrypt(stored.bytes == originalCipher);
        const auto decoded = nihongo::UnprotectPendingCommand(target, stored.bytes);
        CheckPostDecrypt(decoded.status == nihongo::CommandProtectionStatus::success &&
            decoded.bytes == plain);
      }
    }
    if (mode == 1) CheckPostDecrypt(DeleteFileW(stagePath.c_str()) != FALSE);
    else CheckPostDecrypt(GetFileAttributesW(stagePath.c_str()) == INVALID_FILE_ATTRIBUTES);
    if (mode == 3) {
      CheckPostDecrypt(GetFileAttributesW(dataPath.c_str()) == INVALID_FILE_ATTRIBUTES);
    } else {
      CheckPostDecrypt(DeleteFileW(dataPath.c_str()) != FALSE);
    }
  }
}
#endif
