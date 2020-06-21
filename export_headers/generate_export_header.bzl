load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cc_toolchain")

def _make_identifier(s):
    result = ""
    for i in range(len(s)):
        result += s[i] if s[i].isalnum() else "_"

    return result

# Defines the implementation actions to generate_export_header.
def _generate_export_header_impl(ctx):
    cc_toolchain = find_cc_toolchain(ctx)

    define_export = ctx.attr._define_export
    if not define_export:
        if cc_toolchain.compiler == "msvc-cl":
            define_export = "__declspec(dllexport)"
        else:
            define_export = "__attribute__((visibility(\"default\")))"

    define_import = ctx.attr._define_import
    if not define_import:
        if cc_toolchain.compiler == "msvc-cl":
            define_import = "__declspec(dllimport)"
        else:
            define_import = "__attribute__((visibility(\"hidden\")))"

    define_no_export = ctx.attr._define_no_export
    if not define_no_export:
        if cc_toolchain.compiler == "msvc-cl":
            define_no_export = ""
        else:
            define_no_export = "__attribute__((visibility(\"hidden\")))"

    ctx.actions.expand_template(
        template = ctx.attr._templatefile.files.to_list()[0],
        output = ctx.outputs.out,
        substitutions = {
            "@STATIC_DEFINE@": ctx.attr.static_define,
            "@EXPORT_MACRO_NAME@": ctx.attr.export_macro_name,
            "@DEFINE_IMPORT@": define_import,
            "@DEFINE_EXPORT@": define_export,
            "@NO_EXPORT_MACRO_NAME@": ctx.attr.no_export_macro_name,
            "@DEFINE_NO_EXPORT@": define_no_export,
            "@DEPRECATED_MACRO_NAME@": ctx.attr.deprecated_macro_name,
            "@EXPORT_IMPORT_CONDITION@": ctx.attr.export_import_condition,
        },
    )

# Defines the rule to generate_export_header.
_generate_export_header_gen = rule(
    attrs = {
        "_templatefile": attr.label(default = "exportheader.h.in", allow_single_file = True),
        "out": attr.output(mandatory = True),
        "export_macro_name": attr.string(),
        "deprecated_macro_name": attr.string(),
        "export_deprecated_macro_name": attr.string(),
        "no_export_macro_name": attr.string(),
        "no_export_deprecated_macro_name": attr.string(),
        "static_define": attr.string(),
        "export_import_condition": attr.string(),
        "_define_export": attr.string(),
        "_define_import": attr.string(),
        "_define_no_export": attr.string(),
        "_cc_toolchain": attr.label(default = "@bazel_tools//tools/cpp:current_cc_toolchain"),
    },
    output_to_genfiles = True,
    implementation = _generate_export_header_impl,
    toolchains = [
        "@rules_cc//cc:toolchain_type",
    ],
)

def generate_export_header(
        lib = None,
        name = None,
        out = None,
        export_macro_name = None,
        deprecated_macro_name = None,
        export_deprecated_macro_name = None,
        no_export_macro_name = None,
        no_export_deprecated_macro_name = None,
        static_define = None,
        export_import_condition = None,
        **kwargs):
    """Creates a rule to generate an export header for a named library.  This
    is an incomplete implementation of CMake's generate_export_header. (In
    particular, it assumes a platform that uses
    __attribute__((visibility("default"))) to decorate exports.)

    By default, the rule will have a mangled name related to the library name,
    and will produce "<lib>_export.h".

    The CMake documentation of the generate_export_header macro is:
    https://cmake.org/cmake/help/latest/module/GenerateExportHeader.html

    """

    idlib = _make_identifier(lib)

    if name == None:
        name = "__%s_export_h" % idlib
    if out == None:
        out = "%s_export.h" % idlib
    if export_macro_name == None:
        export_macro_name = "%s_EXPORT" % idlib.upper()
    if deprecated_macro_name == None:
        deprecated_macro_name = "%s_DEPRECATED" % idlib.upper()
    if export_deprecated_macro_name == None:
        export_deprecated_macro_name = "%s_DEPRECATED_EXPORT" % idlib.upper()
    if no_export_macro_name == None:
        no_export_macro_name = "%s_NO_EXPORT" % idlib.upper()
    if no_export_deprecated_macro_name == None:
        no_export_deprecated_macro_name = "%s_DEPRECATED_NO_EXPORT" % idlib.upper()
    if static_define == None:
        static_define = "%s_STATIC_DEFINE" % idlib.upper()
    if export_import_condition == None:
        export_import_condition = "%s_EXPORTS" % idlib

    _generate_export_header_gen(
        name = name,
        out = out,
        export_macro_name = export_macro_name,
        deprecated_macro_name = deprecated_macro_name,
        export_deprecated_macro_name = export_deprecated_macro_name,
        no_export_macro_name = no_export_macro_name,
        no_export_deprecated_macro_name = no_export_deprecated_macro_name,
        static_define = static_define,
        export_import_condition = export_import_condition,
        **kwargs
    )
