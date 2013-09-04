Luvent: A Simple Event Library for Lua
======================================

**Luvent is in early development and not recommended for any
  production software.  The API is subject to change and break
  compatibility without warning.**

Luvent is a library for [Lua][], written entirely in Lua, which helps
support [event-driven programming][EDP].  Luvent lets you create
events, which are objects with any number of associated functions.
Whenever you trigger an event the library will execute all functions
attached to that event.  You may trigger an event multiple times and
can provide different arguments to that event’s functions each time.


Requirements
------------

Luvent requires one of the following Lua implementations:

* Lua 5.1 or 5.2
* [LuaJIT][] 2.0

These are the versions we use to test Luvent.  It should work with
later versions of each, and possibly older versions as well.

### Optional ###

The following programs are not necessary in order to use Luvent but
you will need them to run the unit tests, generate API documentation,
and so on.

* [LDoc][]
* [Busted][]


Installation
------------

All you need to do is place `src/Luvent.lua` in a directory that is part of
`package.path` so that Lua can find and load it.  If you have Busted
then you should run `make tests` first to ensure that Luvent behaves
as intended.


Documentation
-------------

Running the command `make docs` will populate the `docs/` directory
with HTML documents that describe Luvent’s API.  The public API
consists of the following functions and methods:

* `Luvent.newEvent()`
* `Luvent:addAction(action)`
* `Luvent:setActionInterval(action_or_id, interval)`
* `Luvent:removeAction(action_or_id)`
* `Luvent:getActionCount()`
* `Luvent:hasAction(action_or_id)`
* `Luvent:disableAction(action_or_id)`
* `Luvent:enableAction(action_or_id)`
* `Luvent:trigger(...)`

**Note:** Developers must never rely on the properties of the return
  values of `Luvent:newEvent()`.  Its non-method properties are not
  part of the public API.

The parameter `action` must be a function, coroutine, or table that
implements the `__call()` metamethod.  The `addAction()` method
returns an ID for the new action which you can save and later pass on
to any method that accepts `action_or_id`.  This is useful for keeping
track of actions when you have no access to the original action
itself, e.g. adding an anonymous function as an action.  The Luvent
API only guarantees the following attributes regarding action IDs:

1. An action ID is true in a boolean context.

2. If two action IDs are equal then they represent the same action.

Code that relies on anything else about action IDs, e.g. their type or
their specific values, may break in the future without warning.

Below is a lengthy example that demonstrates the basics of creating
and triggering events, and adding and removing actions.

```lua
-- In this example we will pretend we are implementing a module in a
-- game that creates and manages enemies.  To simplfy the example we
-- use Enrique García Cota's terrific MiddleClass library in order
-- to make the class and objects for enemies.
--
--     https://github.com/kikito/middleclass
--
require "middleclass"

local Luvent = require "Luvent"
local Enemy = class("Enemy")

-- This hash contains a reference to all living enemies.
Enemy.static.LIVING = {}

function Enemy:initialize(family, maxHP)
    self.family = family
    self.maxHP = maxHP
    self.HP = maxHP
    table.insert(Enemy.LIVING, self)
end

-- This is the event we trigger any time an enemy dies.
Enemy.static.onDie = Luvent.newEvent()

-- This method applies damage to an enemy and will trigger its 'onDie'
-- event if the enemy's hit points reach zero or less.
function Enemy:damage(damage)
    self.HP = self.HP - damage
    if self.HP <= 0 then
        Enemy.onDie:trigger(self)
    end
end

-- Now we can start associating actions with the 'onDie' event.  First
-- we start by removing the enemy from the table of living enemies.
Enemy.onDie:addAction(
    function (enemy)
        for index,living_enemy in ipairs(Enemy.LIVING) do
            if enemy == living_enemy then
                table.remove(Enemy.LIVING, index)
                return
            end
        end
    end)

-- For debugging we want to see on the console when an enemy dies, so
-- we add that as a separate action.  This time we save the return
-- value of addAction() so that later we can use that to remove the
-- action when we want to stop printing debugging output.
local debugAction = Enemy.onDie:addAction(
    function (enemy)
        print(string.format("Enemy %s died", enemy.family))
    end)

-- Now we make some enemies and kill them to demonstrate how the
-- trigger() method used in Enemy:damage() invokes the actions.

local bee = Enemy:new("Bee", 10)
local ladybug = Enemy:new("Ladybug", 1)

-- This will print "2"
print(#Enemy.LIVING)

-- This kills the enemy so the program invokes the two actions above,
-- meaning it will print "Enemy Ladbug died" to the console and will
-- remove it from Enemy.LIVING.
ladybug:damage(100)
print(#Enemy.LIVING)    -- Prints "1"

-- Now we turn off the debugging output by removing that action.  As a
-- result we will see no output after killing the bee.
Enemy.onDie:removeAction(debugAction)
bee:damage(50)
print(#Enemy.LIVING)    -- Prints "0"
```

You can also use [coroutines][] as actions.  This allows you to do
things that you could not with regular functions, such as make sure
that an event will invoke an action a fixed number of times, e.g.:

```lua
-- In this example we are writing code that affects a player in a
-- hypothetical game.  Every time the player dies and uses a continue
-- we want to reset the player's properties.  However, the first time
-- the player uses a continue we want to save the current score, and
-- then we do not execute that action again because our game only
-- records scores the player achieves with the first continue.

require "middleclass"

local Luvent = require "Luvent"
local Player = class("Player")

Player.static.MAX_POWER_LEVEL = 10

function Player:initialize()
    self.HP = 100
    self.powerLevel = Player.MAX_POWER_LEVEL
    self.score = 0
end

function Player:continue()
    Player.onContinue:trigger(self)
end

Player.static.onContinue = Luvent.newEvent()

-- If we use a coroutine for an action then Luvent will automatically
-- remove the action when the coroutine is dead.  That means the
-- action below will only run once because the status of the coroutine
-- becomes dead after its first invocation.
Player.onContinue:addAction(
    coroutine.create(
        function (player)
            -- This is where we would write 'player.score' to a file.
        end))

-- This is the stuff we want to do every time the player continues.
Player.onContinue:addAction(
    function (player)
        player.HP = 100
        player.powerlevel = 1
        player.score = 0
    end)

local P1 = Player:new()

-- The first time we trigger this event it will execute both of the
-- actions above.
P1:continue()

-- But now any other time we trigger the event it will not run the
-- action that saves the score.
P1:continue()
```

Luvent discards all return values from action functions or anything
that coroutines yield.


Acknowledgments and Alternatives
--------------------------------

[EventLib][] by Elijah Frederickson is the major inspiration for the
design and implementation of Luvent.  The Luvent API also owes a debt
of ideas and names to [Node.js][] by Ryan Dahl et al.  The following
is a list of alternatives to Luvent for the sake of comparison, as
some may be better suited for some developers or projects:

* [Custom Event Support](https://github.com/benbeltran/custom_event_support.lua) by Ben Beltran
* [Emitter](https://github.com/friesencr/lua_emitter) by Chris Friesen
* [Lua-Event](https://github.com/slime73/Lua-Event) by Alex Szpakowski
* [Lua-Events](https://github.com/syntruth/Lua-Events) by syntruth
* [Lua-Events](https://github.com/wscherphof/lua-events) by Wouter Scherphof
* [events.lua](https://github.com/mvader/events.lua) by José Miguel Molina


License
-------

[The MIT License](http://opensource.org/licenses/MIT)

Copyright 2013 Eric James Michael Ritz



[Lua]: http://lua.org/
[EDP]: http://en.wikipedia.org/wiki/Event-driven_programming
[EventLib]: https://github.com/mlnlover11/EventLib
[Node.js]: http://nodejs.org/
[LuaJIT]: http://luajit.org/
[LDoc]: http://stevedonovan.github.io/ldoc/
[Busted]: http://olivinelabs.com/busted/
[coroutines]: http://www.lua.org/manual/5.2/manual.html#2.6
