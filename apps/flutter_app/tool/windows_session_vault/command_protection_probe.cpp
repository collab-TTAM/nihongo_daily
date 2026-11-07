// TEST ONLY in-memory bytes; no token, learner payload, file or vault write.
#include "pending_command_protection.h"
#include <stdexcept>
#include <string>
#include <vector>
#ifdef _WIN32
#include <windows.h>
#include <dpapi.h>
#include <bcrypt.h>
#endif
namespace {
using nihongo::CommandProtectionStatus;
const std::string kOwner = "a1000000-0000-4000-8000-000000000001";
std::string Target(const std::string& host, const std::string& owner = kOwner) {
  return "NihongoDaily.ConversationReceipt.v1|https://" + host + "|" + owner;
}
void Check(bool value) {
  if (!value) throw std::runtime_error("command protection probe failed");
}
void InvalidInputs() {
  const auto target = Target("command-protection-test.invalid");
  for (const auto& result : {
      nihongo::ProtectPendingCommand(target, {}),
      nihongo::UnprotectPendingCommand(target, {}),
      nihongo::ProtectPendingCommand(target, std::vector<uint8_t>(32769, 1)),
      nihongo::UnprotectPendingCommand(target, std::vector<uint8_t>(65537, 1))}) {
    Check(result.status == CommandProtectionStatus::invalid_input && result.bytes.empty());
  }
  for (const auto& bad : {std::string(), std::string("OtherApplication:key"),
      std::string("NihongoDaily.Refresh.v1|https://command-test.invalid"),
      Target("command-test.invalid/path"), Target("user@command-test.invalid"),
      Target("command-test.invalid", "INVALID"), target + "|extra"}) {
    const auto p = nihongo::ProtectPendingCommand(bad, {1});
    const auto u = nihongo::UnprotectPendingCommand(bad, {1});
    Check(p.status == CommandProtectionStatus::invalid_input && p.bytes.empty());
    Check(u.status == CommandProtectionStatus::invalid_input && u.bytes.empty());
  }
}
}  // namespace
#ifdef _WIN32
namespace {
// TEST ONLY independent producer: hashes malformed frames BEFORE OS protection.
// This deliberately models valid DPAPI/CNG from another same-user writer.
void Put32(std::vector<uint8_t>* bytes, size_t offset, uint32_t value) {
  for (unsigned i = 0; i < 4; ++i)
    (*bytes)[offset + i] = static_cast<uint8_t>((value >> (8 * i)) & 255);
}
std::vector<uint8_t> FixtureProtect(std::vector<uint8_t> frame,
    const std::string& context) {
  BCRYPT_ALG_HANDLE algorithm = nullptr;
  Check(BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, nullptr, 0) >= 0);
  uint8_t digest[32]{};
  const auto status = BCryptHash(algorithm, nullptr, 0, frame.data(),
      static_cast<ULONG>(frame.size()), digest, sizeof(digest));
  BCryptCloseAlgorithmProvider(algorithm, 0);
  Check(status >= 0);
  frame.insert(frame.end(), digest, digest + sizeof(digest));
  SecureZeroMemory(digest, sizeof(digest));
  DATA_BLOB input{static_cast<DWORD>(frame.size()), frame.data()};
  DATA_BLOB entropy{static_cast<DWORD>(context.size()),
      reinterpret_cast<BYTE*>(const_cast<char*>(context.data()))};
  struct Output {
    DATA_BLOB blob{};
    ~Output() {
      if (blob.pbData) {
        SecureZeroMemory(blob.pbData, blob.cbData);
        LocalFree(blob.pbData);
      }
    }
  } output;
  Check(CryptProtectData(&input, nullptr, &entropy, nullptr, nullptr,
      CRYPTPROTECT_UI_FORBIDDEN, &output.blob) != FALSE);
  Check(output.blob.pbData && output.blob.cbData > 0);
  return {output.blob.pbData, output.blob.pbData + output.blob.cbData};
}
void ValidlyProtectedMalformedFrames(const std::string& target) {
  const auto context = "NihongoDaily.PendingCommandProtection.v1|" + target;
  std::vector<uint8_t> control = {'N', 'D', 'P', 'C', 1, 0, 0, 0};
  control.resize(16, 0);
  Put32(&control, 8, static_cast<uint32_t>(context.size()));
  Put32(&control, 12, 3);
  control.insert(control.end(), context.begin(), context.end());
  control.insert(control.end(), {0, 255, 1});
  const auto accepted = nihongo::UnprotectPendingCommand(target, FixtureProtect(control, context));
  Check(accepted.status == CommandProtectionStatus::success);
  Check(accepted.bytes == std::vector<uint8_t>({0, 255, 1}));
  // Control proves the helper is valid; every mutation gets a FRESH valid digest.
  for (unsigned variant = 0; variant < 12; ++variant) {
    auto frame = control;
    switch (variant) {
      case 0: frame[0] ^= 1; break; // Magic.
      case 1: frame[4] = 2; break; // Unknown version.
      case 2: frame[7] = 1; break; // Reserved byte.
      case 3: Put32(&frame, 8, 0); break;
      case 4: Put32(&frame, 8, 0xffffffffu); break;
      case 5: // Actually empty payload, with otherwise consistent lengths.
        Put32(&frame, 12, 0);
        frame.resize(16 + context.size());
        break;
      case 6: Put32(&frame, 12, 32769); break;
      case 7: Put32(&frame, 12, 0xffffffffu); break;
      case 8: frame[16] ^= 1; break; // Correct entropy, wrong embedded context.
      case 9: frame.push_back(0); break; // Trailing byte before valid digest.
      case 10: frame.pop_back(); break; // Truncated payload, fresh valid digest.
      case 11: // Actual oversized decrypted output, not merely bad length.
        Put32(&frame, 12, 32769);
        frame.resize(16 + context.size() + 32769, 1);
        break;
    }
    const auto rejected = nihongo::UnprotectPendingCommand(target, FixtureProtect(frame, context));
    Check(rejected.status == CommandProtectionStatus::unavailable && rejected.bytes.empty());
  }
}
}  // namespace
bool ProbePendingCommandProtection() {
  try {
    InvalidInputs();
    const auto target = Target("command-protection-test.invalid");
    for (const size_t size : {size_t{1}, size_t{256}, size_t{32768}}) {
      std::vector<uint8_t> plain(size);
      for (size_t i = 0; i < size; ++i) plain[i] = static_cast<uint8_t>(i & 255);
      const auto before = plain;
      const auto sealed = nihongo::ProtectPendingCommand(target, plain);
      Check(sealed.status == CommandProtectionStatus::success);
      Check(!sealed.bytes.empty() && sealed.bytes.size() <= 65536 && sealed.bytes != plain);
      Check(plain == before);
      auto restored = nihongo::UnprotectPendingCommand(target, sealed.bytes);
      Check(restored.status == CommandProtectionStatus::success && restored.bytes == plain);
      SecureZeroMemory(restored.bytes.data(), restored.bytes.size());
      for (const auto& foreign : {Target("other-command-test.invalid"),
          Target("command-protection-test.invalid", "a1000000-0000-4000-8000-000000000002")}) {
        const auto rejected = nihongo::UnprotectPendingCommand(foreign, sealed.bytes);
        Check(rejected.status == CommandProtectionStatus::unavailable && rejected.bytes.empty());
      }
      for (const size_t index : {size_t{0}, sealed.bytes.size() / 2, sealed.bytes.size() - 1}) {
        auto corrupted = sealed.bytes;
        corrupted[index] ^= 128;
        const auto rejected = nihongo::UnprotectPendingCommand(target, corrupted);
        Check(rejected.status == CommandProtectionStatus::unavailable && rejected.bytes.empty());
      }
      auto truncated = sealed.bytes;
      truncated.resize(truncated.size() / 2);
      const auto rejected = nihongo::UnprotectPendingCommand(target, truncated);
      Check(rejected.status == CommandProtectionStatus::unavailable && rejected.bytes.empty());
      SecureZeroMemory(plain.data(), plain.size());
    }
    // Valid DPAPI alone cannot bypass framing or the internal SHA-256 check.
    const auto context = "NihongoDaily.PendingCommandProtection.v1|" + target;
    for (const bool framed : {false, true}) {
      std::vector<uint8_t> invalid(64, 1);
      if (framed) {
        invalid = {'N', 'D', 'P', 'C', 1, 0, 0, 0};
        for (const size_t length : {context.size(), size_t{1}}) {
          for (unsigned i = 0; i < 4; ++i)
            invalid.push_back(static_cast<uint8_t>((length >> (8 * i)) & 255));
        }
        invalid.insert(invalid.end(), context.begin(), context.end());
        invalid.push_back(1);
        invalid.insert(invalid.end(), 32, 0); // Deliberately WRONG digest.
      }
      DATA_BLOB input{static_cast<DWORD>(invalid.size()), invalid.data()};
      DATA_BLOB entropy{static_cast<DWORD>(context.size()),
          reinterpret_cast<BYTE*>(const_cast<char*>(context.data()))};
      DATA_BLOB output{};
      const BOOL protected_ok = CryptProtectData(&input, nullptr, &entropy, nullptr,
          nullptr, CRYPTPROTECT_UI_FORBIDDEN, &output);
      if (!protected_ok || !output.pbData) return false;
      const std::vector<uint8_t> raw(output.pbData, output.pbData + output.cbData);
      SecureZeroMemory(output.pbData, output.cbData);
      LocalFree(output.pbData);
      const auto rejected = nihongo::UnprotectPendingCommand(target, raw);
      Check(rejected.status == CommandProtectionStatus::unavailable && rejected.bytes.empty());
    }
    ValidlyProtectedMalformedFrames(target);
    return true;
  } catch (...) { return false; } // Fixed marker only; no OS detail/payload output.
}
#endif
#ifdef COMMAND_PROTECTION_VALIDATION_MAIN
#include <iostream>
int main() {
  try {
    InvalidInputs();
#ifndef _WIN32
    const auto p = nihongo::ProtectPendingCommand(Target("command-test.invalid"), {1});
    const auto u = nihongo::UnprotectPendingCommand(Target("command-test.invalid"), {1});
    Check(p.status == CommandProtectionStatus::unavailable && p.bytes.empty());
    Check(u.status == CommandProtectionStatus::unavailable && u.bytes.empty());
#endif
    std::cout << "PASS: command protection validation/fail-closed fixtures\n";
    return 0;
  } catch (...) { return 1; }
}
#endif
