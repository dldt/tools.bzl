workspace(name = "tools")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "third_party",
    sha256 = "1fd0f12f78f36a9902044cbec2e80f84120f28287c456e3206a2a9602a318d9d",
    strip_prefix = "third_party.bzl-2cc78df616978f7abd62ce004c509c2b62d1e105/",
    url = "https://github.com/dldt/third_party.bzl/archive/2cc78df616978f7abd62ce004c509c2b62d1e105.zip",
)

load("@third_party//:workspace.bzl", "workspace_repositories")

workspace_repositories()
