// TEST ONLY in-memory bytes; no token, learner payload, file or vault write.
#include "pending_command_protection.h"
#include <stdexcept>
#include <string>
#include <vector>
#ifdef _WIN32
#include <windows.h>
#include <dpapi.h>
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
