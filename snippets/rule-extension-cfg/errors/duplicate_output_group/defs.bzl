"""Extends the drop-in extension, which already returns OutputGroupInfo, and appends another one."""

load("//rules:company.bzl", "mode_report")

def _impl(ctx):
    providers = ctx.super()
    return providers + [OutputGroupInfo(extra = depset())]

double_group_report = rule(
    implementation = _impl,
    parent = mode_report,
)
