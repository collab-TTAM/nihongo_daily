#ifndef NIHONGO_RECEIPT_CREDENTIAL_VAULT_H_
#define NIHONGO_RECEIPT_CREDENTIAL_VAULT_H_
#include <string>
namespace nihongo {
enum class ReceiptVaultStatus { success, not_found, invalid_input, corrupt, unavailable };
struct ReceiptVaultRead { ReceiptVaultStatus status; std::string encoded; };
bool IsReceiptTargetValid(const std::string& target);
bool IsReceiptReferenceValid(const std::string& target, const std::string& encoded);
ReceiptVaultRead ReadReceiptCredential(const std::string& target);
ReceiptVaultStatus WriteReceiptCredential(const std::string& target, const std::string& encoded);
ReceiptVaultStatus ClearReceiptCredential(const std::string& target);
}  // namespace nihongo
#endif
