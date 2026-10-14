#include "session_credential_vault.h"

#include <windows.h>
#include <wincred.h>

#include <algorithm>
#include <memory>
#include <string_view>
#include <utility>
#include <vector>

namespace nihongo {
namespace {
constexpr std::string_view kPrefix = "NihongoDaily.Refresh.v1|https://";
constexpr size_t kMaxSecret = 2048;

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

struct CredentialRelease {
  void operator()(CREDENTIALW* credential) const {
    if (credential) {
      if (credential->CredentialBlob &&
          credential->CredentialBlobSize <= CRED_MAX_CREDENTIAL_BLOB_SIZE) {
        SecureZeroMemory(credential->CredentialBlob,
                         credential->CredentialBlobSize);
      }
      CredFree(credential);
    }
  }
};
}  // namespace

VaultRead ReadRefreshCredential(const std::string& target) {
  if (!ValidTarget(target)) return {VaultStatus::invalid_input, {}};
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
  return written ? VaultStatus::success : VaultStatus::unavailable;
}

VaultStatus ClearRefreshCredential(const std::string& target) {
  if (!ValidTarget(target)) return VaultStatus::invalid_input;
  const std::wstring name(target.begin(), target.end());
  if (CredDeleteW(name.c_str(), CRED_TYPE_GENERIC, 0) ||
      GetLastError() == ERROR_NOT_FOUND) {
    return VaultStatus::success;
  }
  return VaultStatus::unavailable;
}
}  // namespace nihongo
