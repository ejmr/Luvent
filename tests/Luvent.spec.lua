local Luvent = require "Luvent"

describe("Initialization", function ()

    it("Creates events with names", function ()
        local name = "onClick"
        local event = Luvent.new(name)
        assert.are.equal(getmetatable(event), Luvent)
        assert.are.equal(event.name, name)
    end)

    it("Requires a name as a string", function ()
        assert.has.errors(function ()
            local event = Luvent.new()
        end)
        assert.has.errors(function ()
            local event = Luvent.new(123)
        end)
    end)

end)

describe("Basic action management", function ()

    local event
    local noop = function () end
    local echo = function (...) print(...) end

    before_each(function ()
        event = Luvent.new("onClick")
    end)

    describe("Adding actions", function ()

        it("Can add a single action", function ()
            event:addAction(noop)
            assert.are.equal(#event.actions, 1)
            assert.are.equal(event.actions[1], noop)
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

        it("Requires actions to be functions", function ()
            assert.has.errors(function ()
                event:addAction("Not a function")
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
            assert.True(event:usesAction(noop))
            assert.False(event:usesAction(echo))
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
        onClickEvent = Luvent.new("onClick")
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