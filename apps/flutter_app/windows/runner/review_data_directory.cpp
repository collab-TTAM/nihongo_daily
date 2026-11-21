#include "review_data_directory.h"
#include "session_credential_vault.h"
#include <windows.h>
#include <bcrypt.h>
#include <shlobj.h>
#include <array>
#include <vector>
#include <utility>

bool ResolveReviewDataDirectory(const std::string& target, std::string* path) {
  if (!path || !nihongo::IsCredentialTargetValid(target)) return false;
  BCRYPT_ALG_HANDLE algorithm = nullptr;
  if (BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, nullptr, 0) < 0) return false;
  std::vector<UCHAR> input(target.begin(), target.end());
  std::array<UCHAR, 32> digest{};
  const auto status = BCryptHash(algorithm, nullptr, 0, input.data(),
      static_cast<ULONG>(input.size()), digest.data(), static_cast<ULONG>(digest.size()));
  BCryptCloseAlgorithmProvider(algorithm, 0);
  if (status < 0) return false;
  constexpr wchar_t hex[] = L"0123456789abcdef";
  std::wstring key;
  for (const auto value : digest) {
    key.push_back(hex[value >> 4]);
    key.push_back(hex[value & 15]);
  }
  PWSTR raw = nullptr;
  const HRESULT result = SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &raw);
  const std::wstring base = SUCCEEDED(result) && raw ? raw : L"";
  CoTaskMemFree(raw);
  if (base.size() < 3 || base[1] != L':' || base[2] != L'\\') return false;
  const auto directory = base + L"\\NihongoDaily\\ReviewJournal\\v1\\" + key;
  // Do not silently fall back to cwd/temp/network when an OS profile is unusual.
  if (directory.size() > 240) return false;
  const auto length = static_cast<int>(directory.size());
  const int bytes = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS,
      directory.data(), length, nullptr, 0, nullptr, nullptr);
  if (bytes <= 0) return false;
  std::string utf8(static_cast<size_t>(bytes), '\0');
  if (WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, directory.data(),
      length, utf8.data(), bytes, nullptr, nullptr) != bytes) return false;
  *path = std::move(utf8);
  return true;
}
