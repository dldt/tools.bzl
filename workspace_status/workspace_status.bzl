def _workspace_status_rule_impl(ctx):
    # Grab a reference to the root of the users project
    workspace_root = ctx.path(ctx.attr.workspace_root_file).dirname

    # Grab a reference to the execution root, escaping the external/<workspace> folder.
    execution_root = ctx.path(".").dirname.dirname
    content = struct(
        workspace_root = str(workspace_root),
        execution_root = str(execution_root) + "/execroot/" + ctx.attr.workspace_root_name,
    ).to_json()
    ctx.file("locations.json", content = content)

    ctx.file("WORKSPACE")
    ctx.file("BUILD", content = """
exports_files(["locations.json"])
""")

_workspace_status_rule = repository_rule(
    _workspace_status_rule_impl,
    attrs = {
        "workspace_root_file": attr.label(
            default = "@//:WORKSPACE",
        ),
        "workspace_root_name": attr.string(mandatory = True),
    },
)

def workspace_status(name, workspace_root_name):
    _workspace_status_rule(name = name, workspace_root_name = workspace_root_name)
