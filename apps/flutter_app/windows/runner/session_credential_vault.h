#ifndef RUNNER_SESSION_CREDENTIAL_VAULT_H_
#define RUNNER_SESSION_CREDENTIAL_VAULT_H_

#include <string>

namespace nihongo {
enum class VaultStatus { success, not_found, unavailable, invalid_input, corrupt };
struct VaultRead {
  VaultRead(VaultStatus status, std::string&& token);
  VaultRead(const VaultRead&) = delete;
  VaultRead& operator=(const VaultRead&) = delete;
  VaultRead(VaultRead&& other) noexcept;
  VaultRead& operator=(VaultRead&& other) noexcept;
  ~VaultRead();

  // Zero the temporary native copy without changing its length, allowing a
  // TEST ONLY probe to inspect the wiped bytes before destruction.
  void wipe() noexcept;

  VaultStatus status;
  std::string token;
};

// No Flutter/SDK dependency; the same implementation is exercised by CI's
// actual Windows credential/process probe. Never print arguments or OS errors.
bool IsCredentialTargetValid(const std::string& target);
VaultRead ReadRefreshCredential(const std::string& target);
VaultStatus WriteRefreshCredential(const std::string& target,
                                  const std::string& token);
VaultStatus ClearRefreshCredential(const std::string& target);
VaultStatus AcquireCredentialOwner(const std::string& target);
VaultStatus ReleaseCredentialOwner(const std::string& target);

#if defined(NIHONGO_SESSION_VAULT_TEST_HOOKS)
// These hooks exist only in the standalone TEST ONLY probe target.
enum class VaultProbeOperation { read, write, clear };
enum class VaultProbeFault { none, fail_before, commit_then_fail };
void SetVaultProbeFaultOnce(VaultProbeOperation operation,
                            VaultProbeFault fault);
bool VerifySensitiveBufferWipeForTest();
#endif
}  // namespace nihongo
#endif
