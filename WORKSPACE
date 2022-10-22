workspace(name = "tools")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "third_party",
    sha256 = "9589c37e54f351a41f1e373ec9299d5f80b0098865c515d595e676882cb49f6c",
    strip_prefix = "third_party.bzl-d966852c9de94e096675c90821b4f7f134811d0d/",
    url = "https://github.com/dldt/third_party.bzl/archive/d966852c9de94e096675c90821b4f7f134811d0d.zip",
)

load("@third_party//:workspace.bzl", "workspace_repositories")

workspace_repositories()
