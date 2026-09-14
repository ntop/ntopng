-- Run from the repository root: lua tests/unit/session_cookie_expiry.lua
-- Exercise the real header helpers without a running ntopng/Redis instance.

local output
local env = setmetatable({
    package = {path = ""},
    require = function(name)
        assert(name == "ntop_utils" or name == "locales_utils" or
               name == "lua_utils_generic" or name == "dkjson", name)
        return {}
    end,
    ntop = {
        getDirs = function() return {installdir = "."} end,
        getInfo = function()
            return {version = "test", platform = "test", http_port = 3000,
                    https_port = 0}
        end,
        getCookieAttributes = function() return " HttpOnly; SameSite=lax" end
    },
    starts = function(s, prefix) return s:sub(1, #prefix) == prefix end,
    print = function(s) output = s end,
    _SERVER = {URI = "/lua/index.lua"},
    _SESSION = {session = "test-session"}
}, {__index = _G})

local rest_utils = assert(loadfile("scripts/lua/modules/rest_utils.lua", "t", env))()

local function session_cookie()
    return output:match("Set%-Cookie: (session_3000_0=[^\r\n]*)")
end

-- Normal responses must leave the login cookie's expiry untouched. This
-- applies equally to a short configured duration and to a seven-day session.
rest_utils.sendHTTPContentTypeHeader("text/html")
assert(not session_cookie(), "HTML response overwrites the login cookie")
assert(output:find("Content-Type: text/html; charset=utf-8", 1, true))

env._SERVER.URI = "/lua/rest/v2/get/test.lua"
rest_utils.sendHTTPContentTypeHeader("application/json")
assert(not session_cookie(), "API response overwrites the login cookie")
assert(output:find("Access-Control-Allow-Origin: *", 1, true))

-- Explicit cookie lifetimes and their security attributes remain supported.
for _, seconds in ipairs({60, 604800}) do
    rest_utils.sendHTTPHeaderIfName("text/html", nil, seconds)
    local cookie = assert(session_cookie())
    assert(cookie:find("max-age=" .. seconds .. ";", 1, true))
    assert(cookie:find("HttpOnly", 1, true))
    assert(cookie:find("SameSite=lax", 1, true))
end

-- Zero is an explicit lifetime: logout must still expire the cookie.
rest_utils.sendHTTPHeaderLogout("text/html")
assert(assert(session_cookie()):find("max-age=0;", 1, true))

env._SESSION = nil
rest_utils.sendHTTPContentTypeHeader("text/html")
assert(not session_cookie(), "Anonymous response sets a session cookie")

print("PASS: session cookie expiry is preserved; explicit expiry and logout work")
