-- Fleet Jump through Gate Command Mod by MassCraxx
-- v7

-- Undo fix for wormhole orders
function OrderChain.undoOrder(x, y)
    if onClient() then
        invokeServerFunction("undoOrder", x, y)
        return
    end

    if callingPlayer then
        local owner, _, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips)
        if not owner then return end
    end

    local chain = OrderChain.chain
    local i = OrderChain.activeOrder

    local active = #chain > 0 and not OrderChain.finished

    if active and i < #chain then
        OrderChain.chain[#OrderChain.chain] = nil
        if OrderChain.executableOrders > #OrderChain.chain then
            OrderChain.executableOrders = OrderChain.executableOrders - 1
        end

        OrderChain.updateChain()
    elseif active and i == #chain and (chain[#chain].action == OrderType.Jump or chain[#chain].action == OrderType.FlyThroughWormhole) then
        OrderChain.clearAllOrders()
    else
        OrderChain.sendError("Cannot undo last order."%_T)
    end

end
callable(OrderChain, "undoOrder")

-- Wormhole button handling
function OrderChain.addDiscoverWormholeOrder()
    if onClient() then
        invokeServerFunction("addDiscoverWormholeOrder")
        return
    end

    if callingPlayer then
        local owner, _, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips)
        if not owner then
            local player = Player(callingPlayer)
            player:sendChatMessage("", ChatMessageType.Error, "You don't have permission to do that."%_T)
            return
        end
    end

    local shipX, shipY = Sector():getCoordinates()

    for _, action in pairs(OrderChain.chain) do
        if action.action == OrderType.Jump or action.action == OrderType.FlyThroughWormhole then
            shipX = action.x
            shipY = action.y
        end
    end

    if callingPlayer then
        local player = Player(callingPlayer)
        if player:knowsSector(shipX, shipY) or (player.alliance and player.alliance:knowsSector(shipX, shipY)) then
            local sectorView = player:getKnownSector(shipX, shipY) or player.alliance:getKnownSector(shipX, shipY)

            local wormholeDestinations = {sectorView:getWormHoleDestinations()}
            for _, dest in pairs(wormholeDestinations) do
                local order = {action = OrderType.FlyThroughWormhole, x = dest.x, y = dest.y, gate = false}
                if OrderChain.canEnchain(order) then
                    OrderChain.enchain(order)
                end
                return
            end
        else
            OrderChain.sendError("Sector %i:%i has not been discovered yet."%_T, shipX, shipY)
            return
        end
    end

    OrderChain.sendError("No wormhole found in sector %i:%i!"%_T, shipX, shipY)
end
callable(OrderChain, "addDiscoverWormholeOrder")

-- Gate button handling
function OrderChain.addFlyThroughGateOrder(x, y)
    if onClient() then
        invokeServerFunction("addFlyThroughGateOrder")
        return
    end

    if callingPlayer then
        local owner, _, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips)
        if not owner then
            local player = Player(callingPlayer)
            player:sendChatMessage("", ChatMessageType.Error, "You don't have permission to do that."%_T)
            return
        end
    end

    local shipX, shipY = Sector():getCoordinates()

    for _, action in pairs(OrderChain.chain) do
        if action.action == OrderType.Jump or action.action == OrderType.FlyThroughWormhole then
            shipX = action.x
            shipY = action.y
        end
    end

    if callingPlayer then
        local player = Player(callingPlayer)

        if x and y and (player:knowsSector(shipX, shipY) or (player.alliance and player.alliance:knowsSector(shipX, shipY))) then
            local sectorView = player:getKnownSector(shipX, shipY) or player.alliance:getKnownSector(shipX, shipY)

            local gateDestinations = {sectorView:getGateDestinations()}
            for _, dest in pairs(gateDestinations) do
                if dest.x == x and dest.y == y then
                    local order = {action = OrderType.FlyThroughWormhole, x = dest.x, y = dest.y, gate = true}
                    if OrderChain.canEnchain(order) then
                        OrderChain.enchain(order)
                    end
                    return
                end
            end
        elseif x and y then
            OrderChain.sendError("Sector %i:%i has not been discovered yet."%_T, shipX, shipY)
            return
        end

        OrderChain.sendError("Specified gate not found in sector %i:%i!"%_T, shipX, shipY)
    end
end
callable(OrderChain, "addFlyThroughGateOrder")

-- show error messages from mapcommands
callable(OrderChain, "sendError")