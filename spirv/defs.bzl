load("@bazel_skylib//lib:paths.bzl", "paths")

GlslLibraryInfo = provider("Set of GLSL header files", fields = ["hdrs", "includes"])

def _export_headers(ctx, virtual_header_prefix):
    strip_include_prefix = ctx.attr.strip_include_prefix
    include_prefix = ctx.attr.include_prefix
    outs = []
    for hdr in ctx.files.hdrs:
        path = hdr.owner.name
        if strip_include_prefix:
            if path.startswith(strip_include_prefix):
                out = path.lstrip(strip_include_prefix)
                out = out.lstrip("/")
            else:
                fail("{} is not a prefix of {}".format(strip_include_prefix, path))
        else:
            out = path
        if include_prefix:
            out = paths.join(include_prefix, out)

        name = out.replace("/", "_") + "_export"
        out = paths.join(
            virtual_header_prefix,
            out,
        )

        symlink = ctx.actions.declare_file(out)
        ctx.actions.symlink(
            output = symlink,
            target_file = hdr,
        )
        outs.append(symlink)

    return outs

def _compile_files(ctx, includes):
    dephdrs = []
    for dep in ctx.attr.deps:
        glsllibraryinfo = dep[GlslLibraryInfo]
        includes.extend(glsllibraryinfo.includes)
        dephdrs.extend(
            glsllibraryinfo.hdrs,
        )

    args = ctx.actions.args()
    args.add("--target-env={}".format(ctx.attr.target_env))
    args.add("--target-spv={}".format(ctx.attr.target_spv))
    args.add("-std={}{}".format(ctx.attr.std_version, ctx.attr.std_profile))
    args.add_all(includes, format_each = "-I%s", uniquify = True)
    args.add_all(ctx.attr.defines, format_each = "-D%s", uniquify = True)

    if ctx.attr.debug:
        args.add("-g")
    if ctx.attr.optimize:
        args.add("-O")

    strip_output_prefix = ctx.attr.strip_output_prefix
    output_prefix = ctx.attr.output_prefix
    outputs = []
    for src in ctx.files.srcs:
        path = src.owner.name
        if strip_output_prefix:
            if path.startswith(strip_output_prefix):
                output_path = path.lstrip(strip_output_prefix)
                output_path = output_path.lstrip("/")
            else:
                fail("{} is not a prefix of {}".format(strip_output_prefix, path))
        else:
            output_path = path
        if output_prefix:
            output_path = paths.join(output_prefix, output_path)

        output_path = output_path + ".spv"

        output_file = ctx.actions.declare_file(output_path)
        outputs.append((output_path, output_file))
        argsio = ctx.actions.args()
        argsio.add_all(["-o", output_file.path, src])
        ctx.actions.run(
            outputs = [output_file],
            inputs = ctx.files.srcs + ctx.files.hdrs + dephdrs,
            executable = ctx.files.glslc[0],
            arguments = [args, argsio],
        )

    return outputs

def _glsl_library_impl(ctx):
    # compile the files
    this_build_file_dir = paths.dirname(ctx.build_file_path)
    this_package_dir = paths.join(this_build_file_dir, ctx.attr.name)
    spirvs = {spv[0]: spv[1] for spv in _compile_files(ctx, [this_package_dir])}

    # Make sure they are correctly exposed to other packages
    virtual_header_prefix = "_virtual_includes/{}".format(ctx.attr.name)
    hdrs = _export_headers(ctx, virtual_header_prefix)

    includes = [paths.dirname(ctx.build_file_path)]
    for include in ctx.attr.includes:
        path = paths.normalize(paths.join(
            this_build_file_dir,
            virtual_header_prefix,
            include,
        ))
        includes.append(path)
        includes.append(paths.join(ctx.bin_dir.path, path))

    return [
        DefaultInfo(
            files = depset(hdrs),
            runfiles = ctx.runfiles(
                files = spirvs.values(),
            ),
        ),
        GlslLibraryInfo(
            hdrs = hdrs,
            includes = includes,
        ),
        CcInfo(),
    ]

glsl_library = rule(
    implementation = _glsl_library_impl,
    attrs = {
        "include_prefix": attr.string(),
        "strip_include_prefix": attr.string(),
        "output_prefix": attr.string(),
        "strip_output_prefix": attr.string(),
        "srcs": attr.label_list(allow_files = [
            "vert",
            "tesc",
            "tese",
            "geom",
            "frag",
            # compute
            "comp",
            # Mesh shaders
            "mesh",
            "task",
            # ray tracing
            "rgen",
            "rint",
            "rahit",
            "rchit",
            "rmiss",
            "rcall",
            # generic, for inclusion
            "glsl",
        ]),
        "hdrs": attr.label_list(allow_files = ["glsl"]),
        "includes": attr.string_list(default = ["./"]),
        "deps": attr.label_list(
            providers = [GlslLibraryInfo],
        ),
        "std_version": attr.string(
            default = "460",
            values = ["410", "420", "430", "440", "450", "460"],
        ),
        "std_profile": attr.string(
            default = "core",
            values = ["core", "compatibility", "es"],
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
        "defines": attr.string_list(),
        "debug": attr.bool(default = True),
        "optimize": attr.bool(default = True),
        "glslc": attr.label(
            allow_single_file = True,
            default = "@shaderc//:glslc",
        ),
    },
)
