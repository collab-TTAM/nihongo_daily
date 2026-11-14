#include <windows.h>
#include <wincred.h>

#include <algorithm>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

#include "session_credential_vault.h"

#ifndef NIHONGO_SESSION_VAULT_TEST_HOOKS
#error "Standalone probe requires its TEST ONLY fault hooks"
#endif

namespace {
void Check(bool ok) {
  if (!ok) throw std::runtime_error("credential probe assertion failed");
}

std::wstring OwnerMutexNameForProbe(const std::string& target) {
  std::uint64_t hash = 14695981039346656037ull;
  for (const unsigned char value : target) {
    hash ^= value;
    hash *= 1099511628211ull;
  }
  std::wostringstream name;
  name << L"Local\\NihongoDaily.Refresh.Owner.v1." << std::hex
       << std::setfill(L'0') << std::setw(16) << hash;
  return name.str();
}

void WriteCorruptFixture(const std::string& target) {
  // TEST ONLY raw OS corruption injection. Production never bypasses validation.
  std::wstring name(target.begin(), target.end());
  BYTE bytes[] = {'x', 0, 'y'};
  CREDENTIALW credential{};
  credential.Type = CRED_TYPE_GENERIC;
  credential.TargetName = name.data();
  credential.CredentialBlobSize = sizeof(bytes);
  credential.CredentialBlob = bytes;
  credential.Persist = CRED_PERSIST_LOCAL_MACHINE;
  Check(CredWriteW(&credential, 0) != FALSE);
}

DWORD RunChild(std::wstring command) {
  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  PROCESS_INFORMATION process{};
  Check(CreateProcessW(nullptr, command.data(), nullptr, nullptr, FALSE,
                       CREATE_NO_WINDOW, nullptr, nullptr, &startup, &process) !=
        FALSE);
  const DWORD wait = WaitForSingleObject(process.hProcess, 10000);
  DWORD code = 1;
  if (wait == WAIT_OBJECT_0) {
    Check(GetExitCodeProcess(process.hProcess, &code) != FALSE);
  } else {
    TerminateProcess(process.hProcess, 1);
    WaitForSingleObject(process.hProcess, 5000);
  }
  CloseHandle(process.hThread);
  CloseHandle(process.hProcess);
  Check(wait == WAIT_OBJECT_0);
  return code;
}

DWORD ChildOwnerAttempt(const std::string& target, const wchar_t* mode) {
  wchar_t executable[32768]{};
  const DWORD length = GetModuleFileNameW(nullptr, executable, 32768);
  Check(length > 0 && length < 32768);
  const std::wstring name(target.begin(), target.end());
  const std::wstring command = L"\"" + std::wstring(executable) + L"\" " +
                               mode + L" " + name;
  return RunChild(command);
}

void ChildWrite(const std::string& target) {
  wchar_t executable[32768]{};
  const DWORD length = GetModuleFileNameW(nullptr, executable, 32768);
  Check(length > 0 && length < 32768);
  const std::wstring name(target.begin(), target.end());
  std::wstring command = L"\"" + std::wstring(executable) +
                         L"\" --child-write " + name;
  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  PROCESS_INFORMATION process{};
  Check(CreateProcessW(nullptr, command.data(), nullptr, nullptr, FALSE,
                       CREATE_NO_WINDOW, nullptr, nullptr, &startup, &process) !=
        FALSE);
  const DWORD wait = WaitForSingleObject(process.hProcess, 10000);
  DWORD code = 1;
  if (wait == WAIT_OBJECT_0) {
    Check(GetExitCodeProcess(process.hProcess, &code) != FALSE);
  } else {
    TerminateProcess(process.hProcess, 1);
    WaitForSingleObject(process.hProcess, 5000);
  }
  CloseHandle(process.hThread);
  CloseHandle(process.hProcess);
  Check(wait == WAIT_OBJECT_0 && code == 0);
}

void VerifyOneShotNativeFaultInjection(const std::string& target) {
  using nihongo::VaultProbeFault;
  using nihongo::VaultProbeOperation;
  using nihongo::VaultStatus;

  const auto expect_token = [&](const std::string& expected) {
    const auto read = nihongo::ReadRefreshCredential(target);
    Check(read.status == VaultStatus::success && read.token == expected);
  };

  Check(nihongo::ClearRefreshCredential(target) == VaultStatus::success);
  Check(nihongo::WriteRefreshCredential(target, "TEST_ONLY_READ_BASELINE") ==
        VaultStatus::success);
  // one-shot native read failure
  nihongo::SetVaultProbeFaultOnce(VaultProbeOperation::read,
                                  VaultProbeFault::fail_before);
  const auto failed_read = nihongo::ReadRefreshCredential(target);
  Check(failed_read.status == VaultStatus::unavailable &&
        failed_read.token.empty());
  expect_token("TEST_ONLY_READ_BASELINE");

  Check(nihongo::WriteRefreshCredential(target, "TEST_ONLY_WRITE_BASELINE") ==
        VaultStatus::success);
  nihongo::SetVaultProbeFaultOnce(VaultProbeOperation::write,
                                  VaultProbeFault::fail_before);
  Check(nihongo::WriteRefreshCredential(target, "TEST_ONLY_REJECTED_WRITE") ==
        VaultStatus::unavailable);
  expect_token("TEST_ONLY_WRITE_BASELINE");
  Check(nihongo::WriteRefreshCredential(target, "TEST_ONLY_WRITE_RECOVERED") ==
        VaultStatus::success);
  expect_token("TEST_ONLY_WRITE_RECOVERED");

  // ambiguous write commit: actual CredWrite succeeds before the safe error.
  nihongo::SetVaultProbeFaultOnce(VaultProbeOperation::write,
                                  VaultProbeFault::commit_then_fail);
  Check(nihongo::WriteRefreshCredential(target, "TEST_ONLY_AMBIGUOUS_COMMIT") ==
        VaultStatus::unavailable);
  expect_token("TEST_ONLY_AMBIGUOUS_COMMIT");
  Check(nihongo::WriteRefreshCredential(target, "TEST_ONLY_AFTER_AMBIGUOUS") ==
        VaultStatus::success);
  expect_token("TEST_ONLY_AFTER_AMBIGUOUS");

  nihongo::SetVaultProbeFaultOnce(VaultProbeOperation::clear,
                                  VaultProbeFault::fail_before);
  Check(nihongo::ClearRefreshCredential(target) == VaultStatus::unavailable);
  expect_token("TEST_ONLY_AFTER_AMBIGUOUS");
  // explicit clear retry after injected failure
  Check(nihongo::ClearRefreshCredential(target) == VaultStatus::success);
  Check(nihongo::ReadRefreshCredential(target).status == VaultStatus::not_found);
  Check(nihongo::ClearRefreshCredential(target) == VaultStatus::success);
}

void ResetOneShotNativeFaults() {
  using nihongo::VaultProbeFault;
  using nihongo::VaultProbeOperation;
  nihongo::SetVaultProbeFaultOnce(VaultProbeOperation::read, VaultProbeFault::none);
  nihongo::SetVaultProbeFaultOnce(VaultProbeOperation::write, VaultProbeFault::none);
  nihongo::SetVaultProbeFaultOnce(VaultProbeOperation::clear, VaultProbeFault::none);
}
}  // namespace

int wmain(int argc, wchar_t* argv[]) {
  using nihongo::VaultStatus;
  if (argc == 3 &&
      (std::wstring(argv[1]) == L"--child-acquire" ||
       std::wstring(argv[1]) == L"--child-abandon")) {
    const std::wstring name(argv[2]);
    const std::wstring prefix = L"NihongoDaily.Refresh.v1|https://ci-vault-a-";
    const std::wstring suffix = L".invalid";
    if (name.size() <= prefix.size() + suffix.size() || name.size() > 512 ||
        name.compare(0, prefix.size(), prefix) != 0 ||
        name.compare(name.size() - suffix.size(), suffix.size(), suffix) != 0) {
      return 1;
    }
    const std::wstring pid = name.substr(
        prefix.size(), name.size() - prefix.size() - suffix.size());
    if (!std::all_of(pid.begin(), pid.end(), [](wchar_t c) {
          return c >= L'0' && c <= L'9';
        })) {
      return 1;
    }
    std::string target;
    for (const wchar_t c : name) {
      if (c < 0x21 || c > 0x7e) return 1;
      target.push_back(static_cast<char>(c));
    }
    if (nihongo::AcquireCredentialOwner(target) != VaultStatus::success) {
      return 2;
    }
    if (std::wstring(argv[1]) == L"--child-abandon") return 0;
    return nihongo::ReleaseCredentialOwner(target) == VaultStatus::success
               ? 0
               : 1;
  }
  if (argc == 3 && std::wstring(argv[1]) == L"--child-write") {
    const std::wstring name(argv[2]);
    const std::wstring prefix = L"NihongoDaily.Refresh.v1|https://ci-vault-a-";
    const std::wstring suffix = L".invalid";
    if (name.size() <= prefix.size() + suffix.size() || name.size() > 512 ||
        name.compare(0, prefix.size(), prefix) != 0 ||
        name.compare(name.size() - suffix.size(), suffix.size(), suffix) != 0) {
      return 1;
    }
    const auto pid = name.substr(prefix.size(),
                                 name.size() - prefix.size() - suffix.size());
    if (!std::all_of(pid.begin(), pid.end(), [](wchar_t c) {
          return c >= L'0' && c <= L'9';
        })) {
      return 1;
    }
    std::string target;
    for (const wchar_t c : name) {
      if (c < 0x21 || c > 0x7e) return 1;
      target.push_back(static_cast<char>(c));
    }
    return nihongo::WriteRefreshCredential(target, "TEST_ONLY_CHILD_REFRESH") ==
                   VaultStatus::success
               ? 0
               : 1;
  }
  if (argc != 1) return 1;
  const std::string suffix = std::to_string(GetCurrentProcessId()) + ".invalid";
  const std::string a = "NihongoDaily.Refresh.v1|https://ci-vault-a-" + suffix;
  const std::string b = "NihongoDaily.Refresh.v1|https://ci-vault-b-" + suffix;
  bool passed = false;
  try {
    Check(nihongo::ClearRefreshCredential(a) == VaultStatus::success);
    Check(nihongo::ClearRefreshCredential(b) == VaultStatus::success);
    VerifyOneShotNativeFaultInjection(a);
    Check(nihongo::AcquireCredentialOwner(a) == VaultStatus::success);
    Check(ChildOwnerAttempt(a, L"--child-acquire") == 2);
    Check(nihongo::ReleaseCredentialOwner(a) == VaultStatus::success);
    Check(ChildOwnerAttempt(a, L"--child-acquire") == 0);
    // Keep the named object alive while the child exits so the next wait
    // observes WAIT_ABANDONED instead of creating a fresh mutex.
    const std::wstring mutex_name = OwnerMutexNameForProbe(a);
    HANDLE witness = CreateMutexW(nullptr, FALSE, mutex_name.c_str());
    Check(witness != nullptr);
    Check(ChildOwnerAttempt(a, L"--child-abandon") == 0);
    Check(nihongo::AcquireCredentialOwner(a) == VaultStatus::success);
    Check(nihongo::ReleaseCredentialOwner(a) == VaultStatus::success);
    CloseHandle(witness);
    Check(nihongo::ReadRefreshCredential(a).status == VaultStatus::not_found);
    Check(nihongo::WriteRefreshCredential(a, "TEST_ONLY_FIRST_REFRESH") ==
          VaultStatus::success);
    Check(nihongo::ReadRefreshCredential(a).token == "TEST_ONLY_FIRST_REFRESH");
    Check(nihongo::WriteRefreshCredential(b, "TEST_ONLY_OTHER_PROJECT") ==
          VaultStatus::success);
    ChildWrite(a);
    Check(nihongo::ReadRefreshCredential(a).token == "TEST_ONLY_CHILD_REFRESH");
    Check(nihongo::ReadRefreshCredential(b).token == "TEST_ONLY_OTHER_PROJECT");
    Check(nihongo::WriteRefreshCredential(a, std::string(2049, 'x')) ==
          VaultStatus::invalid_input);
    Check(nihongo::WriteRefreshCredential(a, std::string("a\0b", 3)) ==
          VaultStatus::invalid_input);
    Check(nihongo::ReadRefreshCredential(a).token == "TEST_ONLY_CHILD_REFRESH");
    Check(nihongo::WriteRefreshCredential(a, std::string(2048, 'x')) ==
          VaultStatus::success);
    Check(nihongo::ReadRefreshCredential(a).token.size() == 2048);
    Check(nihongo::ClearRefreshCredential("OtherApplication:credential") ==
          VaultStatus::invalid_input);
    Check(nihongo::ReadRefreshCredential("OtherApplication:credential").status ==
          VaultStatus::invalid_input);
    WriteCorruptFixture(a);
    Check(nihongo::ReadRefreshCredential(a).status == VaultStatus::corrupt);
    Check(nihongo::WriteRefreshCredential(a, "TEST_ONLY_RECOVERED_REFRESH") ==
          VaultStatus::success);
    Check(nihongo::ClearRefreshCredential(a) == VaultStatus::success);
    Check(nihongo::ClearRefreshCredential(a) == VaultStatus::success);
    Check(nihongo::ReadRefreshCredential(a).status == VaultStatus::not_found);
    Check(nihongo::ReadRefreshCredential(b).token == "TEST_ONLY_OTHER_PROJECT");
    passed = true;
  } catch (...) {
    // No raw errors, tokens, target names or credentials in output.
  }
  ResetOneShotNativeFaults();
  // Only PID-qualified .invalid TEST ONLY namespaces; never user/live credentials.
  const bool cleared_a = nihongo::ClearRefreshCredential(a) == VaultStatus::success;
  const bool cleared_b = nihongo::ClearRefreshCredential(b) == VaultStatus::success;
  if (!passed || !cleared_a || !cleared_b) {
    std::cerr << "FAIL: actual Windows credential probe\n";
    return 1;
  }
  std::cout << "PASS: actual Windows Credential Manager write/read/replace, "
               "child exit/parent read, project isolation, process owner lease "
               "contention/abandonment recovery, one-shot read/write/ambiguous-commit/clear fault recovery, bounded corrupt data and "
               "idempotent clear. TEST ONLY; no hosted Auth restoration.\n";
  return 0;
}
