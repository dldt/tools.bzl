def _glsl_compile_impl(ctx):
    output = ctx.expand_location("$(location {})".format(ctx.attr.output))
    input = ctx.expand_location("$(location {})".format(ctx.attr.input.label), [ctx.attr.input])
    include = [
        ctx.expand_location("$(location {})".format(include.label), [include])
        for include in ctx.attr.include
    ]

    args = ctx.actions.args()
    args.add("--target-env={}".format(ctx.attr.target_env))
    args.add("--target-spv={}".format(ctx.attr.target_spv))
    args.add("-std={}{}".format(ctx.attr.std_version, ctx.attr.std_profile))
    args.add_all(include, format_each = "-I%s", uniquify = True)
    args.add_all(ctx.attr.define, format_each = "-D%s", uniquify = True)
    args.add_all(["-o", output, input])
    if ctx.attr.debug:
        args.add("-g")
    if ctx.attr.optimize:
        args.add("-O")

    ctx.actions.run(
        outputs = [ctx.outputs.output],
        inputs = ctx.files.input + ctx.files.data + ctx.files.include,
        executable = ctx.files.glslc[0],
        arguments = [args],
    )

    return [DefaultInfo(runfiles = ctx.runfiles(files = [ctx.outputs.output]))]

glsl_compile = rule(
    implementation = _glsl_compile_impl,
    attrs = {
        "output": attr.output(mandatory = True),
        "input": attr.label(allow_single_file = True, mandatory = True),
        "include": attr.label_list(allow_files = True),
        "data": attr.label_list(allow_files = True),
        "std_version": attr.string(
            default = "460",
            values = ["410", "420", "430", "440", "450", "460"],
        ),
        "std_profile": attr.string(
            default = "core",
            values = ["core", "compatibility"],
        ),
        "target_spv": attr.string(
            default = "spv1.5",
            values = ["spv1.0", "spv1.1", "spv1.2", "spv1.3", "spv1.4", "spv1.5"],
        ),
        "target_env": attr.string(
            default = "vulkan1.2",
            values = [
                "vulkan1.0",
                "vulkan1.1",
                "vulkan1.2",
                "vulkan",  # Same as vulkan1.0
                "opengl4.5",
                "opengl",  # Same as opengl4.5
            ],
        ),
        "define": attr.string_list(),
        "debug": attr.bool(default = True),
        "optimize": attr.bool(default = True),
        "glslc": attr.label(
            allow_single_file = True,
            default = "@shaderc//:glslc",
        ),
    },
)
