--[[------------------------------------------------------------------
--
-- Luvent :: A Simple Event Library
--
-- For documentation and license information see the official project
-- website: <https://github.com/ejmr/Luvent>
--
-- Copyright 2013 Eric James Michael Ritz
--
--]]------------------------------------------------------------------

local Luvent = {}

-- Make sure the library can find the methods for each Luvent object.
Luvent.__index = Luvent

--- Create a new event.
--
-- This is the constructor for creating events, i.e. Luvent objects.
-- The new event will have the name given to the constructor and will
-- use the 'Luvent' table for its metatable.
--
-- @param name The name of the event.
--
-- @return A new event.
function Luvent.new(name)
    local event = {}

    assert(type(name) == "string")
    event.name = name
    event.actions = {}
    
    return setmetatable(event, Luvent)
end

--- Add an action to an event.
--
-- Actions are functions.  Triggering an event executes all actions
-- associated with that event.  An event stores its actions as an
-- array of functions.  Adding the same action more than once to the
-- same event has no effect.
--
-- @param newAction A function to run when triggering this event.  The
-- function can accept any number of arguments, but Luvent will
-- discard all of its return values.  The argument can also be a table
-- instead of a function, but it must have a metatable implementing
-- the __call() metamethod.
function Luvent:addAction(newAction)
    if type(newAction) == "table" then
        assert(type(getmetatable(newAction).__call) == "function")
    else
        assert(type(newAction) == "function")
    end

    for _,action in ipairs(self.actions) do
        if newAction == action then
            return
        end
    end

    table.insert(self.actions, newAction)
end

--- Remove an action from an event.
--
-- This method accepts an action and disassociates it from the event.
-- It is safe to call this method even if the action is not associated
-- with the event.
--
-- @param actionToRemove The function to remove from the list of
-- actions for this event.
--
-- @see Luvent:addAction
function Luvent:removeAction(actionToRemove)
    for index,action in ipairs(self.actions) do
        if action == actionToRemove then
            table.remove(self.actions, index)
            return
        end
    end
end

--- Remove all actions from an event.
--
-- Calling this method removes every action from an event.
--
-- @see Luvent:removeAction
function Luvent:removeAllActions()
    self.actions = {}
end

--- Checks for the existence of an action.
--
-- @param actionToFind The action to search for within the event's
-- list of actions.
--
-- @return Boolean true if the event uses the action, and false if it
-- does not.
function Luvent:callsAction(actionToFind)
    for _,action in ipairs(self.actions) do
        if action == actionToFind then
            return true
        end
    end
    return false
end

--- Trigger an event.
--
-- This method triggers an event, which in turn executes every action
-- associated with that event.
--
-- @param ... All arguments given to this method will be passed along
-- to every action.
function Luvent:trigger(...)
    local arguments = { ... }
    for _,action in ipairs(self.actions) do
        action(unpack(arguments))
    end
end

return Luvent
