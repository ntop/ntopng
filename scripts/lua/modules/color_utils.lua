--
-- (C) 2013-26 - ntop.org
--

-- Chart colors, split from graph_utils (which requires lua_utils, ts_utils,
-- db_utils, ...) to be used by light scripts as well

local color_utils = {}

-- ########################################################

local function hue2rgb(p, q, t)
    if t < 0 then t = t + 1 end
    if t > 1 then t = t - 1 end
    if t < 1 / 6 then return p + (q - p) * 6 * t end
    if t < 1 / 2 then return q end
    if t < 2 / 3 then
        return p + (q - p) * (2 / 3 - t) * 6
    end
    return p
end

-- ########################################################

function color_utils.generateColorPalette(n, alpha)
    local colors = {}
    local alpha = 0.8
    
    local baseColors = {
        "#00A3FF", -- Electric blue (primary)
        "#FF3B5C", -- Neon red (critical)
        "#FF9E00", -- Vivid orange (warning)
        "#FFD600", -- Bright yellow (alerts)
        "#3DFAFF", -- Cyan (monitoring)
        "#5232FF", -- Deep purple (intelligence)
        "#00E676", -- Neon green (secure)
        "#B94FFF", -- Magenta (anomalies)
        "#0F2B46", -- Dark blue (protected)
        "#56CFE1", -- Light blue (information)
        "#FF5864", -- Coral (threat)
        "#3F51B5", -- Indigo (defense)
        "#01C8AA", -- Teal (normal)
        "#6874E8", -- Periwinkle (analysis)
        "#FFB627"  -- Amber
    }

    -- Function to convert hex to RGBA
    local function hexToRgba(hex, alpha)
        local hex = hex:gsub("#","")
        local r = tonumber("0x"..hex:sub(1,2))
        local g = tonumber("0x"..hex:sub(3,4))
        local b = tonumber("0x"..hex:sub(5,6))
        return string.format("rgba(%d, %d, %d, %.2f)", r, g, b, alpha)
    end
    
    -- Function to convert hex to hex with alpha
    local function hexToHexAlpha(hex, alpha)
        local alphaHex = string.format("%02x", math.floor(alpha * 255 + 0.5))
        return hex .. alphaHex
    end

    -- If requested colors are fewer than our base set, return a subset
    if n <= #baseColors then
        for i = 1, n do
            -- table.insert(colors, hexToRgba(baseColors[i], alpha))
            table.insert(colors, hexToHexAlpha(baseColors[i], alpha))
        end
        return colors
    end

    -- Get base colors
    for i = 1, #baseColors do 
        -- table.insert(colors, hexToRgba(baseColors[i], alpha))
        table.insert(colors, hexToHexAlpha(baseColors[i], alpha))
    end

    local saturation = 75
    local lightness = 55

    for i = #baseColors, n - 1 do
        -- Use golden angle to distribute hues 
        local hue = (i * 137.508) % 360

        -- Convert HSL to RGB
        local h = hue / 360
        local s = saturation / 100
        local l = lightness / 100

        local r, g, b

        if s == 0 then
            r, g, b = l, l, l
        else

            local q = l < 0.5 and l * (1 + s) or l + s - l * s
            local p = 2 * l - q

            r = hue2rgb(p, q, h + 1 / 3)
            g = hue2rgb(p, q, h)
            b = hue2rgb(p, q, h - 1 / 3)
        end

        local r_int = math.floor(r * 255 + 0.5)
        local g_int = math.floor(g * 255 + 0.5)
        local b_int = math.floor(b * 255 + 0.5)

        local rgba = string.format("rgba(%d, %d, %d, %.2f)", 
                                   r_int, g_int, b_int,
                                   alpha)

        local hex = string.format("#%02X%02X%02X", r_int, g_int, b_int)
        hex = hexToHexAlpha(hex, alpha)

        table.insert(colors, hex)
    end

    return colors
end

color_utils.graph_colors = color_utils.generateColorPalette(30)

function color_utils.get_html_color(index)
    return color_utils.graph_colors[(index % #color_utils.graph_colors) + 1]
end

-- ########################################################

return color_utils
