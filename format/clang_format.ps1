. $PSScriptRoot\common.ps1

$filterout = Get-Ignore-Directories
$filterin = "*.cpp", "*.hpp", "*.c", "*.h"

$cppfiles =
    Get-ChildItem -File -Recurse |
    Where-Object {
        $FullName = $_
        -not ($filterout | Where-Object { $FullName -Like "$_*" })
    } |
    Get-ChildItem -Include $filterin
& clang-format -style=file -i $cppfiles
