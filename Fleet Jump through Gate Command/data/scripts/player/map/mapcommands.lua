include ("ordertypes")
include ("fjtgc")

MapCommands.registerModdedMapCommand(OrderType.UseGate, {
    tooltip = "Use Gate"%_t,
    icon = "data/textures/icons/patrol.png",
    callback = "onGatePressed",
})

MapCommands.registerModdedMapCommand(OrderType.UseWH, {
    tooltip = "Use Wormhole"%_t,
    icon = "data/textures/icons/wormhole.png",
    callback = "onWormholePressed",
})

local __FJTGC_BaseMapCommandsInitUI = MapCommands.initUI

function MapCommands.initUI()
    __FJTGC_BaseMapCommandsInitUI()

    -- gate window
    local res = getResolution()
    local gateWindowSize = vec2(400, 50)
    gateWindow = GalaxyMap():createWindow(Rect(res * 0.5 - gateWindowSize * 0.5, res * 0.5 + gateWindowSize * 0.5))
    gateWindow.caption = "Jump Through Gate"%_t

    local vsplit = UIVerticalSplitter(Rect(gateWindow.size), 10, 10, 0.6)
    gateCombo = gateWindow:createValueComboBox(vsplit.left, "")
    gateButton = gateWindow:createButton(vsplit.right, "Jump"%_t, "onGateWindowOKButtonPressed")

    gateWindow.showCloseButton = 1
    gateWindow.moveable = 1
    gateWindow:hide()
end

-- Wormhole Button
function MapCommands.onWormholePressed()
    -- MapCommands.clearOrdersIfNecessary()
    MapCommands.enqueueOrder("addDiscoverWormholeOrder")
    -- if not MapCommands.isEnqueueing() then MapCommands.runOrders() end
end

-- Gate Button
function MapCommands.onGatePressed()
    enqueueNextOrder = MapCommands.isEnqueueing()

    gateCombo:clear()
    gateData = {}

    local x, y
    local selected = MapCommands.filterPortraits{selected = true}
    
    if #selected > 0 then
        x = selected[1].coordinates.x
        y = selected[1].coordinates.y
        if MapCommands.isEnqueueing() then
            local ix, iy = MapCommands.getLastLocationFromInfo(selected[1].info)
            if ix and iy then
                x, y = ix, iy
            end
        end

        -- if multiple ships selected, check if all ships pos match
        if #selected > 1 then
            for _, portrait in pairs(selected) do
                local ox = portrait.coordinates.x
                local oy = portrait.coordinates.y
                if ox ~= x or oy ~= y then
                    if MapCommands.isEnqueueing() then
                        local ix, iy = MapCommands.getLastLocationFromInfo(portrait.info)
                        if ix and iy then
                            ox, oy = ix, iy
                        end
                        if ox ~= x or oy ~= y then
                            onModError("Selected ships are not in the same system!")
                            return
                        end
                    else
                        onModError("Selected ships are not in the same system!")
                        return
                    end
                end
            end
        end
    else
        return
    end

    local player = Player()
    local sectorView = player:getKnownSector(x, y) or (player.alliance and player.alliance:getKnownSector(x, y))
    if sectorView == nil then
        onModError("Sector %i:%i has not been discovered yet."%_T, x, y)
    else
        local gateDestinations = {sectorView:getGateDestinations()}

        if #gateDestinations == 0 then
            onModError(string.format("No Gates found in sector %i:%i!"%_T, x, y))
        else
            for i, dest in pairs(gateDestinations) do
                local dir = getGateName(x, y, dest.x, dest.y)

                for i = string.len(dir),2,1 do 
                    dir = dir .. " " 
                end

                local line = string.format("%s | %i : %i"%_t, dir, dest.x, dest.y)
            
                color = ColorRGB(0.875, 0.875, 0.875)
            
                gateData[line] = dest
                gateCombo:addEntry(dir, line, color)
            end
            -- buyWindow:hide()
            -- sellWindow:hide()
            -- escortWindow:hide()
            gateWindow:show()
        end  
    end
end

function MapCommands.onGateWindowOKButtonPressed()
    local factionIndex = gateCombo.selectedValue
    local craftLine = gateCombo.selectedEntry
    local gate = gateData[craftLine]

    --MapCommands.clearOrdersIfNecessary(not enqueueNextOrder) -- clear if not enqueueing
    MapCommands.enqueueOrder("addFlyThroughGateOrder", gate.x, gate.y)
    --if not enqueueNextOrder then MapCommands.runOrders() end

    gateWindow:hide()
end

function onModError(msg, ...)
    msg = string.format(msg, ...)
    print("Error: " .. msg)

    local player = Player()
    local x, y = player:getShipPosition(name)

    invokeEntityFunction(x, y, msg, player.craft.id, "data/scripts/entity/orderchain.lua", "sendError", msg)
end
