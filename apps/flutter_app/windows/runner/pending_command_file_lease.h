#ifndef NIHONGO_PENDING_COMMAND_FILE_LEASE_H_
#define NIHONGO_PENDING_COMMAND_FILE_LEASE_H_
#include <memory>
#include <string>
namespace nihongo {
// Exclusive empty sentinel only. NOT a payload backend, ACL or writer identity
// proof. Host must supply an already trusted, ancestor-protected local directory.
class PendingCommandFileLease final {
 public:
  static std::unique_ptr<PendingCommandFileLease> Acquire(
      const std::wstring& trusted_directory) noexcept;
  ~PendingCommandFileLease();
  PendingCommandFileLease(const PendingCommandFileLease&) = delete;
  PendingCommandFileLease& operator=(const PendingCommandFileLease&) = delete;
 private:
  PendingCommandFileLease() = default;
  void* directory_ = nullptr;
  void* file_ = nullptr;
};
}  // namespace nihongo
#endif
