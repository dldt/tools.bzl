def glsl_compile(name, input, output, target_version = "vulkan1.2", spirv_version = "V100"):
    native.genrule(
        name = name,
        srcs = [
            input,
        ],
        outs = [
            output,
        ],
        cmd = "$(location @glslang//:glslangValidator) --client vulkan100 --target-env spirv1.4 --target-env vulkan1.2 $(SRCS) -o $@",
        tools = [
            "@glslang//:glslangValidator",
        ],
    )
