workspace(name = "tools")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "third_party",
    sha256 = "5fd3227d294b9b091737bfff686319f54d3ed1ad9b9d6561f77dd28ff5467912",
    url = "https://github.com/dldt/third_party.bzl/archive/05f2a2c9812bdf298c4038500fbf3f42a8c6deea.zip",
    strip_prefix = "third_party.bzl-05f2a2c9812bdf298c4038500fbf3f42a8c6deea/"
)

load("@third_party//:workspace.bzl", "workspace_repositories")

workspace_repositories()
