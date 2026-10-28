#include "pending_command_partition.h"
#include "receipt_credential_vault.h"
#include <utility>
#ifdef _WIN32
#include <windows.h>
#include <bcrypt.h>
#include <array>
#endif
namespace nihongo {
PendingCommandPartition::PendingCommandPartition(
    std::unique_ptr<PendingCommandFileLease> lease, const std::string& target)
    : target_(target), lease_(std::move(lease)) {}
std::unique_ptr<PendingCommandPartition> PendingCommandPartition::Acquire(
    const std::wstring& trusted_root, const std::string& receipt_target) noexcept {
  try {
    // Validate before hashing or any filesystem operation. No normalization,
    // caller-selected leaf/basename, directory creation or fallback.
    // 136 + 20 fixed suffix characters + 64 hex characters = lease limit220.
    if (!IsReceiptTargetValid(receipt_target) || trusted_root.size() > 136)
      return nullptr;
#ifdef _WIN32
    const auto context = "NihongoDaily.PendingCommandPartition.v1|" + receipt_target;
    struct Algorithm {
      BCRYPT_ALG_HANDLE value = nullptr;
      ~Algorithm() { if (value) BCryptCloseAlgorithmProvider(value, 0); }
    } algorithm;
    if (BCryptOpenAlgorithmProvider(&algorithm.value, BCRYPT_SHA256_ALGORITHM,
        nullptr, 0) < 0) return nullptr;
    std::array<unsigned char, 32> digest{};
    if (BCryptHash(algorithm.value, nullptr, 0,
        reinterpret_cast<PUCHAR>(const_cast<char*>(context.data())),
        static_cast<ULONG>(context.size()), digest.data(),
        static_cast<ULONG>(digest.size())) < 0) return nullptr;
    constexpr wchar_t hex[] = L"0123456789abcdef";
    auto directory = trusted_root + L"\\pending-command-v1\\";
    for (const auto byte : digest) {
      directory.push_back(hex[byte >> 4]);
      directory.push_back(hex[byte & 15]);
    }
    // The lower-level walk rejects non-local/dot/reparse/oversized paths and
    // holds every ancestor plus the exclusive fixed sentinel until destruction.
    auto lease = PendingCommandFileLease::Acquire(directory);
    if (!lease || !lease->CheckPrivateAccessPolicy()) return nullptr;
    return std::unique_ptr<PendingCommandPartition>(
        new PendingCommandPartition(std::move(lease), receipt_target));
#else
    return nullptr;
#endif
  } catch (...) { return nullptr; } // No scope/path/OS diagnostics.
}
void PendingCommandPartition::Revoke() noexcept {
  failed_ = true; // Keep exclusive ownership and uncertain data until owner closes.
}
bool PendingCommandPartition::Current(const std::string& expected_target) noexcept {
  // Exact captured canonical target. A mismatch never opens another partition
  // and permanently fences this object, including its originally valid target.
  if (failed_) return false;
  if (expected_target != target_ || !lease_->CheckPrivateAccessPolicy()) {
    failed_ = true;
    return false;
  }
  return true;
}
PendingCommandCandidate PendingCommandPartition::ReadRecoveryCiphertextCandidate(
    const std::string& expected_target) noexcept {
  if (!Current(expected_target)) return {};
  auto result = lease_->ReadRecoveryCiphertextCandidate();
  if (result.state == PendingCommandCandidateState::unavailable) failed_ = true;
  return result; // Opaque data only; no decryption, receipt or dispatch authority.
}
bool PendingCommandPartition::StageCiphertextCandidate(
    const std::string& expected_target, const std::vector<unsigned char>& bytes) noexcept {
  if (!Current(expected_target)) return false;
  if (!lease_->StageCiphertextCandidate(bytes)) { failed_ = true; return false; }
  return true;
}
bool PendingCommandPartition::PublishStagedCiphertextCandidate(
    const std::string& expected_target) noexcept {
  if (!Current(expected_target)) return false;
  if (!lease_->PublishStagedCiphertextCandidate()) { failed_ = true; return false; }
  return true; // Namespace publication only, NOT durable success before dispatch.
}
}  // namespace nihongo
