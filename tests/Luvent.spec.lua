local Luvent = require "Luvent"

describe("Initialization", function ()

    it("Creates events", function ()
        local event = Luvent.newEvent()
        assert.are.equal(getmetatable(event), Luvent)
    end)

    it("Does not allow changing the metatable", function ()
        local event = Luvent.newEvent()
        assert.has.errors(function ()
            setmetatable(event, {})
        end)
    end)

end)

describe("Basic action management", function ()

    local event

    -- These are three actions.
    local noop = function () end
    local echo = function (...) print(...) end
    local sort = setmetatable({}, {
        __call = function (...)
            table.sort({ ... })
        end
    })

    before_each(function ()
        event = Luvent.newEvent()
    end)

    describe("Adding actions", function ()

        it("Can add a single action", function ()
            event:addAction(noop)
            assert.are.equal(event:getActionCount(), 1)
        end)

        it("Ignores attempts to add an action more than once", function ()
            event:addAction(noop)
            event:addAction(noop)
            event:addAction(noop)
            assert.are.equal(event:getActionCount(), 1)
        end)

        it("Accepts multiple actions", function ()
            event:addAction(noop)
            event:addAction(echo)
            assert.are.equal(event:getActionCount(), 2)
        end)

        it("Accepts a table with a call() metamethod", function ()
            assert.has_no_errors(function ()
                event:addAction(sort)
            end)
            assert.is_true(event:hasAction(sort))
        end)

        it("Requires actions to be callable", function ()
            assert.has.errors(function ()
                event:addAction(setmetatable({}, {}))
            end)
        end)

        it("Returns an ID when adding an action", function ()
            local id = event:addAction(noop)
            assert.is.truthy(id)
        end)

        it("Returns the same ID for events sharing an action", function ()
            local event2 = Luvent.newEvent()
            local id1 = event:addAction(noop)
            local id2 = event2:addAction(noop)

            assert.are.equal(id1, id2)
        end)

    end)

    describe("Removing actions", function ()

        before_each(function ()
            event:addAction(noop)
            event:addAction(echo)
        end)

        it("Can remove a single action using a function", function ()
            assert.are.equal(event:getActionCount(), 2)
            event:removeAction(noop)
            assert.are.equal(event:getActionCount(), 1)
        end)

        it("Can remove a single action using an ID", function ()
            local id = event:addAction(function () end)
            assert.are.equal(event:getActionCount(), 3)
            event:removeAction(id)
            assert.are.equal(event:getActionCount(), 2)
        end)

        it("Can remove all actions", function ()
            assert.are.equal(event:getActionCount(), 2)
            event:removeAllActions()
            assert.are.equal(event:getActionCount(), 0)
        end)
        
    end)

    describe("Getting information about actions", function ()

        it("Can tell if an action exists", function ()
            event:addAction(noop)
            event:addAction(sort)
            assert.True(event:hasAction(noop))
            assert.True(event:hasAction(sort))
            assert.False(event:hasAction(echo))
        end)
    
    end)

    describe("Disabling and re-enabling actions", function ()

        it("Does not invoke disabled actions", function ()
            local echo = spy.new(echo)
            local noop = spy.new(noop)

            event:addAction(echo)
            event:addAction(noop)
            event:disableAction(echo)
            event:trigger()

            assert.spy(echo).was_not_called()
            assert.spy(noop).was_called(1)

            event:enableAction(echo)
            event:trigger()

            assert.spy(echo).was_called(1)
            assert.spy(noop).was_called(2)
        end)

        it("Does not remove disabled actions", function ()
            event:addAction(noop)
            event:addAction(echo)
            assert.are.equal(event:getActionCount(), 2)
            
            event:disableAction(noop)
            assert.are.equal(event:getActionCount(), 2)
            
            event:enableAction(noop)
            assert.are.equal(event:getActionCount(), 2)
        end)

    end)

    describe("Limiting the number of invocations for actions", function ()

        it("Can disable an action after so many invocations", function ()
            local noop = spy.new(noop)

            event:addAction(noop)
            event:setActionTriggerLimit(noop, 3)

            for i = 1, 10 do
                event:trigger()
            end

            assert.spy(noop).was.called(3)
            assert.is_false(event:isActionEnabled(noop))
        end)

        it("Can remove a limit", function ()
            local noop = spy.new(noop)

            event:addAction(noop)
            event:setActionTriggerLimit(noop, 0)

            for i = 1, 10 do
                event:trigger()
            end

            assert.spy(noop).was_not_called()
            assert.is_false(event:isActionEnabled(noop))

            event:removeActionTriggerLimit(noop)

            for i = 1, 10 do
                event:trigger()
            end

            assert.spy(noop).was.called(10)
            assert.is_true(event:isActionEnabled(noop))
        end)

        it("Will disable an action with a limit of zero", function ()
            event:addAction(noop)
            event:setActionTriggerLimit(noop, 0)
            assert.is_false(event:isActionEnabled(noop))
        end)

        it("Will re-enable an action when removing its limit", function ()
            event:addAction(noop)
            event:disableAction(noop)
            assert.is_false(event:isActionEnabled(noop))
            event:removeActionTriggerLimit(noop)
            assert.is_true(event:isActionEnabled(noop))
        end)

        it("Only accepts non-negative numbers as limits", function ()
            event:addAction(noop)
            assert.is.error(function ()
                event:setActionTriggerLimit(noop, -1)
            end)
            assert.is.error(function ()
                event:setActionTriggerLimit(noop, "100")
            end)
        end)

        it("Enforces limits per-event for shared actions", function ()
            local event1 = Luvent.newEvent()
            local event2 = Luvent.newEvent()

            event1:addAction(noop)
            event2:addAction(noop)
            
            event1:setActionTriggerLimit(noop, 10)

            for i = 1, 10 do
                event1:trigger()
                event2:trigger()
            end

            assert.is_false(event1:isActionEnabled(noop))
            assert.is_true(event2:isActionEnabled(noop))
        end)

    end)

end)

describe("Triggering events", function ()

    local onClickEvent
    local button
    local bumpCounter 
    local updateLabel

    setup(function ()
        bumpCounter = function (button)
            button.clickCount = button.clickCount + 1
        end
        updateLabel = function (button)
            button.label = string.format("Clicks: %i", button.clickCount)
        end
    end)

    before_each(function ()
        onClickEvent = Luvent.newEvent()
        button = { clickCount = 0, label = "" }
    end)

    it("Allows triggering an event with no actions", function ()
        assert.are.equal(onClickEvent:getActionCount(), 0)
        assert.has_no.errors(function () onClickEvent:trigger() end)
    end)

    it("Calls actions that take no arguments", function ()
        local noop = spy.new(function () end)
        
        onClickEvent:addAction(noop)
        onClickEvent:trigger()
        assert.spy(noop).was.called()

        onClickEvent:trigger()
        onClickEvent:trigger()
        onClickEvent:trigger()
        assert.spy(noop).was.called(4)
    end)

    it("Passes arguments to actions", function ()
        local bump = spy.new(bumpCounter)

        onClickEvent:addAction(bump)
        onClickEvent:trigger(button)
        onClickEvent:trigger(button)
        onClickEvent:trigger(button)

        assert.spy(bump).was_called_with(button)
        assert.are.equal(button.clickCount, 3)
    end)

    it("Invokes multiple actions", function ()
        local bump = spy.new(bumpCounter)
        local update = spy.new(updateLabel)

        onClickEvent:addAction(bump)
        onClickEvent:addAction(update)
        onClickEvent:trigger(button)    
        onClickEvent:trigger(button)
        onClickEvent:trigger(button)

        assert.spy(bump).was.called(3)
        assert.spy(bump).was_called_with(button)
        assert.spy(update).was.called(3)
        assert.spy(update).was_called_with(button)
        assert.are.equal(button.clickCount, 3)
        assert.are.equal(button.label, "Clicks: 3")
    end)

end)

describe("Operators", function ()

    it("Can compare two events for equality", function ()
        local eventOne = Luvent.newEvent()
        local eventTwo = Luvent.newEvent()
        local eventThree = Luvent.newEvent()
        local connections = 0
        local updateConnectionCount = function ()
            connections = connections + 1
        end

        eventOne:addAction(updateConnectionCount)
        eventTwo:addAction(updateConnectionCount)
        assert.are.equal(eventOne, eventTwo)

        -- Give eventTwo more actions than eventOne.
        eventTwo:addAction(function () print "Connected" end)
        assert.are_not.equal(eventOne, eventTwo)

        -- Give eventThree the same number of actions as eventOne but
        -- give it a different action.
        eventThree:addAction(function () print "Connect" end)
        assert.are_not.equal(eventOne, eventThree)
    end)

end)

describe("Controlling time between actions #delay", function ()

    local event
    local ticks
    local bumpTicks
    local startTime

    before_each(function ()
        event = Luvent.newEvent()
        ticks = 0
        bumpTicks = spy.new(function () ticks = ticks + 1 end)
        startTime = os.time()
    end)

    it("Calls an action only after so many seconds", function ()
        local id = event:addAction(bumpTicks)
        event:setActionInterval(id, 1)
        
        while (os.time() - startTime) < 3 do
            event:trigger()
        end

        assert.are.equal(ticks, 3)
        assert.spy(bumpTicks).was.called(3)
    end)

    it("Can mix actions with and without delays", function()
        local switch = false
        local id1 = event:addAction(function () switch = true end)
        local id2 = event:addAction(bumpTicks)

        event:setActionInterval(id2, 10)
        
        assert.are.equal(event:getActionCount(), 2)

        -- We trigger the event but ten seconds will not pass.  So we
        -- should only see the side-effects of the first action and
        -- not 'bumpTicks'.
        event:trigger()
        assert.is_true(switch)
        assert.are.equal(ticks, 0)
        assert.spy(bumpTicks).was_not.called()
    end)

    it("Can remove the delay from an action", function ()
        local id = event:addAction(bumpTicks)
        event:setActionInterval(id, 10)

        while (os.time() - startTime) < 3 do
            event:trigger()
        end

        assert.are.equal(ticks, 0)
        event:removeActionInterval(id)
        event:trigger()
        assert.are.equal(ticks, 1)
    end)

end)

describe("Using coroutines as actions", function ()

    local event
    local noop

    before_each(function ()
        event = Luvent.newEvent()
        noop = coroutine.create(function () end)
    end)

    it("Accepts coroutines as actions", function ()
        event:addAction(noop)
        assert.are.equal(event:getActionCount(), 1)
        assert.is_true(event:hasAction(noop))
    end)

    it("Creates an ID to remove a coroutine", function ()
        local id = event:addAction(noop)
        assert.are.equal(event:getActionCount(), 1)
        event:removeAction(id)
        assert.are.equal(event:getActionCount(), 0)
    end)

    it("Automatically removes dead coroutines", function ()
        local id = event:addAction(noop)
        event:trigger()
        assert.are.equal(event:getActionCount(), 0)
        assert.is_false(event:hasAction(id))
    end)

    it("Supports coroutines that yield", function ()
        local ticks = 0
        local bump = coroutine.create(function ()
            while ticks < 10 do
                ticks = ticks + 1
                coroutine.yield()
            end
        end)

        event:addAction(bump)

        while event:getActionCount() > 0 do
            event:trigger()
        end

        assert.are.equal(ticks, 10)
    end)

end)

describe("Action priorities", function ()

    local event
    local ticks
    local addA, addB, addC

    before_each(function ()
        event = Luvent.newEvent()
        ticks = {}
        addA = event:addAction(function ()
            table.insert(ticks, "A")
        end)
        addB = event:addAction(function ()
            table.insert(ticks, "B")
        end)
        addC = event:addAction(function ()
            table.insert(ticks, "C")
        end)
    end)

    it("Requires priorities to be non-negative integers", function ()
        assert.is.error(function () event:setActionPriority(addA, -1) end)
        assert.is.error(function () event:setActionPriority(addA, "10") end)
    end)

    it("Calls actions with priorities first", function ()
        event:setActionPriority(addC, 1)
        event:trigger()
        assert.are.equal(ticks[1], "C")
    end)

    it("Sorts priorities in descending order", function ()
        event:setActionPriority(addC, 3)
        event:setActionPriority(addA, 2)
        event:setActionPriority(addB, 1)
        event:trigger()
        assert.are.same(ticks, {"C", "A", "B"})
    end)

    it("Can remove priorities", function ()
        event:setActionPriority(addC, 3)
        event:setActionPriority(addA, 2)
        event:setActionPriority(addB, 1)
        event:trigger()
        event:removeActionPriority(addA)
        event:trigger()
        assert.are.same(ticks, {"C", "A", "B", "C", "B", "A"})
    end)

end)