#ifndef NIHONGO_PENDING_COMMAND_PARTITION_H_
#define NIHONGO_PENDING_COMMAND_PARTITION_H_
#include "pending_command_file_lease.h"
namespace nihongo {
// Isolated prerequisite, not a durable backend, Auth proof or retention approval.
// Serialized owner only. Host supplies an already trusted, existing root and a
// canonical receipt target captured from its configured project/verified account.
class PendingCommandPartition final {
 public:
  static std::unique_ptr<PendingCommandPartition> Acquire(
      const std::wstring& trusted_root, const std::string& receipt_target) noexcept;
  PendingCommandCandidate ReadRecoveryCiphertextCandidate(
      const std::string& expected_target) noexcept;
  bool StageCiphertextCandidate(const std::string& expected_target,
      const std::vector<unsigned char>& bytes) noexcept;
  bool PublishStagedCiphertextCandidate(const std::string& expected_target) noexcept;
  // Serialized owner only: deny future operations, retain lease/data until destruction.
  // Idempotent; not cancellation of concurrent I/O, logout deletion or reconciliation.
  void Revoke() noexcept;
  ~PendingCommandPartition() = default;
  PendingCommandPartition(const PendingCommandPartition&) = delete;
  PendingCommandPartition& operator=(const PendingCommandPartition&) = delete;
 private:
  PendingCommandPartition(std::unique_ptr<PendingCommandFileLease> lease,
      const std::string& target);
  bool Current(const std::string& expected_target) noexcept;
  const std::string target_;
  std::unique_ptr<PendingCommandFileLease> lease_;
  bool failed_ = false;
};
// Sensitive in-memory bytes only. Caller must validate the complete command DTO;
// successful DPAPI decoding is not Auth, original-writer or receipt proof.
struct PendingCommandPlaintextCandidate {
  PendingCommandCandidateState state = PendingCommandCandidateState::unavailable;
  std::vector<unsigned char> plaintext;
};
// Synthetic-only composition. No raw staging/decryption bypass is exposed here.
// Same serialized-owner/root preconditions as PendingCommandPartition.
class ProtectedPendingCommandPartition final {
 public:
  static std::unique_ptr<ProtectedPendingCommandPartition> Acquire(
      const std::wstring& trusted_root, const std::string& receipt_target) noexcept;
  bool Stage(const std::string& expected_target,
      const std::vector<unsigned char>& plaintext) noexcept;
  bool Publish(const std::string& expected_target) noexcept;
  PendingCommandPlaintextCandidate ReadRecovery(const std::string& expected_target) noexcept;
  void Revoke() noexcept;
  ~ProtectedPendingCommandPartition() = default;
  ProtectedPendingCommandPartition(const ProtectedPendingCommandPartition&) = delete;
  ProtectedPendingCommandPartition& operator=(const ProtectedPendingCommandPartition&) = delete;
 private:
  ProtectedPendingCommandPartition(std::unique_ptr<PendingCommandPartition> partition,
      const std::string& target);
  bool Current(const std::string& expected_target) noexcept;
  const std::string target_;
  std::unique_ptr<PendingCommandPartition> partition_;
  bool failed_ = false;
};
}  // namespace nihongo
#endif
