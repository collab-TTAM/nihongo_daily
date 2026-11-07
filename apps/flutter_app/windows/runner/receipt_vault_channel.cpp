#include "receipt_vault_channel.h"

#include <flutter/standard_method_codec.h>
#include "receipt_credential_vault.h"
#include "pending_command_protection.h"

namespace {
void Fail(flutter::MethodResult<flutter::EncodableValue>* result) {
  result->Error("receipt_storage_unavailable", "Receipt storage unavailable");
}
}  // namespace

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
RegisterReceiptVaultChannel(flutter::BinaryMessenger* messenger) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "nihongo_daily/conversation_receipts_v1",
          &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler([](
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    const auto& method = call.method_name();
    const bool transform = method == "protectCommand" || method == "unprotectCommand";
    if (method != "read" && method != "write" && method != "clear" && !transform) {
      result->NotImplemented();
      return;
    }
    try {
      const auto* args = call.arguments()
                             ? std::get_if<flutter::EncodableMap>(call.arguments())
                             : nullptr;
      if (!args || args->size() != ((method == "write" || transform) ? 2u : 1u)) {
        Fail(result.get());
        return;
      }
      const auto it = args->find(flutter::EncodableValue("target"));
      const auto* target = it == args->end()
                               ? nullptr
                               : std::get_if<std::string>(&it->second);
      if (!target || !nihongo::IsReceiptTargetValid(*target)) {
        Fail(result.get());
        return;
      }
      if (transform) {
        const auto entry = args->find(flutter::EncodableValue("bytes"));
        const auto* bytes = entry == args->end()
                                ? nullptr
                                : std::get_if<std::vector<uint8_t>>(&entry->second);
        if (!bytes) {
          Fail(result.get());
          return;
        }
        const auto value = method == "protectCommand"
            ? nihongo::ProtectPendingCommand(*target, *bytes)
            : nihongo::UnprotectPendingCommand(*target, *bytes);
        if (value.status == nihongo::CommandProtectionStatus::success) {
          result->Success(flutter::EncodableValue(value.bytes));
        } else {
          Fail(result.get());
        }
      } else if (method == "read") {
        const auto read = nihongo::ReadReceiptCredential(*target);
        if (read.status == nihongo::ReceiptVaultStatus::not_found) {
          result->Success(flutter::EncodableValue());
        } else if (read.status == nihongo::ReceiptVaultStatus::success) {
          result->Success(flutter::EncodableValue(read.encoded));
        } else {
          Fail(result.get());
        }
      } else if (method == "clear") {
        if (nihongo::ClearReceiptCredential(*target) ==
            nihongo::ReceiptVaultStatus::success) {
          result->Success(flutter::EncodableValue(true));
        } else {
          Fail(result.get());
        }
      } else {
        const auto ref = args->find(flutter::EncodableValue("reference"));
        const auto* encoded = ref == args->end()
                                  ? nullptr
                                  : std::get_if<std::string>(&ref->second);
        if (encoded && nihongo::WriteReceiptCredential(*target, *encoded) ==
                           nihongo::ReceiptVaultStatus::success) {
          result->Success(flutter::EncodableValue(true));
        } else {
          Fail(result.get());
        }
      }
    } catch (...) {
      // Never expose OS errors, target identifiers or payloads to the channel.
      Fail(result.get());
    }
  });
  return channel;
}
