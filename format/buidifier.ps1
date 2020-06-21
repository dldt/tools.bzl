. $PSScriptRoot\common.ps1

$filterout = Get-Ignore-Directories
$filterin = "WORKSPACE", "BUILD", "package.BUILD", "*.bzl", "*.bazel"

$bzlfiles =
    Get-ChildItem -File -Recurse |
    Where-Object {
        $FullName = $_
        -not ($filterout | Where-Object { $FullName -Like "$_*" })
    } |
    Get-ChildItem -Include $filterin
& buildifier $bzlfiles