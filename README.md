Luvent: A Simple Event Library for Lua
======================================

Luvent is a library for [Lua][], written entirely in Lua, which helps
support [event-driven programming][EDP].  Luvent lets you create
events, which are objects with any number of associated functions.
Whenever you trigger an event the library will execute all functions
attached to that event.  You may trigger an event multiple times and
can provide different arguments to that event’s functions each time.

There are great alternatives to Luvent listed below.  However, most of
those libraries do not have an explicit license.  I created Luvent to
use in a commercial game, built on the [LÖVE][] framework, and so I
could not use any library that did not explicitly grant legal
permission to use the code in that situation.  Luvent may not be that
different from existing libraries in terms of its functionality; but
it is and will always be free for developers to use in any program
whether it is commercial or not.


Requirements
------------

Luvent requires one of the following Lua implementations:

* [Lua][] >= 5.1
* [LuaJIT][] >= 2.0
* [LÖVE][] >= 0.8.0

These are the versions we use to test Luvent.  It should work with
later versions of each, and possibly older versions as well.

### Optional ###

The following programs are not necessary in order to use Luvent but
you will need them to run the unit tests, generate API documentation,
and so on.

* [LDoc][] >= 1.4.0
* [Busted][] >= 1.10.0
* [GNU Make][] >= 3


Installation
------------

All you need to do is place `src/Luvent.lua` in a directory that is
part of `package.path` so that Lua can find and load it.  Since the
entire library is that one file you can also simply copy
`src/Luvent.lua` into the directory alongside the rest of your code
and `require()` it from there.  If you have Busted then you can run
`make tests` first to ensure that Luvent behaves as intended.


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
you must *never* rely on the properties of the event objects.
Anything that is not a method is not part of the API and may change at
any time.

Once you have an event object you can begin to add ‘actions’ to it via
its `addAction()` method.  To invoke those actions you ‘trigger’ the
event by calling its `trigger()` method.  Every action associated with
the event will receive any parameters you give to `trigger()`.

Below is a lengthy example that demonstrates the basics of creating
and triggering events, and adding and removing actions.

```lua
-- In this example you will pretend you are implementing a module in a
-- game that creates and manages enemies.  To simplfy the example you
-- use Enrique García Cota's terrific MiddleClass library in order
-- to make the class and objects for enemies.
--
--     https://github.com/kikito/middleclass
--
local class = require "middleclass"

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

-- This is the event you trigger any time an enemy dies.
Enemy.static.onDie = Luvent.newEvent()

-- This method applies damage to an enemy and will trigger its 'onDie'
-- event if the enemy's hit points reach zero or less.
function Enemy:damage(damage)
    self.HP = self.HP - damage
    if self.HP <= 0 then
        Enemy.onDie:trigger(self)
    end
end

-- Now you can start associating actions with the 'onDie' event.  First
-- you start by removing the enemy from the table of living enemies.
Enemy.onDie:addAction(
    function (enemy)
        for index,living_enemy in ipairs(Enemy.LIVING) do
            if enemy == living_enemy then
                table.remove(Enemy.LIVING, index)
                return
            end
        end
    end)

-- For debugging you want to see on the console when an enemy dies, so
-- you add that as a separate action.  This time you save the return
-- value of addAction() so that later you can use that to remove the
-- action when you want to stop printing debugging output.
local debugAction = Enemy.onDie:addAction(
    function (enemy)
        print(string.format("Enemy %s died", enemy.family))
    end)

-- Now you make some enemies and kill them to demonstrate how the
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

-- Now you turn off the debugging output by removing that action.  As a
-- result you will see no output after killing the bee.
Enemy.onDie:removeAction(debugAction)
bee:damage(50)
print(#Enemy.LIVING)    -- Prints "0"
```

**Note:** Luvent discards all return values from action functions or
anything that coroutines yield.

### Getting Information About Actions ###

Luvent provides two methods for gathering information about the
relationship between an event an actions.

1. The method `getActionCount()` tells you the number of actions
   associated with an event.  *This is not necessarily the number of
   actions that `trigger()` will invoke.* The method only tells you
   the number of unique actions associated with the event via its
   `addAction()` method.  Luvent allows you to temporarily disable
   actions and to delay their execution, which means `trigger()` will
   not call those actions even though they are still associated with
   the event.  That is why you cannot rely on `getActionCount()` to
   tell you the exact number of actions an event will run.

2. The method `hasAction(action_or_id)` accepts an action or an action
   ID (i.e. the return value of `addAction()`) and returns a boolean
   indicating whether or not the action is part of the event.
   However, if `hasAction()` returns true that is not a guarantee that
   the event will call that action, for the same reasons that affect
   `getActionCount()`.

### Enabling and Disabling Actions ###

In the example above you removed an action.  Calling the
`getActionCount()` of an event will tell us how many actions it has.
However, this is not necessarily the number of actions it will invoke
if you trigger the event.

When you add an action Luvent enables it by default.  You can disable
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
method only turns-off the action temporarily.  Later you could call
`enableAction()` to turn the action back on.  When you use
`removeAction()`, however, it is like deleting the action from the
event.

You can also think of the methods in pairs.

1. `removeAction()` is the opposite of `addAction()`.

2. `disableAction()` is the opposite of `enableAction()`.

The first pair of methods affect the return value of
`getActionCount()` and `hasAction()`.  The second pair does not.

### Action Intervals ###

Events may have actions with *intervals,* i.e. guaranteed delays in
the amount of time that must pass before the action will run again.
Luvent allows us to define intervals in terms of seconds.  For
example:

```lua
-- In this example you have a game where the AI has an 'onThink' event.
-- You want the AI to do many things on that event, but some of them
-- may be expensive in terms of performance.  So there may be actions
-- which you only want to run every so many seconds.

local function someSlowFunction(ai)
    -- You do something with the AI here that can take a while and so
    -- you do not want to always run this action.
end

AI.onThink:addAction(someSlowFunction)

-- Now you can tell the event to execute the action every ten seconds.
AI.onThink:setActionInterval(someSlowFunction, 10)

-- No matter how often you trigger the event, someSlowFunction() will
-- only run once per ten seconds.
while true do
    AI.onThink:trigger()
end
```

Actions have no interval by default.  You can use the method
`removeActionInterval()` to take away any interval from an action,
even if that action has no interval in the first place.

### Prioritizing Actions ###

By default Luvent makes no guarantees about the order in which an
event will execute actions.  But you can create such guarantees by
assigning numeric priorities to actions.  In that case Luvent will
invoke actions based on the order of the priority, from highest to
lowest, for example:

```lua
-- Let's say you are writing an AI for a board game.  You have an
-- 'onMove' event which triggers a variety of actions.  The functions
-- have stub implementations for the sake of brevity.

AI.onMove = Luvent.newEvent()

local function makeMove(player, board) end
local function analyzeCurrentPosition(player, board) end
local function searchPatternDatabase(player, board) end
local function estimateScore(player, board) end

AI.onMove:addAction(makeMove)
AI.onMove:addAction(analyzeCurrentPosition)
AI.onMove:addAction(searchPatternDatabase)
AI.onMove:addAction(estimateScore)

-- At this point you have given no action any explicit priority.  So if
-- you trigger the event now then there is no guarantee about the order
-- in which Luvent will call each action.  You cannot even rely on the
-- event to call the actions in the order you added them.

AI.onMove:setActionPriority(makeMove, 2)
AI.onMove:setActionPriority(analyzeCurrentPosition, 4)
AI.onMove:setActionPriority(searchPatternDatabase, 3)
AI.onMove:setActionPriority(estimateScore, 1)
```

After you set the priorities at the end then when you call
`AI.onMove:trigger()` it will invoke the actions in this order:

1. `analyzeCurrentPosition()`
2. `searchPatternDatabase()`
3. `makeMove()`
4. `estimateScore()`

You can use `removeActionPriority()` on any of these actions to place
them back at the bottom of the list, which is Luvent’s default
behavior.  Any action without an explicit priority will run last.  If
more than one action has the same priority then there is no guarantee
about the order in which Luvent will call those actions.

### Action Limits ###

There are situations where you may want to limit the amount of times
an event will invoke a specific action.  You can control this by
setting the ‘limit’ for the action.  For example:

```lua
-- In this example you are working with an 'onDeath' event for players
-- in a game.  The first time the player dies you want to save his or
-- her score.  But the player can continue after that and you do not
-- want to record scores after the first continue.  And so you want
-- the action for saving the score to run only once.

Game.onDeath = Luvent.newEvent()

local function saveScore(player) end
local function promptForContinue(player) end

Game.onDeath:addAction(saveScore)
Game.onDeath:addAction(promptForContinue)

-- This tells Luvent the limit for the action, i.e. the number of
-- times to invoke the action before automatically removing it.  This
-- specific example causes the event to call saveScore() only once and
-- then it will remove the action from 'onDeath'.
Game.onDeath:setActionLimit(saveScore, 1)

-- And for sanity this makes sure to save the score first by giving it
-- a higher priority than promptForContinue().  The number ten here is
-- an arbitrary choice; it just needs to be a number greater than zero
-- since there is no explicit priority for the other action.
Game.onDeath:setActionPriority(saveScore, 10)
```

The first call to `Game.onDeath:trigger()` will invoke `saveScore()`
and then `promptForContinue()`.  All future `trigger()` calls will
only invoke the second action.  Once an action reaches its limit then
Luvent effectively calls `removeAction()`, meaning you would have to
manually re-add the action before the event would use it again.

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

Copyright 2013–2014 Eric James Michael Ritz



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
[GNU Make]: https://www.gnu.org/software/make/
