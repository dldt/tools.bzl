workspace(name = "tools")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "third_party",
    sha256 = "e45bc1c880349ea5b19bb452c1e4805231b56ab8c8810fd141ce7916df457dab",
    strip_prefix = "third_party.bzl-fe80e14d5bd2f20f0c5588daca2c8daf4755621b/",
    url = "https://github.com/dldt/third_party.bzl/archive/fe80e14d5bd2f20f0c5588daca2c8daf4755621b.zip",
)

load("@third_party//:workspace.bzl", "workspace_repositories")

workspace_repositories()
