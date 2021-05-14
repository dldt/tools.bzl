# Split the Get-ChildItem into two calls, so it does not traverse symlinks
function Get-Ignore-Directories {
    $submodules = & git config --file .gitmodules --get-regexp path | ForEach-Object { ($_ -Split " ")[1] }
    $bazelfolders = Get-Item -Path "bazel-*"
    $bazelfolders, $submodules | Where-Object { Test-Path -PathType Container $_ } | Get-Item
}
