--
-- (C) 2014-24 - ntop.org
--

-- ###############################################

-- removes trailing/leading spaces
function trimString(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- ###############################################

-- removes all spaces
function trimSpace(what)
    if (what == nil) then
        return ("")
    end
    return (string.gsub(string.gsub(what, "%s+", ""), "+%s", ""))
end

-- ##############################################

-- Note: Regexs are applied by default. Pass plain=true to disable them.
function string.contains(str, start, is_plain)
    if type(str) ~= 'string' or type(start) ~= 'string' or isEmptyString(str) or isEmptyString(start) then
        return false
    end

    local i, _ = string.find(str, start, 1, is_plain)

    return (i ~= nil)
end

-- ##############################################

function shortenString(name, max_len)
    local ellipsis = "\u{2026}" -- The unicode ellipsis (takes less space than three separate dots)
    if (name == nil) then
        return ("")
    end

    if max_len == nil then
        max_len = ntop.getPref("ntopng.prefs.max_ui_strlen")
        max_len = tonumber(max_len)
        if (max_len == nil) then
            max_len = 24
        end
    end

    -- Error, max_len is not a number, print an error and return the name
    if not tonumber(max_len) then
        traceError(TRACE_DEBUG, TRACE_CONSOLE, "Length parameter is not a number.")
        tprint(debug.traceback())
        return name
    end
    if (string.len(name) < max_len + 1 --[[ The space taken by the ellipsis --]] ) then
        return (name)
    else
        return (string.sub(name, 1, max_len) .. ellipsis)
    end
end

-- ##############################################

function string.containsIgnoreCase(str, start, is_plain)
    return string.contains(string.lower(str), string.lower(start), is_plain)
end

-- startswith
function startswith(s, char)
    return string.sub(s, 1, string.len(s)) == char
end

-- endswith
function endswith(s, char)
    return string.sub(s, -#char) == char
end
