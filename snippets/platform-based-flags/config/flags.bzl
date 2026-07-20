def _device_mode_flag_impl(ctx):
    return []

device_mode_flag = rule(
    implementation = _device_mode_flag_impl,
    build_setting = config.bool(flag = True),
)
