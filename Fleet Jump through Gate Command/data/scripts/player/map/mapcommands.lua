-- Fleet Jump through Gate Command Mod by MassCraxx
-- v7

include("data/scripts/player/map/common")
include("stringutility")
include("utility")
include("goods")

-- overwrite onClient block
if onClient() then

    local lastOrderInfos = {}
    
    local OrderButtonType =
    {
        Undo = 1,
        Loop = 2,
        Patrol = 3,
        Attack = 4,
        Mine = 5,
        Salvage = 6,
        Escort = 7,
        BuyGoods = 8,
        SellGoods = 9,
        RefineOres = 10,
        Stop = 11,
        Repair = 12,
        RepairTarget = 13,
        Gate = 14,
        Wormhole = 15,
    }
    
    local orders = {}
    
    local shipsContainer
    local ordersContainer
    local craftPortraits = {}
    local playerShipPortraits = {}
    local allianceShipPortraits = {}
    local orderButtons = {}
    local shipsScrollUpButton
    local shipsScrollDownButton
    local shipsFrame
    local shipsBarIcon
    local hideOffScreenShipsCheckBox
    local showStationsCheckBox
    
    local enqueueNextOrder
    local buyWindow, sellWindow, escortWindow, repairTargetWindow
    local orderWindows = {}
    local buyCombo, sellCombo, escortCombo, repairTargetCombo
    local escortData = {}
    local repairTargetData = {}
    local preferOwnStationsCheck
    local buyFilterTextBox, sellFilterTextBox
    local buyMarginCombo, sellMarginCombo
    local buyAmountTextBox, sellAmountTextBox
    
    MapCommands.enchainCoordinates = nil
    
    local automaticChange = false
    local shipsBarScrollPosition = 0
    local shipsBarOffset = 0.0
    local shipsBarMaxCount = 10
    local shipsBarCount = 0
    local sortedCraftPortraits = {}
    local barPortraits = {}
    local lastClickedPortrait = {}
    local rectSelection = {}
    
    local barOffset = vec2(60, 60)
    local arrowHeight = 30
    local barIconHeight = 40
    local checkboxHeight = 20
    
    local portraitHeight = 60
    local portraitWidth = 120
    local padding = 10
    
    local commandPadding = 10
    local commandDiameter = 40
    
    function MapCommands.initialize()
        local player = Player()
        player:registerCallback("onShowGalaxyMap", "onShowGalaxyMap")
        player:registerCallback("onHideGalaxyMap", "onHideGalaxyMap")
        player:registerCallback("onSelectMapCoordinates", "onSelectMapCoordinates")
        player:registerCallback("onShipOrderInfoUpdated", "onPlayerShipOrderInfoChanged")
        player:registerCallback("onShipPositionUpdated", "onPlayerShipSectorChanged")
        player:registerCallback("onGalaxyMapUpdate", "onGalaxyMapUpdate")
        player:registerCallback("onGalaxyMapMouseDown", "onGalaxyMapMouseDown")
        player:registerCallback("onGalaxyMapMouseUp", "onGalaxyMapMouseUp")
        player:registerCallback("onGalaxyMapMouseMove", "onGalaxyMapMouseMove")
        player:registerCallback("onMapRenderAfterLayers", "onMapRenderAfterLayers")
    
        MapCommands.initUI()
    end
    
    function MapCommands.onScrollUp()
        shipsBarScrollPosition = shipsBarScrollPosition - 1
        if shipsBarScrollPosition < 0 then shipsBarScrollPosition = 0 end
    end
    
    function MapCommands.onScrollDown()
        shipsBarScrollPosition = shipsBarScrollPosition + 1
        local count = #barPortraits - shipsBarCount
        if count < 0 then count = 0 end
        if shipsBarScrollPosition > count then shipsBarScrollPosition = count end
    end
    
    function MapCommands.initUI()
    
        -- ships frame
        local barContainer = GalaxyMap():createContainer()
    
        local res = getResolution()
    
        local offset = vec2(res.x - portraitWidth - 2 * padding - barOffset.x, barOffset.y)
    
        local arrowUpRect, arrowDownRect = Rect(), Rect()
    
        arrowUpRect.lower = offset + vec2(padding, 3 * padding + barIconHeight + checkboxHeight)
        arrowUpRect.upper = arrowUpRect.lower + vec2(portraitWidth, arrowHeight)
        shipsScrollUpButton = barContainer:createButton(arrowUpRect, "", "onScrollUp")
        shipsScrollUpButton.icon = "data/textures/icons/arrow-up2.png"
    
        shipsBarMaxCount = math.floor((res.y - 3 * portraitHeight + 3 * padding - 2 * arrowHeight - (barIconHeight + padding + checkboxHeight)) / (portraitHeight + padding))
    
        arrowDownRect.lower = offset + vec2(padding, shipsBarMaxCount * (portraitHeight + padding) + 4 * padding + arrowHeight + barIconHeight + checkboxHeight)
        arrowDownRect.upper = arrowDownRect.lower + vec2(portraitWidth, arrowHeight)
        shipsScrollDownButton = barContainer:createButton(arrowDownRect, "", "onScrollDown")
        shipsScrollDownButton.icon = "data/textures/icons/arrow-down2.png"
    
        local shipFrameRect = Rect()
        shipFrameRect.lower = vec2(res.x - portraitWidth - 2 * padding - barOffset.x, barOffset.y)
        shipFrameRect.upper = shipFrameRect.lower + vec2(portraitWidth + 2 * padding, 3 * padding + barIconHeight + checkboxHeight)
        shipsFrame = barContainer:createFrame(shipFrameRect)
        shipsFrame.catchAllMouseInput = true
        shipsFrame.layer = shipsFrame.layer - 1 -- the frame catches all input, make sure it is below other elements
        shipsFrame.backgroundColor = ColorARGB(0.5, 0.3, 0.3, 0.3)
    
        local shipsBarIconRect = Rect()
        shipsBarIconRect.lower = offset + vec2(portraitWidth / 2 - barIconHeight + padding, padding)
        shipsBarIconRect.upper = shipsBarIconRect.lower + vec2(barIconHeight * 2, barIconHeight)
        shipsBarIcon = barContainer:createPicture(shipsBarIconRect, "data/textures/ui/fleet.png")
        shipsBarIcon.tooltip = "Ctrl-A: Select all ships in the selected sector."%_t
        shipsBarIcon.isIcon = true
    
        local showAllRect = Rect()
        showAllRect.lower = offset + vec2(portraitWidth / 2 + padding, 2 * padding + barIconHeight)
        showAllRect.upper = showAllRect.lower + vec2(portraitWidth / 2, checkboxHeight)
        hideOffScreenShipsCheckBox = barContainer:createCheckBox(showAllRect, "data/textures/icons/eye-crossed.png", "")
        hideOffScreenShipsCheckBox.tooltip = "Hide off-screen ships"%_t
        hideOffScreenShipsCheckBox.icon = true
        hideOffScreenShipsCheckBox.checked = true
    
        local showStationsRect = Rect()
        showStationsRect.lower = offset + vec2(padding, 2 * padding + barIconHeight)
        showStationsRect.upper = showStationsRect.lower + vec2(portraitWidth / 2, 20)
        showStationsCheckBox = barContainer:createCheckBox(showStationsRect, "data/textures/icons/station.png", "")
        showStationsCheckBox.tooltip = "Stations"%_t
        showStationsCheckBox.icon = true
        showStationsCheckBox.checked = true
    
        -- containers
        shipsContainer = GalaxyMap():createContainer()
        ordersContainer = GalaxyMap():createContainer()
    
        -- buttons for orders
        orderButtons = {}
        orders = {}
        table.insert(orders, {tooltip = "Undo"%_t,              icon = "data/textures/icons/undo.png",              callback = "onUndoPressed",         type = OrderButtonType.Undo})
        table.insert(orders, {tooltip = "Patrol Sector"%_t,     icon = "data/textures/icons/back-forth.png",        callback = "onPatrolPressed",       type = OrderButtonType.Patrol})
        table.insert(orders, {tooltip = "Attack Enemies"%_t,    icon = "data/textures/icons/crossed-rifles.png",    callback = "onAggressivePressed",   type = OrderButtonType.Attack})
        table.insert(orders, {tooltip = "Escort"%_t,            icon = "data/textures/icons/escort.png",            callback = "onEscortPressed",       type = OrderButtonType.Escort})
        table.insert(orders, {tooltip = "Repair"%_t,            icon = "data/textures/icons/health-normal.png",     callback = "onRepairPressed",       type = OrderButtonType.Repair})
        table.insert(orders, {tooltip = "Repair Target"%_t,     icon = "data/textures/icons/repair-target.png",     callback = "onRepairTargetPressed", type = OrderButtonType.RepairTarget})
        table.insert(orders, {tooltip = "Mine"%_t,              icon = "data/textures/icons/mining.png",            callback = "onMinePressed",         type = OrderButtonType.Mine})
        table.insert(orders, {tooltip = "Salvage"%_t,           icon = "data/textures/icons/scrap-metal.png",       callback = "onSalvagePressed",      type = OrderButtonType.Salvage})
        table.insert(orders, {tooltip = "Refine Ores"%_t,       icon = "data/textures/icons/metal-bar.png",         callback = "onRefineOresPressed",   type = OrderButtonType.RefineOres})
        table.insert(orders, {tooltip = "Buy Goods"%_t,         icon = "data/textures/icons/bag.png",               callback = "onBuyGoodsPressed",     type = OrderButtonType.BuyGoods})
        table.insert(orders, {tooltip = "Sell Goods"%_t,        icon = "data/textures/icons/sell.png",              callback = "onSellGoodsPressed",    type = OrderButtonType.SellGoods})
        table.insert(orders, {tooltip = "Loop"%_t,              icon = "data/textures/icons/loop.png",              callback = "onLoopPressed",         type = OrderButtonType.Loop})
        table.insert(orders, {tooltip = "Stop"%_t,              icon = "data/textures/icons/halt.png",              callback = "onStopPressed",         type = OrderButtonType.Stop})
    
        for i, order in pairs(orders) do
            local button = ordersContainer:createRoundButton(Rect(), order.icon, order.callback)
            button.tooltip = order.tooltip
    
            table.insert(orderButtons, button)
        end
    
        local res = getResolution()
        local size = vec2(600, 170)
        local unmatchable = "%+/#$@?{}[]><()"
    
        -- windows for choosing goods
        -- selling
        sellWindow = GalaxyMap():createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
        sellWindow.caption = "Sell Goods /* Order Window Caption Galaxy Map */"%_t
    
        local hsplit = UIHorizontalMultiSplitter(Rect(sellWindow.size), 10, 10, 3)
        local vsplit = UIVerticalMultiSplitter(hsplit.top, 10, 0, 1)
    
        sellCombo = sellWindow:createValueComboBox(vsplit.left, "")
    
        sellFilterTextBox = sellWindow:createTextBox(vsplit.right, "onSellFilterTextChanged")
        sellFilterTextBox.backgroundText = "Filter /* Filter Goods */"%_t
        sellFilterTextBox.forbiddenCharacters = unmatchable
        sellFilterTextBox.backgroundIcon = "data/textures/icons/magnifying_glass.png"
    
        local vsplit = UIVerticalSplitter(hsplit:partition(1), 10, 0, 0.7)
        sellWindow:createLabel(vsplit.left, "Amount to remain on ship: "%_t, 14)
    
        sellAmountTextBox = sellWindow:createTextBox(vsplit.right, "")
        sellAmountTextBox.backgroundText = "Amount /* of goods to buy */"%_t
    
        local vsplit = UIVerticalSplitter(hsplit:partition(2), 10, 0, 0.7)
        sellWindow:createLabel(vsplit.left, "Sell for at least X% of average price:"%_t, 14)
        sellMarginCombo = sellWindow:createValueComboBox(vsplit.right, "")
    
        local vsplit = UIVerticalSplitter(hsplit.bottom, 10, 0, 0.5)
        preferOwnStationsCheck = sellWindow:createCheckBox(vsplit.left, "Prefer Own Stations /* Checkbox caption for ship behavior */"%_t, "")
        preferOwnStationsCheck.captionLeft = false
        preferOwnStationsCheck.tooltip = "If checked, the ship will prefer your own stations for delivering the goods."%_t
    
        sellWindow:createButton(vsplit.right, "Sell /* Start sell order button caption */"%_t, "onSellWindowOKButtonPressed")
    
    
        -- buying
        buyWindow = GalaxyMap():createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
        buyWindow.caption = "Buy Goods /* Order Window Caption Galaxy Map */"%_t
    
        local hsplit = UIHorizontalMultiSplitter(Rect(buyWindow.size), 10, 10, 3)
        local vsplit = UIVerticalMultiSplitter(hsplit.top, 10, 0, 1)
    
        buyCombo = buyWindow:createValueComboBox(vsplit.left, "")
    
        buyFilterTextBox = buyWindow:createTextBox(vsplit.right, "onBuyFilterTextChanged")
        buyFilterTextBox.backgroundText = "Filter /* Filter Goods */"%_t
        buyFilterTextBox.forbiddenCharacters = unmatchable
        buyFilterTextBox.backgroundIcon = "data/textures/icons/magnifying_glass.png"
    
        local vsplit = UIVerticalSplitter(hsplit:partition(1), 10, 0, 0.7)
        buyWindow:createLabel(vsplit.left, "Amount to have on ship:"%_t, 14)
    
        buyAmountTextBox = buyWindow:createTextBox(vsplit.right, "")
        buyAmountTextBox.backgroundText = "Amount /* of goods to buy */"%_t
    
        local vsplit = UIVerticalSplitter(hsplit:partition(2), 10, 0, 0.7)
        buyWindow:createLabel(vsplit.left, "Buy for at least X% of average price:"%_t, 14)
        buyMarginCombo = buyWindow:createValueComboBox(vsplit.right, "")
    
        local vsplit = UIVerticalSplitter(hsplit.bottom, 10, 0, 0.5)
        buyWindow:createButton(vsplit.right, "Buy /* Start buy order button caption */"%_t, "onBuyWindowOKButtonPressed")
    
    
        -- both
        for _, combo in pairs({buyMarginCombo, sellMarginCombo}) do
            combo:addEntry(false, "Any"%_t)
            for i = 50, 150, 5 do
                combo:addEntry(i / 100, string.format("%i %%", i))
            end
        end
    
        -- escort window
        local escortSize = vec2(550, 50)
        escortWindow = GalaxyMap():createWindow(Rect(res * 0.5 - escortSize * 0.5, res * 0.5 + escortSize * 0.5))
        escortWindow.caption = "Escort Craft /* Order Window Caption Galaxy Map */"%_t
    
        local vsplit = UIVerticalSplitter(Rect(escortWindow.size), 10, 10, 0.6)
        escortCombo = escortWindow:createValueComboBox(vsplit.left, "")
        escortWindow:createButton(vsplit.right, "Escort /* Start escort order button caption */"%_t, "onEscortWindowOKButtonPressed")
    
        -- repair target window
        local repairTargetSize = escortSize
        repairTargetWindow = GalaxyMap():createWindow(Rect(res * 0.5 - repairTargetSize * 0.5, res * 0.5 + repairTargetSize * 0.5))
        repairTargetWindow.caption = "Repair Target /* Order Window Caption Galaxy Map */"%_t
    
        local vsplit = UIVerticalSplitter(Rect(repairTargetWindow.size), 10, 10, 0.6)
        repairTargetCombo = repairTargetWindow:createValueComboBox(vsplit.left, "")
        repairTargetWindow:createButton(vsplit.right, "Repair /* Start repair order button caption */"%_t, "onRepairTargetWindowOKButtonPressed")
    
    
        -- all windows
        for _, window in pairs({buyWindow, sellWindow, escortWindow, repairTargetWindow}) do
            table.insert(orderWindows, window)
    
            window.showCloseButton = 1
            window.moveable = 1
            window:hide()
        end

        MapCommands.initUI_FJTGC()
    end
    
    function MapCommands.onGalaxyMapKeyboardEvent(key, pressed)
        if key == KeyboardKey.LShift or key == KeyboardKey.RShift then
            shipsBarOffset = shipsBarOffset - shipsBarScrollPosition
            MapCommands.updateButtons(true)
        end
    
        if not pressed and (key == KeyboardKey.LShift or key == KeyboardKey.RShift) and not MapCommands.isEnqueueing() then
            MapCommands.runOrders()
        end
    
        if pressed and key == KeyboardKey._A then
            local shift = Keyboard().shiftPressed
            if Keyboard().controlPressed then
                for _, portrait in pairs(MapCommands.filterPortraits{inside = true}) do
                    portrait.portrait.selected = not shift
                end
            end
        end
    
        if pressed and key == KeyboardKey._F then
            for _, portrait in pairs(MapCommands.filterPortraits{selected = true}) do
                if portrait.coordinates then
                    local galaxyMap = GalaxyMap()
                    automaticChange = true
                    galaxyMap:setSelectedCoordinates(portrait.coordinates.x, portrait.coordinates.y)
                    galaxyMap:lookAtSmooth(portrait.coordinates.x, portrait.coordinates.y)
                    break
                end
            end
        end
    end
    
    function MapCommands.updateButtons(sort)
        -- early return when no portraits exist
        if #craftPortraits == 0 then
            MapCommands.hideOrderButtons()
            shipsScrollUpButton.visible = false
            shipsScrollDownButton.visible = false
            return
        end
    
        MapCommands.enchainCoordinates = nil
    
        local enqueueing = MapCommands.isEnqueueing()
        local sx, sy = GalaxyMap():getSelectedCoordinatesScreenPosition()
        local cx, cy = GalaxyMap():getSelectedCoordinates()
    
        local selected, unselected = MapCommands.filterPortraits{selected = true}
        local sectorPortraits, otherPortraits = MapCommands.filterPortraits{inside = true}
    
        -- mark portraits in sector
        for _, portrait in pairs(sectorPortraits) do
            portrait.portrait.inSector = true
        end
    
        for _, portrait in pairs(otherPortraits) do
            portrait.portrait.inSector = false
        end
    
        local showCommandButtons = true
        if #MapCommands.filterPortraits{portraits = selected, selected = true} == 0 then
            showCommandButtons = false
        end
    
        if #selected > 0 and enqueueing then
            local x, y = MapCommands.getLastLocationFromInfo(selected[1].info)
            if x and y then
                sx, sy = GalaxyMap():getCoordinatesScreenPosition(ivec2(x, y))
                cx, cy = x, y
                MapCommands.enchainCoordinates = {x=x, y=y}
            else
                MapCommands.enchainCoordinates = {x=cx, y=cy}
            end
        end
    
        if sort then
            local hiddenPortraits
    
            if #selected > 0 and enqueueing then
                sortedCraftPortraits = selected
                hiddenPortraits = unselected
            else
                sortedCraftPortraits = craftPortraits
                hiddenPortraits = {}
            end
    
            -- portrait locations
    
            for _, portrait in pairs(hiddenPortraits) do
                if portrait.portrait.index ~= lastClickedPortrait.index then
                    portrait.portrait:hide()
                    portrait.icon:hide()
                    portrait.line:hide()
                end
            end
    
            function joinArrays (into, from)
                for i=1,#from do
                    into[#into+1] = from[i]
                end
            end
    
            shipsBarScrollPosition = 0
    
            local selectedX, selectedY = GalaxyMap():getSelectedCoordinates()
    
            -- sort by distance to selected sector
    --        table.sort(sortedCraftPortraits, function(a, b)
    --            local aX, aY = a.coordinates.x - selectedX, a.coordinates.y - selectedY
    --            local aDistance = aX * aX + aY * aY
    --            local bX, bY = b.coordinates.x - selectedX, b.coordinates.y - selectedY
    --            local bDistance = bX * bX + bY * bY
    --            if aDistance ~= bDistance then
    --                return aDistance < bDistance
    --            else
    --                if a.portrait.selected and not b.portrait.selected then
    --                    return true
    --                else
    --                    return false
    --                end
    --            end
    --        end)
    
            -- sort by name with ships in current sector at the top
            table.sort(sortedCraftPortraits, function(a, b)
                local aInside = MapCommands.isPortraitInCurrentSector(a)
                local bInside = MapCommands.isPortraitInCurrentSector(b)
                if aInside and not bInside then
                    return true
                elseif not aInside and bInside then
                    return false
                else
                    return a.name < b.name
                end
            end)
        end
    
        local right, bottom = getResolution().x, getResolution().y
    
        -- tooltip lines
        local inSectorLine = "In Selected Sector"%_t
        local notVisibleLine = "Not on Screen"%_t
        local showAllShips = not hideOffScreenShipsCheckBox.checked
        local showStations = showStationsCheckBox.checked
    
        local filteredCraftPortraits = sortedCraftPortraits
        if not showStations then
            filteredCraftPortraits = {}
            for _, portrait in pairs(sortedCraftPortraits) do
                local name = portrait.name
                local player = Player()
                local type
    
                if portrait.alliance and player.alliance then
                    type = player.alliance:getShipType(name)
                else
                    type = player:getShipType(name)
                end
    
                if type ~= EntityType.Station then
                    table.insert(filteredCraftPortraits, portrait)
                else
                    portrait.portrait:hide()
                    portrait.icon:hide()
                    portrait.line:hide()
                end
            end
        end
    
        if showAllShips then
            barPortraits = filteredCraftPortraits
        else
            -- only list ships that are on screen
            barPortraits = {}
            for _, portrait in pairs(filteredCraftPortraits) do
                local sx, sy = GalaxyMap():getCoordinatesScreenPosition(ivec2(portrait.coordinates.x, portrait.coordinates.y))
                if portrait.portrait.selected or (0 < sx and  sx < right and 0 < sy and sy < bottom) or portrait.portrait.index == lastClickedPortrait.index then
                    table.insert(barPortraits, portrait)
                else
                    portrait.portrait:hide()
                    portrait.icon:hide()
                    portrait.line:hide()
                end
            end
        end
    
        -- refresh tooltips and ship name colors (not on screen -> grey)
        for _, portrait in pairs(barPortraits) do
            local sx, sy = GalaxyMap():getCoordinatesScreenPosition(ivec2(portrait.coordinates.x, portrait.coordinates.y))
            if 0 < sx and  sx < right and 0 < sy and sy < bottom then
                portrait.portrait.fontColor = ColorRGB(1, 1, 1)
    
                if portrait.portrait.inSector then
                    portrait.portrait.tooltip = inSectorLine
                else
                    portrait.portrait.tooltip = nil
                end
            else
                portrait.portrait.fontColor = ColorRGB(0.5, 0.5, 0.5)
    
                if portrait.portrait.inSector then
                    portrait.portrait.tooltip = inSectorLine .. "\n" .. notVisibleLine
                else
                    portrait.portrait.tooltip = notVisibleLine
                end
            end
        end
    
        if shipsBarScrollPosition > #barPortraits - shipsBarCount then
            shipsBarScrollPosition = math.max(#barPortraits - shipsBarCount, 0)
        elseif shipsBarScrollPosition < 0 then
            shipsBarScrollPosition = 0
        end
    
        shipsBarCount = math.min(#barPortraits, shipsBarMaxCount)
    
        local offset = vec2(right - portraitWidth - barOffset.x - padding, barOffset.y - portraitHeight + barIconHeight + 2 * padding + checkboxHeight)
    
        local shipScrollButtonsVisible = #barPortraits > shipsBarCount
        shipsScrollUpButton.visible = shipScrollButtonsVisible
        shipsScrollDownButton.visible = shipScrollButtonsVisible
        if shipScrollButtonsVisible then
            shipsScrollUpButton.active = shipsBarScrollPosition ~= 0
            shipsScrollDownButton.active =  shipsBarScrollPosition < #barPortraits - shipsBarCount
        end
    
        local shipFrameRect = Rect()
    
        shipFrameRect.lower = vec2(right - portraitWidth - 2 * padding - barOffset.x, barOffset.y)
        shipFrameRect.upper = shipFrameRect.lower + vec2(portraitWidth + 2 * padding, shipsBarCount * (portraitHeight + padding) + 3 * padding + barIconHeight + checkboxHeight)
    
        if #barPortraits > shipsBarMaxCount then
            shipFrameRect.upper = shipFrameRect.upper + vec2(0, (arrowHeight + padding) * 2)
            offset.y = offset.y + arrowHeight + padding
        end
    
        shipsFrame.rect = shipFrameRect
    
        -- parameters of ship shrinking near top and bottom border of sidebar:
    
        -- the number of ship portraits displayed additionally when portraits are small
        -- fractions are allowed
        local additionalSmallCount = 0.9
        -- the maximum number of ships which can be displayed in smaller size
        -- should be larger than additionalSmallCount
        -- fractions are allowed
        local smallCount = 3
    
        for i, portrait in pairs(barPortraits) do
            -- calculate the ship index as shown in the bar
            local shipIndex = i - shipsBarOffset
            if shipIndex < -additionalSmallCount or shipIndex > shipsBarCount + additionalSmallCount + 1 then
                portrait.portrait:hide()
                portrait.icon:hide()
                portrait.line:hide()
                goto continue
            end
    
            local scale = 1.0
            local borderMin, borderMax, shipsBarBorderOffset
    
            if shipIndex < smallCount - additionalSmallCount + 1 then
                scale = (shipIndex + additionalSmallCount) / (smallCount + 1)
                shipsBarBorderOffset = shipsBarOffset
                borderMin, borderMax = 0.5, smallCount - additionalSmallCount + 1
            else
                -- same as shipIndex, but counted from bottom to top
                local shipBackIndex = shipsBarCount + 1 - shipIndex
                if shipBackIndex < smallCount - additionalSmallCount + 1 then
                    scale = (shipBackIndex + additionalSmallCount) / (smallCount + 1)
                    shipsBarBorderOffset = #barPortraits - shipsBarOffset - shipsBarCount
                    borderMin, borderMax = shipsBarCount + 0.5, shipsBarCount - smallCount + additionalSmallCount
                end
            end
    
            -- if scale smaller one, change ship index, which is used for offset
            if scale < 1.0 then
                -- square the scale for offset to avoid overlap
                local scaleOffset = scale * scale
                local offsetShipIndex = (1 - scaleOffset) * borderMin + scaleOffset * borderMax
    
                -- when there are no more ships above or below, show ships on top or bottom border in full size without offset
                if shipsBarBorderOffset and shipsBarBorderOffset < additionalSmallCount then
                    -- this factor is used to blend between the default position and the shrink position
                    local offsetFactor = 1 - shipsBarBorderOffset / additionalSmallCount
                    -- this makes the growing and shrinking at the beginning smoother
                    -- it's also necessary to ensure the portraits do not intersect the scrolling arrows
                    offsetFactor = 1 - offsetFactor * offsetFactor
                    scale = scale * offsetFactor + (1 - offsetFactor)
                    shipIndex = shipIndex * (1 - offsetFactor) + offsetShipIndex * offsetFactor
                else
                    shipIndex = offsetShipIndex
                end
            end
    
            local rect = Rect()
            local fullsize = vec2(portraitWidth, portraitHeight)
            local size = fullsize * vec2(1, scale)
    
            -- offset the portrait, so the scaling appears to be from center
            local sizeDelta = (fullsize - size) / 2
            rect.lower = vec2(0, shipIndex * (portraitHeight + padding)) + offset + sizeDelta
            rect.upper = rect.lower + size
            portrait.portrait.rect = rect
            portrait.portrait.fontSize = 14 * scale
            portrait.portrait:show()
            portrait.line:show()
    
            if portrait.picture and portrait.picture ~= "" then
                portrait.icon.rect = Rect(rect.topRight - vec2(8, 8), rect.topRight + vec2(8, 8))
                portrait.icon:show()
                portrait.icon.picture = portrait.picture
            else
                portrait.icon:hide()
            end
    
            ::continue::
        end
    
        -- command buttons
        if showCommandButtons then
            local visibleButtons = {}
            for i, button in pairs(orderButtons) do
                local add = true
    
                if orders[i].type == OrderButtonType.Stop then
                    if MapCommands.isEnqueueing() then
                        -- cannot enqueue a "stop"
                        add = false
                    end
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
    
            local offset = vec2(right - portraitWidth - 3 * padding - barOffset.x - commandDiameter - commandPadding, barOffset.y)
    
            for i, button in pairs(visibleButtons) do
                local rect = Rect()
                rect.lower = vec2(0, i * (commandDiameter + commandPadding)) + offset
                rect.upper = rect.lower + vec2(commandDiameter, commandDiameter)
                button.rect = rect
    
                button:show()
            end
        else
            MapCommands.hideOrderButtons()
        end
    end
    
    function MapCommands.updateTransitArea()
        local portraits = MapCommands.filterPortraits{selected = true}
        if #portraits == 0 then
            GalaxyMap():resetTransitArea()
            return
        end
    
        local player = Player()
        local alliance = player.alliance
    
        local reach = 10000
        local canPassRifts = true
        local x, y
        for _, portrait in pairs(portraits) do
            local shipReach
    
            x = portrait.coordinates.x
            y = portrait.coordinates.y
    
            if portrait.owner == player.index then
                shipReach = player:getShipHyperspaceReach(portrait.name)
                canPassRifts = canPassRifts and player:getShipCanPassRifts(portrait.name)
            elseif alliance then
                shipReach = alliance:getShipHyperspaceReach(portrait.name)
                canPassRifts = canPassRifts and alliance:getShipCanPassRifts(portrait.name)
            end
    
    --        print("shipreach: " .. tostring(shipReach))
    
            if shipReach and shipReach > 0 then
                reach = math.min(reach, shipReach)
            end
        end
    
    --    print("coords: (" .. x .. ", " .. y .. "), reach: " .. reach)
    
        if reach == 10000 then return end
    
        local map = GalaxyMap()
    --    local x, y = map:getSelectedCoordinates()
    
        -- while enqueueing, move transit area to the location that we'll be jumping from
        if MapCommands.isEnqueueing() then
            local selected = MapCommands.filterPortraits{selected = true}
            if #selected > 0 then
                local ix, iy = MapCommands.getLastLocationFromInfo(selected[1].info)
                if ix and iy then
                    x, y = ix, iy
                end
            end
        end
    
        map:setTransitArea(ivec2(x, y), reach, canPassRifts)
    end
    
    local selectedPortraits = {}
    
    function MapCommands.isSelected(id)
        if selectedPortraits[id] then
            return true
        else
            return false
        end
    end
    
    function MapCommands.updateSelectedPortraits()
        for _, portrait in pairs(craftPortraits) do
            local id = portrait.name .. "_" .. tostring(portrait.owner)
            if portrait.portrait.selected then
                if not selectedPortraits[id] then
                    MapRoutes.onPortraitSelectionChanged(portrait, true)
                    selectedPortraits[id] = true
                end
            else
                if selectedPortraits[id] then
                    MapRoutes.onPortraitSelectionChanged(portrait, false)
                    selectedPortraits[id] = nil
                end
            end
        end
    end
    
    function MapCommands.updateLines()
    
        local galaxyMap = GalaxyMap()
        local selected = {}
        local hovered = {}
        selected.x, selected.y = galaxyMap:getSelectedCoordinates()
        hovered.x, hovered.y = galaxyMap:getHoveredCoordinates()
    
        for _, portrait in pairs(craftPortraits) do
            local id = portrait.name .. "_" .. tostring(portrait.owner)
    
            local sx, sy = galaxyMap:getCoordinatesScreenPosition(ivec2(portrait.coordinates.x, portrait.coordinates.y))
    
            portrait.line.dynamic = true
            portrait.line.from = vec2(sx, sy)
            portrait.line.to = portrait.portrait.lower + vec2(0, portrait.portrait.size.y * 0.5)
    
            local lineColor = ColorARGB(0.2, 0.3, 0.3, 0.3)
            local frameColor = ColorRGB(0.3, 0.3, 0.3)
    
            if portrait.portrait.mouseOver or (portrait.coordinates.x == hovered.x and portrait.coordinates.y == hovered.y) then
                lineColor = ColorARGB(0.2, 1, 1, 1)
                frameColor = ColorRGB(0.5, 0.5, 0.5)
            end
    
            if portrait.coordinates.x == selected.x and portrait.coordinates.y == selected.y then
                lineColor = ColorARGB(0.2, 1, 1, 1)
            end
    
            if portrait.portrait.selected then
                lineColor = ColorARGB(0.5, 1, 1, 1)
            end
    
            portrait.line.color = lineColor
            portrait.portrait.frameColor = frameColor
        end
    
    end
    
    function MapCommands.hideOrderButtons()
        for _, button in pairs(orderButtons) do
            button:hide()
        end
    
        for _, window in pairs(orderWindows) do
            window:hide()
        end

        MapCommands.hideOrderButtons_FJTGC()
    end
    
    function MapCommands.makePortrait(faction, name)
        local portrait = shipsContainer:createCraftPortrait(Rect(), "onPortraitPressed")
        portrait.craftName = name
        portrait.alliance = faction.isAlliance
    
        local icon = shipsContainer:createPicture(Rect(), "")
        icon.flipped = true
        icon.isIcon = true
        icon:hide()
    
        local line = shipsContainer:createLine(vec2(), vec2())
    
        local info = faction:getShipOrderInfo(name)
        local portraitWrapper = {portrait = portrait, info = info, icon = icon, line = line, name = name, owner = faction.index, picture = MapCommands.getActionIconFromInfo(info)}
    
        table.insert(craftPortraits, portraitWrapper)
    
        return portraitWrapper
    end
    
    function MapCommands.getPortrait(faction, name)
        if faction.isPlayer then
            if not playerShipPortraits[name] then
                playerShipPortraits[name] = MapCommands.makePortrait(faction, name)
            end
            return playerShipPortraits[name]
        else
            if not allianceShipPortraits[name] then
                allianceShipPortraits[name] = MapCommands.makePortrait(faction, name)
            end
            return allianceShipPortraits[name]
        end
    end
    
    function MapCommands.makePortraits(faction)
        if not valid(faction) then return end
    
        for i, name in pairs({faction:getShipNames()}) do
            if not faction:getShipDestroyed(name) then
                local portraitWrapper = MapCommands.getPortrait(faction, name)
                local x, y = faction:getShipPosition(name)
                portraitWrapper.coordinates = {x=x, y=y}
            end
        end
    end
    
    function MapCommands.isPortraitInCurrentSector(portraitWrapper)
        -- if coordinates have not been set yet, it's not in the current sector
        if not portraitWrapper.coordinates then return false end
    
        local selectedX, selectedY = GalaxyMap():getSelectedCoordinates()
        return (portraitWrapper.coordinates.x == selectedX and portraitWrapper.coordinates.y == selectedY)
    end
    
    function MapCommands.isEnqueueing()
        return Keyboard():keyPressed(KeyboardKey.LShift) or Keyboard():keyPressed(KeyboardKey.RShift)
    end
    
    function MapCommands.onSelectMapCoordinates(x, y)
        -- only execute when sector has been changed by player directly
        if automaticChange then
            automaticChange = false
            return
        end
    
        for _, portrait in pairs(craftPortraits) do
            portrait.portrait.selected = false
        end
    
        if MapCommands.isEnqueueing() then
            for _, portrait in pairs(MapCommands.filterPortraits{inside = true}) do
                portrait.portrait.selected = true
            end
        end
    
        MapCommands.updateButtons(true)
    end
    
    function MapCommands.playOrderChainSound(name, info)
        -- remember last order index of each ship
        -- we must distinguish between 3 cases:
        -- * info.currentIndex increases (ie. a new order was selected, but not added) -> no sound
        -- * info.currentIndex remains the same, but length changes (ie. a new order was added) -> play sound
        -- * info.currentIndex remains the same, and number of orders is 1 (ie. a new order was added, after there were no orders (ie. first order)) -> play sound
        local lastOrderInfo = lastOrderInfos[name] or {chain = {}}
        lastOrderInfos[name] = info
    
        -- don't play a sound when orders are reset
        -- this avoids double playing as when not enchaining, orders are usually first reset and then reassigned
        if #info.chain == 0 then return end
    
        local numOrdersChanged = #info.chain ~= #lastOrderInfo.chain
        local chainResetOrFirstOrder = (#info.chain == 1 and nextIndex == 1)
    
        local nextIndex = info.currentIndex
    
        if chainResetOrFirstOrder or numOrdersChanged then
            for _, portrait in pairs(craftPortraits) do
                if portrait.name == name and portrait.portrait.selected then
                    playSound("interface/confirm_order", 1, 0.35)
                    break
                end
            end
        end
    
    end
    
    
    function MapCommands.onPlayerShipOrderInfoChanged(name, info)
        -- update UI depending on new order info
        local portrait = playerShipPortraits[name]
        if portrait then
            portrait.info = info
    
            local current = info.chain[info.currentIndex]
            if current and current.icon then
                portrait.picture = current.icon
            else
                portrait.picture = nil
            end
        end
    
        MapCommands.playOrderChainSound(name, info)
    end
    
    function MapCommands.onAllianceShipOrderInfoChanged(name, info)
        -- update UI depending on new order info
        local portrait = allianceShipPortraits[name]
        if portrait then
            portrait.info = info
    
            local current = info.chain[info.currentIndex]
            if current and current.icon then
                portrait.picture = current.icon
            else
                portrait.picture = nil
            end
        end
    
        MapCommands.playOrderChainSound(name, info)
    end
    
    function MapCommands.onShipSectorChanged(portraitWrapper, x, y)
        -- if one of the moved ships is in the selected sector, update the sector
        portraitWrapper.coordinates = {x=x, y=y}
    
        if portraitWrapper.portrait.selected and MapCommands.isPortraitInCurrentSector(portraitWrapper) then
            automaticChange = true
            GalaxyMap():setSelectedCoordinates(x, y)
        end
    end
    
    function MapCommands.onPlayerShipSectorChanged(name, x, y)
        if playerShipPortraits[name] then
            MapCommands.onShipSectorChanged(playerShipPortraits[name], x, y)
        end
    end
    
    function MapCommands.onAllianceShipSectorChanged(name, x, y)
        if allianceShipPortraits[name] then
            MapCommands.onShipSectorChanged(allianceShipPortraits[name], x, y)
        end
    end
    
    function MapCommands.onGalaxyMapMouseDown(button, mx, my, cx, cy)
    
        if button == MouseButton.Right and #MapCommands.filterPortraits{selected = true} > 0 then
            -- consume right click if at least one craft is selected to prevent opening the context menu
            return true
        end
    
        if button == MouseButton.Left then
            rectSelection = {mouseStart = {x = mx, y = my}, sectorStart = {x = cx, y = cy}}
        end
    
        return false
    end
    
    function MapCommands.onGalaxyMapMouseUp(button, mx, my, cx, cy, mapMoved)
    
        if button == MouseButton.Right
                and #MapCommands.filterPortraits{selected = true} > 0
                and not mapMoved then
    
            MapCommands.enqueueJump(cx, cy)
            return true
        end
    
        if button == MouseButton.Left and rectSelection.mouseStart ~= nil then
            if math.abs(rectSelection.mouseStart.x - mx) > 1 or math.abs(rectSelection.mouseStart.y - my) > 1 then
                MapCommands.selectCraftsInRect(rectSelection.sectorStart.x, rectSelection.sectorStart.y, cx, cy)
                rectSelection = {}
                return true
            end
    
            rectSelection = {}
        end
    
        return false
    end
    
    function MapCommands.onGalaxyMapMouseMove(mx, my, dx, dy, dz)
        if shipsFrame.mouseOver and dz ~= 0 then
            shipsBarScrollPosition = shipsBarScrollPosition - dz
            return true
        end
    
        return false
    end
    
    function MapCommands.onMapRenderAfterLayers()
        if rectSelection.mouseStart == nil then return end
    
        local renderer = UIRenderer()
        renderer:renderBorder(vec2(rectSelection.mouseStart.x, rectSelection.mouseStart.y), Mouse().position, ColorRGB(1, 1, 1), 0)
        renderer:display()
    end
    
    function MapCommands.selectCraftsInRect(lowerX, lowerY, upperX, upperY)
        if lowerX > upperX then
            lowerX, upperX = upperX, lowerX
        end
    
        if lowerY > upperY then
            lowerY, upperY = upperY, lowerY
        end
    
        for _, portrait in pairs(craftPortraits) do
            if portrait.coordinates.x >= lowerX and portrait.coordinates.x <= upperX and portrait.coordinates.y >= lowerY and portrait.coordinates.y <= upperY then
                portrait.portrait.selected = true
            else
                portrait.portrait.selected = false
            end
        end
    end
    
    function MapCommands.onPortraitPressed(pressedPortrait)
        if lastClickedPortrait.index == pressedPortrait.index then
            for _, portrait in pairs(craftPortraits) do
                if portrait.portrait.index == pressedPortrait.index and portrait.coordinates then
                    local galaxyMap = GalaxyMap()
                    automaticChange = true
                    galaxyMap:setSelectedCoordinates(portrait.coordinates.x, portrait.coordinates.y)
                    galaxyMap:lookAtSmooth(portrait.coordinates.x, portrait.coordinates.y)
    
                    pressedPortrait.selected = true
    
                    -- reset doubleclick timer
                    lastClickedPortrait = {}
                    return
                end
            end
        else
            -- start doubleclick timer
            lastClickedPortrait = {index = pressedPortrait.index, time = 0}
        end
    
        local otherPortraitsSelected = false
        if not Keyboard().controlPressed then
            -- deselect all portraits
            for _, portrait in pairs(MapCommands.filterPortraits{selected = true}) do
                if portrait.portrait.index ~= pressedPortrait.index then
                    portrait.portrait.selected = false
                    otherPortraitsSelected = true
                end
            end
        end
    
        if otherPortraitsSelected then
            pressedPortrait.selected = true
        else
            pressedPortrait.selected = not pressedPortrait.selected
        end
    end
    
    function MapCommands.onGalaxyMapUpdate(timeStep)
        local relativeOffset = (shipsBarScrollPosition - shipsBarOffset)
        if relativeOffset < 0 then
            relativeOffset = -math.sqrt(-relativeOffset)
        else
            relativeOffset = math.sqrt(relativeOffset)
        end
    
        if math.abs(relativeOffset) < timeStep * 10 then
            shipsBarOffset = shipsBarScrollPosition
        else
            shipsBarOffset = shipsBarOffset + relativeOffset * timeStep * 10
        end
    
        MapCommands.updateDoubleClickTimer(timeStep)
        MapCommands.updateButtons()
        MapCommands.updateTransitArea()
        MapCommands.updateSelectedPortraits()
        MapCommands.updateLines()
        MapCommands.updateNotificationsVisible()
    
    end
    
    function MapCommands.updateNotificationsVisible()
    
        local left = shipsFrame.rect.lower.x
        local right = shipsFrame.rect.upper.x
        local bottom = shipsFrame.rect.lower.y
        local top = shipsFrame.rect.upper.y
    
        for i, button in pairs(orderButtons) do
            if button.visible then
                left = math.min(left, button.rect.lower.x)
            end
        end
    
        left = left - 40
        top = top + 40
    
        local mouse = Mouse().position
        local inArea = mouse.x > left and mouse.x < right
                        and mouse.y < top and mouse.y > bottom
    
        Hud().notificationsVisible = not inArea
    end
    
    function MapCommands.updateDoubleClickTimer(timeStep)
        if lastClickedPortrait.time == nil then return end
    
        lastClickedPortrait.time = lastClickedPortrait.time + timeStep
        if lastClickedPortrait.time > 0.5 then
            lastClickedPortrait = {}
        end
    end
    
    function MapCommands.fillTradeCombo(combo, filter)
        combo:clear()
    
        local values = {}
        local highlighted = {}
    
        if filter and filter ~= "" then
            for _, good in pairs(goods) do
                local displayName = good:good():displayName(1)
                if not string.match(string.lower(displayName), filter) then
                    goto continue
                end
    
                table.insert(values, {name = good.name, displayName = displayName})
    
                ::continue::
            end
        else
            -- add all goods that are on board of the selected crafts
            local selected = MapCommands.filterPortraits{selected = true}
            for _, portrait in pairs(selected) do
                local cargos
                if portrait.alliance then
                    cargos = Alliance(portrait.owner):getShipCargos(portrait.name)
                else
                    cargos = Player(portrait.owner):getShipCargos(portrait.name)
                end
    
                for good, amount in pairs(cargos) do
                    table.insert(highlighted, {name = good.name, displayName = good:displayName(1)})
                end
            end
    
            -- no filter for normal goods: add all
            for _, good in pairs(goods) do
                table.insert(values, {name = good.name, displayName = good:good():displayName(1)})
            end
        end
    
        -- sort goods by name
        table.sort(highlighted, function(a, b) return a.displayName < b.displayName end)
        table.sort(values, function(a, b) return a.displayName < b.displayName end)
    
        -- add goods to the combo box
        if #highlighted > 0 then
            for _, v in pairs(highlighted) do
                combo:addEntry(v.name, v.displayName)
            end
    
            if #values > 0 then
                combo:addEntry("", "-------------")
            end
        end
    
        for _, v in pairs(values) do
            combo:addEntry(v.name, v.displayName)
        end
    end
    
    function MapCommands.fillTargetCombo(comboBox)
        comboBox:clear()
        local comboData = {}
    
        local x, y = GalaxyMap():getSelectedCoordinates()
        local player = Player()
        local portraits = MapCommands.filterPortraits{selected = true}
    
        MapCommands.addComboEntries(comboBox, comboData, player, portraits, player.index, {player:getNamesOfShipsInSector(x, y)}, ColorRGB(0.875, 0.875, 0.875))
    
        if player.alliance then
            MapCommands.addComboEntries(comboBox, comboData, player, portraits, player.allianceIndex, {player.alliance:getNamesOfShipsInSector(x, y)}, ColorRGB(1, 0, 1))
        end
    
        return comboData
    end
    
    function MapCommands.addComboEntries(comboBox, comboData, player, portraits, factionIndex, crafts, color)
        for _, name in pairs(crafts) do
            local canAdd = true
            for _, portrait in pairs(portraits) do
                if portrait.owner == factionIndex and portrait.name == name then
                    canAdd = false
                end
            end
    
            if canAdd then
                local line = name
                local type
                if factionIndex == player.index then
                    type = player:getShipType(name)
                elseif factionIndex == player.allianceIndex then
                    type = player.alliance:getShipType(name)
                end
    
                if type == EntityType.Ship then
                    line = string.format("%s (Ship)"%_t, name)
                elseif type == EntityType.Station then
                    line = string.format("%s (Station)"%_t, name)
                end
    
                comboData[line] = name
                comboBox:addEntry(factionIndex, line, color)
            end
        end
    end
    
    function MapCommands.onEscortPressed()
        enqueueNextOrder = MapCommands.isEnqueueing()
    
        escortData = MapCommands.fillTargetCombo(escortCombo)
    
        for _, window in pairs(orderWindows) do
            window:hide()
        end
    
        escortWindow:show()
    end
    
    function MapCommands.onRepairTargetPressed()
        enqueueNextOrder = MapCommands.isEnqueueing()
    
        repairTargetData = MapCommands.fillTargetCombo(repairTargetCombo)
    
        for _, window in pairs(orderWindows) do
            window:hide()
        end
    
        repairTargetWindow:show()
    end
    
    function MapCommands.onBuyGoodsPressed()
        enqueueNextOrder = MapCommands.isEnqueueing()
    
        buyFilterTextBox:clear()
        buyAmountTextBox:clear()
        MapCommands.fillTradeCombo(buyCombo)
    
        for _, window in pairs(orderWindows) do
            window:hide()
        end
    
        buyWindow:show()
    end
    
    function MapCommands.onSellGoodsPressed()
        enqueueNextOrder = MapCommands.isEnqueueing()
    
        sellFilterTextBox:clear()
        sellAmountTextBox:clear()
        MapCommands.fillTradeCombo(sellCombo)
    
        for _, window in pairs(orderWindows) do
            window:hide()
        end
    
        sellWindow:show()
    end
    
    function MapCommands.onRefineOresPressed()
        MapCommands.clearOrdersIfNecessary()
        MapCommands.enqueueOrder("addRefineOresOrder")
        if not MapCommands.isEnqueueing() then MapCommands.runOrders() end
    end
    
    function MapCommands.onSellFilterTextChanged(textbox, text)
        MapCommands.fillTradeCombo(sellCombo, textbox.text)
    end
    
    function MapCommands.onBuyFilterTextChanged(textbox, text)
        MapCommands.fillTradeCombo(buyCombo, string.lower(textbox.text))
    end
    
    function MapCommands.onBuyWindowOKButtonPressed()
        -- get the good the player wants traded
        local good = buyCombo.selectedValue
        if not good or good == "" then return end
    
        local amount = tonumber(buyAmountTextBox.text)
        if not amount then return end
    
        local margin = buyMarginCombo.selectedValue
    
        MapCommands.clearOrdersIfNecessary(not enqueueNextOrder) -- clear if not enqueueing
        MapCommands.enqueueOrder("addBuyOrder", good, margin, amount)
        if not enqueueNextOrder then MapCommands.runOrders() end
    
        buyWindow:hide()
    end
    
    function MapCommands.onSellWindowOKButtonPressed()
    
        local good = sellCombo.selectedValue
        if not good or good == "" then return end
    
        local amount = tonumber(sellAmountTextBox.text) or 0
        if not amount then return end
    
        local margin = sellMarginCombo.selectedValue
        local preferOwn = preferOwnStationsCheck.checked
    
        MapCommands.clearOrdersIfNecessary(not enqueueNextOrder) -- clear if not enqueueing
        MapCommands.enqueueOrder("addSellOrder", good, margin, amount, preferOwn)
        if not enqueueNextOrder then MapCommands.runOrders() end
    
        sellWindow:hide()
    end
    
    function MapCommands.onEscortWindowOKButtonPressed()
        local player = Player()
    
        local factionIndex = escortCombo.selectedValue
        local craftLine = escortCombo.selectedEntry
        local craftName = escortData[craftLine]
    
        MapCommands.clearOrdersIfNecessary(not enqueueNextOrder) -- clear if not enqueueing
        MapCommands.enqueueOrder("addEscortOrder", nil, factionIndex, craftName)
        if not enqueueNextOrder then MapCommands.runOrders() end
    
        escortWindow:hide()
    end
    
    function MapCommands.onRepairTargetWindowOKButtonPressed()
        local player = Player()
    
        local factionIndex = repairTargetCombo.selectedValue
        local craftLine = repairTargetCombo.selectedEntry
        local craftName = repairTargetData[craftLine]
    
        MapCommands.clearOrdersIfNecessary(not enqueueNextOrder) -- clear if not enqueueing
        MapCommands.enqueueOrder("addRepairTargetOrder", nil, factionIndex, craftName)
        if not enqueueNextOrder then MapCommands.runOrders() end
    
        repairTargetWindow:hide()
    end
    
    function MapCommands.onStopPressed()
        MapCommands.enqueueOrder("clearAllOrders")
    end
    
    function MapCommands.onShowGalaxyMap()
        local player = Player()
        local alliance = player.alliance
        if alliance then
            alliance:registerCallback("onShipOrderInfoUpdated", "onAllianceShipOrderInfoChanged")
            alliance:registerCallback("onShipPositionUpdated", "onAllianceShipSectorChanged")
        end
    
        local x, y = GalaxyMap():getSelectedCoordinates()
    
        shipsContainer:clear()
        craftPortraits = {}
        playerShipPortraits = {}
        allianceShipPortraits = {}
    
        local player = Player()
        MapCommands.makePortraits(player)
        MapCommands.makePortraits(player.alliance)
    
        MapCommands.updateButtons(true)
    end
    
    function MapCommands.onHideGalaxyMap()
        MapCommands.runOrders()
        Hud().notificationsVisible = true
    end
    
    function MapCommands.filterPortraits(args)
    
        local matching = {}
        local notMatching = {}
    
        local portraits = craftPortraits
        if args.portraits then
            portraits = args.portraits
        end
    
        for _, portrait in pairs(portraits) do
            if (args.selected == nil or portrait.portrait.selected == args.selected) and
               (args.inside == nil or MapCommands.isPortraitInCurrentSector(portrait) == args.inside) then
                table.insert(matching, portrait)
            else
                table.insert(notMatching, portrait)
            end
        end
    
        return matching, notMatching
    end
    
    function MapCommands.getActionIconFromInfo(info)
        if info then
            local current = info.chain[info.currentIndex]
            if current and current.icon then
                return current.icon
            end
        end
    end
    
    function MapCommands.getLastLocationFromInfo(info)
        if not info then return end
        if not info.chain then return end
    
        local i = #info.chain
    
        while i > 0 do
            local current = info.chain[i]
            local x, y = current.x, current.y
    
            if x and y then return x, y end
    
            i = i - 1
        end
    
    end
    
    function MapCommands.getCommandsFromInfo(info, x, y)
        if not info then return {} end
        if not info.chain then return {} end
        if not info.coordinates then return {} end
    
        local cx, cy = info.coordinates.x, info.coordinates.y
        local i = info.currentIndex
    
        if i == 0 then i = 1 end
    
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
    
    function MapCommands.hasCommandToUndo(info)
        if not info then return false end
        if not info.chain then return false end
    
        -- if it's not done (index == 0)
        -- and not currently doing the last order, we can still undo orders
        -- exception: jumps can still be undone
        local active = #info.chain > 0 and not info.finished
        if active and (info.currentIndex < #info.chain
                or info.chain[#info.chain].action == OrderType.Jump
                or info.chain[#info.chain].action == OrderType.FlyThroughWormhole) then
            return true
        end
    
        return false
    end
    
    function MapCommands.getPortraits()
        return craftPortraits
    end
    
    function MapCommands.clearOrders()
        local remoteNotLoaded = "That sector isn't loaded to memory on the server. Please contact your server administrator for help."%_t
    
        for _, portrait in pairs(craftPortraits) do
            if portrait.portrait.selected then
                invokeEntityFunction(portrait.coordinates.x, portrait.coordinates.y, remoteNotLoaded, {faction = portrait.owner, name = portrait.name}, "data/scripts/entity/orderchain.lua", "clearAllOrders")
            end
        end
    end
    
    function MapCommands.enqueueOrder(order, ...)
        local remoteNotLoaded = "That sector isn't loaded to memory on the server. Please contact your server administrator for help."%_t
    
        for _, portrait in pairs(craftPortraits) do
            if portrait.portrait.selected then
                portrait.hasNewOrders = true
                invokeEntityFunction(portrait.coordinates.x, portrait.coordinates.y, remoteNotLoaded, {faction = portrait.owner, name = portrait.name}, "data/scripts/entity/orderchain.lua", order, ...)
            end
        end
    end
    
    function MapCommands.runOrders()
        local remoteNotLoaded = "That sector isn't loaded to memory on the server. Please contact your server administrator for help."%_t
    
        for _, portrait in pairs(craftPortraits) do
            if portrait.hasNewOrders then
                portrait.hasNewOrders = nil
                invokeEntityFunction(portrait.coordinates.x, portrait.coordinates.y, remoteNotLoaded, {faction = portrait.owner, name = portrait.name}, "data/scripts/entity/orderchain.lua", "runOrders")
            end
        end
    end
    
    -- FJTGC Mod --
    local gateWindow
    local gateCombo
    local gateData = {}

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
    function MapCommands.initUI_FJTGC()

        -- gate button
        local gateOrder = {tooltip = "Use Gate"%_t, icon = "data/textures/icons/patrol.png", callback = "onGatePressed", type = OrderType.Gate}
        local index = #orders-1

        table.insert(orders, index, gateOrder)

        local gateButton = ordersContainer:createRoundButton(Rect(), gateOrder.icon, gateOrder.callback)
        gateButton.tooltip = gateOrder.tooltip

        table.insert(orderButtons, index, gateButton)

        -- wormhole button
        local wormholeOrder = {tooltip = "Use Wormhole"%_t, icon = "data/textures/icons/wormhole.png", callback = "onWormholePressed", type = OrderType.Wormhole}
        local index = #orders-1

        table.insert(orders, index, wormholeOrder)

        local button = ordersContainer:createRoundButton(Rect(), wormholeOrder.icon, wormholeOrder.callback)
        button.tooltip = wormholeOrder.tooltip

        table.insert(orderButtons, index, button)

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
        MapCommands.clearOrdersIfNecessary()
        MapCommands.enqueueOrder("addDiscoverWormholeOrder")
        if not MapCommands.isEnqueueing() then MapCommands.runOrders() end
    end

    -- Gate Window
    function MapCommands.hideOrderButtons_FJTGC()
        gateWindow:hide()
    end

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

    function onModError(msg, ...)
        msg = string.format(msg, ...)
        print("Error: " .. msg)

        local player = Player()
        local x, y = player:getShipPosition(name)

        invokeEntityFunction(x, y, msg, player.craft.id, "data/scripts/entity/orderchain.lua", "sendError", msg)
    end

end -- onClient()