// TEST ONLY syscall faults, never linked into the app runner. Compile the
// unchanged lease source under a distinct class name; normal target remains real.
#include <string>
#include <vector>
#include <functional>
#include <iostream>
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
  HANDLE candidate = INVALID_HANDLE_VALUE;
  unsigned candidateOpens = 0, candidateReads = 0, stageProbes = 0, recoveryTriggers = 0;
  unsigned candidateBytes = 0;
  std::function<void()> unresolvedStage;
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
  const auto result = ::FlushFileBuffers(file);
  if (fault.mode == 11 && file == fault.stage && fault.renamed && fault.flushes == 2)
    ExitProcess(result != FALSE && fault.renames == 1 && fault.writes == 0 ? 0 : 5);
  return result;
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
  const auto result = ::CloseHandle(file);
  if (fault.mode == 12 && file == fault.stage && fault.renamed && fault.closes == 1)
    ExitProcess(result != FALSE && fault.flushes == 2 && fault.renames == 1 && fault.writes == 0 ? 0 : 5);
  return result;
}
// Arm only after successful Stage. Record the actual reopened DELETE handle so
// the pre-rename flush and post-rename operations belong to the same source.
HANDLE WINAPI FaultCreateFileW(LPCWSTR path, DWORD access, DWORD share,
    LPSECURITY_ATTRIBUTES attributes, DWORD creation, DWORD flags, HANDLE templateFile) {
  const auto handle = ::CreateFileW(path, access, share, attributes, creation, flags, templateFile);
  const auto error = GetLastError();
  if (fault.mode >= 13 && fault.mode <= 15 && creation == OPEN_EXISTING) {
    if (access == (GENERIC_READ | READ_CONTROL)) {
      ++fault.candidateOpens;
      if (fault.mode == 14 && handle == INVALID_HANDLE_VALUE && error == ERROR_FILE_NOT_FOUND) {
        fault.unresolvedStage(); // Insert real .stage before candidate absence returns.
        ++fault.recoveryTriggers;
      }
      if (handle != INVALID_HANDLE_VALUE) fault.candidate = handle;
    }
    if (access == FILE_READ_ATTRIBUTES && (flags & FILE_FLAG_BACKUP_SEMANTICS) != 0) {
      ++fault.stageProbes;
      if (fault.mode == 15 && fault.stageProbes == 2 &&
          handle == INVALID_HANDLE_VALUE && error == ERROR_FILE_NOT_FOUND) {
        ++fault.recoveryTriggers;
        ++fault.faults;
        SetLastError(ERROR_ACCESS_DENIED); // Only the final stage absence probe fails.
        return INVALID_HANDLE_VALUE;
      }
    }
  }

  if (fault.mode >= 5 && (access & DELETE) != 0 && handle != INVALID_HANDLE_VALUE)
    fault.stage = handle;
  SetLastError(error); // Fixture callbacks must not change the real open outcome.
  return handle;
}
BOOL WINAPI FaultReadFile(HANDLE file, LPVOID bytes, DWORD size,
                         LPDWORD read, LPOVERLAPPED overlapped) {
  const auto result = ::ReadFile(file, bytes, size, read, overlapped);
  const auto error = GetLastError();
  if ((fault.mode == 13 || fault.mode == 15) && file == fault.candidate) {
    ++fault.candidateReads;
    if (result != FALSE) fault.candidateBytes += *read;
    if (fault.mode == 13 && fault.recoveryTriggers == 0 && result != FALSE && *read > 0) {
      fault.unresolvedStage(); // Real stage appears before the reader completes metadata/postchecks.
      ++fault.recoveryTriggers;
    }
  }
  SetLastError(error);
  return result;
}
BOOL WINAPI FaultSetFileInformationByHandle(HANDLE file, FILE_INFO_BY_HANDLE_CLASS kind,
                                           LPVOID info, DWORD size) {
  if (fault.mode >= 5 && file == fault.stage && kind == FileRenameInfo) {
    ++fault.renames;
    if (fault.mode == 9)
      ExitProcess(fault.renames == 1 && fault.flushes == 1 && fault.writes == 0 ? 0 : 5);
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
    if (fault.mode == 10)
      ExitProcess(fault.renamed && fault.renames == 1 && fault.flushes == 1 && fault.writes == 0 ? 0 : 5);
    return result; // Race case must be rejected by the real no-replace syscall.
  }
  return ::SetFileInformationByHandle(file, kind, info, size);
}
}  // namespace
#define PendingCommandFileLease FaultPendingCommandFileLease
#define WriteFile FaultWriteFile
#define ReadFile FaultReadFile
#define FlushFileBuffers FaultFlushFileBuffers
#define CloseHandle FaultCloseHandle
#define CreateFileW FaultCreateFileW
#define SetFileInformationByHandle FaultSetFileInformationByHandle
#include "../../windows/runner/pending_command_file_lease.cpp"
#undef SetFileInformationByHandle
#undef CreateFileW
#undef CloseHandle
#undef FlushFileBuffers
#undef ReadFile
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
// Real candidate data/absence is observed between the two stage probes. The
// callback writes only a unique synthetic stage through the normal probe API.
bool ProbeCommandRecoveryInterleave(const std::wstring& directory, int mode,
                                    const std::function<void()>& unresolvedStage) {
  if (mode < 13 || mode > 15 || fault.mode != 0) return false;
  struct Reset { ~Reset() { fault = {}; } } reset;
  auto lease = nihongo::FaultPendingCommandFileLease::Acquire(directory);
  if (!lease || !lease->CheckPrivateAccessPolicy()) return false;
  fault = {};
  fault.mode = mode;
  fault.unresolvedStage = unresolvedStage;
  const auto result = lease->ReadRecoveryCiphertextCandidate();
  std::cout << "CHECK: recovery interleave snapshot mode=" << mode
      << " unavailable=" << (result.state == nihongo::PendingCommandCandidateState::unavailable)
      << " empty=" << result.bytes.empty()
      << " reads=" << fault.candidateReads << " read-bytes=" << fault.candidateBytes
      << " opens=" << fault.candidateOpens << " probes=" << fault.stageProbes
      << " triggers=" << fault.recoveryTriggers << " faults=" << fault.faults << std::endl;
  if (result.state != nihongo::PendingCommandCandidateState::unavailable ||
      !result.bytes.empty() || lease->CheckPrivateAccessPolicy()) return false;
  const auto repeated = lease->ReadRecoveryCiphertextCandidate();
  const auto raw = lease->ReadCiphertextCandidate();
  if (repeated.state != nihongo::PendingCommandCandidateState::unavailable ||
      !repeated.bytes.empty() || raw.state != nihongo::PendingCommandCandidateState::unavailable ||
      !raw.bytes.empty() || lease->StageCiphertextCandidate(std::vector<unsigned char>(64, 0x5a)) ||
      lease->PublishStagedCiphertextCandidate()) return false;
  lease.reset();
  return fault.recoveryTriggers == 1 && fault.candidateOpens == 1 &&
      // The production reader uses one exact-size ReadFile, then size/ACL recheck;
      // it has no separate EOF read. Require the actual complete64-byte data read.
      fault.candidateReads == (mode == 14 ? 0u : 1u) &&
      fault.candidateBytes == (mode == 14 ? 0u : 64u) && fault.stageProbes == 2 &&
      fault.faults == (mode == 15 ? 1u : 0u) && fault.writes == 0 && fault.renames == 0;
}
// TEST ONLY child entry: successful exits occur solely inside the selected real
// syscall boundary above. ExitProcess deliberately bypasses C++ lease cleanup.
int CommandPublishExitChild(const std::wstring& directory, const std::wstring& mode) {
  try {
    int point = 0;
    if (mode == L"before-rename") point = 9;
    else if (mode == L"after-rename") point = 10;
    else if (mode == L"after-flush") point = 11;
    else if (mode == L"after-close") point = 12;
    else ExitProcess(5);
    auto lease = nihongo::FaultPendingCommandFileLease::Acquire(directory);
    if (!lease || !lease->StageCiphertextCandidate(std::vector<unsigned char>(64, 0xa5))) ExitProcess(5);
    fault = {};
    fault.mode = point; // Arm only after real Stage and its checked close.
    (void)lease->PublishStagedCiphertextCandidate();
    ExitProcess(5); // Returning without reaching the selected boundary is failure.
  } catch (...) { ExitProcess(5); }
}
#else
bool ProbeCommandStageFault(const std::wstring&, int) { return false; }
#endif
