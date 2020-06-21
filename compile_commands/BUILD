load("@rules_cc//cc:defs.bzl", "cc_binary")

cc_binary(
    name = "fix_compilation_db",
    srcs = ["fix_compilation_db.cpp"],
    visibility = ["//visibility:public"],
    deps = [
        "@argparse",
        "@fmt",
        "@nlohmannjson",
    ],
)
