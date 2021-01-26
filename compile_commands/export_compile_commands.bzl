"""Export a clang compatible compilation database from bazel rules_cc.

Inspired by https://github.com/grailbio/bazel-compilation-database
"""

# Handle a :all or //package

load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cc_toolchain")
load(
    "@rules_cc//cc:action_names.bzl",
    "CPP_COMPILE_ACTION_NAME",
    "C_COMPILE_ACTION_NAME",
    "OBJCPP_COMPILE_ACTION_NAME",
    "OBJC_COMPILE_ACTION_NAME",
)

CompileInfo = provider(
    doc = "Compilation information for a given source file",
    fields = dict(
        compilation_db = "Transitive depset info about compilation flags for the target",
    ),
)

_c_extensions = [
    "c",
]

_cpp_extensions = [
    "cc",
    "cpp",
    "cxx",
    "hh",
    "hpp",
    "hxx",
]

_objc_extensions = [
    "m",
]

_objcpp_extensions = [
    "mm",
]

_cc_rules = [
    "cc_library",
    "cc_binary",
    "cc_test",
    "cc_inc_library",
    "cc_proto_library",
]

_objc_rules = [
    "objc_library",
    "objc_binary",
]

_all_rules = _cc_rules + _objc_rules

def _compilation_db_json(compilation_db):
    # Return a JSON string for the compilation db entries.
    entries = [entry.to_json() for entry in compilation_db]
    return ",\n ".join(entries)

def _sources(target, ctx):
    srcs = []
    if "srcs" in dir(ctx.rule.attr):
        srcs += [f for src in ctx.rule.attr.srcs for f in src.files.to_list()]
    if "hdrs" in dir(ctx.rule.attr):
        srcs += [f for src in ctx.rule.attr.hdrs for f in src.files.to_list()]

    if ctx.rule.kind == "cc_proto_library":
        srcs += [f for f in target.files.to_list() if f.extension in ["h", "cc"]]

    return srcs

def _get_tools_info(ctx, feature_configuration, action_name):
    return cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = action_name,
    )

def _add_if_needed(arr, add_arr):
    filtered = []
    for to_add in add_arr:
        found = False
        for existing in arr:
            if existing == to_add:
                found = True
        if not found:
            filtered.append(to_add)
    return arr + filtered

def _get_flags_info(ctx, source_path, destination_path, compilation_context, feature_configuration, cc_toolchain, action_name):
    if action_name == C_COMPILE_ACTION_NAME:
        opts = (ctx.fragments.cpp.copts + ctx.fragments.cpp.conlyopts) or []
    elif action_name == CPP_COMPILE_ACTION_NAME:
        opts = (ctx.fragments.cpp.copts + ctx.fragments.cpp.cxxopts) or []
    elif action_name == OBJC_COMPILE_ACTION_NAME:
        opts = ctx.fragments.objc.copts or []
    elif action_name == OBJCPP_COMPILE_ACTION_NAME:
        opts = ctx.fragments.objc.cxxopts or []
    else:
        opts = []

    execution_root_maker = "@EXECUTION_ROOT@/"

    v = cc_common.create_compile_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        source_file = source_path,
        output_file = destination_path,
        preprocessor_defines =
            depset(direct = compilation_context.local_defines.to_list(), transitive = [compilation_context.defines]),
        framework_include_directories = depset([execution_root_maker + x for x in compilation_context.framework_includes.to_list()]),
        include_directories = depset([execution_root_maker + x for x in compilation_context.includes.to_list()]),
        quote_include_directories = depset([execution_root_maker + x for x in compilation_context.quote_includes.to_list()]),
        system_include_directories = depset([execution_root_maker + x for x in compilation_context.system_includes.to_list()]),
    )

    flags = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = action_name,
        variables = cc_common.create_compile_variables(
            feature_configuration = feature_configuration,
            cc_toolchain = cc_toolchain,
            source_file = source_path,
            output_file = destination_path,
            preprocessor_defines =
                depset(direct = compilation_context.local_defines.to_list(), transitive = [compilation_context.defines]),
            framework_include_directories = depset([execution_root_maker + x for x in compilation_context.framework_includes.to_list()]),
            include_directories = depset([execution_root_maker + x for x in compilation_context.includes.to_list()]),
            quote_include_directories = depset([execution_root_maker + x for x in compilation_context.quote_includes.to_list()]),
            system_include_directories = depset([execution_root_maker + x for x in compilation_context.system_includes.to_list()]),
        ),
    )
    return _add_if_needed(flags, opts)

def _compilation_database_aspect_impl(target, ctx):
    # Write the compile commands for this target to a file, and return
    # the commands for the transitive closure.

    # We support only these rule kinds.
    if ctx.rule.kind not in _all_rules:
        return []

    compilation_db = []

    cc_toolchain = find_cc_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )

    compilation_context = target[CcInfo].compilation_context

    srcs = _sources(target, ctx)
    if not srcs:
        return []

    action_name = None
    for source in srcs:
        if source.extension in _c_extensions:
            action_name = C_COMPILE_ACTION_NAME
        elif source.extension in _cpp_extensions:
            action_name = CPP_COMPILE_ACTION_NAME
        elif source.extension in _objc_extensions:
            action_name = OBJC_COMPILE_ACTION_NAME
        elif source.extension in _objcpp_extensions:
            action_name = OBJCPP_COMPILE_ACTION_NAME
        else:
            continue

        source_path = source.path
        destination_path = source_path + ".o"

        compiler = _get_tools_info(ctx, feature_configuration, action_name)
        compile_flags = _get_flags_info(ctx, source_path, destination_path, compilation_context, feature_configuration, cc_toolchain, action_name)

        compile_arguments = [compiler] + compile_flags

        workspace_root_marker = "@WORKSPACE_ROOT@"
        compilation_db.append(
            struct(arguments = compile_arguments, directory = workspace_root_marker, file = source.path),
        )

    # Write the commands for this target.
    compdb_file = ctx.actions.declare_file(ctx.label.name + ".compile_commands.json")
    ctx.actions.write(
        content = _compilation_db_json(compilation_db),
        output = compdb_file,
    )

    # Collect all transitive dependencies.
    transitive_compilation_db = []
    all_compdb_files = []
    for dep in ctx.rule.attr.deps:
        if CompileInfo not in dep:
            continue
        transitive_compilation_db.extend(dep[CompileInfo].compilation_db)
        all_compdb_files.append(dep[OutputGroupInfo].compdb_files)

    compilation_db.extend(transitive_compilation_db)
    all_compdb_files = depset([compdb_file], transitive = all_compdb_files)

    return [
        CompileInfo(compilation_db = compilation_db),
        OutputGroupInfo(compdb_files = all_compdb_files),
    ]

compilation_database_aspect = aspect(
    attr_aspects = ["deps"],
    attrs = {
        "_cc_toolchain": attr.label(
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain"),
        ),
        "_xcode_config": attr.label(default = Label("@bazel_tools//tools/osx:current_xcode_config")),
    },
    fragments = ["cpp", "objc", "apple"],
    required_aspect_providers = [CompileInfo],
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
    implementation = _compilation_database_aspect_impl,
)

def _compilation_database_impl(ctx):
    # Generates a single compile_commands.json file with the
    # transitive depset of specified targets.

    if ctx.attr.disable:
        ctx.actions.write(output = ctx.outputs.filename, content = "[]\n")
        return

    compilation_db = []
    for target in ctx.attr.targets:
        compilation_db.extend(target[CompileInfo].compilation_db)

    content = "[\n " + _compilation_db_json(compilation_db) + "\n]\n"

    temporaryfile = ctx.actions.declare_file("compile_commands.in.json")
    ctx.actions.write(output = temporaryfile, content = content)
    tools = ctx.resolve_tools(tools = [ctx.attr._fix_compilation_db])
    ctx.actions.run(
        outputs = [ctx.outputs.filename],
        inputs = [temporaryfile, ctx.attr.locations.files.to_list()[0]],
        tools = ctx.attr._fix_compilation_db.files,
        executable = ctx.executable._fix_compilation_db,
        arguments = ["-b", str(ctx.attr.locations.files.to_list()[0].path), str(ctx.outputs.filename.path), str(temporaryfile.path)],
        progress_message = "Fixing compile_commands.json for current execution root",
        mnemonic = "CompileCommands",
    )

export_compile_commands = rule(
    attrs = {
        "targets": attr.label_list(
            aspects = [compilation_database_aspect],
            doc = "List of all cc targets which should be included.",
            providers = [CompileInfo],
        ),
        "disable": attr.bool(
            default = False,
            doc = ("Makes this operation a no-op; useful in combination with a 'select' " +
                   "for platforms where the internals of this rule are not properly " +
                   "supported. For known unsupported platforms (e.g. Windows), the " +
                   "rule is always a no-op."),
        ),
        "_fix_compilation_db": attr.label(
            default = ":fix_compilation_db",
            executable = True,
            cfg = "host",
        ),
        "locations": attr.label(
            allow_single_file = True,
        ),
    },
    outputs = {
        "filename": "compile_commands.json",
    },
    implementation = _compilation_database_impl,
)
