// TEST ONLY syscall faults, never linked into the app runner. Compile the
// unchanged lease source under a distinct class name; normal target remains real.
#include <string>
#include <vector>
#include <functional>
#ifdef _WIN32
#include <windows.h>
#include <aclapi.h>
namespace {
struct FaultState {
  int mode = 0;
  HANDLE stage = INVALID_HANDLE_VALUE;
  unsigned writes = 0, flushes = 0, closes = 0, faults = 0;
  unsigned renames = 0;
  bool renamed = false;
  std::function<void()> racingTarget;
} fault;
BOOL WINAPI FaultWriteFile(HANDLE file, LPCVOID bytes, DWORD size,
                          LPDWORD written, LPOVERLAPPED overlapped) {
  if (fault.mode == 0) return ::WriteFile(file, bytes, size, written, overlapped);
  fault.stage = file;
  ++fault.writes;
  if (fault.mode == 1) {
    ++fault.faults;
    return ::WriteFile(file, bytes, size / 2, written, overlapped);
  }
  if (fault.mode == 2) {
    ++fault.faults;
    *written = 0;
    SetLastError(ERROR_WRITE_FAULT);
    return FALSE;
  }
  return ::WriteFile(file, bytes, size, written, overlapped);
}
BOOL WINAPI FaultFlushFileBuffers(HANDLE file) {
  if (fault.mode != 0 && file == fault.stage) {
    ++fault.flushes;
    if (fault.mode == 3 || (fault.mode == 7 && fault.renamed && fault.flushes == 2)) {
      ++fault.faults;
      SetLastError(ERROR_WRITE_FAULT);
      return FALSE;
    }
  }
  return ::FlushFileBuffers(file);
}
BOOL WINAPI FaultCloseHandle(HANDLE file) {
  if (fault.mode != 0 && file == fault.stage) {
    ++fault.closes;
    if ((fault.mode == 4 || fault.mode == 8) && fault.closes == 1) {
      ++fault.faults;
      SetLastError(ERROR_INVALID_HANDLE);
      return FALSE; // Leave actual handle open: RAII must retry the real close.
    }
  }
  return ::CloseHandle(file);
}
// Arm only after successful Stage. Record the actual reopened DELETE handle so
// the pre-rename flush and post-rename operations belong to the same source.
HANDLE WINAPI FaultCreateFileW(LPCWSTR path, DWORD access, DWORD share,
    LPSECURITY_ATTRIBUTES attributes, DWORD creation, DWORD flags, HANDLE templateFile) {
  const auto handle = ::CreateFileW(path, access, share, attributes, creation, flags, templateFile);
  if (fault.mode >= 5 && (access & DELETE) != 0 && handle != INVALID_HANDLE_VALUE)
    fault.stage = handle;
  return handle;
}
BOOL WINAPI FaultSetFileInformationByHandle(HANDLE file, FILE_INFO_BY_HANDLE_CLASS kind,
                                           LPVOID info, DWORD size) {
  if (fault.mode >= 5 && file == fault.stage && kind == FileRenameInfo) {
    ++fault.renames;
    if (fault.mode == 5) {
      ++fault.faults;
      SetLastError(ERROR_ACCESS_DENIED);
      return FALSE; // Inject refusal before rename; preserve the stage.
    }
    if (fault.mode == 6) {
      fault.racingTarget(); // Real target creation AFTER all production prechecks.
      ++fault.faults;
    }
    const auto result = ::SetFileInformationByHandle(file, kind, info, size);
    fault.renamed = result != FALSE;
    return result; // Race case must be rejected by the real no-replace syscall.
  }
  return ::SetFileInformationByHandle(file, kind, info, size);
}
}  // namespace
#define PendingCommandFileLease FaultPendingCommandFileLease
#define WriteFile FaultWriteFile
#define FlushFileBuffers FaultFlushFileBuffers
#define CloseHandle FaultCloseHandle
#define CreateFileW FaultCreateFileW
#define SetFileInformationByHandle FaultSetFileInformationByHandle
#include "../../windows/runner/pending_command_file_lease.cpp"
#undef SetFileInformationByHandle
#undef CreateFileW
#undef CloseHandle
#undef FlushFileBuffers
#undef WriteFile
#undef PendingCommandFileLease
// One serialized synthetic invocation. No flags/ports in the production class.
bool ProbeCommandStageFault(const std::wstring& directory, int mode) {
  if (mode < 1 || mode > 4 || fault.mode != 0) return false;
  struct Reset { ~Reset() { fault = {}; } } reset;
  fault = {};
  fault.mode = mode;
  auto lease = nihongo::FaultPendingCommandFileLease::Acquire(directory);
  if (!lease || !lease->CheckPrivateAccessPolicy()) return false;
  if (lease->StageCiphertextCandidate(std::vector<unsigned char>(64, 0xa5))) return false;
  if (fault.faults != 1 || fault.writes != 1 ||
      lease->CheckPrivateAccessPolicy()) return false;
  const auto read = lease->ReadCiphertextCandidate();
  if (read.state != nihongo::PendingCommandCandidateState::unavailable ||
      !read.bytes.empty() ||
      lease->StageCiphertextCandidate(std::vector<unsigned char>(64, 0x5a))) return false;
  lease.reset(); // All stage/lease handles must really be closed before inspection.
  return fault.faults == 1 && fault.writes == 1 &&
      fault.flushes == (mode >= 3 ? 1u : 0u) &&
      fault.closes == (mode == 4 ? 2u : 1u);
}
// Return failure unless the unchanged publication method sees exactly the
// intended syscall outcome and fences every subsequent read/stage/publish.
bool ProbeCommandPublishFault(const std::wstring& directory, int mode,
                             const std::function<void()>& racingTarget) {
  if (mode < 5 || mode > 8 || fault.mode != 0) return false;
  struct Reset { ~Reset() { fault = {}; } } reset;
  auto lease = nihongo::FaultPendingCommandFileLease::Acquire(directory);
  if (!lease || !lease->StageCiphertextCandidate(std::vector<unsigned char>(64, 0xa5))) return false;
  fault = {};
  fault.mode = mode;
  fault.racingTarget = racingTarget;
  if (lease->PublishStagedCiphertextCandidate()) return false;
  if (fault.faults != 1 || fault.renames != 1 || fault.renamed != (mode >= 7) ||
      lease->CheckPrivateAccessPolicy()) return false;
  const auto read = lease->ReadCiphertextCandidate();
  if (read.state != nihongo::PendingCommandCandidateState::unavailable ||
      !read.bytes.empty() || lease->PublishStagedCiphertextCandidate() ||
      lease->StageCiphertextCandidate(std::vector<unsigned char>(64, 0x5a))) return false;
  lease.reset();
  return fault.faults == 1 && fault.renames == 1 && fault.writes == 0 &&
      fault.flushes == (mode >= 7 ? 2u : 1u) &&
      fault.closes == (mode == 8 ? 2u : 1u);
}
#else
bool ProbeCommandStageFault(const std::wstring&, int) { return false; }
#endif
