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
function Luvent.newEvent(name)
    local event = {}

    --- An event object created by Luvent.
    --
    -- @class table
    -- @name Event
    --
    -- @field name A string with the name of the event.
    --
    -- @field actions An array containing all actions to execute when
    -- triggering this event.  An action must be either a function or a
    -- table that implements the call() metamethod.
    assert(type(name) == "string")
    event.name = name
    event.actions = {}
    
    return setmetatable(event, Luvent)
end

--- Compare two events for equality.
--
-- Two events are equal if they meet three criteria.  First, they must
-- have the same 'name' property.  Second, their 'actions' properties
-- must be tables of the same length.  And finally, their 'actions'
-- tables must contain the same functions.  The test can be slow
-- because the comparison has an O(N^2) complexity.
--
-- @return A boolean indicating whether or not the events are equal.
Luvent.__eq = function (e1, e2)
    if getmetatable(e1) ~= Luvent or getmetatable(e2) ~= Luvent then
        return false
    end

    if e1.name ~= e2.name then return false end
    if #e1.actions ~= #e2.actions then return false end

    for _,a1 in ipairs(e1.actions) do
        local found = false
        for _,a2 in ipairs(e2.actions) do
            if a1 == a2 then
                found = true
                break
            end
        end
        if found == false then return false end
    end

    return true
end

--- Determine if something is a valid action.
--
-- @param action The object we test to see if it is a valid action.
--
-- @return Boolean true if the parameter is an action, and boolean
-- false if it is not.
local function isValidAction(action)
    if type(action) == "table" then
        if type(getmetatable(action)["__call"]) == "function" then
            return true
        end
    elseif type(action) == "function" then
        return true
    end
    return false
end

--- Find a specific action associated with an event.
--
-- @param event The event in which we search for the action.
-- @param actionToFind The action to search for.
--
-- @return The function always returns two values.  If the event
-- contains the action then the function returns boolean true and an
-- integer, the index where that action appears in the event's table
-- of actions.  If the event does not contain the action then the
-- function returns boolean false and nil.
local function findAction(event, actionToFind)
    for index,action in ipairs(event.actions) do
        if action == actionToFind then
            return true, index
        end
    end
    return false, nil
end

--- Add an action to an event.
--
-- It is not possible to add the same action more than once.
--
-- @param newAction A function or callable table to run when
-- triggering this event.
function Luvent:addAction(newAction)
    assert(isValidAction(newAction) == true)
    if self:callsAction(newAction) then return end
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
    local exists,index = findAction(self, actionToRemove)
    if exists == true then
        table.remove(self.actions, index)
    end
end

--- Remove all actions from an event.
--
-- @see Luvent:removeAction
function Luvent:removeAllActions()
    self.actions = {}
end

--- Check for the existence of an action.
--
-- @param actionToFind The action to search for within the event's
-- list of actions.
--
-- @return Boolean true if the event uses the action, and false if it
-- does not.
function Luvent:callsAction(actionToFind)
    return (findAction(self, actionToFind))
end

--- Trigger an event.
--
-- This method executes every action associated with the event.
-- Luvent throws away the return values from all actions invoked by
-- this method.
--
-- @param ... All arguments given to this method will be passed along
-- to every action.
function Luvent:trigger(...)
    local arguments = { ... }
    for _,action in ipairs(self.actions) do
        action(unpack(arguments))
    end
end

-- Do not allow external code to modify the metatable of events in
-- order to improve stability, particularly by preventing bugs caused
-- by external manipulation of the metatable.
Luvent.__metatable = Luvent

return Luvent
