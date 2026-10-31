// TEST ONLY fixtures; no live credentials, tokens or transcript content.
#include "receipt_credential_vault.h"
#include <stdexcept>
#include <string>
#ifdef _WIN32
#include <windows.h>
#include <wincred.h>
#include "session_credential_vault.h"
#endif
namespace {
const std::string owner = "a1000000-0000-4000-8000-000000000001";
const std::string other = "a1000000-0000-4000-8000-000000000002";
const std::string event = "B1000000-0000-4000-8000-000000000001";
std::string Target(const std::string& host, const std::string& user) {
  return "NihongoDaily.ConversationReceipt.v1|https://" + host + "|" + user;
}
std::string Reference(const std::string& host, const std::string& user,
                      const std::string& operation = "start_conversation") {
  return "{\"version\":1,\"project_origin\":\"https://" + host + "\",\"owner_id\":\"" + user +
         "\",\"operation\":\"" + operation + "\",\"client_event_id\":\"" + event + "\"}";
}
void Check(bool ok) { if (!ok) throw std::runtime_error("receipt probe failed"); }
void ValidationChecks() {
  const auto target = Target("receipt-test.invalid", owner);
  const auto valid = Reference("receipt-test.invalid", owner);
  for (const char* op : {"start_conversation", "conversation_turn", "finish_conversation"})
    Check(nihongo::IsReceiptReferenceValid(target, Reference("receipt-test.invalid", owner, op)));
  Check(nihongo::IsReceiptTargetValid(target));
  for (const auto& bad : {std::string(), std::string("OtherApplication:key"),
       std::string("NihongoDaily.Refresh.v1|https://receipt-test.invalid"),
       Target("receipt-test.invalid/path", owner), Target("user@receipt-test.invalid", owner),
       Target("receipt-test.invalid", "PRIVATE"), target + "|extra"})
    Check(!nihongo::IsReceiptTargetValid(bad));
  for (const auto& bad : {std::string(), valid + " ", valid + "{}", std::string(1025, 'x'),
       Reference("other.invalid", owner), Reference("receipt-test.invalid", other),
       Reference("receipt-test.invalid", owner, "tutor_explain"),
       std::string("{\"access_token\":\"PRIVATE\"}"), std::string("PRIVATE")})
    Check(!nihongo::IsReceiptReferenceValid(target, bad));
  auto changed = valid;
  changed.replace(11, 1, "2");
  Check(!nihongo::IsReceiptReferenceValid(target, changed));
  changed = valid;
  changed.insert(changed.size() - 1, ",\"text_ja\":\"PRIVATE\"");
  Check(!nihongo::IsReceiptReferenceValid(target, changed));
  changed = valid;
  changed.insert(1, "\"version\":1,");
  Check(!nihongo::IsReceiptReferenceValid(target, changed));
}
}  // namespace
#ifdef _WIN32
bool ProbeReceiptCredentials() {
  using nihongo::ReceiptVaultStatus;
  const auto host = "ci-receipt-" + std::to_string(GetCurrentProcessId()) + ".invalid";
  const auto a = Target(host, owner);
  const auto b = Target(host, other);
  const auto c = Target("other-" + host, owner);
  bool passed = false;
  try {
    ValidationChecks();
    Check(!nihongo::IsCredentialTargetValid(a)); // Auth allowlist remains separate.
    Check(nihongo::ClearReceiptCredential(a) == ReceiptVaultStatus::success);
    Check(nihongo::ReadReceiptCredential(a).status == ReceiptVaultStatus::not_found);
    Check(nihongo::WriteReceiptCredential(a, Reference(host, owner)) == ReceiptVaultStatus::success);
    Check(nihongo::WriteReceiptCredential(b, Reference(host, other)) == ReceiptVaultStatus::success);
    Check(nihongo::WriteReceiptCredential(c, Reference("other-" + host, owner)) == ReceiptVaultStatus::success);
    Check(nihongo::ReadReceiptCredential(a).encoded == Reference(host, owner));
    Check(nihongo::WriteReceiptCredential(a, Reference(host, other)) == ReceiptVaultStatus::invalid_input);
    Check(nihongo::WriteReceiptCredential(a, std::string(1025, 'x')) == ReceiptVaultStatus::invalid_input);
    Check(nihongo::ReadReceiptCredential(a).encoded == Reference(host, owner));
    Check(nihongo::WriteReceiptCredential(a, Reference(host, owner, "finish_conversation")) == ReceiptVaultStatus::success);
    Check(nihongo::ReadReceiptCredential(a).encoded == Reference(host, owner, "finish_conversation"));
    // TEST ONLY direct corruption of this PID-qualified .invalid slot.
    std::wstring name(a.begin(), a.end());
    BYTE raw[] = {'x', 0, 'y'};
    CREDENTIALW credential{};
    credential.Type = CRED_TYPE_GENERIC;
    credential.TargetName = name.data();
    credential.CredentialBlobSize = sizeof(raw);
    credential.CredentialBlob = raw;
    credential.Persist = CRED_PERSIST_LOCAL_MACHINE;
    Check(CredWriteW(&credential, 0) != FALSE);
    Check(nihongo::ReadReceiptCredential(a).status == ReceiptVaultStatus::corrupt);
    Check(nihongo::ClearReceiptCredential(a) == ReceiptVaultStatus::success);
    Check(nihongo::ClearReceiptCredential(a) == ReceiptVaultStatus::success);
    Check(nihongo::ReadReceiptCredential(b).encoded == Reference(host, other));
    Check(nihongo::ReadReceiptCredential(c).encoded == Reference("other-" + host, owner));
    Check(nihongo::ClearReceiptCredential("OtherApplication:key") == ReceiptVaultStatus::invalid_input);
    passed = true;
  } catch (...) {}
  const bool ca = nihongo::ClearReceiptCredential(a) == ReceiptVaultStatus::success;
  const bool cb = nihongo::ClearReceiptCredential(b) == ReceiptVaultStatus::success;
  const bool cc = nihongo::ClearReceiptCredential(c) == ReceiptVaultStatus::success;
  return passed && ca && cb && cc;
}
#endif
#ifdef RECEIPT_VALIDATION_MAIN
#include <iostream>
int main() {
  try { ValidationChecks(); std::cout << "PASS: native receipt validation fixtures\n"; return 0; }
  catch (...) { std::cerr << "FAIL: native receipt validation fixtures\n"; return 1; }
}
#endif
