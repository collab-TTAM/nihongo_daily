#include "pending_command_file_lease.h"
#ifdef _WIN32
#include <windows.h>
#include <aclapi.h>
#include <cstddef>
#endif
namespace nihongo {
namespace {
bool ValidDirectory(const std::wstring& path) {
  if (path.size() < 4 || path.size() > 220 || path[1] != L':' ||
      path[2] != L'\\' || !((path[0] >= L'A' && path[0] <= L'Z') ||
                            (path[0] >= L'a' && path[0] <= L'z'))) return false;
  size_t start = 3;
  for (size_t i = 3; i <= path.size(); ++i) {
    if (i == path.size() || path[i] == L'\\') {
      const auto part = path.substr(start, i - start);
      if (part.empty() || part == L"." || part == L".." ||
          part.back() == L'.' || part.back() == L' ') return false;
      start = i + 1;
    } else if (path[i] < 32 || std::wstring(L"/:<>\"|?*").find(path[i]) !=
                                  std::wstring::npos) return false;
  }
  return true;
}
#ifdef _WIN32
bool Ordinary(HANDLE handle, bool directory) {
  BY_HANDLE_FILE_INFORMATION info{};
  if (GetFileType(handle) != FILE_TYPE_DISK ||
      !GetFileInformationByHandle(handle, &info) ||
      (info.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0 ||
      ((info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0) != directory)
    return false;
  return directory || (info.nNumberOfLinks == 1 && info.nFileSizeHigh == 0 &&
                       info.nFileSizeLow == 0);
}
#endif
}  // namespace
namespace {
#ifdef _WIN32
bool PrivatePolicy(HANDLE handle, BYTE expectedFlags) noexcept {
  try {
    if (!handle) return false;
    struct Token {
      HANDLE value = nullptr;
      ~Token() { if (value) CloseHandle(value); }
    } token;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token.value)) return false;
    DWORD length = 0;
    GetTokenInformation(token.value, TokenUser, nullptr, 0, &length);
    if (length == 0 || length > 65536) return false;
    std::vector<unsigned char> data(length);
    if (!GetTokenInformation(token.value, TokenUser, data.data(), length, &length)) return false;
    const auto user = reinterpret_cast<TOKEN_USER*>(data.data())->User.Sid;
    if (!IsValidSid(user)) return false;
    struct Security {
      PSECURITY_DESCRIPTOR value = nullptr;
      ~Security() { if (value) LocalFree(value); }
    } security;
    PSID owner = nullptr;
    PACL dacl = nullptr;
    if (GetSecurityInfo(handle, SE_FILE_OBJECT,
        OWNER_SECURITY_INFORMATION | DACL_SECURITY_INFORMATION, &owner, nullptr,
        &dacl, nullptr, &security.value) != ERROR_SUCCESS) return false;
    SECURITY_DESCRIPTOR_CONTROL control = 0;
    DWORD revision = 0;
    if (!owner || !IsValidSid(owner) || !EqualSid(owner, user) || !dacl ||
        !IsValidAcl(dacl) || !GetSecurityDescriptorControl(security.value, &control, &revision) ||
        (control & SE_DACL_PRESENT) == 0 || (control & SE_DACL_PROTECTED) == 0) return false;
    BYTE system[SECURITY_MAX_SID_SIZE]{};
    DWORD systemSize = sizeof(system);
    if (!CreateWellKnownSid(WinLocalSystemSid, nullptr, system, &systemSize)) return false;
    const bool userIsSystem = EqualSid(user, system) != FALSE;
    if (dacl->AceCount != (userIsSystem ? 1 : 2)) return false;
    bool sawUser = false;
    bool sawSystem = userIsSystem;
    for (DWORD i = 0; i < dacl->AceCount; ++i) {
      void* raw = nullptr;
      if (!GetAce(dacl, i, &raw)) return false;
      const auto ace = static_cast<ACCESS_ALLOWED_ACE*>(raw);
      if (ace->Header.AceType != ACCESS_ALLOWED_ACE_TYPE ||
          ace->Header.AceFlags != expectedFlags ||
          static_cast<size_t>(ace->Header.AceSize) < sizeof(ACCESS_ALLOWED_ACE) || ace->Mask != FILE_ALL_ACCESS) return false;
      const auto sid = static_cast<PSID>(&ace->SidStart);
      if (!IsValidSid(sid) || GetLengthSid(sid) >
          ace->Header.AceSize - offsetof(ACCESS_ALLOWED_ACE, SidStart)) return false;
      if (EqualSid(sid, user) && !sawUser) sawUser = true;
      else if (EqualSid(sid, system) && !sawSystem) sawSystem = true;
      else return false;
    }
    return sawUser && sawSystem;
  } catch (...) { return false; }
}
#endif
}  // namespace
bool PendingCommandFileLease::HasPrivateDirectoryAccessPolicy() const noexcept {
#ifdef _WIN32
  return !directories_.empty() && PrivatePolicy(
      static_cast<HANDLE>(directories_.back()), OBJECT_INHERIT_ACE | CONTAINER_INHERIT_ACE);
#else
  return false;
#endif
}
bool PendingCommandFileLease::HasPrivateSentinelAccessPolicy() const noexcept {
#ifdef _WIN32
  return PrivatePolicy(static_cast<HANDLE>(file_), 0);
#else
  return false;
#endif
}
PendingCommandFileLease::~PendingCommandFileLease() {
#ifdef _WIN32
  if (file_) CloseHandle(static_cast<HANDLE>(file_));
  for (auto it = directories_.rbegin(); it != directories_.rend(); ++it)
    if (*it) CloseHandle(static_cast<HANDLE>(*it));
#endif
}
std::unique_ptr<PendingCommandFileLease> PendingCommandFileLease::Acquire(
    const std::wstring& trusted_directory) noexcept {
  try {
    if (!ValidDirectory(trusted_directory)) return nullptr;
#ifdef _WIN32
    auto lease = std::unique_ptr<PendingCommandFileLease>(new PendingCommandFileLease());
    // Open each ancestor itself (never follow its final reparse point), from
    // drive root downwards. Keep every validated name pinned against rename
    // until the sentinel closes. This does NOT validate ACLs or writer identity.
    for (size_t end = 3; end <= trusted_directory.size(); ++end) {
      if (end != 3 && end != trusted_directory.size() &&
          trusted_directory[end] != L'\\') continue;
      const auto ancestor = trusted_directory.substr(0, end);
      // Reserve ownership before CreateFile: vector allocation cannot leak a
      // newly opened handle, including failures part-way through the walk.
      lease->directories_.push_back(nullptr);
      const auto dir = CreateFileW(ancestor.c_str(), FILE_READ_ATTRIBUTES |
          (end == trusted_directory.size() ? READ_CONTROL : 0),
          FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING,
          FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
      if (dir == INVALID_HANDLE_VALUE) return nullptr;
      lease->directories_.back() = dir;
      if (!Ordinary(dir, true)) return nullptr;
    }
    const auto path = trusted_directory + L"\\pending-command.lock";
    const auto file = CreateFileW(path.c_str(), GENERIC_READ | GENERIC_WRITE,
        0, nullptr, OPEN_ALWAYS, FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
    if (file == INVALID_HANDLE_VALUE) return nullptr;
    lease->file_ = file;
    if (!Ordinary(file, false)) return nullptr;
    // Never truncate, write, delete, or inherit any handle. Keep the stable
    // sentinel after release/crash; deleting it could split competing writers.
    return lease;
#else
    return nullptr;
#endif
  } catch (...) {
    return nullptr; // No path/OS diagnostics or plaintext fallback.
  }
}
}  // namespace nihongo
