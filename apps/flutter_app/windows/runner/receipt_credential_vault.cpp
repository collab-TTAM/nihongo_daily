#include "receipt_credential_vault.h"
#include <algorithm>
#include <string_view>
#ifdef _WIN32
#include <windows.h>
#include <wincred.h>
#include <memory>
#include <utility>
#include <vector>
#endif
namespace nihongo {
namespace {
constexpr std::string_view kPrefix = "NihongoDaily.ConversationReceipt.v1|";
bool Uuid(const std::string& value, bool lower) {
  if (value.size() != 36) return false;
  for (size_t i = 0; i < value.size(); ++i) {
    const char c = value[i];
    if (i == 8 || i == 13 || i == 18 || i == 23) {
      if (c != '-') return false;
    } else if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') ||
                 (!lower && c >= 'A' && c <= 'F'))) return false;
  }
  return true;
}
std::string Lower(std::string value) {
  for (char& c : value) if (c >= 'A' && c <= 'F') c = static_cast<char>(c + ('a' - 'A'));
  return value;
}
}  // namespace
bool IsReceiptTargetValid(const std::string& target) {
  if (target.size() > 600 || target.compare(0, kPrefix.size(), kPrefix) != 0) return false;
  const auto split = target.rfind('|');
  if (split == std::string::npos || split <= kPrefix.size()) return false;
  const auto origin = target.substr(kPrefix.size(), split - kPrefix.size());
  if (origin.size() <= 8 || origin.size() > 480 || origin.compare(0, 8, "https://") != 0 ||
      !Uuid(target.substr(split + 1), true)) return false;
  return std::all_of(origin.begin() + 8, origin.end(), [](char c) {
    return (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') ||
           c == '.' || c == '-' || c == ':' || c == '[' || c == ']';
  });
}
bool IsReceiptReferenceValid(const std::string& target, const std::string& encoded) {
  if (!IsReceiptTargetValid(target) || encoded.empty() || encoded.size() > 1024) return false;
  const auto split = target.rfind('|');
  const auto origin = target.substr(kPrefix.size(), split - kPrefix.size());
  const auto owner = target.substr(split + 1);
  const std::string prefix = "{\"version\":1,\"project_origin\":\"" + origin + "\",\"owner_id\":\"";
  if (encoded.compare(0, prefix.size(), prefix) != 0 || encoded.size() < prefix.size() + 36) return false;
  const auto supplied_owner = encoded.substr(prefix.size(), 36);
  if (!Uuid(supplied_owner, false) || Lower(supplied_owner) != owner) return false;
  for (const char* operation : {"start_conversation", "conversation_turn", "finish_conversation"}) {
    const std::string beginning = prefix + supplied_owner + "\",\"operation\":\"" + operation + "\",\"client_event_id\":\"";
    if (encoded.size() == beginning.size() + 38 && encoded.compare(0, beginning.size(), beginning) == 0 &&
        encoded.compare(encoded.size() - 2, 2, "\"}") == 0 &&
        Uuid(encoded.substr(beginning.size(), 36), false)) return true;
  }
  return false;
}
#ifdef _WIN32
namespace {
struct ReleaseReceipt {
  void operator()(CREDENTIALW* credential) const {
    if (!credential) return;
    if (credential->CredentialBlob && credential->CredentialBlobSize <= CRED_MAX_CREDENTIAL_BLOB_SIZE)
      SecureZeroMemory(credential->CredentialBlob, credential->CredentialBlobSize);
    CredFree(credential);
  }
};
}  // namespace
ReceiptVaultRead ReadReceiptCredential(const std::string& target) {
  if (!IsReceiptTargetValid(target)) return {ReceiptVaultStatus::invalid_input, {}};
  const std::wstring name(target.begin(), target.end());
  PCREDENTIALW raw = nullptr;
  if (!CredReadW(name.c_str(), CRED_TYPE_GENERIC, 0, &raw))
    return {GetLastError() == ERROR_NOT_FOUND ? ReceiptVaultStatus::not_found : ReceiptVaultStatus::unavailable, {}};
  const std::unique_ptr<CREDENTIALW, ReleaseReceipt> credential(raw);
  if (!raw || raw->Type != CRED_TYPE_GENERIC || !raw->CredentialBlob ||
      raw->CredentialBlobSize == 0 || raw->CredentialBlobSize > 1024)
    return {ReceiptVaultStatus::corrupt, {}};
  std::string encoded(reinterpret_cast<const char*>(raw->CredentialBlob), raw->CredentialBlobSize);
  if (!IsReceiptReferenceValid(target, encoded)) {
    SecureZeroMemory(encoded.data(), encoded.size());
    return {ReceiptVaultStatus::corrupt, {}};
  }
  return {ReceiptVaultStatus::success, std::move(encoded)};
}
ReceiptVaultStatus WriteReceiptCredential(const std::string& target, const std::string& encoded) {
  if (!IsReceiptReferenceValid(target, encoded)) return ReceiptVaultStatus::invalid_input;
  std::wstring name(target.begin(), target.end());
  std::vector<BYTE> bytes(encoded.begin(), encoded.end());
  CREDENTIALW credential{};
  credential.Type = CRED_TYPE_GENERIC;
  credential.TargetName = name.data();
  credential.CredentialBlobSize = static_cast<DWORD>(bytes.size());
  credential.CredentialBlob = bytes.data();
  credential.Persist = CRED_PERSIST_LOCAL_MACHINE;
  const bool written = CredWriteW(&credential, 0) != FALSE;
  SecureZeroMemory(bytes.data(), bytes.size());
  return written ? ReceiptVaultStatus::success : ReceiptVaultStatus::unavailable;
}
ReceiptVaultStatus ClearReceiptCredential(const std::string& target) {
  if (!IsReceiptTargetValid(target)) return ReceiptVaultStatus::invalid_input;
  const std::wstring name(target.begin(), target.end());
  if (CredDeleteW(name.c_str(), CRED_TYPE_GENERIC, 0) || GetLastError() == ERROR_NOT_FOUND)
    return ReceiptVaultStatus::success;
  return ReceiptVaultStatus::unavailable;
}
#endif
}  // namespace nihongo
