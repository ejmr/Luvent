local sources = {"src/Luvent.lua"}
local tests   = {"tests/Luvent.spec.lua"}

tup.rule(sources, "^ Running Luacheck^ luacheck %f")

tup.rule(sources,
         "^ Creating TAGS for Emacs^ ctags-exuberant --languages=lua -e %f",
         {"TAGS"})

tup.rule(tests, [[^ Running Unit Tests^ busted --pattern=".spec.lua" %f]])

tup.rule(sources,
         [[^ Generating Documentation^ ldoc --dir="docs/" %f]],
         {"docs/index.html", "docs/ldoc.css"})
