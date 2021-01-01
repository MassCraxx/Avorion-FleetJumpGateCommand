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

