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

-- This table represents the entire module.
local Luvent = {}
Luvent.__index = Luvent

--- Create a new event.
--
-- This is the constructor for creating events, i.e. Luvent objects.
--
-- @return A new event.
function Luvent.newEvent()
    local event = {}

    --- An event object created by Luvent.
    --
    -- @class table
    -- @name Event
    --
    -- @field actions An array containing all actions to execute when
    -- triggering this event.
    --
    -- @see newAction
    event.actions = {}
    
    return setmetatable(event, Luvent)
end

--- Compare two events for equality.
--
-- Two events are equal if they meet two criteria.  First, their
-- 'actions' properties must be tables of the same length.  And
-- second, their 'actions' tables must contain the same contents.  The
-- test can be slow because the comparison has an O(N^2) complexity.
--
-- @return A boolean indicating whether or not the events are equal.
Luvent.__eq = function (e1, e2)
    if getmetatable(e1) ~= Luvent or getmetatable(e2) ~= Luvent then
        return false
    end

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

--- The metatable that internally designates actions.
Luvent.Action = {}
Luvent.Action.__index = Luvent.Action

--- Determine if something is a valid action callable.
--
-- Every action must have a 'callable' property which actually
-- executes the logic for that action.  That property must satisfy
-- this predicate.
--
-- @param callable The object to test.
--
-- @return Boolean true if the parameter is a valid callable, and
-- boolean false if it is not.
local function isActionCallable(callable)
    if type(callable) == "table" then
        if type(getmetatable(callable)["__call"]) == "function" then
            return true
        end
    elseif type(callable) == "function" then
        return true
    elseif type(callable) == "thread" then
        if coroutine.status(callable) ~= "dead" then
            return true
        end
    end

    return false
end

--- Create a new action.
--
-- Luvent stores actions as tables, which this function creates.
-- These tables are private to the library and no part of the public
-- API ever accepts or returns them.
--
-- @param callable The actual logic to execute for this action.
--
-- @return The new action.
local function newAction(callable)
    local action = {}
    
    assert(isActionCallable(callable))
    action.callable = callable

    -- This is an ID which we can use later to refer to this action.
    -- For example, we could use this ID to find an action to remove
    -- when we added that action using an anonymous function, meaning
    -- we would not be able to use the function itself to find the
    -- action like normal.
    action.id = tostring(callable)

    -- This boolean indicates whether or not the action is enabled.
    -- Events will never invoke disable actions.  This flag makes it
    -- possible to disable an action without removing it.
    action.enabled = true

    -- Each action has a priority, which is a non-negative integer.
    -- Events will execute actions in the order of their priority
    -- value which this property represents.  By default the value is
    -- zero so that all actions have equal priority.
    action.priority = 0

    -- This property represents the number of times events can invoke
    -- this action.  If the value is a non-negative number then Luvent
    -- will disable the action after trigger() invokes the action that
    -- many times.  If the value is a negative number then Luvent will
    -- always invoke the action when triggering events.  We use a
    -- negative number as a sentinel value because the public API does
    -- not accept negative limit values.
    --
    -- @see Luvent:setActionTriggerLimit
    action.limit = -1

    -- This property keeps track of how many times events have invoked
    -- this action.  We reset this to zero whenever we change the
    -- 'limit' property.
    action.numberOfInvocations = 0

    -- If we have a non-zero interval then we need to keep track of
    -- how often we consider this action for execution.  The
    -- properties below help track the time of when we last called
    -- this action, and when considering whether or not to call it
    -- again we subtract the current time from this time and see if it
    -- is greater to or equal than the interval.  When first creating
    -- the action we set the property to the current time so that we
    -- can start counting the clock from the moment we created the
    -- action (i.e. now) up until the first time the interval elapses.
    action.interval = 0
    action.timeOfLastInvocation = os.time()

    return setmetatable(action, Luvent.Action)
end

--- Compare two actions for equality.
--
-- @return A boolean indicating if the two actions share the same ID.
Luvent.Action.__eq = function (a1, a2)
    if getmetatable(a1) ~= Luvent.Action
    or getmetatable(a2) ~= Luvent.Action then
        return false
    end

    return a1.id == a2.id
end

--- Find a specific action associated with an event.
--
-- @param event The event in which we search for the action.
--
-- @param actionToFind The action to search for, which can be anything
-- acceptable as the action argument to the addAction() method.
--
-- @return The function always returns two values.  If the event
-- contains the action then the function returns boolean true and an
-- integer, the index where that action appears in the event's table
-- of actions.  If the event does not contain the action then the
-- function returns boolean false and nil.
local function findAction(event, actionToFind)
    local key

    if type(actionToFind) == "string" then
        key = "id"
    elseif isActionCallable(actionToFind) then
        key = "callable"
    else
        error("Invalid action parameter: " .. tostring(actionToFind))
    end

    for index,action in ipairs(event.actions) do
        if action[key] == actionToFind then
            return true, index
        end
    end
    
    return false, nil
end

--- Add an action to an event.
--
-- It is not possible to add the same action more than once.
--
-- @param actionToAdd A function or callable table to run when
-- triggering this event.
--
-- @return The ID of the action.
--
-- @see isActionCallable
function Luvent:addAction(actionToAdd)
    assert(isActionCallable(actionToAdd) == true)

    -- We do not allow adding an action more than once to an event.
    if self:hasAction(actionToAdd) then return end

    local new = newAction(actionToAdd)
    table.insert(self.actions, new)
    return new.id
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

--- Return the number of actions associated with an event.
--
-- @return An integer representing the number of actions.  Note that
-- because actions can run on delays this number does not indicate how
-- many actions the event will execute when we trigger it.  The number
-- only tells us the total number of actions bound to the event.
function Luvent:getActionCount()
    return #self.actions
end

--- Check for the existence of an action.
--
-- @param actionToFind The action to search for within the event's
-- list of actions.
--
-- @return Boolean true if the event uses the action, and false if it
-- does not.
function Luvent:hasAction(actionToFind)
    return (findAction(self, actionToFind))
end

--- Invoke an action.
--
-- This is the internal mechanism for running actions when we trigger
-- an event.  It takes care to invoke actions in the correct way based
-- on their base type, e.g. actions that are coroutines.
--
-- @param action The action to invoke.
--
-- @param ... Any additional arguments to give to the action.
--
-- @return Boolean true if we can invoke this action again at a later
-- time and false if we cannot, e.g. if it is a dead coroutine, in
-- which case we remove the action.
--
-- @see Luvent:setActionTriggerLimit
local function invokeAction(action, ...)
    if action.enabled == false then
        return true
    end

    if type(action.callable) == "thread" then
        coroutine.resume(action.callable, ...)
        if coroutine.status(action.callable) == "dead" then
            return false
        end
    else
        action.callable(...)
    end

    action.numberOfInvocations = action.numberOfInvocations + 1

    if action.limit >= 0
    and action.numberOfInvocations >= action.limit then
        action.enabled = false
    end

    return true
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
    local call = function (action, ...)
        local keep = invokeAction(action, ...)
        if keep == false then
            self:removeAction(action.id)
        end
    end
        
    for _,action in ipairs(self.actions) do
        if action.interval > 0 then
            if os.difftime(os.time(), action.timeOfLastInvocation) >= action.interval then
                call(action, ...)
                action.timeOfLastInvocation = os.time()
            end
        else
            call(action, ...)
        end
    end
end

--- Modify the interval of an action
--
-- This method lets us change an action to adhere to an interval, i.e.
-- the number of seconds that must pass before the event will invoke
-- the action again.  The method also lets us set the interval to zero
-- so that the event will invoke the action regardless of time.
--
-- @param actionToFind The action to modify.  This must either be
-- something acceptable to Luvent:addAction() or it must be the ID
-- that Luvent:addAction() returns for each action.  It is an error to
-- call this method on an action that does is not part of the event.
--
-- @param interval An integer representing the new interval.
function Luvent:setActionInterval(actionToFind, interval)
    local exists,index = findAction(self, actionToFind)
    assert(exists)
    self.actions[index].interval = interval
end

--- Enable an action.
--
-- This method enables an action so that triggering the event will
-- call the action.  Luvent enables all actions by default, so this
-- method is meant primarily for re-enabling disabled actions.
--
-- @param actionToFind The action to enable.  This must either be an
-- action ID or something acceptable to the Luvent:addAction() method.
--
-- @see Luvent:disableAction
function Luvent:enableAction(actionToFind)
    local exists,index = findAction(self, actionToFind)
    assert(exists)
    self.actions[index].enabled = true
end

--- Disable an action.
--
-- This method disables an action so that triggering the event will
-- not invoke the action.  This allows us to temporarily stop using an
-- action without removing it from the event.
--
-- @param actionToFind The action to disable.  This must either be an
-- action ID or something acceptable to the Luvent:addAction() method.
--
-- @see Luvent:enableAction
function Luvent:disableAction(actionToFind)
    local exists,index = findAction(self, actionToFind)
    assert(exists)
    self.actions[index].enabled = false
end

--- Determine if an action is enabled or not.
--
-- @param actionToFind The action to check.  This must either be an
-- action ID or something acceptable to the Luvent:addAction() method.
--
-- @return Boolean true if the action is enabled and false if the
-- action is disabled.
function Luvent:isActionEnabled(actionToFind)
    local exists,index = findAction(self, actionToFind)
    assert(exists)
    return self.actions[index].enabled
end

--- Set a limit on how many times events will call an action.
--
-- This method tells Luvent to disable the action after a certain
-- number of invocations.  Luvent will only disable the action, not
-- remove it, so that later we can re-enable it.  Luvent only enforces
-- the limit on the event that calls this method, even if multiple
-- events share the action.
--
-- @param actionToFind The action to modify.  This must either be an
-- action ID or something acceptable to the Luvent:addAction() method.
--
-- @param limit A non-negative integer representing the maximum number
-- of times the invoke the action.  If the value is zero then Luvent
-- will disable the action.
function Luvent:setActionTriggerLimit(actionToFind, limit)
    local exists,index = findAction(self, actionToFind)
    assert(exists)
    assert(type(limit) == "number" and limit >= 0)
    self.actions[index].limit = limit
    self.actions[index].numberOfInvocations = 0

    if limit == 0 then
        self.actions[index].enabled = false
    end
end

--- Remove any limit on an action.
--
-- This method gets rid of any limit placed on an action.  If the
-- action is disabled then this method will re-enable it.
--
-- @param actionToFind The action to modify.  This must either be an
-- action ID or something acceptable to the Luvent:addAction() method.
--
-- @see Luvent:setActionTriggerLimit
function Luvent:removeActionTriggerLimit(actionToFind)
    local exists,index = findAction(self, actionToFind)
    assert(exists)
    self.actions[index].limit = -1
    self.actions[index].numberOfInvocations = 0
    self.actions[index].enabled = true
end

-- Do not allow external code to modify the metatable of events and
-- actions in order to improve stability, particularly by preventing
-- bugs caused by external manipulation of the metatable.
Luvent.Action.__metatable = Luvent.Action
Luvent.__metatable = Luvent

return Luvent
