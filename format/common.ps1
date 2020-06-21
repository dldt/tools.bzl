# Split the Get-ChildItem into two calls, so it does not traverse symlinks
function Get-Ignore-Directories {
    $submodules = & git config --file .gitmodules --get-regexp path | ForEach-Object { ($_ -Split " ")[1] }
    ".bazel/", $submodules | Where-Object { Test-Path $_ } | Get-Item
}
