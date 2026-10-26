#include "receipt_vault_channel.h"

#include <flutter/standard_method_codec.h>
#include "receipt_credential_vault.h"

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
    if (method != "read" && method != "write" && method != "clear") {
      result->NotImplemented();
      return;
    }
    try {
      const auto* args = call.arguments()
                             ? std::get_if<flutter::EncodableMap>(call.arguments())
                             : nullptr;
      if (!args || args->size() != (method == "write" ? 2u : 1u)) {
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
      if (method == "read") {
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
