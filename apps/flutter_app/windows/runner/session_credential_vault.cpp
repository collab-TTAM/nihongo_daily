#include "session_credential_vault.h"

#include <windows.h>
#include <wincred.h>

#include <algorithm>
#include <cstdint>
#if defined(NIHONGO_SESSION_VAULT_TEST_HOOKS)
#include <atomic>
#endif
#include <iomanip>
#include <map>
#include <memory>
#include <mutex>
#include <sstream>
#include <string_view>
#include <utility>
#include <vector>

namespace nihongo {
namespace {
constexpr std::string_view kPrefix = "NihongoDaily.Refresh.v1|https://";
constexpr size_t kMaxSecret = 2048;

struct OwnerLease {
  HANDLE mutex;
  DWORD thread_id;
};
std::mutex owner_lease_guard;
std::map<std::string, OwnerLease> owner_leases;

#if defined(NIHONGO_SESSION_VAULT_TEST_HOOKS)
std::atomic<VaultProbeFault> read_probe_fault{VaultProbeFault::none};
std::atomic<VaultProbeFault> write_probe_fault{VaultProbeFault::none};
std::atomic<VaultProbeFault> clear_probe_fault{VaultProbeFault::none};

std::atomic<VaultProbeFault>& ProbeFaultSlot(VaultProbeOperation operation) {
  switch (operation) {
    case VaultProbeOperation::read:
      return read_probe_fault;
    case VaultProbeOperation::write:
      return write_probe_fault;
    case VaultProbeOperation::clear:
      return clear_probe_fault;
  }
  return clear_probe_fault;
}

bool ConsumeProbeFault(VaultProbeOperation operation, VaultProbeFault fault) {
  auto expected = fault;
  return ProbeFaultSlot(operation).compare_exchange_strong(
      expected, VaultProbeFault::none);
}
#endif

std::wstring OwnerMutexName(const std::string& target) {
  // Stable non-secret name: the canonical target is never embedded in the
  // kernel object namespace, and collisions can only fail closed.
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

bool ValidTarget(const std::string& target) {
  if (target.size() <= kPrefix.size() || target.size() > 512 ||
      target.compare(0, kPrefix.size(), kPrefix) != 0) {
    return false;
  }
  return std::all_of(target.begin() + kPrefix.size(), target.end(), [](char c) {
    return (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') ||
           c == '.' || c == '-' || c == ':' || c == '[' || c == ']';
  });
}

bool ValidSecret(const std::string& token) {
  return !token.empty() && token.size() <= kMaxSecret &&
         std::all_of(token.begin(), token.end(), [](unsigned char c) {
           return c >= 0x21 && c <= 0x7e;
         });
}

void EraseCredentialBlob(CREDENTIALW* credential) noexcept {
  // Credential Manager supplies the allocation and its exact byte length.
  // Wipe malformed/oversized blobs too; the validity limit is not a wipe limit.
  if (credential && credential->CredentialBlob &&
      credential->CredentialBlobSize > 0) {
    SecureZeroMemory(credential->CredentialBlob,
                     credential->CredentialBlobSize);
  }
}

void EraseSecretString(std::string& secret) noexcept {
  if (!secret.empty()) SecureZeroMemory(secret.data(), secret.size());
}

// Copy into the destination, then wipe the source while its original size and
// storage are still valid. Moving std::string first can reset an SSO source to
// size zero while leaving its inline bytes outside EraseSecretString's range.
void CopyThenEraseSecret(std::string& destination, std::string& source) {
  try {
    destination.assign(source);
  } catch (...) {
    EraseSecretString(source);
    EraseSecretString(destination);
    throw;
  }
  EraseSecretString(source);
}

struct CredentialRelease {
  void operator()(CREDENTIALW* credential) const {
    if (credential) {
      EraseCredentialBlob(credential);
      CredFree(credential);
    }
  }
};
}  // namespace

VaultRead::VaultRead(VaultStatus value, std::string&& secret)
    : status(value) {
  CopyThenEraseSecret(token, secret);
}

VaultRead::VaultRead(VaultRead&& other) : status(other.status) {
  CopyThenEraseSecret(token, other.token);
}

VaultRead& VaultRead::operator=(VaultRead&& other) {
  if (this != &other) {
    wipe();
    status = other.status;
    CopyThenEraseSecret(token, other.token);
  }
  return *this;
}

VaultRead::~VaultRead() { wipe(); }

void VaultRead::wipe() noexcept { EraseSecretString(token); }

#if defined(NIHONGO_SESSION_VAULT_TEST_HOOKS)
bool VerifySensitiveBufferWipeForTest() {
  std::vector<BYTE> oversized_blob(CRED_MAX_CREDENTIAL_BLOB_SIZE + 1, 0x5a);
  CREDENTIALW credential{};
  credential.CredentialBlob = oversized_blob.data();
  credential.CredentialBlobSize =
      static_cast<DWORD>(oversized_blob.size());
  EraseCredentialBlob(&credential);
  const bool blob_wiped =
      std::all_of(oversized_blob.begin(), oversized_blob.end(),
                  [](BYTE value) { return value == 0; });

  const auto verify_transfer = [](std::string source) {
    std::string expected(source);
    char* const source_buffer = source.data();
    const auto source_size = source.size();
    VaultRead initial{VaultStatus::success, std::move(source)};
    const bool input_wiped = std::all_of(
        source_buffer, source_buffer + source_size,
        [](char value) { return value == '\0'; });
    const bool input_preserved = initial.token == expected;

    char* const move_buffer = initial.token.data();
    const auto move_size = initial.token.size();
    VaultRead moved{std::move(initial)};
    const bool move_source_wiped = std::all_of(
        move_buffer, move_buffer + move_size,
        [](char value) { return value == '\0'; });
    const bool move_preserved = moved.token == expected;

    VaultRead assigned{VaultStatus::success,
                       std::string("TEST_ONLY_REPLACED_REFRESH")};
    char* const assignment_buffer = moved.token.data();
    const auto assignment_size = moved.token.size();
    assigned = std::move(moved);
    const bool assignment_source_wiped = std::all_of(
        assignment_buffer, assignment_buffer + assignment_size,
        [](char value) { return value == '\0'; });
    const bool assignment_preserved = assigned.token == expected;
    assigned.wipe();
    const bool destination_wiped = std::all_of(
        assigned.token.begin(), assigned.token.end(),
        [](char value) { return value == '\0'; });
    EraseSecretString(expected);
    return input_wiped && input_preserved && move_source_wiped &&
           move_preserved && assignment_source_wiped && assignment_preserved &&
           destination_wiped;
  };

  return blob_wiped && verify_transfer("short-secret") &&
         verify_transfer("TEST_ONLY_TEMPORARY_REFRESH_SECRET_BUFFER");
}
#endif

#if defined(NIHONGO_SESSION_VAULT_TEST_HOOKS)
void SetVaultProbeFaultOnce(VaultProbeOperation operation,
                            VaultProbeFault fault) {
  ProbeFaultSlot(operation).store(fault);
}
#endif

bool IsCredentialTargetValid(const std::string& target) { return ValidTarget(target); }

VaultRead ReadRefreshCredential(const std::string& target) {
  if (!ValidTarget(target)) return {VaultStatus::invalid_input, {}};
#if defined(NIHONGO_SESSION_VAULT_TEST_HOOKS)
  // One-shot native read failure: no Credential Manager call is made.
  if (ConsumeProbeFault(VaultProbeOperation::read,
                        VaultProbeFault::fail_before)) {
    SetLastError(ERROR_ACCESS_DENIED);
    return {VaultStatus::unavailable, {}};
  }
#endif
  const std::wstring name(target.begin(), target.end());
  PCREDENTIALW raw = nullptr;
  if (!CredReadW(name.c_str(), CRED_TYPE_GENERIC, 0, &raw)) {
    return {GetLastError() == ERROR_NOT_FOUND ? VaultStatus::not_found
                                            : VaultStatus::unavailable,
            {}};
  }
  const std::unique_ptr<CREDENTIALW, CredentialRelease> credential(raw);
  if (!raw || raw->Type != CRED_TYPE_GENERIC || !raw->CredentialBlob ||
      raw->CredentialBlobSize == 0 || raw->CredentialBlobSize > kMaxSecret) {
    return {VaultStatus::corrupt, {}};
  }
  std::string token(reinterpret_cast<const char*>(raw->CredentialBlob),
                    raw->CredentialBlobSize);
  if (!ValidSecret(token)) {
    SecureZeroMemory(token.data(), token.size());
    return {VaultStatus::corrupt, {}};
  }
  return {VaultStatus::success, std::move(token)};
}

VaultStatus WriteRefreshCredential(const std::string& target,
                                  const std::string& token) {
  if (!ValidTarget(target) || !ValidSecret(token)) {
    return VaultStatus::invalid_input;
  }
#if defined(NIHONGO_SESSION_VAULT_TEST_HOOKS)
  // One-shot write-before-commit failure preserves the previous OS value.
  if (ConsumeProbeFault(VaultProbeOperation::write,
                        VaultProbeFault::fail_before)) {
    SetLastError(ERROR_ACCESS_DENIED);
    return VaultStatus::unavailable;
  }
#endif
  std::wstring name(target.begin(), target.end());
  std::vector<BYTE> bytes(token.begin(), token.end());
  CREDENTIALW credential{};
  credential.Type = CRED_TYPE_GENERIC;
  credential.TargetName = name.data();
  credential.CredentialBlobSize = static_cast<DWORD>(bytes.size());
  credential.CredentialBlob = bytes.data();
  credential.Persist = CRED_PERSIST_LOCAL_MACHINE;
  const bool written = CredWriteW(&credential, 0) != FALSE;
  SecureZeroMemory(bytes.data(), bytes.size());
  if (!written) return VaultStatus::unavailable;
#if defined(NIHONGO_SESSION_VAULT_TEST_HOOKS)
  // The real write committed; report one ambiguous failure to the caller.
  if (ConsumeProbeFault(VaultProbeOperation::write,
                        VaultProbeFault::commit_then_fail)) {
    SetLastError(ERROR_WRITE_FAULT);
    return VaultStatus::unavailable;
  }
#endif
  return VaultStatus::success;
}

VaultStatus ClearRefreshCredential(const std::string& target) {
  if (!ValidTarget(target)) return VaultStatus::invalid_input;
#if defined(NIHONGO_SESSION_VAULT_TEST_HOOKS)
  // One-shot clear failure leaves the current OS value for explicit retry.
  if (ConsumeProbeFault(VaultProbeOperation::clear,
                        VaultProbeFault::fail_before)) {
    SetLastError(ERROR_ACCESS_DENIED);
    return VaultStatus::unavailable;
  }
#endif
  const std::wstring name(target.begin(), target.end());
  const bool deleted = CredDeleteW(name.c_str(), CRED_TYPE_GENERIC, 0) != FALSE;
  const DWORD error = deleted ? ERROR_SUCCESS : GetLastError();
  if (!deleted && error != ERROR_NOT_FOUND) return VaultStatus::unavailable;
#if defined(NIHONGO_SESSION_VAULT_TEST_HOOKS)
  // The OS deletion committed; report one ambiguous failure to the caller.
  if (deleted && ConsumeProbeFault(VaultProbeOperation::clear,
                                   VaultProbeFault::commit_then_fail)) {
    SetLastError(ERROR_WRITE_FAULT);
    return VaultStatus::unavailable;
  }
#endif
  return VaultStatus::success;
}

VaultStatus AcquireCredentialOwner(const std::string& target) {
  if (!ValidTarget(target)) return VaultStatus::invalid_input;
  std::lock_guard<std::mutex> guard(owner_lease_guard);
  if (owner_leases.find(target) != owner_leases.end()) {
    return VaultStatus::unavailable;
  }
  const std::wstring name = OwnerMutexName(target);
  HANDLE mutex = CreateMutexW(nullptr, FALSE, name.c_str());
  if (!mutex) return VaultStatus::unavailable;
  const DWORD wait = WaitForSingleObject(mutex, 0);
  if (wait != WAIT_OBJECT_0 && wait != WAIT_ABANDONED) {
    CloseHandle(mutex);
    return VaultStatus::unavailable;
  }
  try {
    owner_leases.emplace(target, OwnerLease{mutex, GetCurrentThreadId()});
  } catch (...) {
    ReleaseMutex(mutex);
    CloseHandle(mutex);
    return VaultStatus::unavailable;
  }
  return VaultStatus::success;
}

VaultStatus ReleaseCredentialOwner(const std::string& target) {
  if (!ValidTarget(target)) return VaultStatus::invalid_input;
  std::lock_guard<std::mutex> guard(owner_lease_guard);
  const auto it = owner_leases.find(target);
  if (it == owner_leases.end() ||
      it->second.thread_id != GetCurrentThreadId()) {
    return VaultStatus::unavailable;
  }
  if (!ReleaseMutex(it->second.mutex)) return VaultStatus::unavailable;
  CloseHandle(it->second.mutex);
  owner_leases.erase(it);
  return VaultStatus::success;
}
}  // namespace nihongo
