-- Fleet Jump through Gate Command Mod by MassCraxx
-- v3

OrderButtonType["Wormhole"] = 12
if onClient() then
local oldInitUI = MapCommands.initUI
function MapCommands.initUI()
    oldInitUI()
    local wormholeOrder = {tooltip = "Wormhole"%_t, icon = "data/textures/icons/wormhole.png", callback = "onWormholePressed", type = OrderButtonType.Wormhole}
    local index = #orders-1
    
    table.insert(orders, index, wormholeOrder)

    local button = ordersContainer:createRoundButton(Rect(), wormholeOrder.icon, wormholeOrder.callback)
    button.tooltip = wormholeOrder.tooltip

    table.insert(orderButtons, index, button)
end

function MapCommands.updateButtonLocations()
    if #craftPortraits == 0 then
        MapCommands.hideOrderButtons()
        return
    end

    MapCommands.enchainCoordinates = nil

    local enqueueing = MapCommands.isEnqueueing()
    local sx, sy = GalaxyMap():getSelectedCoordinatesScreenPosition()
    local cx, cy = GalaxyMap():getSelectedCoordinates()
    local selected = MapCommands.getSelectedPortraits()

    local usedPortraits
    if #selected > 0 and enqueueing then
        usedPortraits = selected

        local x, y = MapCommands.getLastLocationFromInfo(selected[1].info)
        if x and y then
            sx, sy = GalaxyMap():getCoordinatesScreenPosition(ivec2(x, y))
            cx, cy = x, y
            MapCommands.enchainCoordinates = {x=x, y=y}
        else
            MapCommands.enchainCoordinates = {x=cx, y=cy}
        end
    else
        usedPortraits = craftPortraits
    end


    for _, portrait in pairs(craftPortraits) do
        if enqueueing and not portrait.portrait.selected then
            portrait.portrait:hide()
            portrait.icon:hide()
        end
    end

    local showAbove = Keyboard():keyPressed(KeyboardKey.LControl) or Keyboard():keyPressed(KeyboardKey.RControl)

    -- portraits
    local diameter = 50
    local padding = 10

    local columns = math.min(#usedPortraits, math.max(4, round(math.sqrt(#usedPortraits))))

    local offset = vec2(columns * diameter + (columns - 1) * padding, padding * 3)
    offset.x = -offset.x / 2
    offset = offset + vec2(sx, sy)

    local x = 0
    local y = 0
    for _, portrait in pairs(usedPortraits) do
        local rect = Rect()
        rect.lower = vec2(x * (diameter + padding), y * (diameter + padding)) + offset
        rect.upper = rect.lower + vec2(diameter, diameter)
        portrait.portrait.rect = rect
        portrait.portrait:show()

        if portrait.picture and portrait.picture ~= "" then
            portrait.icon.rect = Rect(rect.topRight - vec2(8, 8), rect.topRight + vec2(8, 8))
            portrait.icon:show()
            portrait.icon.picture = portrait.picture
        end

        if showAbove then
            MapCommands.mirrorUIElementY(portrait.portrait, sy)
            MapCommands.mirrorUIElementY(portrait.icon, sy)
        end

        x = x + 1
        if x >= columns then
            x = 0
            y = y + 1
        end

        ::continue::
    end


    -- buttons
    if #selected > 0 then
        if x ~= 0 then
            y = y + 1
        end

        local visibleButtons = {}
        for i, button in pairs(orderButtons) do
            local add = true

            if (orders[i].type == OrderButtonType.Stop or orders[i].type == OrderButtonType.Wormhole) and MapCommands.isEnqueueing() then
                -- cannot enqueue a "stop"
                add = false
            elseif orders[i].type == OrderButtonType.Undo then

                -- cannot undo if there is nothing to undo
                local hasCommands = false

                for _, portrait in pairs(selected) do
                    if MapCommands.hasCommandToUndo(portrait.info) then
                        hasCommands = true
                        break
                    end
                end

                if not hasCommands then
                    add = false
                end

            elseif orders[i].type == OrderButtonType.Loop then
                -- cannot loop if there are no commands based in the selected sector
                local hasCommands = false

                if MapCommands.isEnqueueing() then
                    for _, portrait in pairs(selected) do
                        local commands = MapCommands.getCommandsFromInfo(portrait.info, cx, cy)
                        if #commands > 0 then
                            hasCommands = true
                            break
                        end
                    end
                end

                if not hasCommands then
                    add = false
                end
            end

            if add then
                table.insert(visibleButtons, button)
            else
                button:hide()
            end
        end


        local oDiameter = 35

        local offset = vec2(#visibleButtons * oDiameter + (#visibleButtons - 1) * padding, padding * 5)
        offset.x = -offset.x / 2
        offset = offset + vec2(sx, sy)

        for _, button in pairs(visibleButtons) do
            local rect = Rect()
            rect.lower = vec2(x * (oDiameter + padding), y * (oDiameter + padding)) + offset
            rect.upper = rect.lower + vec2(oDiameter, oDiameter)
            button.rect = rect

            if showAbove then
                MapCommands.mirrorUIElementY(button, sy)
            end

            button:show()

            x = x + 1
        end
    else
        MapCommands.hideOrderButtons()
    end
end

function MapCommands.onWormholePressed()
    MapCommands.clearOrdersIfNecessary()
    MapCommands.enqueueOrder("addWormholeOrder")
end

function MapCommands.getCommandsFromInfo(info, x, y)
    if not info then return {} end
    if not info.chain then return {} end
    if not info.coordinates then return {} end

    local cx, cy = info.coordinates.x, info.coordinates.y
    local i = info.currentIndex

    local result = {}
    while i > 0 and i <= #info.chain do
        local current = info.chain[i]

        if cx == x and cy == y then
            table.insert(result, current)
        end

        if current.action == OrderType.Jump or current.action == OrderType.FlyThroughWormhole then
            cx, cy = current.x, current.y
        end

        i = i + 1
    end

    return result
end

end -- onClient()
