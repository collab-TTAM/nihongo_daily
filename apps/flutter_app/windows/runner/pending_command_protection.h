#ifndef NIHONGO_PENDING_COMMAND_PROTECTION_H_
#define NIHONGO_PENDING_COMMAND_PROTECTION_H_
#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>
namespace nihongo {
// Opaque bytes only: not a storage backend, Auth check or receipt release grant.
constexpr size_t kPendingCommandPlainLimit = 32768;
constexpr size_t kPendingCommandCipherLimit = 65536;
enum class CommandProtectionStatus { success, invalid_input, unavailable };
struct CommandProtectionResult {
  CommandProtectionStatus status;
  std::vector<uint8_t> bytes;
};
// receipt_target is validated as existing canonical metadata scope; NEVER written.
CommandProtectionResult ProtectPendingCommand(
    const std::string& receipt_target, const std::vector<uint8_t>& plaintext);
CommandProtectionResult UnprotectPendingCommand(
    const std::string& receipt_target, const std::vector<uint8_t>& ciphertext);
}  // namespace nihongo
#endif
