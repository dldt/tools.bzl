SourceFilesInfo = provider(
    doc = "Aggregate C++ source files for a given target",
    fields = dict(
        srcs = "Non transitive source file list",
        hdrs = "Non transitive header file list",
    ),
)

def _source_files_aspect_impl(target, ctx):
    srcs = []
    hdrs = []

    if "srcs" in dir(ctx.rule.attr):
        srcs += [f for src in ctx.rule.attr.srcs for f in src.files.to_list()]

    if "hdrs" in dir(ctx.rule.attr):
        hdrs += [f for src in ctx.rule.attr.hdrs for f in src.files.to_list()]

    return [
        SourceFilesInfo(
            srcs = srcs,
            hdrs = hdrs,
        ),
    ]

source_files_aspect = aspect(
    attr_aspects = ["deps"],
    implementation = _source_files_aspect_impl,
)

def _run_clang_tidy_impl(ctx):
    # Generates a single compile_commands.json file with the
    # transitive depset of specified targets.

    files = []
    for target in ctx.attr.targets:
        for srcs in target[SourceFilesInfo].srcs:
            files.append(srcs)
        for hdrs in target[SourceFilesInfo].hdrs:
            files.append(hdrs)

    ctx.actions.run(
        outputs = [ctx.outputs.filename],
        inputs = ctx.attr.compile_commands.files.to_list() + files,
        executable = "clang-tidy",
        arguments = [ctx.expand_location("-p=$(location " + str(ctx.attr.compile_commands.label) + ")", targets = [ctx.attr.compile_commands]), "--export-fixes=" + str(ctx.outputs.filename.path)] + [f.path for f in files],
        progress_message = "Running clang-tidy on selected targets",
        mnemonic = "ClangTidy",
    )

run_clang_tidy = rule(
    attrs = {
        "targets": attr.label_list(
            aspects = [source_files_aspect],
            doc = "List of all cc targets which should be included.",
        ),
        "compile_commands": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
        "disable": attr.bool(
            default = False,
            doc = ("Makes this operation a no-op; useful in combination with a 'select' " +
                   "for platforms where the internals of this rule are not properly " +
                   "supported. For known unsupported platforms (e.g. Windows), the " +
                   "rule is always a no-op."),
        ),
    },
    outputs = {
        "filename": "fixes.xml",
    },
    implementation = _run_clang_tidy_impl,
)
