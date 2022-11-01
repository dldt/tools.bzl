workspace(name = "tools")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "third_party",
    sha256 = "7a51e1e8f2799ef37c965c7df17a12a9d4b9d8781ff61a73086cad173380b9a8",
    strip_prefix = "third_party.bzl-86bca4efcbb39069f0e897c0d191b87a26607df6/",
    url = "https://github.com/dldt/third_party.bzl/archive/86bca4efcbb39069f0e897c0d191b87a26607df6.zip",
)

load("@third_party//:workspace.bzl", "workspace_repositories")

workspace_repositories()
