#ifndef NIHONGO_PENDING_COMMAND_FILE_LEASE_H_
#define NIHONGO_PENDING_COMMAND_FILE_LEASE_H_
#include <memory>
#include <string>
#include <vector>
namespace nihongo {
// Exclusive empty sentinel only. NOT a payload backend, ACL or writer identity
// proof. Host must establish trusted local directory ownership/ACL first.
class PendingCommandFileLease final {
 public:
  static std::unique_ptr<PendingCommandFileLease> Acquire(
      const std::wstring& trusted_directory) noexcept;
  ~PendingCommandFileLease();
  PendingCommandFileLease(const PendingCommandFileLease&) = delete;
  PendingCommandFileLease& operator=(const PendingCommandFileLease&) = delete;
 private:
  PendingCommandFileLease() = default;
  std::vector<void*> directories_;
  void* file_ = nullptr;
};
}  // namespace nihongo
#endif
