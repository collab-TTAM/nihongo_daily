#ifndef NIHONGO_PENDING_COMMAND_FILE_LEASE_H_
#define NIHONGO_PENDING_COMMAND_FILE_LEASE_H_
#include <memory>
#include <string>
#include <vector>
namespace nihongo {
enum class PendingCommandCandidateState { unavailable, absent, present };
struct PendingCommandCandidate {
  PendingCommandCandidateState state = PendingCommandCandidateState::unavailable;
  std::vector<unsigned char> bytes;
};
// Exclusive sentinel/read-only opaque candidate. NOT a payload backend or writer identity
// proof. Host must establish trusted local directory ownership/ACL first.
class PendingCommandFileLease final {
 public:
  static std::unique_ptr<PendingCommandFileLease> Acquire(
      const std::wstring& trusted_directory) noexcept;
  // Read-only strict leaf-directory policy, NOT ancestor/sentinel ACL assurance.
  bool HasPrivateDirectoryAccessPolicy() const noexcept;
  // Read-only held sentinel policy: explicit non-inheritable user/SYSTEM ACEs.
  // Snapshot only, never payload permission or protection from later mutation.
  bool HasPrivateSentinelAccessPolicy() const noexcept;
  // Serialized-owner check: any observed failure permanently fences this lease.
  // No reset, payload authority, cross-restart persistence or check/use guarantee.
  bool CheckPrivateAccessPolicy() noexcept;
  // Opaque candidate only, never authenticated/decrypted/committed authority.
  // Fixed basename, 1..65536 bytes; any read uncertainty fences this lease.
  PendingCommandCandidate ReadCiphertextCandidate() noexcept;
  ~PendingCommandFileLease();
  PendingCommandFileLease(const PendingCommandFileLease&) = delete;
  PendingCommandFileLease& operator=(const PendingCommandFileLease&) = delete;
 private:
  PendingCommandFileLease() = default;
  std::vector<void*> directories_;
  void* file_ = nullptr;
  bool policy_failed_ = false;
  std::wstring directory_;
};
}  // namespace nihongo
#endif
