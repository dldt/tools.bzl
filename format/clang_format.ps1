# Split the Get-ChildItem into two calls, so it does not traverse symlinks
$cppfiles = Get-ChildItem -Path . -File -Recurse | Get-ChildItem -Include "*.cpp", "*.hpp", "*.c", "*.h"
& clang-format -style=file -i $cppfiles
