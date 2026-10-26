cmake_minimum_required(VERSION 3.14)
project(session_vault_probe LANGUAGES CXX)
if(NOT WIN32)
  message(FATAL_ERROR "Actual Windows credential store is required")
endif()
add_executable(session_vault_probe
  "session_vault_probe.cpp"
  "receipt_vault_probe.cpp"
  "command_protection_probe.cpp"
  "../../windows/runner/pending_command_protection.cpp"
  "../../windows/runner/receipt_credential_vault.cpp"
  "../../windows/runner/session_credential_vault.cpp"
)
target_compile_features(session_vault_probe PRIVATE cxx_std_17)
target_compile_definitions(session_vault_probe PRIVATE NOMINMAX UNICODE _UNICODE)
target_compile_options(session_vault_probe PRIVATE /W4 /WX /EHsc)
target_link_libraries(session_vault_probe PRIVATE advapi32 crypt32 bcrypt)
target_include_directories(session_vault_probe PRIVATE "../../windows/runner")
