#include "pending_command_protection.h"
#include "receipt_credential_vault.h"
#include <algorithm>
#include <array>
#include <utility>
#ifdef _WIN32
#include <windows.h>
#include <dpapi.h>
#include <bcrypt.h>
#endif
namespace nihongo {
namespace {
bool Valid(const std::string& target, const std::vector<uint8_t>& bytes, size_t limit) {
  return IsReceiptTargetValid(target) && !bytes.empty() && bytes.size() <= limit;
}
#ifdef _WIN32
constexpr std::array<uint8_t, 8> kMagic = {'N', 'D', 'P', 'C', 1, 0, 0, 0};
constexpr size_t kDigestSize = 32;
// Additional entropy is a domain/partition binding, NOT a hidden key or Auth.
std::string Context(const std::string& target) {
  return "NihongoDaily.PendingCommandProtection.v1|" + target;
}
struct SecretBuffer {
  std::vector<uint8_t> bytes;
  ~SecretBuffer() { if (!bytes.empty()) SecureZeroMemory(bytes.data(), bytes.size()); }
};
struct SecretDigest {
  std::array<uint8_t, kDigestSize> bytes{};
  ~SecretDigest() { SecureZeroMemory(bytes.data(), bytes.size()); }
};
struct LocalBlob {
  DATA_BLOB value{};
  ~LocalBlob() {
    if (value.pbData) {
      SecureZeroMemory(value.pbData, value.cbData);
      LocalFree(value.pbData);
    }
  }
};
bool Digest(const uint8_t* data, size_t size, std::array<uint8_t, kDigestSize>* out) {
  BCRYPT_ALG_HANDLE algorithm = nullptr;
  if (BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, nullptr, 0) < 0)
    return false;
  const auto status = BCryptHash(algorithm, nullptr, 0,
      const_cast<PUCHAR>(data), static_cast<ULONG>(size), out->data(),
      static_cast<ULONG>(out->size()));
  BCryptCloseAlgorithmProvider(algorithm, 0);
  return status >= 0;
}
void Size(std::vector<uint8_t>* frame, size_t size) {
  for (unsigned i = 0; i < 4; ++i)
    frame->push_back(static_cast<uint8_t>((size >> (i * 8)) & 255));
}
uint32_t ReadSize(const std::vector<uint8_t>& frame, size_t offset) {
  uint32_t result = 0;
  for (unsigned i = 0; i < 4; ++i)
    result |= static_cast<uint32_t>(frame[offset + i]) << (i * 8);
  return result;
}
CommandProtectionResult Transform(const std::string& target,
    const std::vector<uint8_t>& input, bool protect) {
  SecretBuffer frame;
  const auto context = Context(target);
  if (protect) {
    frame.bytes.reserve(16 + context.size() + input.size() + kDigestSize);
    frame.bytes.assign(kMagic.begin(), kMagic.end());
    Size(&frame.bytes, context.size());
    Size(&frame.bytes, input.size());
    frame.bytes.insert(frame.bytes.end(), context.begin(), context.end());
    frame.bytes.insert(frame.bytes.end(), input.begin(), input.end());
    SecretDigest digest;
    if (!Digest(frame.bytes.data(), frame.bytes.size(), &digest.bytes))
      return {CommandProtectionStatus::unavailable, {}};
    frame.bytes.insert(frame.bytes.end(), digest.bytes.begin(), digest.bytes.end());
  } else {
    frame.bytes = input;
  }
  DATA_BLOB source{static_cast<DWORD>(frame.bytes.size()), frame.bytes.data()};
  DATA_BLOB entropy{static_cast<DWORD>(context.size()),
      reinterpret_cast<BYTE*>(const_cast<char*>(context.data()))};
  LocalBlob output;
  // User context ONLY; never CRYPTPROTECT_LOCAL_MACHINE or interactive prompts.
  const BOOL ok = protect
      ? CryptProtectData(&source, nullptr, &entropy, nullptr, nullptr,
                         CRYPTPROTECT_UI_FORBIDDEN, &output.value)
      : CryptUnprotectData(&source, nullptr, &entropy, nullptr, nullptr,
                           CRYPTPROTECT_UI_FORBIDDEN, &output.value);
  const size_t max_frame = 16 + context.size() + kPendingCommandPlainLimit + kDigestSize;
  if (!ok || !output.value.pbData || output.value.cbData == 0 ||
      output.value.cbData > (protect ? kPendingCommandCipherLimit : max_frame))
    return {CommandProtectionStatus::unavailable, {}};
  if (protect) {
    return {CommandProtectionStatus::success,
        std::vector<uint8_t>(output.value.pbData, output.value.pbData + output.value.cbData)};
  }
  SecretBuffer decoded;
  decoded.bytes.assign(output.value.pbData, output.value.pbData + output.value.cbData);
  const auto& value = decoded.bytes;
  if (value.size() < 16 + context.size() + 1 + kDigestSize ||
      !std::equal(kMagic.begin(), kMagic.end(), value.begin()) ||
      ReadSize(value, 8) != context.size())
    return {CommandProtectionStatus::unavailable, {}};
  const size_t payload_size = ReadSize(value, 12);
  if (payload_size == 0 || payload_size > kPendingCommandPlainLimit ||
      value.size() != 16 + context.size() + payload_size + kDigestSize ||
      !std::equal(context.begin(), context.end(), value.begin() + 16))
    return {CommandProtectionStatus::unavailable, {}};
  SecretDigest digest;
  if (!Digest(value.data(), value.size() - kDigestSize, &digest.bytes))
    return {CommandProtectionStatus::unavailable, {}};
  uint8_t difference = 0;
  for (size_t i = 0; i < kDigestSize; ++i)
    difference |= static_cast<uint8_t>(digest.bytes[i] ^ value[value.size() - kDigestSize + i]);
  if (difference != 0) return {CommandProtectionStatus::unavailable, {}};
  return {CommandProtectionStatus::success,
      std::vector<uint8_t>(value.begin() + 16 + context.size(), value.end() - kDigestSize)};
}
#endif
}  // namespace
CommandProtectionResult ProtectPendingCommand(const std::string& target,
    const std::vector<uint8_t>& plaintext) {
  if (!Valid(target, plaintext, kPendingCommandPlainLimit))
    return {CommandProtectionStatus::invalid_input, {}};
#ifdef _WIN32
  try { return Transform(target, plaintext, true); }
  catch (...) { return {CommandProtectionStatus::unavailable, {}}; }
#else
  return {CommandProtectionStatus::unavailable, {}};
#endif
}
CommandProtectionResult UnprotectPendingCommand(const std::string& target,
    const std::vector<uint8_t>& ciphertext) {
  if (!Valid(target, ciphertext, kPendingCommandCipherLimit))
    return {CommandProtectionStatus::invalid_input, {}};
#ifdef _WIN32
  try { return Transform(target, ciphertext, false); }
  catch (...) { return {CommandProtectionStatus::unavailable, {}}; }
#else
  return {CommandProtectionStatus::unavailable, {}};
#endif
}
}  // namespace nihongo
