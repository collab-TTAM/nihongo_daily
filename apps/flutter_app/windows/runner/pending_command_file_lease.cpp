#include "pending_command_file_lease.h"
#ifdef _WIN32
#include <windows.h>
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
PendingCommandFileLease::~PendingCommandFileLease() {
#ifdef _WIN32
  if (file_) CloseHandle(static_cast<HANDLE>(file_));
  if (directory_) CloseHandle(static_cast<HANDLE>(directory_));
#endif
}
std::unique_ptr<PendingCommandFileLease> PendingCommandFileLease::Acquire(
    const std::wstring& trusted_directory) noexcept {
  try {
    if (!ValidDirectory(trusted_directory)) return nullptr;
#ifdef _WIN32
    auto lease = std::unique_ptr<PendingCommandFileLease>(new PendingCommandFileLease());
    const auto dir = CreateFileW(trusted_directory.c_str(), FILE_READ_ATTRIBUTES,
        FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING,
        FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
    if (dir == INVALID_HANDLE_VALUE) return nullptr;
    lease->directory_ = dir;
    if (!Ordinary(dir, true)) return nullptr;
    const auto path = trusted_directory + L"\\pending-command.lock";
    const auto file = CreateFileW(path.c_str(), GENERIC_READ | GENERIC_WRITE,
        0, nullptr, OPEN_ALWAYS, FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
    if (file == INVALID_HANDLE_VALUE) return nullptr;
    lease->file_ = file;
    if (!Ordinary(file, false)) return nullptr;
    // Never truncate, write, delete, or inherit either handle. Keep the stable
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
