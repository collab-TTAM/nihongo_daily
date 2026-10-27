// TEST ONLY: unique temporary directories and empty sentinel; no payloads.
#include "pending_command_file_lease.h"
#include <stdexcept>
#ifdef _WIN32
#include <windows.h>
namespace {
void Check(bool value) {
  if (!value) throw std::runtime_error("command lease probe failed");
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
