package = "Luvent"
version = "1.0.0-1"
source = {
    url = "https://github.com/ejmr/Luvent/archive/v1.0.0.zip",
}
description = {
    summary = "A simple library for event-driven programming.",
    detailed = [[
        Luvent is a library for event-driven programming in Lua.  It
        allows you to create an arbitrary number of 'events' and then
        associate 'actions' with those events, which are chunks of
        code that Luvent will execute whenever you 'trigger' an event.
        ]],
    homepage = "https://github.com/ejmr/Luvent",
    license = "MIT",
}
dependencies = {
    "lua >= 5.1",
}
build = {
    type = "builtin",
    modules = {
        Luvent = "src/Luvent.lua",
    },
}
