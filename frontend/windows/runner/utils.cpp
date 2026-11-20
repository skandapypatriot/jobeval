#include "utils.h"
#include <flutter_windows.h>
#include <iostream>

std::string GetExePath() {
    wchar_t path[MAX_PATH];
    GetModuleFileNameW(nullptr, path, MAX_PATH);
    return std::string(path, path + wcslen(path));
}