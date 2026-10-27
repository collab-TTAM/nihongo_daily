// TEST ONLY: unique temporary directories and empty sentinel; no payloads.
#include "pending_command_file_lease.h"
#include <stdexcept>
#include <cstring>
#include <vector>
#ifdef _WIN32
#include <windows.h>
#include <winioctl.h>
#include <sddl.h>
#include <aclapi.h>
#include <iostream>
namespace {
void Check(bool value) {
  if (!value) throw std::runtime_error("command lease probe failed");
}
// TEST ONLY direct mount-point producer, no shell or symlink fallback/skip.
void Junction(const std::wstring& name, const std::wstring& target) {
  Check(CreateDirectoryW(name.c_str(), nullptr) != FALSE);
  const auto substitute = L"\\??\\" + target;
  const auto subBytes = static_cast<USHORT>(substitute.size() * sizeof(wchar_t));
  const auto printBytes = static_cast<USHORT>(target.size() * sizeof(wchar_t));
  std::vector<unsigned char> bytes(size_t{16} + subBytes + 2 + printBytes + 2, 0);
  const auto put16 = [&](size_t at, unsigned value) {
    bytes[at] = static_cast<unsigned char>(value & 255);
    bytes[at + 1] = static_cast<unsigned char>((value >> 8) & 255);
  };
  const DWORD tag = IO_REPARSE_TAG_MOUNT_POINT;
  std::memcpy(bytes.data(), &tag, sizeof(tag));
  put16(4, static_cast<unsigned>(bytes.size() - 8));
  put16(10, subBytes);
  put16(12, static_cast<unsigned>(subBytes) + 2u);
  put16(14, printBytes);
  std::memcpy(bytes.data() + 16, substitute.data(), subBytes);
  std::memcpy(bytes.data() + 16 + subBytes + 2, target.data(), printBytes);
  const auto handle = CreateFileW(name.c_str(), GENERIC_WRITE, 0, nullptr,
      OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
  Check(handle != INVALID_HANDLE_VALUE);
  DWORD returned = 0;
  const bool set = DeviceIoControl(handle, FSCTL_SET_REPARSE_POINT, bytes.data(),
      static_cast<DWORD>(bytes.size()), nullptr, 0, &returned, nullptr) != FALSE;
  CloseHandle(handle);
  Check(set);
}
void AncestorMatrix(const std::wstring& root) {
  const auto real = root + L"\\real";
  const auto leaf = real + L"\\leaf";
  const auto link = root + L"\\junction";
  const auto moved = root + L"\\moved";
  bool passed = false;
  try {
    Check(CreateDirectoryW(real.c_str(), nullptr) != FALSE);
    Check(CreateDirectoryW(leaf.c_str(), nullptr) != FALSE);
    Junction(link, real);
    Check(!nihongo::PendingCommandFileLease::Acquire(link)); // Final reparse.
    Check(!nihongo::PendingCommandFileLease::Acquire(link + L"\\leaf")); // Ancestor.
    Check(GetFileAttributesW((leaf + L"\\pending-command.lock").c_str()) == INVALID_FILE_ATTRIBUTES);
    // Failed walks release every prior ancestor; junction can still be renamed.
    Check(MoveFileW(link.c_str(), moved.c_str()) != FALSE);
    Check(MoveFileW(moved.c_str(), link.c_str()) != FALSE);
    auto lease = nihongo::PendingCommandFileLease::Acquire(leaf);
    Check(lease != nullptr); // Direct non-reparse control.
    Check(MoveFileW(real.c_str(), moved.c_str()) == FALSE);
    Check(DeleteFileW((leaf + L"\\pending-command.lock").c_str()) == FALSE);
    lease.reset();
    Check(MoveFileW(real.c_str(), moved.c_str()) != FALSE);
    Check(MoveFileW(moved.c_str(), real.c_str()) != FALSE);
    passed = true;
  } catch (...) { /* cleanup only the synthetic names, never follow junction */ }
  const bool unlinked = RemoveDirectoryW(link.c_str()) != FALSE;
  DeleteFileW((leaf + L"\\pending-command.lock").c_str());
  const bool leafRemoved = RemoveDirectoryW(leaf.c_str()) != FALSE;
  const bool realRemoved = RemoveDirectoryW(real.c_str()) != FALSE;
  Check(passed && unlinked && leafRemoved && realRemoved);
}
std::wstring FixtureUserSid() {
  struct Token {
    HANDLE value = nullptr;
    ~Token() { if (value) CloseHandle(value); }
  } token;
  Check(OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token.value) != FALSE);
  DWORD size = 0;
  GetTokenInformation(token.value, TokenUser, nullptr, 0, &size);
  Check(size > 0 && size <= 65536);
  std::vector<unsigned char> data(size);
  Check(GetTokenInformation(token.value, TokenUser, data.data(), size, &size) != FALSE);
  struct SidText {
    LPWSTR value = nullptr;
    ~SidText() { if (value) LocalFree(value); }
  } text;
  Check(ConvertSidToStringSidW(reinterpret_cast<TOKEN_USER*>(data.data())->User.Sid,
      &text.value) != FALSE);
  return std::wstring(text.value);
}
// TEST ONLY bounded classification of our synthetic descriptor, never a SID,
// path, SDDL, token, raw OS error or production failure detail. No assertion uses
// this diagnostic snapshot; the original exact checker remains authoritative.
void DescribeFixturePolicy(const std::wstring& directory, const std::wstring& user) {
  struct Local {
    void* value = nullptr;
    ~Local() { if (value) LocalFree(value); }
  } expected, descriptor;
  if (!ConvertStringSidToSidW(user.c_str(), &expected.value)) {
    std::cout << "CHECK: command ACL snapshot unavailable" << std::endl;
    return;
  }
  PSID owner = nullptr;
  PACL dacl = nullptr;
  auto name = directory;
  if (GetNamedSecurityInfoW(name.data(), SE_FILE_OBJECT,
      OWNER_SECURITY_INFORMATION | DACL_SECURITY_INFORMATION, &owner, nullptr,
      &dacl, nullptr, &descriptor.value) != ERROR_SUCCESS) {
    std::cout << "CHECK: command ACL snapshot unavailable" << std::endl;
    return;
  }
  SECURITY_DESCRIPTOR_CONTROL control = 0;
  DWORD revision = 0;
  const bool queried = GetSecurityDescriptorControl(descriptor.value, &control, &revision) != FALSE;
  bool flags = dacl && IsValidAcl(dacl);
  bool masks = flags;
  if (flags) {
    for (DWORD i = 0; i < dacl->AceCount; ++i) {
      void* raw = nullptr;
      if (!GetAce(dacl, i, &raw)) { flags = false; masks = false; break; }
      const auto ace = static_cast<ACCESS_ALLOWED_ACE*>(raw);
      flags = flags && ace->Header.AceType == ACCESS_ALLOWED_ACE_TYPE &&
          ace->Header.AceFlags == (OBJECT_INHERIT_ACE | CONTAINER_INHERIT_ACE);
      masks = masks && ace->Mask == FILE_ALL_ACCESS;
    }
  }
  std::cout << "CHECK: command ACL snapshot query=" << queried
      << " owner-match=" << (owner && IsValidSid(owner) && EqualSid(owner, expected.value))
      << " present=" << ((control & SE_DACL_PRESENT) != 0)
      << " protected=" << ((control & SE_DACL_PROTECTED) != 0)
      << " ace-count=" << (dacl ? dacl->AceCount : 0)
      << " exact-flags=" << flags << " full-control=" << masks << std::endl;
}
void PrivatePolicyMatrix(const std::wstring& root) {
  const auto user = FixtureUserSid();
  const auto current = L"(A;OICI;FA;;;" + user + L")";
  const std::wstring system = user == L"S-1-5-18" ? L"" : L"(A;OICI;FA;;;SY)";
  // TEST ONLY: no inheritable parent ACEs, so enabling inheritance on case 2
  // changes its protection bit without adding another reason for rejection.
  const auto parent = root + L"\\acl-parent";
  struct ParentCleanup {
    const std::wstring& path;
    bool created = false;
    ~ParentCleanup() { if (created) RemoveDirectoryW(path.c_str()); }
  } parentCleanup{parent};
  struct ParentSecurity {
    PSECURITY_DESCRIPTOR value = nullptr;
    ~ParentSecurity() { if (value) LocalFree(value); }
  } parentSecurity;
  const auto parentPolicy = L"O:" + user + L"D:P(A;;FA;;;" + user + L")" +
      (user == L"S-1-5-18" ? L"" : L"(A;;FA;;;SY)");
  Check(ConvertStringSecurityDescriptorToSecurityDescriptorW(parentPolicy.c_str(),
      SDDL_REVISION_1, &parentSecurity.value, nullptr) != FALSE);
  SECURITY_ATTRIBUTES parentAttributes{};
  parentAttributes.nLength = sizeof(parentAttributes);
  parentAttributes.lpSecurityDescriptor = parentSecurity.value;
  Check(CreateDirectoryW(parent.c_str(), &parentAttributes) != FALSE);
  parentCleanup.created = true;
  const std::vector<std::wstring> policies = {
      L"O:" + user + L"D:P" + current + system,
      L"O:" + user + L"D:P" + current + system + L"(A;OICI;GR;;;WD)",
      L"O:" + user + L"D:" + current + system,
      L"O:" + user + L"D:P" + current + system + L"(A;OICI;GR;;;BA)"};
  for (size_t i = 0; i < policies.size(); ++i) {
    std::cout << "CHECK: command ACL case " << i << " descriptor-create" << std::endl;
    const auto directory = parent + L"\\acl-" + std::to_wstring(i);
    struct Security {
      PSECURITY_DESCRIPTOR value = nullptr;
      ~Security() { if (value) LocalFree(value); }
    } security;
    Check(ConvertStringSecurityDescriptorToSecurityDescriptorW(policies[i].c_str(),
        SDDL_REVISION_1, &security.value, nullptr) != FALSE);
    SECURITY_ATTRIBUTES attributes{};
    attributes.nLength = sizeof(attributes);
    attributes.lpSecurityDescriptor = security.value;
    Check(CreateDirectoryW(directory.c_str(), &attributes) != FALSE);
    bool passed = false;
    try {
      if (i == 2) {
        // Omitting P from creation SDDL did not clear protection on the CI
        // filesystem. Explicitly set the documented inheritance flag instead.
        BOOL present = FALSE;
        BOOL defaulted = FALSE;
        PACL expected = nullptr;
        Check(GetSecurityDescriptorDacl(security.value, &present, &expected,
            &defaulted) != FALSE);
        Check(present && expected && IsValidAcl(expected));
        auto name = directory;
        Check(SetNamedSecurityInfoW(name.data(), SE_FILE_OBJECT,
            DACL_SECURITY_INFORMATION | UNPROTECTED_DACL_SECURITY_INFORMATION,
            nullptr, nullptr, expected, nullptr) == ERROR_SUCCESS);
        struct ActualSecurity {
          PSECURITY_DESCRIPTOR value = nullptr;
          ~ActualSecurity() { if (value) LocalFree(value); }
        } actual;
        PACL actualDacl = nullptr;
        Check(GetNamedSecurityInfoW(name.data(), SE_FILE_OBJECT,
            DACL_SECURITY_INFORMATION, nullptr, nullptr, &actualDacl, nullptr,
            &actual.value) == ERROR_SUCCESS);
        SECURITY_DESCRIPTOR_CONTROL control = 0;
        DWORD revision = 0;
        Check(GetSecurityDescriptorControl(actual.value, &control, &revision) != FALSE);
        Check((control & SE_DACL_PRESENT) != 0 && (control & SE_DACL_PROTECTED) == 0);
        Check(actualDacl && IsValidAcl(actualDacl) &&
            actualDacl->AceCount == expected->AceCount);
        for (DWORD at = 0; at < expected->AceCount; ++at) {
          void* want = nullptr;
          void* got = nullptr;
          Check(GetAce(expected, at, &want) != FALSE);
          Check(GetAce(actualDacl, at, &got) != FALSE);
          const auto bytes = static_cast<ACE_HEADER*>(want)->AceSize;
          Check(static_cast<ACE_HEADER*>(got)->AceSize == bytes &&
              std::memcmp(want, got, bytes) == 0);
        }
        std::cout << "CHECK: command ACL unprotected fixture exact ACEs verified" << std::endl;
      }
      DescribeFixturePolicy(directory, user);
      std::cout << "CHECK: command ACL case " << i << " acquire" << std::endl;
      auto lease = nihongo::PendingCommandFileLease::Acquire(directory);
      Check(lease != nullptr);
      std::cout << "CHECK: command ACL case " << i << " policy-first" << std::endl;
      Check(lease->HasPrivateDirectoryAccessPolicy() == (i == 0));
      std::cout << "CHECK: command ACL case " << i << " policy-repeat" << std::endl;
      Check(lease->HasPrivateDirectoryAccessPolicy() == (i == 0)); // Read only/idempotent.
      lease.reset();
      std::cout << "CHECK: command ACL case " << i << " reacquire" << std::endl;
      auto again = nihongo::PendingCommandFileLease::Acquire(directory);
      Check(again != nullptr);
      std::cout << "CHECK: command ACL case " << i << " policy-after-reacquire" << std::endl;
      Check(again->HasPrivateDirectoryAccessPolicy() == (i == 0));
      passed = true;
    } catch (...) { /* clean synthetic entries even on policy failure */ }
    std::cout << "CHECK: command ACL case " << i << " cleanup" << std::endl;
    const bool fileRemoved = DeleteFileW((directory + L"\\pending-command.lock").c_str()) != FALSE;
    const bool dirRemoved = RemoveDirectoryW(directory.c_str()) != FALSE;
    Check(passed && fileRemoved && dirRemoved);
    std::cout << "CHECK: command ACL case " << i << " complete" << std::endl;
  }
  Check(RemoveDirectoryW(parent.c_str()) != FALSE);
  parentCleanup.created = false;
}
void SentinelPolicyMatrix(const std::wstring& root) {
  const auto directory = root + L"\\sentinel-acl";
  const auto sentinel = directory + L"\\pending-command.lock";
  Check(CreateDirectoryW(directory.c_str(), nullptr) != FALSE);
  bool passed = false;
  try {
    const auto user = FixtureUserSid();
    for (const bool broad : {false, true}) {
      const auto policy = L"O:" + user + L"D:P(A;;FA;;;" + user + L")" +
          (user == L"S-1-5-18" ? L"" : L"(A;;FA;;;SY)") +
          (broad ? L"(A;;GR;;;WD)" : L"");
      struct Security {
        PSECURITY_DESCRIPTOR value = nullptr;
        ~Security() { if (value) LocalFree(value); }
      } security;
      Check(ConvertStringSecurityDescriptorToSecurityDescriptorW(policy.c_str(),
          SDDL_REVISION_1, &security.value, nullptr) != FALSE);
      SECURITY_ATTRIBUTES attributes{};
      attributes.nLength = sizeof(attributes);
      attributes.lpSecurityDescriptor = security.value;
      const auto file = CreateFileW(sentinel.c_str(), GENERIC_READ | GENERIC_WRITE,
          0, &attributes, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr);
      Check(file != INVALID_HANDLE_VALUE);
      CloseHandle(file);
      {
        auto lease = nihongo::PendingCommandFileLease::Acquire(directory);
        Check(lease != nullptr);
        Check(lease->HasPrivateSentinelAccessPolicy() == !broad);
        Check(lease->HasPrivateSentinelAccessPolicy() == !broad);
      }
      {
        auto lease = nihongo::PendingCommandFileLease::Acquire(directory);
        Check(lease != nullptr);
        Check(lease->HasPrivateSentinelAccessPolicy() == !broad);
      }
      WIN32_FILE_ATTRIBUTE_DATA info{};
      Check(GetFileAttributesExW(sentinel.c_str(), GetFileExInfoStandard, &info) != FALSE);
      Check(info.nFileSizeLow == 0 && info.nFileSizeHigh == 0);
      Check(DeleteFileW(sentinel.c_str()) != FALSE);
    }
    passed = true;
  } catch (...) { /* cleanup synthetic sentinel, no production ACL repair */ }
  DeleteFileW(sentinel.c_str());
  const bool removed = RemoveDirectoryW(directory.c_str()) != FALSE;
  Check(passed && removed);
  std::cout << "PASS: Windows command held sentinel private ACL/rejection/reacquire (TEST ONLY)" << std::endl;
}
// TEST ONLY: a pre-opened security-control handle deliberately outlives lease
// acquisition. Sharing excludes data writers, not an already authorized owner.
void HeldPolicyMutationMatrix(const std::wstring& root) {
  const auto directory = root + L"\\acl-mutation";
  const auto sentinel = directory + L"\\pending-command.lock";
  const auto user = FixtureUserSid();
  const auto policy = [&](bool folder, bool broad) {
    const std::wstring flags = folder ? L"OICI" : L"";
    return L"O:" + user + L"D:P(A;" + flags + L";FA;;;" + user + L")" +
        (user == L"S-1-5-18" ? L"" : L"(A;" + flags + L";FA;;;SY)") +
        (broad ? L"(A;" + flags + L";GR;;;WD)" : L"");
  };
  const auto apply = [&](HANDLE handle, bool folder, bool broad) {
    struct Security {
      PSECURITY_DESCRIPTOR value = nullptr;
      ~Security() { if (value) LocalFree(value); }
    } security;
    Check(ConvertStringSecurityDescriptorToSecurityDescriptorW(
        policy(folder, broad).c_str(), SDDL_REVISION_1, &security.value, nullptr) != FALSE);
    BOOL present = FALSE;
    BOOL defaulted = FALSE;
    PACL dacl = nullptr;
    Check(GetSecurityDescriptorDacl(security.value, &present, &dacl, &defaulted) != FALSE);
    Check(present && dacl && IsValidAcl(dacl)); // Never install a null DACL.
    Check(SetSecurityInfo(handle, SE_FILE_OBJECT,
        DACL_SECURITY_INFORMATION | PROTECTED_DACL_SECURITY_INFORMATION,
        nullptr, nullptr, dacl, nullptr) == ERROR_SUCCESS);
  };
  struct InitialSecurity {
    PSECURITY_DESCRIPTOR value = nullptr;
    ~InitialSecurity() { if (value) LocalFree(value); }
  } initialDirectory, initialFile;
  Check(ConvertStringSecurityDescriptorToSecurityDescriptorW(policy(true, false).c_str(),
      SDDL_REVISION_1, &initialDirectory.value, nullptr) != FALSE);
  Check(ConvertStringSecurityDescriptorToSecurityDescriptorW(policy(false, false).c_str(),
      SDDL_REVISION_1, &initialFile.value, nullptr) != FALSE);
  SECURITY_ATTRIBUTES directoryAttributes{};
  directoryAttributes.nLength = sizeof(directoryAttributes);
  directoryAttributes.lpSecurityDescriptor = initialDirectory.value;
  SECURITY_ATTRIBUTES fileAttributes{};
  fileAttributes.nLength = sizeof(fileAttributes);
  fileAttributes.lpSecurityDescriptor = initialFile.value;
  Check(CreateDirectoryW(directory.c_str(), &directoryAttributes) != FALSE);
  bool passed = false;
  try {
    struct Handle {
      HANDLE value = INVALID_HANDLE_VALUE;
      ~Handle() { if (value != INVALID_HANDLE_VALUE) CloseHandle(value); }
    } folder, file;
    folder.value = CreateFileW(directory.c_str(), READ_CONTROL | WRITE_DAC,
        FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING,
        FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
    Check(folder.value != INVALID_HANDLE_VALUE);
    apply(folder.value, true, false);
    file.value = CreateFileW(sentinel.c_str(), READ_CONTROL | WRITE_DAC,
        FILE_SHARE_READ | FILE_SHARE_WRITE, &fileAttributes, CREATE_NEW,
        FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
    Check(file.value != INVALID_HANDLE_VALUE);
    apply(file.value, false, false);
    std::cout << "CHECK: held ACL mutation acquire" << std::endl;
    auto lease = nihongo::PendingCommandFileLease::Acquire(directory);
    Check(lease != nullptr);
    Check(lease->HasPrivateDirectoryAccessPolicy());
    Check(lease->HasPrivateSentinelAccessPolicy());
    Check(lease->CheckPrivateAccessPolicy());
    Check(lease->CheckPrivateAccessPolicy());
    std::cout << "CHECK: held ACL mutation directory broad" << std::endl;
    apply(folder.value, true, true);
    Check(!lease->HasPrivateDirectoryAccessPolicy());
    Check(!lease->CheckPrivateAccessPolicy());
    Check(!lease->HasPrivateDirectoryAccessPolicy());
    Check(!lease->CheckPrivateAccessPolicy());
    Check(lease->HasPrivateSentinelAccessPolicy()); // Protected file stays separate.
    apply(folder.value, true, false);
    Check(lease->HasPrivateDirectoryAccessPolicy()); // Snapshot, not sticky authority.
    Check(!lease->CheckPrivateAccessPolicy());
    std::cout << "CHECK: held ACL mutation sentinel broad" << std::endl;
    apply(file.value, false, true);
    Check(!lease->HasPrivateSentinelAccessPolicy());
    Check(!lease->HasPrivateSentinelAccessPolicy());
    Check(lease->HasPrivateDirectoryAccessPolicy());
    apply(file.value, false, false);
    Check(lease->HasPrivateSentinelAccessPolicy());
    Check(!nihongo::PendingCommandFileLease::Acquire(directory));
    WIN32_FILE_ATTRIBUTE_DATA info{};
    Check(GetFileAttributesExW(sentinel.c_str(), GetFileExInfoStandard, &info) != FALSE);
    Check(info.nFileSizeLow == 0 && info.nFileSizeHigh == 0);
    Check(!lease->CheckPrivateAccessPolicy());
    // Fresh synthetic lease isolates sentinel-triggered failure from leaf failure.
    // Reacquiring is NOT a production reconciliation or restart permission.
    lease.reset();
    lease = nihongo::PendingCommandFileLease::Acquire(directory);
    Check(lease != nullptr);
    Check(lease->CheckPrivateAccessPolicy());
    apply(file.value, false, true);
    Check(lease->HasPrivateDirectoryAccessPolicy());
    Check(!lease->CheckPrivateAccessPolicy());
    Check(!lease->CheckPrivateAccessPolicy());
    apply(file.value, false, false);
    Check(lease->HasPrivateSentinelAccessPolicy());
    Check(lease->HasPrivateDirectoryAccessPolicy());
    Check(!lease->CheckPrivateAccessPolicy());
    Check(!lease->CheckPrivateAccessPolicy());
    Check(!nihongo::PendingCommandFileLease::Acquire(directory));
    Check(GetFileAttributesExW(sentinel.c_str(), GetFileExInfoStandard, &info) != FALSE);
    Check(info.nFileSizeLow == 0 && info.nFileSizeHigh == 0);
    passed = true;
  } catch (...) { /* RAII closes lease/control handles before synthetic cleanup */ }
  const bool fileRemoved = DeleteFileW(sentinel.c_str()) != FALSE;
  const bool dirRemoved = RemoveDirectoryW(directory.c_str()) != FALSE;
  Check(passed && fileRemoved && dirRemoved);
  std::cout << "PASS: Windows command held directory/sentinel ACL mutation snapshots (TEST ONLY)" << std::endl;
  std::cout << "PASS: Windows command lease sticky policy failure fence (TEST ONLY)" << std::endl;
}
// TEST ONLY subprocess, explicit whitelist and bounded wait, never a shell.
void StageExitProcess(const std::wstring& directory, const std::wstring& mode) {
  Check(mode == L"partial" || mode == L"flushed");
  wchar_t executable[32768]{};
  const auto length = GetModuleFileNameW(nullptr, executable, 32768);
  Check(length > 0 && length < 32768);
  std::wstring command = L"\"" + std::wstring(executable) +
      L"\" --command-stage-exit-child \"" + directory + L"\" " + mode;
  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  PROCESS_INFORMATION process{};
  Check(CreateProcessW(nullptr, command.data(), nullptr, nullptr, FALSE,
      CREATE_NO_WINDOW, nullptr, nullptr, &startup, &process) != FALSE);
  const auto wait = WaitForSingleObject(process.hProcess, 10000);
  DWORD code = 1;
  const bool queried = wait == WAIT_OBJECT_0 && GetExitCodeProcess(process.hProcess, &code) != FALSE;
  if (wait != WAIT_OBJECT_0) {
    TerminateProcess(process.hProcess, 1);
    WaitForSingleObject(process.hProcess, 5000);
  }
  CloseHandle(process.hThread);
  CloseHandle(process.hProcess);
  Check(wait == WAIT_OBJECT_0 && queried && code == 0);
}
// TEST ONLY opaque synthetic bytes; no learner text or valid-command assertion.
void CandidateReadMatrix(const std::wstring& root) {
  using State = nihongo::PendingCommandCandidateState;
  const auto directory = root + L"\\candidate-read";
  const auto sentinel = directory + L"\\pending-command.lock";
  const auto candidate = directory + L"\\pending-command.bin";
  const auto stage = directory + L"\\pending-command.stage";
  const auto alias = directory + L"\\candidate-alias";
  const auto target = directory + L"\\target";
  const auto user = FixtureUserSid();
  struct Security {
    PSECURITY_DESCRIPTOR value = nullptr;
    ~Security() { if (value) LocalFree(value); }
  } folderSecurity, fileSecurity, broadSecurity;
  const auto descriptor = [&](Security& out, bool folder, bool broad) {
    const std::wstring flags = folder ? L"OICI" : L"";
    const auto policy = L"O:" + user + L"D:P(A;" + flags + L";FA;;;" + user + L")" +
        (user == L"S-1-5-18" ? L"" : L"(A;" + flags + L";FA;;;SY)") +
        (broad ? L"(A;" + flags + L";GR;;;WD)" : L"");
    Check(ConvertStringSecurityDescriptorToSecurityDescriptorW(policy.c_str(),
        SDDL_REVISION_1, &out.value, nullptr) != FALSE);
  };
  descriptor(folderSecurity, true, false);
  descriptor(fileSecurity, false, false);
  descriptor(broadSecurity, false, true);
  SECURITY_ATTRIBUTES folderAttributes{};
  folderAttributes.nLength = sizeof(folderAttributes);
  folderAttributes.lpSecurityDescriptor = folderSecurity.value;
  const auto create = [&](const std::wstring& path, DWORD size, bool broad) {
    SECURITY_ATTRIBUTES attributes{};
    attributes.nLength = sizeof(attributes);
    attributes.lpSecurityDescriptor = broad ? broadSecurity.value : fileSecurity.value;
    const std::vector<unsigned char> bytes(size, 0xa5);
    const auto handle = CreateFileW(path.c_str(), GENERIC_WRITE, 0, &attributes,
        CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr);
    Check(handle != INVALID_HANDLE_VALUE);
    DWORD written = 0;
    const bool ok = size == 0 || WriteFile(handle, bytes.data(), size, &written, nullptr) != FALSE;
    CloseHandle(handle);
    Check(ok && written == size);
  };
  Check(CreateDirectoryW(directory.c_str(), &folderAttributes) != FALSE);
  bool passed = false;
  try {
    create(sentinel, 0, false);
    for (unsigned kind = 0; kind < 9; ++kind) {
      std::cout << "CHECK: ciphertext candidate case " << kind << std::endl;
      // absent, min, max, empty, oversized, broad ACL, hardlink, directory, junction.
      const DWORD size = kind == 2 ? 65536 : kind == 3 ? 0 : kind == 4 ? 65537 : 1;
      if (kind >= 1 && kind <= 6) create(candidate, size, kind == 5);
      if (kind == 6) Check(CreateHardLinkW(alias.c_str(), candidate.c_str(), nullptr) != FALSE);
      if (kind == 7) Check(CreateDirectoryW(candidate.c_str(), nullptr) != FALSE);
      if (kind == 8) {
        Check(CreateDirectoryW(target.c_str(), nullptr) != FALSE);
        Junction(candidate, target);
      }
      auto lease = nihongo::PendingCommandFileLease::Acquire(directory);
      Check(lease != nullptr);
      const auto result = lease->ReadCiphertextCandidate();
      if (kind == 0) {
        Check(result.state == State::absent && result.bytes.empty());
        Check(lease->ReadCiphertextCandidate().state == State::absent);
        Check(lease->CheckPrivateAccessPolicy());
      } else if (kind <= 2) {
        Check(result.state == State::present);
        Check(result.bytes == std::vector<unsigned char>(size, 0xa5));
        const auto repeat = lease->ReadCiphertextCandidate();
        Check(repeat.state == State::present && repeat.bytes == result.bytes);
        Check(lease->CheckPrivateAccessPolicy());
      } else {
        Check(result.state == State::unavailable && result.bytes.empty());
        Check(!lease->CheckPrivateAccessPolicy());
      }
      if (kind >= 1 && kind <= 6) {
        WIN32_FILE_ATTRIBUTE_DATA info{};
        Check(GetFileAttributesExW(candidate.c_str(), GetFileExInfoStandard, &info) != FALSE);
        Check(info.nFileSizeHigh == 0 && info.nFileSizeLow == size); // Never truncated.
      }
      if (kind == 6) Check(DeleteFileW(alias.c_str()) != FALSE);
      if (kind >= 1 && kind <= 6) Check(DeleteFileW(candidate.c_str()) != FALSE);
      if (kind >= 7) Check(RemoveDirectoryW(candidate.c_str()) != FALSE);
      if (kind == 8) {
        Check(GetFileAttributesW((target + L"\\pending-command.bin").c_str()) == INVALID_FILE_ATTRIBUTES);
        Check(RemoveDirectoryW(target.c_str()) != FALSE);
      }
      if (kind >= 3) {
        create(candidate, 1, false); // Repair synthetic fixture, NEVER reset lease.
        const auto denied = lease->ReadCiphertextCandidate();
        Check(denied.state == State::unavailable && denied.bytes.empty());
        Check(DeleteFileW(candidate.c_str()) != FALSE);
      }
    }
    {
      std::cout << "CHECK: ciphertext candidate sharing failure" << std::endl;
      create(candidate, 1, false);
      auto lease = nihongo::PendingCommandFileLease::Acquire(directory);
      Check(lease != nullptr);
      const auto initial = lease->ReadCiphertextCandidate();
      Check(initial.state == State::present && initial.bytes ==
          std::vector<unsigned char>(1, 0xa5));
      struct Handle {
        HANDLE value = INVALID_HANDLE_VALUE;
        ~Handle() { if (value != INVALID_HANDLE_VALUE) CloseHandle(value); }
      } blocker, control;
      blocker.value = CreateFileW(candidate.c_str(), GENERIC_READ,
          FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr,
          OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
      Check(blocker.value != INVALID_HANDLE_VALUE);
      // Independently prove the real OS failure condition before reader checks.
      control.value = CreateFileW(candidate.c_str(), GENERIC_READ | READ_CONTROL,
          0, nullptr, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
      const auto error = GetLastError();
      Check(control.value == INVALID_HANDLE_VALUE && error == ERROR_SHARING_VIOLATION);
      Check(lease->HasPrivateDirectoryAccessPolicy());
      Check(lease->HasPrivateSentinelAccessPolicy());
      const auto denied = lease->ReadCiphertextCandidate();
      Check(denied.state == State::unavailable && denied.bytes.empty());
      Check(!lease->CheckPrivateAccessPolicy());
      Check(CloseHandle(blocker.value) != FALSE);
      blocker.value = INVALID_HANDLE_VALUE;
      const auto afterRelease = lease->ReadCiphertextCandidate();
      Check(afterRelease.state == State::unavailable && afterRelease.bytes.empty());
      Check(!lease->CheckPrivateAccessPolicy());
      lease.reset();
      // TEST ONLY fresh-object control, never restart/reconciliation authority.
      lease = nihongo::PendingCommandFileLease::Acquire(directory);
      Check(lease != nullptr);
      const auto fresh = lease->ReadCiphertextCandidate();
      Check(fresh.state == State::present && fresh.bytes == initial.bytes);
      Check(lease->CheckPrivateAccessPolicy());
      Check(DeleteFileW(candidate.c_str()) != FALSE);
      std::cout << "PASS: Windows ciphertext candidate sharing failure/sticky release/control (TEST ONLY)" << std::endl;
    }
    const auto readStage = [&](const std::vector<unsigned char>& expected) {
      struct Handle {
        HANDLE value = INVALID_HANDLE_VALUE;
        ~Handle() { if (value != INVALID_HANDLE_VALUE) CloseHandle(value); }
      } file;
      file.value = CreateFileW(stage.c_str(), GENERIC_READ | READ_CONTROL, 0, nullptr,
          OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
      Check(file.value != INVALID_HANDLE_VALUE);
      std::vector<unsigned char> actual(expected.size());
      DWORD read = 0;
      Check(ReadFile(file.value, actual.data(), static_cast<DWORD>(actual.size()), &read, nullptr) != FALSE);
      Check(read == expected.size() && actual == expected);
      unsigned char extra = 0;
      Check(ReadFile(file.value, &extra, 1, &read, nullptr) != FALSE && read == 0);
      BY_HANDLE_FILE_INFORMATION info{};
      Check(GetFileInformationByHandle(file.value, &info) != FALSE);
      Check(info.nNumberOfLinks == 1 && info.nFileSizeHigh == 0 && info.nFileSizeLow == expected.size());
      struct SecuritySnapshot {
        PSECURITY_DESCRIPTOR value = nullptr;
        ~SecuritySnapshot() { if (value) LocalFree(value); }
      } snapshot;
      PSID owner = nullptr;
      PACL dacl = nullptr;
      Check(GetSecurityInfo(file.value, SE_FILE_OBJECT, OWNER_SECURITY_INFORMATION |
          DACL_SECURITY_INFORMATION, &owner, nullptr, &dacl, nullptr, &snapshot.value) == ERROR_SUCCESS);
      SECURITY_DESCRIPTOR_CONTROL control = 0;
      DWORD revision = 0;
      Check(GetSecurityDescriptorControl(snapshot.value, &control, &revision) != FALSE);
      Check((control & SE_DACL_PRESENT) != 0 && (control & SE_DACL_PROTECTED) != 0);
      PSID expectedOwner = nullptr;
      BOOL defaulted = FALSE;
      Check(GetSecurityDescriptorOwner(fileSecurity.value, &expectedOwner, &defaulted) != FALSE);
      Check(owner && IsValidSid(owner) && EqualSid(owner, expectedOwner));
      PACL expectedDacl = nullptr;
      BOOL present = FALSE;
      Check(GetSecurityDescriptorDacl(fileSecurity.value, &present, &expectedDacl, &defaulted) != FALSE);
      Check(present && expectedDacl && dacl && IsValidAcl(dacl) && dacl->AceCount == expectedDacl->AceCount);
      for (DWORD i = 0; i < expectedDacl->AceCount; ++i) {
        void* want = nullptr;
        Check(GetAce(expectedDacl, i, &want) != FALSE);
        const auto size = static_cast<ACE_HEADER*>(want)->AceSize;
        bool found = false;
        for (DWORD j = 0; j < dacl->AceCount; ++j) {
          void* got = nullptr;
          Check(GetAce(dacl, j, &got) != FALSE);
          found = found || (static_cast<ACE_HEADER*>(got)->AceSize == size &&
              std::memcmp(want, got, size) == 0);
        }
        Check(found); // Exact explicit ACEs, order independent of SetEntriesInAcl.
      }
    };
    for (const size_t size : {size_t{0}, size_t{65537}, size_t{1}, size_t{65536}}) {
      std::cout << "CHECK: ciphertext stage bound " << size << std::endl;
      auto lease = nihongo::PendingCommandFileLease::Acquire(directory);
      Check(lease != nullptr);
      const std::vector<unsigned char> bytes(size, 0xa5);
      const bool staged = lease->StageCiphertextCandidate(bytes);
      Check(staged == (size > 0 && size <= 65536));
      Check(GetFileAttributesW(candidate.c_str()) == INVALID_FILE_ATTRIBUTES); // Not published.
      if (!staged) {
        Check(GetFileAttributesW(stage.c_str()) == INVALID_FILE_ATTRIBUTES);
        Check(!lease->CheckPrivateAccessPolicy());
        Check(!lease->StageCiphertextCandidate(std::vector<unsigned char>(1, 0x5a)));
      } else {
        readStage(bytes); // Independently read exact bytes and owner/DACL.
        Check(lease->CheckPrivateAccessPolicy());
        Check(lease->ReadCiphertextCandidate().state == State::absent); // No commit authority.
        Check(!lease->StageCiphertextCandidate(std::vector<unsigned char>(1, 0x5a)));
        Check(!lease->CheckPrivateAccessPolicy());
        readStage(bytes); // Duplicate attempt never overwrites the first stage.
        lease.reset();
        lease = nihongo::PendingCommandFileLease::Acquire(directory);
        Check(lease != nullptr);
        Check(!lease->StageCiphertextCandidate(std::vector<unsigned char>(1, 0x5a)));
        Check(!lease->CheckPrivateAccessPolicy());
        readStage(bytes); // Abandoned stage remains a conflict across objects.
        Check(DeleteFileW(stage.c_str()) != FALSE); // Synthetic cleanup only.
      }
    }
    {
      create(candidate, 1, false);
      auto lease = nihongo::PendingCommandFileLease::Acquire(directory);
      Check(lease != nullptr);
      Check(!lease->StageCiphertextCandidate(std::vector<unsigned char>(1, 0x5a)));
      Check(!lease->CheckPrivateAccessPolicy());
      Check(GetFileAttributesW(stage.c_str()) == INVALID_FILE_ATTRIBUTES);
      WIN32_FILE_ATTRIBUTE_DATA info{};
      Check(GetFileAttributesExW(candidate.c_str(), GetFileExInfoStandard, &info) != FALSE);
      Check(info.nFileSizeHigh == 0 && info.nFileSizeLow == 1);
      const auto original = CreateFileW(candidate.c_str(), GENERIC_READ, 0, nullptr,
          OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
      Check(original != INVALID_HANDLE_VALUE);
      unsigned char byte = 0;
      DWORD read = 0;
      const bool unchanged = ReadFile(original, &byte, 1, &read, nullptr) != FALSE;
      const bool closed = CloseHandle(original) != FALSE;
      Check(unchanged && read == 1 && byte == 0xa5 && closed);
      Check(DeleteFileW(candidate.c_str()) != FALSE);
    }
    std::cout << "PASS: Windows ciphertext create-new private stage/flush/bounds/no-overwrite/no-publish (TEST ONLY)" << std::endl;
    for (const auto& mode : {std::wstring(L"partial"), std::wstring(L"flushed")}) {
      std::cout << "CHECK: ciphertext stage child exit " << (mode == L"partial" ? "partial-fixture" : "real-flushed-stage") << std::endl;
      StageExitProcess(directory, mode);
      const std::vector<unsigned char> expected(mode == L"partial" ? size_t{3} : size_t{65536}, 0xa5);
      auto lease = nihongo::PendingCommandFileLease::Acquire(directory);
      Check(lease != nullptr); // Child ExitProcess released lease without C++ destruction.
      Check(lease->CheckPrivateAccessPolicy());
      readStage(expected); // Same exact bytes, owner and ACL after subprocess exit.
      Check(GetFileAttributesW(candidate.c_str()) == INVALID_FILE_ATTRIBUTES);
      const auto unpublished = lease->ReadCiphertextCandidate();
      Check(unpublished.state == State::absent && unpublished.bytes.empty());
      Check(!lease->StageCiphertextCandidate(std::vector<unsigned char>(1, 0x5a)));
      Check(!lease->CheckPrivateAccessPolicy());
      readStage(expected); // Neither complete nor partial abandoned stage is replaced.
      Check(DeleteFileW(stage.c_str()) != FALSE); // Unique synthetic cleanup ONLY.
    }
    std::cout << "PASS: Windows ciphertext stage subprocess abrupt-exit/preserve/no-publish (TEST ONLY)" << std::endl;
    const auto checkCollisionMarker = [&](const std::wstring& path) {
      struct Handle {
        HANDLE value = INVALID_HANDLE_VALUE;
        ~Handle() { if (value != INVALID_HANDLE_VALUE) CloseHandle(value); }
      } file;
      file.value = CreateFileW(path.c_str(), GENERIC_READ, 0, nullptr,
          OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
      Check(file.value != INVALID_HANDLE_VALUE);
      BY_HANDLE_FILE_INFORMATION info{};
      Check(GetFileInformationByHandle(file.value, &info) != FALSE);
      Check(info.nFileSizeHigh == 0 && info.nFileSizeLow == 1 && info.nNumberOfLinks == 1);
      unsigned char byte = 0;
      DWORD read = 0;
      Check(ReadFile(file.value, &byte, 1, &read, nullptr) != FALSE);
      Check(read == 1 && byte == 0xa5);
    };
    for (const bool reparse : {false, true}) {
      std::cout << "CHECK: ciphertext stage collision " << (reparse ? "junction" : "directory") << std::endl;
      const auto keep = (reparse ? target : stage) + L"\\collision-marker";
      if (reparse) {
        Check(CreateDirectoryW(target.c_str(), nullptr) != FALSE);
        create(keep, 1, false);
        Junction(stage, target);
      } else {
        Check(CreateDirectoryW(stage.c_str(), nullptr) != FALSE);
        create(keep, 1, false);
      }
      auto lease = nihongo::PendingCommandFileLease::Acquire(directory);
      Check(lease != nullptr);
      Check(lease->CheckPrivateAccessPolicy());
      Check(!lease->StageCiphertextCandidate(std::vector<unsigned char>(1, 0x5a)));
      Check(!lease->CheckPrivateAccessPolicy());
      const auto attributes = GetFileAttributesW(stage.c_str());
      Check(attributes != INVALID_FILE_ATTRIBUTES && (attributes & FILE_ATTRIBUTE_DIRECTORY) != 0);
      Check(((attributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0) == reparse);
      checkCollisionMarker(keep); // Exact original bytes remain in the collision/target.
      Check(GetFileAttributesW(candidate.c_str()) == INVALID_FILE_ATTRIBUTES);
      const auto collisionTarget = reparse ? target : stage;
      Check(GetFileAttributesW((collisionTarget + L"\\pending-command.stage").c_str()) == INVALID_FILE_ATTRIBUTES);
      Check(GetFileAttributesW((collisionTarget + L"\\pending-command.bin").c_str()) == INVALID_FILE_ATTRIBUTES);
      if (!reparse) Check(DeleteFileW(keep.c_str()) != FALSE);
      Check(RemoveDirectoryW(stage.c_str()) != FALSE); // Unlink junction itself, no traversal.
      if (reparse) checkCollisionMarker(keep); // Target survives unlinking.
      Check(!lease->StageCiphertextCandidate(std::vector<unsigned char>(1, 0x5a)));
      Check(!lease->CheckPrivateAccessPolicy());
      Check(GetFileAttributesW(stage.c_str()) == INVALID_FILE_ATTRIBUTES);
      if (reparse) {
        Check(DeleteFileW(keep.c_str()) != FALSE);
        Check(RemoveDirectoryW(target.c_str()) != FALSE);
      }
    }
    std::cout << "PASS: Windows ciphertext stage directory/junction collision preserve/sticky rejection (TEST ONLY)" << std::endl;
    passed = true;
  } catch (...) { /* cleanup only unique synthetic entries, never follow junction */ }
  DeleteFileW(alias.c_str());
  const auto stageAttributes = GetFileAttributesW(stage.c_str());
  if (stageAttributes != INVALID_FILE_ATTRIBUTES &&
      (stageAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0 &&
      (stageAttributes & FILE_ATTRIBUTE_REPARSE_POINT) == 0)
    DeleteFileW((stage + L"\\collision-marker").c_str());
  DeleteFileW(stage.c_str());
  RemoveDirectoryW(stage.c_str());
  DeleteFileW((target + L"\\collision-marker").c_str());
  DeleteFileW(candidate.c_str());
  RemoveDirectoryW(candidate.c_str());
  RemoveDirectoryW(target.c_str());
  const bool fileRemoved = DeleteFileW(sentinel.c_str()) != FALSE;
  const bool dirRemoved = RemoveDirectoryW(directory.c_str()) != FALSE;
  Check(passed && fileRemoved && dirRemoved);
  std::cout << "PASS: Windows bounded ciphertext candidate read/ACL/link/reparse/sticky failure (TEST ONLY)" << std::endl;
}
void Child(const std::wstring& directory, DWORD expected) {
  wchar_t executable[32768]{};
  const auto length = GetModuleFileNameW(nullptr, executable, 32768);
  Check(length > 0 && length < 32768);
  std::wstring command = L"\"" + std::wstring(executable) +
      L"\" --command-lease-child \"" + directory + L"\"";
  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  PROCESS_INFORMATION process{};
  Check(CreateProcessW(nullptr, command.data(), nullptr, nullptr, FALSE,
      CREATE_NO_WINDOW, nullptr, nullptr, &startup, &process) != FALSE);
  const auto wait = WaitForSingleObject(process.hProcess, 10000);
  DWORD code = 1;
  if (wait == WAIT_OBJECT_0) GetExitCodeProcess(process.hProcess, &code);
  else { TerminateProcess(process.hProcess, 1); WaitForSingleObject(process.hProcess, 5000); }
  CloseHandle(process.hThread);
  CloseHandle(process.hProcess);
  Check(wait == WAIT_OBJECT_0 && code == expected);
}
}  // namespace
int CommandLeaseChild(const std::wstring& directory) {
  const auto lease = nihongo::PendingCommandFileLease::Acquire(directory);
  // Bypass C++ destruction deliberately: OS must reclaim handles on process exit.
  ExitProcess(lease ? 0 : 3);
}
// TEST ONLY: flushed mode uses actual production staging. Partial mode is an
// explicit synthetic incomplete-stage producer, NOT a Stage() fault injection.
int CommandStageExitChild(const std::wstring& directory, const std::wstring& mode) {
  try {
    if (mode != L"partial" && mode != L"flushed") ExitProcess(5);
    const auto lease = nihongo::PendingCommandFileLease::Acquire(directory);
    if (!lease || !lease->CheckPrivateAccessPolicy()) ExitProcess(5);
    if (mode == L"flushed") {
      const bool staged = lease->StageCiphertextCandidate(std::vector<unsigned char>(65536, 0xa5));
      ExitProcess(staged ? 0 : 5); // Deliberately bypass lease's C++ destructor.
    }
    const auto user = FixtureUserSid();
    const auto policy = L"O:" + user + L"D:P(A;;FA;;;" + user + L")" +
        (user == L"S-1-5-18" ? L"" : L"(A;;FA;;;SY)");
    struct Security {
      PSECURITY_DESCRIPTOR value = nullptr;
      ~Security() { if (value) LocalFree(value); }
    } security;
    if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(policy.c_str(),
        SDDL_REVISION_1, &security.value, nullptr)) ExitProcess(5);
    SECURITY_ATTRIBUTES attributes{};
    attributes.nLength = sizeof(attributes);
    attributes.lpSecurityDescriptor = security.value;
    const auto path = directory + L"\\pending-command.stage";
    const auto file = CreateFileW(path.c_str(), GENERIC_WRITE, 0, &attributes,
        CREATE_NEW, FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
    if (file == INVALID_HANDLE_VALUE) ExitProcess(5);
    const unsigned char bytes[3] = {0xa5, 0xa5, 0xa5};
    DWORD written = 0;
    const bool partial = WriteFile(file, bytes, static_cast<DWORD>(sizeof(bytes)), &written, nullptr) != FALSE;
    // No explicit flush or CloseHandle, no C++ destruction: OS exit cleanup.
    ExitProcess(partial && written == sizeof(bytes) ? 0 : 5);
  } catch (...) { ExitProcess(5); }
}
bool ProbePendingCommandFileLease() {
  wchar_t temp[MAX_PATH]{};
  const auto count = GetTempPathW(MAX_PATH, temp);
  Check(count > 0 && count < MAX_PATH);
  const auto directory = std::wstring(temp) + L"nd-command-lease-" +
      std::to_wstring(GetCurrentProcessId()) + L"-" + std::to_wstring(GetTickCount64());
  for (const auto& invalid : {L"", L"relative", L"C:\\safe\\..", L"C:\\safe:ads", L"\\\\server\\path"})
    Check(!nihongo::PendingCommandFileLease::Acquire(invalid));
  Check(CreateDirectoryW(directory.c_str(), nullptr) != FALSE);
  const auto sentinel = directory + L"\\pending-command.lock";
  const auto alias = directory + L"\\alias.lock";
  bool passed = false;
  try {
    std::cout << "CHECK: command lease original process matrix" << std::endl;
    auto lease = nihongo::PendingCommandFileLease::Acquire(directory);
    Check(lease != nullptr);
    Check(!nihongo::PendingCommandFileLease::Acquire(directory));
    Child(directory, 3);
    Check(DeleteFileW(sentinel.c_str()) == FALSE);
    Check(MoveFileW(directory.c_str(), (directory + L"-moved").c_str()) == FALSE);
    lease.reset();
    Child(directory, 0); // Abrupt exit, no destructor; then parent reacquires.
    lease = nihongo::PendingCommandFileLease::Acquire(directory);
    Check(lease != nullptr);
    lease.reset();
    Check(CreateHardLinkW(alias.c_str(), sentinel.c_str(), nullptr) != FALSE);
    Check(!nihongo::PendingCommandFileLease::Acquire(directory));
    Check(DeleteFileW(alias.c_str()) != FALSE);
    auto file = CreateFileW(sentinel.c_str(), GENERIC_WRITE, 0, nullptr,
        OPEN_EXISTING, 0, nullptr);
    Check(file != INVALID_HANDLE_VALUE);
    DWORD written = 0;
    const char marker = 'x';
    const bool wrote = WriteFile(file, &marker, 1, &written, nullptr) != FALSE;
    CloseHandle(file);
    Check(wrote && written == 1);
    Check(!nihongo::PendingCommandFileLease::Acquire(directory));
    WIN32_FILE_ATTRIBUTE_DATA info{};
    Check(GetFileAttributesExW(sentinel.c_str(), GetFileExInfoStandard, &info) != FALSE);
    Check(info.nFileSizeLow == 1); // Reject without truncating unknown content.
    Check(DeleteFileW(sentinel.c_str()) != FALSE);
    Check(CreateDirectoryW(sentinel.c_str(), nullptr) != FALSE);
    Check(!nihongo::PendingCommandFileLease::Acquire(directory));
    Check(RemoveDirectoryW(sentinel.c_str()) != FALSE);
    Check(nihongo::PendingCommandFileLease::Acquire(directory) != nullptr);
    std::cout << "CHECK: command lease ancestor matrix" << std::endl;
    AncestorMatrix(directory);
    std::cout << "CHECK: command lease ACL matrix" << std::endl;
    PrivatePolicyMatrix(directory);
    SentinelPolicyMatrix(directory);
    HeldPolicyMutationMatrix(directory);
    CandidateReadMatrix(directory);
    std::cout << "CHECK: command lease all matrices complete" << std::endl;
    passed = true;
  } catch (...) { /* fixed outer failure, still clean synthetic namespace */ }
  DeleteFileW(alias.c_str());
  DeleteFileW(sentinel.c_str());
  RemoveDirectoryW(sentinel.c_str());
  const bool removed = RemoveDirectoryW(directory.c_str()) != FALSE;
  return passed && removed;
}
#else
int main() {
  for (const auto& path : {L"", L"relative", L"C:\\safe", L"C:\\safe\\..", L"C:\\safe:ads", L"\\\\server\\path"})
    if (nihongo::PendingCommandFileLease::Acquire(path)) return 1;
  return 0;
}
#endif
