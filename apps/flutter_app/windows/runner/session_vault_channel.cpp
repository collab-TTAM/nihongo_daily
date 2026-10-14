#include "session_vault_channel.h"

#include <flutter/standard_method_codec.h>
#include "session_credential_vault.h"

namespace {
void Fail(flutter::MethodResult<flutter::EncodableValue>* result) {
  result->Error("session_vault_unavailable", "Session storage unavailable");
}
}  // namespace

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
RegisterSessionVaultChannel(flutter::BinaryMessenger* messenger) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "nihongo_daily/session_vault_v1",
          &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler([](
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    const auto& method = call.method_name();
    if (method != "read" && method != "write" && method != "clear") {
      result->NotImplemented();
      return;
    }
    const auto* args = call.arguments()
                           ? std::get_if<flutter::EncodableMap>(call.arguments())
                           : nullptr;
    if (!args || args->size() != (method == "write" ? 2u : 1u)) {
      Fail(result.get());
      return;
    }
    const auto target_it = args->find(flutter::EncodableValue("target"));
    const auto* target = target_it == args->end()
                             ? nullptr
                             : std::get_if<std::string>(&target_it->second);
    if (!target) {
      Fail(result.get());
      return;
    }
    if (method == "read") {
      const auto read = nihongo::ReadRefreshCredential(*target);
      if (read.status == nihongo::VaultStatus::not_found) {
        result->Success(flutter::EncodableValue());
      } else if (read.status == nihongo::VaultStatus::success) {
        result->Success(flutter::EncodableValue(read.token));
      } else {
        Fail(result.get());
      }
    } else if (method == "clear") {
      if (nihongo::ClearRefreshCredential(*target) ==
          nihongo::VaultStatus::success) {
        result->Success(flutter::EncodableValue(true));
      } else {
        Fail(result.get());
      }
    } else {
      const auto it = args->find(flutter::EncodableValue("token"));
      const auto* token = it == args->end()
                              ? nullptr
                              : std::get_if<std::string>(&it->second);
      if (token && nihongo::WriteRefreshCredential(*target, *token) ==
                       nihongo::VaultStatus::success) {
        result->Success(flutter::EncodableValue(true));
      } else {
        Fail(result.get());
      }
    }
  });
  return channel;
}
