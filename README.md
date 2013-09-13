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

There exists some great alternatives to Luvent, as you will see listed
below.  However, most of those libraries do not have an explicit
license.  I created Luvent to use in a commercial game, built on the
[LÖVE][] framework, and so I could not use any library that did not
explicitly grant legal permission to use the code in that situation.
Luvent may not be that different from existing libraries in terms of
its functionality; but it is and will always be free for developers to
use in any program whether it is commercial or not.


Requirements
------------

Luvent requires one of the following Lua implementations:

* Lua >= 5.1
* [LuaJIT][] >= 2.0
* LÖVE >= 0.8.0

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
with HTML documents that describe Luvent’s API.

### Terminology ###

* **Event:** An object which you can `trigger(...)` in order to invoke
  *all actions* associated with the event.

* **Action:** Any of the following qualify as actions that you can
  associate with events:

    1. A function.
    2. A [coroutine][].
    3. A table that supports the `__call()` [metamethod][].

* **Action ID:** An object that represents an action.  The method
  `addAction()` will return an action ID that you can save to later
  use with methods such as `disableAction()`.  Instead of the ID you
  can also use the action itself, e.g. if the action is a function
  then any method that asks for an ‘action or ID’ will accept that
  function itself or the ID that `addAction()` returned when given the
  function.  Action IDs are always true in a boolean context.  If two
  IDs are equal then they represent the same action.  Those are the
  only two properties that the API provides; if you rely on anything
  else about action IDs (e.g. their type) then your code may suddenly
  break in the future.

### Basic Example ###

You create new events with the `newEvent()` function. Note well that
must *never* rely on the properties of the event objects.  Anything
that is not a method is not part of the API and may change at any
time.

Once you have an event object you can begin to add ‘actions’ to it via
its `addAction()` method.  To invoke those actions you ‘trigger’ the
event by calling its `trigger()` method.  Every action associated with
the event will receive any parameters you give to `trigger()`.

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

**Note:** Luvent discards all return values from action functions or
anything that coroutines yield.

### Enabling and Disabling Actions ###

In the example above we removed an action.  Calling the
`getActionCount()` of an event will tell us how many actions it has.
However, this is not necessarily the number of actions it will invoke
if we trigger the event.

When we add an action Luvent enables it by default.  We can disable
actions though.  For example:

```lua
local debugAction = Enemy.onDie:addAction(
    function (enemy)
        print(string.format("Enemy %s died", enemy.family))
    end)

-- ...Later in the code...

Enemy.onDie:disableAction(debugAction)
```

The difference between this method and `removeAction()` is that this
method only turns-off the action temporarily.  Later we could call
`enableAction()` to turn the action back on.  When we use
`removeAction()`, however, it is like deleting the action from the
event.

You can also think of the methods in pairs.

1. `removeAction()` is the opposite of `addAction()`.

2. `disableAction()` is the opposite of `enableAction()`.

The first pair of methods affect the return value of
`getActionCount()` and `hasAction()`.  The second pair does not.

### Action Intervals ###

### Prioritizing Actions ###

### Action Limits ###

### Complete List of the Public API ###

You create events with the function `Luvent.newEvent()`.  The function
returns an object with the following methods:

* `trigger(...)`
* `addAction(action)`
* `removeAction(action_or_id)`
* `removeAllActions()`
* `getActionCount()`
* `hasAction(action_or_id)`
* `isActionEnabled(action_or_id)`
* `enableAction(action_or_id)`
* `disableAction(action_or_id)`
* `setActionPriority(action_or_id)`
* `removeActionPriority(action_or_id)`
* `setActionTriggerLimit(action_or_id)`
* `removeActionTriggerLimit(action_or_id)`
* `setActionInterval(action_or_id)`
* `removeActionInterval(action_or_id)`


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
[coroutine]: http://www.lua.org/manual/5.2/manual.html#2.6
[metamethod]: http://www.lua.org/manual/5.2/manual.html#2.4
[LÖVE]: http://love2d.org/
