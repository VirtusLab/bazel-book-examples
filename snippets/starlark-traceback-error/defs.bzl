def broken_macro(name):
    greeting = "hello"
    greeting.upperr()
    native.filegroup(
        name = name,
        srcs = [],
    )
