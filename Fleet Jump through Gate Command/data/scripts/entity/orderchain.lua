-- Fleet Jump through Gate Command Mod by MassCraxx
-- v5

-- Wormhole handling

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
        if player:knowsSector(shipX, shipY) or player.alliance:knowsSector(shipX, shipY) then
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

    OrderChain.sendError("No Wormhole found in Sector %i:%i!"%_T, shipX, shipY)
end
callable(OrderChain, "addDiscoverWormholeOrder")

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

        if player:knowsSector(shipX, shipY) or player.alliance:knowsSector(shipX, shipY) then
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
        else
            OrderChain.sendError("Sector %i:%i has not been discovered yet."%_T, shipX, shipY)
            return
        end
    end

    OrderChain.sendError("Gate not found in Sector %i:%i!"%_T, shipX, shipY)
end
callable(OrderChain, "addFlyThroughGateOrder")