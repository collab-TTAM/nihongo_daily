# Native Windows receipt credential primitive — Issue #17

Current continuation: parent516f809 Windows probe passed CI40243813552. The
separate receiver/normal runner registration and actual Dart/process probe are
now authored in WINDOWS_RECEIPT_CHANNEL.md; their new-head execution is pending.
The original increment/evidence below is historical. Learner recovery is still
memory-only; no Auth/dispatch authority follows from stored metadata.

Independent receipt_credential_vault.cpp/.h uses Windows Credential Manager generic
credentials for bounded metadata, under NihongoDaily.ConversationReceipt.v1 only.
Auth refresh vault source/allowlist/namespace remains untouched. Targets bind one
HTTPS-origin shape (ASCII lowercase host authority chars, <=480) and lowercase
owner UUID, total<=600. Native checks shape, not DNS/verified Auth/canonical URI
semantics; trusted Dart scope normalization remains required. No learner URL input.

Reference validation accepts ONLY exact local v1 five-field JSON order, origin
matching target, logical owner UUID matching target, three operation names and an
exact UUID event. Owner/event spelling may retain uppercase; no arbitrary fields,
text/token/response/claim/escaped values/whitespace/trailing bytes. Max1024bytes.
This native grammar matches canonical Dart-produced scalar metadata; it is not a
general JSON parser, authentication, receipt lookup proof or dispatch authority.

Read validates credential type/blob bounds and full scope-bound payload. Missing
is distinct from corrupt/unavailable; unknown OS errors are fixed statuses. Invalid
write/target never invokes OS mutation. Temporary write/corrupt-read/raw OS buffers
are wiped before release; returned std::string/Dart values are not zeroization
proof. Clear is exact-target/idempotent. No enumeration, bulk deletion, logging,
plaintext fallback, expiry, pending eviction or cross-process CAS is installed.
The higher Dart store still owns single-writer/no-overwrite/lifecycle rules: the
raw OS write primitive itself replaces one slot and is not a reservation API.
Credential Manager is OS-user scoped, not protection from same-user processes.

New TEST ONLY receipt_vault_probe.cpp is compiled and called inside the existing
mandatory Windows credential probe. All original Auth assertions/build flags are
preserved; failure of receipt checks fails that step. PID-qualified .invalid test
slots only, bounded payloads, independent owner/project entries, invalid writes
preserve prior metadata, replace/read, raw corruption detection, idempotent clear,
Auth allowlist separation and final cleanup of all three slots. OS checks are
AUTHORED locally UNRUN; Windows is unavailable here. No new cloud/live credentials.

Portable validation section of the SAME source/probe compiled locally with g++17
-Wall -Wextra -Werror -pedantic and passed. This does not execute Windows APIs.
Reproduce from root:
 g++ -std=c++17 -Wall -Wextra -Werror -pedantic -DRECEIPT_VALIDATION_MAIN -I apps/flutter_app/windows/runner apps/flutter_app/windows/runner/receipt_credential_vault.cpp apps/flutter_app/tool/windows_session_vault/receipt_vault_probe.cpp -o /tmp/receipt-validation
 /tmp/receipt-validation

Native code is built ONLY by the probe in this increment. MethodChannel receiver,
normal runner registration/build, actual Dart-to-OS and fresh-process restart
probes are STILL pending. Existing missing receiver still fails unavailable; no
application/default/Auth strategy/provider/collection/Pro change. Current learner
route recovery remains memory-only. Next wire separate native channel with exact
argument validation and safe status mapping, then prove actual bridge/restart and
captured runtime persistence-before-send/Auth/profile/drain/authenticated lookup.
All14 hosted gates pending; metadata/null/unknown result never authorizes new event
or provider redispatch. Keep41draft/17open/AIoff/no release acceptance.

Parentd4f3116 CI40238853289/latest attempt1 allfive/every step success/no skips;
Flutter job1244tests/fiveChrome and all17mockchannel cases passed. Component proof,
not hosted learner acceptance. New exact-head full CI/Windows OS probe required.

Local final: portable native validator compiled C++17 with -Wall -Wextra -Werror -pedantic and passed;46 QA/inventory121/whitespace/separate namespace/payload/OS buffer/cleanup/diff review PASS. All120 prior QA cases/findings/gates and original Auth test lines preserved; no Windows/native OS/API execution or local Flutter/build claim.
