# Split the Get-ChildItem into two calls, so it does not traverse symlinks
$bzlfiles = Get-ChildItem -Path . -File -Recurse | Get-ChildItem -Include "WORKSPACE", "BUILD", "package.BUILD", "*.bzl"
& buildifier $bzlfiles
