#ifndef RUNNER_REVIEW_DATA_DIRECTORY_H_
#define RUNNER_REVIEW_DATA_DIRECTORY_H_
#include <string>
// Current OS user's LocalAppData + fixed namespace + SHA256(canonical target).
// Resolves only; never creates/deletes files or returns raw OS error details.
bool ResolveReviewDataDirectory(const std::string& target, std::string* path);
#endif
