-- Fleet Jump through Gate Command Mod by MassCraxx
-- v5

package.path = package.path .. ";data/scripts/?.lua"
include("utility")
include("stringutility")
include ("callable")

OrderButtonType["Gate"] = 12
OrderButtonType["Wormhole"] = 13

local gateWindow
local gateCombo
local gateData = {}

if onClient() then

-- Gate name util
local dirs =
{
    {name = "E /*direction*/"%_t,    angle = math.pi * 2 * 0 / 16},
    {name = "ENE /*direction*/"%_t,  angle = math.pi * 2 * 1 / 16},
    {name = "NE /*direction*/"%_t,   angle = math.pi * 2 * 2 / 16},
    {name = "NNE /*direction*/"%_t,  angle = math.pi * 2 * 3 / 16},
    {name = "N /*direction*/"%_t,    angle = math.pi * 2 * 4 / 16},
    {name = "NNW /*direction*/"%_t,  angle = math.pi * 2 * 5 / 16},
    {name = "NW /*direction*/"%_t,   angle = math.pi * 2 * 6 / 16},
    {name = "WNW /*direction*/"%_t,  angle = math.pi * 2 * 7 / 16},
    {name = "W /*direction*/"%_t,    angle = math.pi * 2 * 8 / 16},
    {name = "WSW /*direction*/"%_t,  angle = math.pi * 2 * 9 / 16},
    {name = "SW /*direction*/"%_t,   angle = math.pi * 2 * 10 / 16},
    {name = "SSW /*direction*/"%_t,  angle = math.pi * 2 * 11 / 16},
    {name = "S /*direction*/"%_t,    angle = math.pi * 2 * 12 / 16},
    {name = "SSE /*direction*/"%_t,  angle = math.pi * 2 * 13 / 16},
    {name = "SE /*direction*/"%_t,   angle = math.pi * 2 * 14 / 16},
    {name = "ESE /*direction*/"%_t,  angle = math.pi * 2 * 15 / 16},
    {name = "E /*direction*/"%_t,    angle = math.pi * 2 * 16 / 16}
}

function getGateName(x, y, tx, ty)
    local ownAngle = math.atan2(ty - y, tx - x) + math.pi * 2
    if ownAngle > math.pi * 2 then ownAngle = ownAngle - math.pi * 2 end
    if ownAngle < 0 then ownAngle = ownAngle + math.pi * 2 end

    local dirString = ""
    local min = 3.0 
    for _, dir in pairs(dirs) do
        local d = math.abs(ownAngle - dir.angle)
        if d < min then
            min = d
            dirString = dir.name -- set our gate's direction string so it can be used to set an icon for it.
        end
    end
    return dirString
end

-- Init

local oldInitUI = MapCommands.initUI
function MapCommands.initUI()
    oldInitUI()
    -- gate button
    local gateOrder = {tooltip = "Use Gate"%_t, icon = "data/textures/icons/patrol.png", callback = "onGatePressed", type = OrderButtonType.Gate}
    local index = #orders-1
    
    table.insert(orders, index, gateOrder)

    local gateButton = ordersContainer:createRoundButton(Rect(), gateOrder.icon, gateOrder.callback)
    gateButton.tooltip = gateOrder.tooltip

    table.insert(orderButtons, index, gateButton)

    -- wormhole button
    local wormholeOrder = {tooltip = "Use Wormhole"%_t, icon = "data/textures/icons/wormhole.png", callback = "onWormholePressed", type = OrderButtonType.Wormhole}
    local index = #orders-1
    
    table.insert(orders, index, wormholeOrder)

    local button = ordersContainer:createRoundButton(Rect(), wormholeOrder.icon, wormholeOrder.callback)
    button.tooltip = wormholeOrder.tooltip

    table.insert(orderButtons, index, button)

    -- gate window
    local res = getResolution()
    local gateWindowSize = vec2(400, 50)
    gateWindow = GalaxyMap():createWindow(Rect(res * 0.5 - gateWindowSize * 0.5, res * 0.5 + gateWindowSize * 0.5))
    gateWindow.caption = "Jump through Gate"%_t

    local vsplit = UIVerticalSplitter(Rect(gateWindow.size), 10, 10, 0.6)
    gateCombo = gateWindow:createValueComboBox(vsplit.left, "")
    gateButton = gateWindow:createButton(vsplit.right, "Jump"%_t, "onGateWindowOKButtonPressed")

    gateWindow.showCloseButton = 1
    gateWindow.moveable = 1
    gateWindow:hide()
end

-- Wormhole Button

function MapCommands.onWormholePressed()
    MapCommands.clearOrdersIfNecessary()
    MapCommands.enqueueOrder("addDiscoverWormholeOrder")
    if not MapCommands.isEnqueueing() then MapCommands.runOrders() end
end

-- Gate Window

local oldhideOrderButtons = MapCommands.hideOrderButtons
function MapCommands.hideOrderButtons()
    oldhideOrderButtons()
    gateWindow:hide()
end

function MapCommands.onGatePressed()
    enqueueNextOrder = MapCommands.isEnqueueing()

    gateCombo:clear()
    gateData = {}

    local x, y = GalaxyMap():getSelectedCoordinates()

    if MapCommands.isEnqueueing() then
        local selected = MapCommands.getSelectedPortraits()
        if #selected > 0 then
            local ix, iy = MapCommands.getLastLocationFromInfo(selected[1].info)
            if ix and iy then
                x, y = ix, iy
            end
        end
    end

    local player = Player()
    local sectorView = player:getKnownSector(x, y)
    if sectorView == nil then
        onError("Sector %i:%i has not been discovered yet."%_T, x, y)
    else
        local gateDestinations = {sectorView:getGateDestinations()}

        if #gateDestinations == 0 then
            onError(string.format("No Gate found in Sector %i:%i!"%_T, x, y))
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
    
            buyWindow:hide()
            sellWindow:hide()
            escortWindow:hide()
            gateWindow:show()
        end  
    end
end

function MapCommands.onGateWindowOKButtonPressed()
    local factionIndex = gateCombo.selectedValue
    local craftLine = gateCombo.selectedEntry
    local gate = gateData[craftLine]

    MapCommands.clearOrdersIfNecessary(not enqueueNextOrder) -- clear if not enqueueing
    MapCommands.enqueueOrder("addFlyThroughGateOrder", gate.x, gate.y)
    if not enqueueNextOrder then MapCommands.runOrders() end

    gateWindow:hide()
end

function onError(msg, ...)
    -- FIXME if u can
    msg = string.format(msg, ...)
    print("Error: " .. msg)

    local player = Player()
    local x, y = player:getShipPosition(name)

    invokeEntityFunction(x, y, msg, player.craft.id, "data/scripts/entity/orderchain.lua", "sendError", "If you see this message, my hack did not work.")
end

end -- onClient()