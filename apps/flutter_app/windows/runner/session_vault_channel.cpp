#include "session_vault_channel.h"

#include <flutter/standard_method_codec.h>
#include "session_credential_vault.h"
#include "review_data_directory.h"

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
    if (method != "read" && method != "write" && method != "clear" &&
        method != "reviewDirectory" && method != "acquireOwner" &&
        method != "releaseOwner"
#if defined(NIHONGO_SESSION_VAULT_TEST_HOOKS)
        && method != "testInjectFault"
#endif
    ) {
      result->NotImplemented();
      return;
    }
    const auto* args = call.arguments()
                           ? std::get_if<flutter::EncodableMap>(call.arguments())
                           : nullptr;
    const auto expected_arguments =
        method == "write" ? 2u : method == "testInjectFault" ? 3u : 1u;
    if (!args || args->size() != expected_arguments) {
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
#if defined(NIHONGO_SESSION_VAULT_TEST_HOOKS)
    if (method == "testInjectFault") {
      const auto operation_it =
          args->find(flutter::EncodableValue("operation"));
      const auto fault_it = args->find(flutter::EncodableValue("fault"));
      const auto* operation =
          operation_it == args->end()
              ? nullptr
              : std::get_if<std::string>(&operation_it->second);
      const auto* fault =
          fault_it == args->end()
              ? nullptr
              : std::get_if<std::string>(&fault_it->second);
      const std::string suffix = ".invalid";
      if (!nihongo::IsCredentialTargetValid(*target) ||
          target->size() <= suffix.size() ||
          target->compare(target->size() - suffix.size(), suffix.size(),
                          suffix) != 0 ||
          !operation || !fault) {
        Fail(result.get());
        return;
      }
      nihongo::VaultProbeOperation native_operation;
      if (*operation == "read") {
        native_operation = nihongo::VaultProbeOperation::read;
      } else if (*operation == "write") {
        native_operation = nihongo::VaultProbeOperation::write;
      } else if (*operation == "clear") {
        native_operation = nihongo::VaultProbeOperation::clear;
      } else {
        Fail(result.get());
        return;
      }
      nihongo::VaultProbeFault native_fault;
      if (*fault == "fail_before") {
        native_fault = nihongo::VaultProbeFault::fail_before;
      } else if (*fault == "commit_then_fail" &&
                 native_operation == nihongo::VaultProbeOperation::write) {
        native_fault = nihongo::VaultProbeFault::commit_then_fail;
      } else {
        Fail(result.get());
        return;
      }
      nihongo::SetVaultProbeFaultOnce(native_operation, native_fault);
      result->Success(flutter::EncodableValue(true));
      return;
    }
#endif
    if (method == "acquireOwner") {
      if (nihongo::AcquireCredentialOwner(*target) ==
          nihongo::VaultStatus::success) {
        result->Success(flutter::EncodableValue(true));
      } else {
        Fail(result.get());
      }
    } else if (method == "releaseOwner") {
      if (nihongo::ReleaseCredentialOwner(*target) ==
          nihongo::VaultStatus::success) {
        result->Success(flutter::EncodableValue(true));
      } else {
        Fail(result.get());
      }
    } else if (method == "reviewDirectory") {
      std::string path;
      if (ResolveReviewDataDirectory(*target, &path)) {
        result->Success(flutter::EncodableValue(path));
      } else {
        Fail(result.get());
      }
    } else if (method == "read") {
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
