def _policy_repo_impl(repository_ctx):
    repository_ctx.file("BUILD.bazel", "exports_files([\"policy.txt\"])\n")
    repository_ctx.file(
        "policy.txt",
        "release_channel={}\nowner=platform-team\n".format(repository_ctx.attr.channel),
    )


_policy_repo = repository_rule(
    implementation = _policy_repo_impl,
    attrs = {
        "channel": attr.string(default = "dev"),
    },
)


def _policy_extension_impl(module_ctx):
    channel = "dev"
    for module in module_ctx.modules:
        for release in module.tags.release:
            channel = release.channel

    _policy_repo(
        name = "release_policy",
        channel = channel,
    )


policy_extension = module_extension(
    implementation = _policy_extension_impl,
    tag_classes = {
        "release": tag_class(attrs = {
            "channel": attr.string(default = "dev"),
        }),
    },
)
