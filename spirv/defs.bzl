load("@bazel_skylib//lib:paths.bzl", "paths")

GlslLibraryInfo = provider("Set of GLSL header files", fields = ["hdrs", "includes"])
SpirvLibraryInfo = provider("Set of Spirv files", fields = ["spvs", "includes"])

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

    args = []
    args.append("-MD")
    args.append("--target-env={}".format(ctx.attr.target_env))
    args.append("--target-spv={}".format(ctx.attr.target_spv))
    args.append("-std={}{}".format(ctx.attr.std_version, ctx.attr.std_profile))
    args.extend(["-I{}".format(include) for include in includes])
    args.extend(["-D{}".format(define) for define in ctx.attr.defines])

    if ctx.attr.debug:
        args.append("-g")
    if ctx.attr.optimize:
        args.append("-O")

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

        output_spv = ctx.actions.declare_file(output_path + ".spv")
        output_spv_d = output_path + ".d"
        output_dep_in = ctx.actions.declare_file(paths.join(output_spv_d, "deps.txt.in"))
        output_build_in = ctx.actions.declare_file("build.txt.in", sibling = output_dep_in)

        output_dep = ctx.actions.declare_file("deps.txt", sibling=output_dep_in)
        output_build = ctx.actions.declare_file("build.txt", sibling=output_build_in)

        outputs.extend([output_spv, output_dep, output_build])

        argsio = ["-MF", output_dep_in.path, "-o", output_spv.path, src.path]

        ctx.actions.run(
            outputs = [output_spv, output_dep_in],
            inputs = ctx.files.srcs + ctx.files.hdrs + dephdrs,
            executable = ctx.files.glslc[0],
            arguments = args + argsio,
        )

        ctx.actions.write(
            content = " ".join([ctx.files.glslc[0].path] + args + argsio) + "\n" +
                      " ".join([ctx.files.fix_compilation_commands[0].path, ctx.files.locations[0].path, output_build.path, output_build_in.path, output_dep.path, output_dep_in.path]),
            output = output_build_in,
        )

        ctx.actions.run(
            outputs = [output_build, output_dep],
            inputs = [ctx.files.locations[0], output_build_in, output_dep_in],
            executable = ctx.files.fix_compilation_commands[0],
            arguments = [ctx.files.locations[0].path, output_build.path, output_build_in.path, output_dep.path, output_dep_in.path],
        )

    return outputs

def _glsl_library_impl(ctx):
    # compile the files
    this_build_file_dir = paths.dirname(ctx.build_file_path)
    this_package_dir = paths.join(this_build_file_dir, ctx.attr.name)
    spirvs = _compile_files(ctx, [this_package_dir])

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

    providers = [
        DefaultInfo(
            files = depset(hdrs + spirvs),
            runfiles = ctx.runfiles(
                files = spirvs,
            ),
        ),
        GlslLibraryInfo(
            hdrs = hdrs,
            includes = includes,
        ),
        CcInfo(),  # So it can be used as a dep for cc_library/binary and have spirvs embedded as runfiles
    ]

    if spirvs:
        # Compute output location for spv files
        # This will be used to populate the includes variable of the SpirvLibraryInfo provider
        # Check if this could made more resilient
        spirvs_root = paths.join(ctx.bin_dir.path, spirvs[0].owner.workspace_root)
        providers.append(SpirvLibraryInfo(
            spvs = spirvs,
            includes = [spirvs_root],
        ))

    return providers

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
            # mesh shaders
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
            default = "spv1.3",
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
        "fix_compilation_commands": attr.label(
            allow_single_file = True,
            default = "@tools//spirv:fix_compilation_commands",
        ),
        "locations": attr.label(
            allow_single_file = True,
            default = "@workspace_status//:locations.json",
        )
    },
)
