local Luvent = require "Luvent"

describe("Initialization", function ()

    it("Creates events with names", function ()
        local name = "onClick"
        local event = Luvent.newEvent(name)
        assert.are.equal(getmetatable(event), Luvent)
        assert.are.equal(event.name, name)
    end)

    it("Requires a name as a string", function ()
        assert.has.errors(function ()
            local event = Luvent.newEvent()
        end)
        assert.has.errors(function ()
            local event = Luvent.newEvent(123)
        end)
    end)

    it("Does not allow changing the metatable", function ()
        local event = Luvent.newEvent("onLoad")
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
        event = Luvent.newEvent("onClick")
    end)

    describe("Adding actions", function ()

        it("Can add a single action", function ()
            event:addAction(noop)
            assert.are.equal(#event.actions, 1)
        end)

        it("Ignores attempts to add an action more than once", function ()
            event:addAction(noop)
            event:addAction(noop)
            event:addAction(noop)
            assert.are.equal(#event.actions, 1)
        end)

        it("Accepts multiple actions", function ()
            event:addAction(noop)
            event:addAction(echo)
            assert.are.equal(#event.actions, 2)
        end)

        it("Accepts a table with a call() metamethod", function ()
            assert.has_no_errors(function ()
                event:addAction(sort)
            end)
        end)

        it("Requires actions to be callable", function ()
            assert.has.errors(function ()
                event:addAction(setmetatable({}, {}))
            end)
        end)

    end)

    describe("Removing actions", function ()

        before_each(function ()
            event:addAction(noop)
            event:addAction(echo)
        end)

        it("Can remove a single action", function ()
            assert.are.equal(#event.actions, 2)
            event:removeAction(noop)
            assert.are.equal(#event.actions, 1)
        end)

        it("Can remove all actions", function ()
            assert.are.equal(#event.actions, 2)
            event:removeAllActions()
            assert.are.equal(#event.actions, 0)
        end)
        
    end)

    describe("Getting information about actions", function ()

        it("Can tell if an action exists", function ()
            event:addAction(noop)
            event:addAction(sort)
            assert.True(event:callsAction(noop))
            assert.True(event:callsAction(sort))
            assert.False(event:callsAction(echo))
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
        onClickEvent = Luvent.newEvent("onClick")
        button = { clickCount = 0, label = "" }
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
        local eventOne = Luvent.newEvent("onConnect")
        local eventTwo = Luvent.newEvent("onConnect")
        local eventThree = Luvent.newEvent("onConnect")
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

describe("Controlling time between actions", function ()

    local event
    local ticks
    local bumpTicks

    before_each(function ()
        event = Luvent.newEvent("eachTick")
        ticks = 0
        bumpTicks = function () ticks = ticks + 1 end
    end)

    it("Calls an action only after so many seconds", function ()
        local startTime = os.time()
        local bump = spy.new(bumpTicks)
        event:addActionWithInterval(bump, 1)
        
        while true do
            event:trigger()
            if os.time() - startTime > 3 then
                break
            end
        end

        assert.are.equal(ticks, 3)
        assert.spy(bump).was.called(3)
    end)

    it("Can mix actions with and without delays", function()
    end)

end)