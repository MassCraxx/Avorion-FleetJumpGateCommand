-- Fleet Jump through Gate Command Mod by MassCraxx
-- v3

if onClient() then
function MapRoutes.makeRoute(faction, name, info, start)

    local id = name .. "_" .. tostring(faction.index)
    local route = routesByShip[id]
    if route then
        route.container:clear()
    else
        local container = routesContainer:createContainer(Rect())
        route = {container = container}
        routesByShip[id] = route
    end

    route.info = info
    route.start = start

    if not info then return end
    if not start then return end
    if not info.chain then return end
    if #info.chain == 0 then return end
    if not info.currentIndex then return end
    if info.currentIndex == 0 then return end

    -- plot routes
    local visited = {}

    local i = info.currentIndex
    local cx, cy = start.x, start.y
    while i <= #info.chain do

        if visited[i] then break end
        visited[i] = true

        local current = info.chain[i]
        if not current then break end

        if current.action == OrderType.Jump or current.action == OrderType.FlyThroughWormhole then
            local line = route.container:createMapArrowLine()
            line.from = ivec2(cx, cy)
            line.to = ivec2(current.x, current.y)
            line.color = ColorARGB(0.4, 0, 0.8, 0)
            if current.invalid then
                line.color = ColorARGB(0.4, 0.8, 0, 0)
            end
            line.width = 10

            cx, cy = current.x, current.y
        end

        if current.action == OrderType.Loop then
            i = current.loopIndex
        else
            i = i + 1
        end
    end
end

function MapRoutes.renderIcons()
    local map = GalaxyMap()
    local renderer = UIRenderer()

    for name, route in pairs(routesByShip) do
        local info = route.info
        if not info then goto continue end

        local i = info.currentIndex
        local cx, cy = route.start.x, route.start.y
        while i <= #info.chain do

            local current = info.chain[i]
            if not current then break end

            if current.action == OrderType.Jump or current.action == OrderType.FlyThroughWormhole then
                cx, cy = current.x, current.y
            end

            if current.action then
                local sx, sy = GalaxyMap():getCoordinatesScreenPosition(ivec2(cx, cy))

                local orderType = OrderTypes[current.action]
                if orderType and orderType.pixelIcon and orderType.pixelIcon ~= "" then
                    renderer:renderCenteredPixelIcon(vec2(sx, sy), ColorRGB(1, 1, 1), orderType.pixelIcon)
                end
            end

            i = i + 1
        end

        ::continue::
    end

    renderer:display()
end


function MapRoutes.getOrderDescription(order, i, line)
    if order.action == OrderType.Jump or order.action == OrderType.FlyThroughWormhole then
        line.ltext = "[${i}] Jump"%_t % {i=i}
        line.ctext = " >>> "
        line.rtext = order.x .. " : " .. order.y
    elseif order.action == OrderType.Mine then
        line.ltext = "[${i}] Mine Asteroids"%_t % {i=i}
    elseif order.action == OrderType.Salvage then
        line.ltext = "[${i}] Salvage Wreckages"%_t % {i=i}
    elseif order.action == OrderType.Loop then
        line.ltext = "[${i}] Loop"%_t % {i=i}
        line.ctext = " >>> "
        line.rtext = order.loopIndex
    elseif order.action == OrderType.Aggressive then
        line.ltext = "[${i}] Attack Enemies"%_t % {i=i}
    elseif order.action == OrderType.Patrol then
        line.ltext = "[${i}] Patrol Sector"%_t % {i=i}
    elseif order.action == OrderType.BuyGoods then
        line.ltext = "[${i}] Buy '${good}'"%_t % {i = i, good = order.args[1]}
        line.rtext = "Until ${amount} units"%_t % {amount = order.args[3]}
    elseif order.action == OrderType.SellGoods then
        line.ltext = "[${i}] Sell '${good}'"%_t % {i = i, good = order.args[1]}
        line.rtext = "Until ${amount} units"%_t % {amount = order.args[3]}
    elseif order.action == OrderType.RefineOres then
        line.ltext = "[${i}] Refine Ores"%_t % {i = i}
    end
end
end -- onClient()
