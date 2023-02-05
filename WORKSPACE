workspace(name = "tools")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "third_party",
    sha256 = "65deaa109a43be0d8c8257e1078b456e91744fa8a09e32cbf77ffc8c3474d1e1",
    strip_prefix = "third_party.bzl-2ffe2a37b913830c2b8e2878af2d3ec0ffd053a1/",
    url = "https://github.com/dldt/third_party.bzl/archive/2ffe2a37b913830c2b8e2878af2d3ec0ffd053a1.zip",
)

load("@third_party//:workspace.bzl", "workspace_repositories")

workspace_repositories()
