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
  const std::vector<std::wstring> policies = {
      L"O:" + user + L"D:P" + current + system,
      L"O:" + user + L"D:P" + current + system + L"(A;OICI;GR;;;WD)",
      L"O:" + user + L"D:" + current + system,
      L"O:" + user + L"D:P" + current + system + L"(A;OICI;GR;;;BA)"};
  for (size_t i = 0; i < policies.size(); ++i) {
    std::cout << "CHECK: command ACL case " << i << " descriptor-create" << std::endl;
    const auto directory = root + L"\\acl-" + std::to_wstring(i);
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
    DescribeFixturePolicy(directory, user);
    bool passed = false;
    try {
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
