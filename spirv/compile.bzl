def _glsl_compile_impl(ctx):
    output = ctx.expand_location("$(location {})".format(ctx.attr.output))
    input = ctx.expand_location("$(location {})".format(ctx.attr.input.label), [ctx.attr.input])
    include = [
        ctx.expand_location("$(location {})".format(include.label), [include]) for include in ctx.attr.include
    ]

    args = ctx.actions.args()
    args.add_all(["--client", ctx.attr.client_version])
    args.add_all(ctx.attr.target_version, before_each = "--target-env", uniquify = True)
    args.add_all(include, before_each = "-I", uniquify = True);
    args.add_all(["-o", output, input])

    ctx.actions.run(
        outputs = [ctx.outputs.output],
        inputs = ctx.files.input + ctx.files.data,
        executable = ctx.files.glslangValidator[0],
        arguments = [args],
    )

    return [DefaultInfo(runfiles = ctx.runfiles(files = [ctx.outputs.output]))]

glsl_compile = rule(
    implementation = _glsl_compile_impl,
    attrs = {
        "output": attr.output(mandatory = True),
        "input": attr.label(allow_single_file = True, mandatory = True),
        "include": attr.label_list(allow_files = False),
        "data": attr.label_list(allow_files = True),
        "target_version": attr.string_list(
            default = ["vulkan1.2", "spirv1.4"],
        ),
        "client_version": attr.string(
            default = "vulkan100",
        ),
        "glslangValidator": attr.label(
            allow_single_file = True,
            default = "@glslang//:glslangValidator",
        ),
    },
)
