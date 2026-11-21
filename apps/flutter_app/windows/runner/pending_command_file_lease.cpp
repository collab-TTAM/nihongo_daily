#include "pending_command_file_lease.h"
#ifdef _WIN32
#include <windows.h>
#include <aclapi.h>
#include <cstddef>
#include <cstring>
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
bool PendingCommandFileLease::CheckPrivateAccessPolicy() noexcept {
  if (policy_failed_) return false;
  if (!HasPrivateDirectoryAccessPolicy() || !HasPrivateSentinelAccessPolicy()) {
    policy_failed_ = true;
    return false;
  }
  return true;
}
PendingCommandFileLease::~PendingCommandFileLease() {
#ifdef _WIN32
  if (file_) CloseHandle(static_cast<HANDLE>(file_));
  for (auto it = directories_.rbegin(); it != directories_.rend(); ++it)
    if (*it) CloseHandle(static_cast<HANDLE>(*it));
#endif
}
PendingCommandCandidate PendingCommandFileLease::ReadCiphertextCandidate() noexcept {
  const auto fail = [&]() {
    policy_failed_ = true;
    return PendingCommandCandidate{};
  };
  try {
    if (!CheckPrivateAccessPolicy()) return fail();
#ifdef _WIN32
    struct File {
      HANDLE value = INVALID_HANDLE_VALUE;
      ~File() { if (value != INVALID_HANDLE_VALUE) CloseHandle(value); }
    } file;
    const auto path = directory_ + L"\\pending-command.bin";
    file.value = CreateFileW(path.c_str(), GENERIC_READ | READ_CONTROL, 0, nullptr,
        OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
    if (file.value == INVALID_HANDLE_VALUE) {
      const auto error = GetLastError();
      if (error != ERROR_FILE_NOT_FOUND || !CheckPrivateAccessPolicy()) return fail();
      return {PendingCommandCandidateState::absent, {}};
    }
    const auto bounded = [&](BY_HANDLE_FILE_INFORMATION& info) {
      return GetFileType(file.value) == FILE_TYPE_DISK &&
          GetFileInformationByHandle(file.value, &info) &&
          (info.dwFileAttributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT)) == 0 &&
          info.nNumberOfLinks == 1 && info.nFileSizeHigh == 0 &&
          info.nFileSizeLow > 0 && info.nFileSizeLow <= 65536 &&
          PrivatePolicy(file.value, 0);
    };
    BY_HANDLE_FILE_INFORMATION before{}, after{};
    if (!bounded(before)) return fail(); // Before allocating the candidate buffer.
    PendingCommandCandidate result;
    result.bytes.resize(before.nFileSizeLow);
    DWORD read = 0;
    if (!ReadFile(file.value, result.bytes.data(), before.nFileSizeLow, &read, nullptr) ||
        read != before.nFileSizeLow || !bounded(after) ||
        after.nFileSizeLow != before.nFileSizeLow || !CheckPrivateAccessPolicy()) return fail();
    result.state = PendingCommandCandidateState::present;
    return result;
#else
    return fail();
#endif
  } catch (...) { return fail(); } // Never publish partial bytes or raw OS errors.
}
PendingCommandCandidate PendingCommandFileLease::ReadRecoveryCiphertextCandidate() noexcept {
  const auto fail = [&]() {
    policy_failed_ = true;
    return PendingCommandCandidate{};
  };
  try {
    if (!CheckPrivateAccessPolicy()) return fail();
#ifdef _WIN32
    const auto stageAbsent = [&]() {
      struct File {
        HANDLE value = INVALID_HANDLE_VALUE;
        ~File() { if (value != INVALID_HANDLE_VALUE) CloseHandle(value); }
      } file;
      const auto path = directory_ + L"\\pending-command.stage";
      file.value = CreateFileW(path.c_str(), FILE_READ_ATTRIBUTES, 0, nullptr,
          OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS, nullptr);
      // Any object, including directory/reparse, is unresolved. Never follow,
      // read, repair, adopt or delete it. Only definite filename absence passes.
      if (file.value != INVALID_HANDLE_VALUE) return false;
      return GetLastError() == ERROR_FILE_NOT_FOUND && CheckPrivateAccessPolicy();
    };
    if (!stageAbsent()) return fail();
    auto candidate = ReadCiphertextCandidate();
    if (candidate.state == PendingCommandCandidateState::unavailable ||
        !stageAbsent() || !CheckPrivateAccessPolicy()) return fail();
    return candidate; // Opaque snapshot only; no durable reservation/replay authority.
#else
    return fail();
#endif
  } catch (...) { return fail(); }
}
bool PendingCommandFileLease::StageCiphertextCandidate(
    const std::vector<unsigned char>& bytes) noexcept {
  const auto fail = [&]() { policy_failed_ = true; return false; };
  try {
    if (bytes.empty() || bytes.size() > 65536 || !CheckPrivateAccessPolicy()) return fail();
    if (ReadCiphertextCandidate().state != PendingCommandCandidateState::absent) return fail();
#ifdef _WIN32
    const auto captured = bytes; // Bounded copy before creating any stage file.
    struct Token {
      HANDLE value = nullptr;
      ~Token() { if (value) CloseHandle(value); }
    } token;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token.value)) return fail();
    DWORD length = 0;
    GetTokenInformation(token.value, TokenUser, nullptr, 0, &length);
    if (length == 0 || length > 65536) return fail();
    std::vector<unsigned char> data(length);
    if (!GetTokenInformation(token.value, TokenUser, data.data(), length, &length)) return fail();
    const auto user = reinterpret_cast<TOKEN_USER*>(data.data())->User.Sid;
    if (!IsValidSid(user)) return fail();
    BYTE system[SECURITY_MAX_SID_SIZE]{};
    DWORD systemSize = sizeof(system);
    if (!CreateWellKnownSid(WinLocalSystemSid, nullptr, system, &systemSize)) return fail();
    EXPLICIT_ACCESSW entries[2]{};
    const ULONG count = EqualSid(user, system) ? 1UL : 2UL;
    for (ULONG i = 0; i < count; ++i) {
      entries[i].grfAccessPermissions = FILE_ALL_ACCESS;
      entries[i].grfAccessMode = SET_ACCESS;
      entries[i].grfInheritance = NO_INHERITANCE;
      BuildTrusteeWithSidW(&entries[i].Trustee, i == 0 ? user : system);
    }
    struct Acl {
      PACL value = nullptr;
      ~Acl() { if (value) LocalFree(value); }
    } acl;
    if (SetEntriesInAclW(count, entries, nullptr, &acl.value) != ERROR_SUCCESS ||
        !acl.value || !IsValidAcl(acl.value)) return fail();
    SECURITY_DESCRIPTOR descriptor{};
    if (!InitializeSecurityDescriptor(&descriptor, SECURITY_DESCRIPTOR_REVISION) ||
        !SetSecurityDescriptorOwner(&descriptor, user, FALSE) ||
        !SetSecurityDescriptorDacl(&descriptor, TRUE, acl.value, FALSE) ||
        !SetSecurityDescriptorControl(&descriptor, SE_DACL_PROTECTED, SE_DACL_PROTECTED)) return fail();
    SECURITY_ATTRIBUTES attributes{};
    attributes.nLength = sizeof(attributes);
    attributes.lpSecurityDescriptor = &descriptor;
    if (!CheckPrivateAccessPolicy()) return fail();
    struct File {
      HANDLE value = INVALID_HANDLE_VALUE;
      ~File() { if (value != INVALID_HANDLE_VALUE) CloseHandle(value); }
    } file;
    const auto path = directory_ + L"\\pending-command.stage";
    file.value = CreateFileW(path.c_str(), GENERIC_READ | GENERIC_WRITE | READ_CONTROL,
        0, &attributes, CREATE_NEW, FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
    if (file.value == INVALID_HANDLE_VALUE) return fail(); // Preserve any existing stage.
    if (!Ordinary(file.value, false) || !PrivatePolicy(file.value, 0) ||
        !CheckPrivateAccessPolicy()) return fail(); // Leave uncertain stage, never delete.
    DWORD written = 0;
    const auto size = static_cast<DWORD>(captured.size());
    if (!WriteFile(file.value, captured.data(), size, &written, nullptr) ||
        written != size || !FlushFileBuffers(file.value)) return fail();
    BY_HANDLE_FILE_INFORMATION info{};
    if (GetFileType(file.value) != FILE_TYPE_DISK ||
        !GetFileInformationByHandle(file.value, &info) ||
        (info.dwFileAttributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT)) != 0 ||
        info.nNumberOfLinks != 1 || info.nFileSizeHigh != 0 || info.nFileSizeLow != size ||
        !PrivatePolicy(file.value, 0) || !CheckPrivateAccessPolicy()) return fail();
    const bool closed = CloseHandle(file.value) != FALSE;
    if (closed) file.value = INVALID_HANDLE_VALUE;
    if (!closed || !CheckPrivateAccessPolicy()) return fail();
    staged_bytes_ = captured; // Only this successful lease may propose publication.
    return true; // Flushed STAGING ONLY. No rename, publish, commit or dispatch.
#else
    return fail();
#endif
  } catch (...) { return fail(); }
}
bool PendingCommandFileLease::PublishStagedCiphertextCandidate() noexcept {
  const auto fail = [&]() { policy_failed_ = true; return false; };
  try {
    if (staged_bytes_.empty() || staged_bytes_.size() > 65536 ||
        !CheckPrivateAccessPolicy() ||
        ReadCiphertextCandidate().state != PendingCommandCandidateState::absent) return fail();
#ifdef _WIN32
    struct File {
      HANDLE value = INVALID_HANDLE_VALUE;
      ~File() { if (value != INVALID_HANDLE_VALUE) CloseHandle(value); }
    } file;
    const auto source = directory_ + L"\\pending-command.stage";
    const auto target = directory_ + L"\\pending-command.bin";
    file.value = CreateFileW(source.c_str(), GENERIC_READ | GENERIC_WRITE |
        READ_CONTROL | DELETE, 0, nullptr, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
    if (file.value == INVALID_HANDLE_VALUE) return fail();
    const auto valid = [&]() {
      BY_HANDLE_FILE_INFORMATION info{};
      return GetFileType(file.value) == FILE_TYPE_DISK &&
          GetFileInformationByHandle(file.value, &info) &&
          (info.dwFileAttributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT)) == 0 &&
          info.nNumberOfLinks == 1 && info.nFileSizeHigh == 0 &&
          info.nFileSizeLow == staged_bytes_.size() && PrivatePolicy(file.value, 0) &&
          CheckPrivateAccessPolicy();
    };
    if (!valid()) return fail();
    std::vector<unsigned char> bytes(staged_bytes_.size());
    DWORD read = 0;
    if (!ReadFile(file.value, bytes.data(), static_cast<DWORD>(bytes.size()), &read, nullptr) ||
        read != bytes.size() || bytes != staged_bytes_) return fail();
    unsigned char extra = 0;
    if (!ReadFile(file.value, &extra, 1, &read, nullptr) || read != 0 ||
        !valid() || !FlushFileBuffers(file.value)) return fail();
    const auto nameBytes = target.size() * sizeof(wchar_t);
    const auto total = sizeof(FILE_RENAME_INFO) + nameBytes;
    std::vector<ULONG_PTR> storage((total + sizeof(ULONG_PTR) - 1) / sizeof(ULONG_PTR), 0);
    const auto rename = reinterpret_cast<FILE_RENAME_INFO*>(storage.data());
    rename->ReplaceIfExists = FALSE;
    rename->RootDirectory = nullptr;
    rename->FileNameLength = static_cast<DWORD>(nameBytes);
    std::memcpy(rename->FileName, target.data(), nameBytes);
    if (!CheckPrivateAccessPolicy() || !SetFileInformationByHandle(file.value,
        FileRenameInfo, rename, static_cast<DWORD>(total))) return fail();
    // Any failure AFTER rename is uncertain publication, never rollback/delete/retry.
    if (!valid() || !FlushFileBuffers(file.value)) return fail();
    const bool closed = CloseHandle(file.value) != FALSE;
    if (closed) file.value = INVALID_HANDLE_VALUE;
    if (!closed || !CheckPrivateAccessPolicy()) return fail();
    staged_bytes_.clear();
    return true; // Namespace candidate ONLY, not authenticated/durable dispatch authority.
#else
    return fail();
#endif
  } catch (...) { return fail(); }
}
std::unique_ptr<PendingCommandFileLease> PendingCommandFileLease::Acquire(
    const std::wstring& trusted_directory) noexcept {
  try {
    if (!ValidDirectory(trusted_directory)) return nullptr;
#ifdef _WIN32
    auto lease = std::unique_ptr<PendingCommandFileLease>(new PendingCommandFileLease());
    lease->directory_ = trusted_directory;
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
