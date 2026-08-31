# ntopng Lua API Reference (`ntop.*` bindings)

This document describes all C→Lua bindings exposed as `ntop.*` functions via
`src/LuaEngineNtop.cpp`.  It is intended both for human developers writing Lua
scripts and as a machine-readable reference for AI-assisted code generation (e.g.
Claude Code in this repository).

---

## Table of Contents

1. [How the Lua API works](#1-how-the-lua-api-works)
2. [REST API development guide](#2-rest-api-development-guide)
3. [System & Information](#3-system--information)
4. [File System](#4-file-system)
5. [Redis / Cache](#5-redis--cache)
6. [Preferences](#6-preferences)
7. [User Management & Authentication](#7-user-management--authentication)
8. [MFA / TOTP](#8-mfa--totp)
9. [Network & IP Utilities](#9-network--ip-utilities)
10. [Address Resolution](#10-address-resolution)
11. [HTTP Client](#11-http-client)
12. [Logging](#12-logging)
13. [Historical Statistics (SQLite)](#13-historical-statistics-sqlite)
14. [RRD](#14-rrd)
15. [Alerts](#15-alerts)
16. [Recipient Queues](#16-recipient-queues)
17. [nDPI / Protocol Classification](#17-ndpi--protocol-classification)
18. [SNMP](#18-snmp)
19. [Ping](#19-ping)
20. [Traffic Recording & Extraction](#20-traffic-recording--extraction)
21. [IPS / nEdge](#21-ips--nedge)
22. [ZMQ](#22-zmq)
23. [Time & Ticks](#23-time--ticks)
24. [UDP / TCP Send](#24-udp--tcp-send)
25. [ASN & Geolocation](#25-asn--geolocation)
26. [Bitmap Utilities](#26-bitmap-utilities)
27. [Score / Severity](#27-score--severity)
28. [Edition / Platform Checks](#28-edition--platform-checks)
29. [Privilege Management](#29-privilege-management)
30. [Custom Categories & nDPI Reload](#30-custom-categories--ndpi-reload)
31. [Flow / Host Checks & Risks](#31-flow--host-checks--risks)
32. [In-Memory Lua Cache](#32-in-memory-lua-cache)
33. [Miscellaneous](#33-miscellaneous)

---

## 1. How the Lua API works

### C→Lua registration

Every Lua function registered in `_ntop_reg[]` (bottom of
`src/LuaEngineNtop.cpp`) follows this pattern:

```c
// 1. Implement a static C function
static int ntop_my_function(lua_State* vm) {
    // read args
    ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING);
    const char* arg = lua_tostring(vm, 1);
    // do work, push return value
    lua_pushstring(vm, result);
    return CONST_LUA_OK;  // or CONST_LUA_ERROR
}

// 2. Register it
{ "myFunction", ntop_my_function },   // called as ntop.myFunction(...)
```

### Script request flow

```
HTTP request → HTTPserver.cpp → Lua VM → scripts/lua/<path>.lua
                                          ├── _GET["param"]        (GET params)
                                          ├── _POST["param"]       (POST params)
                                          ├── _SESSION["user"]     (logged-in username)
                                          ├── _SESSION["group"]    (user role)
                                          └── ntop.*()             (C bindings)
```

### Standard boilerplate (all Lua scripts)

```lua
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"        -- helper utilities
local json = require("dkjson")
local rest_utils = require("rest_utils")  -- for REST endpoints
```

---

## 2. REST API development guide

### File location

REST endpoints live at:

```
scripts/lua/rest/v2/<method>/<resource>/<sub-resource>.lua
```

| HTTP method | Directory |
|-------------|-----------|
| GET         | `get/`    |
| POST        | `add/`, `create/`, `set/`, `edit/` |
| DELETE      | `delete/` |
| PUT/PATCH   | `edit/`   |

The URL to call an endpoint is:
```
http(s)://<host>:3000/lua/rest/v2/<method>/<resource>/<sub>.lua
```

### Minimal REST endpoint template

```lua
-- (C) 2013-26 - ntop.org

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils = require("rest_utils")
require "lua_utils"
local json = require("dkjson")

-- ── Read parameters ──────────────────────────────────────────────────────────
local ifid   = _GET["ifid"]
local param1 = _GET["param1"]

-- ── Validate ─────────────────────────────────────────────────────────────────
if isEmptyString(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

if isEmptyString(param1) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

-- ── Authorization ─────────────────────────────────────────────────────────────
if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

-- ── Work ─────────────────────────────────────────────────────────────────────
interface.select(ifid)

local result = {}
-- populate result ...

-- ── Return JSON ───────────────────────────────────────────────────────────────
rest_utils.answer(rest_utils.consts.success.ok, result)
```

### `rest_utils.answer(rc [, data])`

`rc` must be one of the constants in `rest_utils.consts`:

**Success codes**

| Constant | HTTP | rc | Meaning |
|----------|------|----|---------|
| `success.ok` | 200 | 0 | Generic success |

**Error codes**

| Constant | HTTP | rc | Meaning |
|----------|------|----|---------|
| `err.not_found` | 404 | -1 | Resource not found |
| `err.invalid_interface` | 400 | -2 | Bad/missing interface id |
| `err.not_granted` | 401 | -3 | Insufficient privileges |
| `err.invalid_host` | 400 | -4 | Bad host |
| `err.invalid_args` | 400 | -5 | Missing/bad arguments |
| `err.internal_error` | 500 | -6 | Server error |
| `err.bad_format` | 400 | -7 | Malformed data |
| `err.bad_content` | 400 | -8 | Bad content |

### Common patterns

**Selecting an interface**
```lua
local ifid = _GET["ifid"]
interface.select(ifid)
-- now interface.* calls operate on that interface
```

**Reading Redis data**
```lua
local value = ntop.getCache("ntopng.prefs.my_key")
ntop.setCache("ntopng.prefs.my_key", "new_value", 3600)  -- optional TTL
```

**Reading/writing hash maps**
```lua
ntop.setHashCache("ntopng.user.admin", "language", "en")
local lang = ntop.getHashCache("ntopng.user.admin", "language")
```

**JSON encode/decode**
```lua
local json = require("dkjson")
local encoded = json.encode({ key = "value" })
local decoded = json.decode(encoded)
```

**Admin-only guard**
```lua
if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end
```

**POST body (JSON)**
```lua
local body = _POST["JSON"]          -- raw JSON string
local data = json.decode(body or "")
local field = data and data["field"]
```

---

## 3. System & Information

| Lua call | Returns | Description |
|----------|---------|-------------|
| `ntop.getDirs()` | table | All ntopng directory paths: `installdir`, `scriptdir`, `httpdocsdir`, `workingdir`, `bindir`, `callbacksdir`, `pcapdir`, `dbarchivedir`, `etcdir`, `sharedir` |
| `ntop.getInfo([verbose])` | table | Product info, version, OS, license, uptime, port numbers. Pass `false` for a smaller payload. |
| `ntop.getUptime()` | integer | Uptime in seconds since last restart |
| `ntop.systemHostStat()` | table | CPU load, memory usage, alert queue drops/writes |
| `ntop.threadsInfo()` | table | All running ntopng threads |
| `ntop.refreshCPULoad()` | number\|nil | Trigger CPU load refresh; returns current value |
| `ntop.checkLicense()` | integer | Run license validation (returns 1) |
| `ntop.getSystemAlertsStats()` | table | Alert statistics (drops, writes) |
| `ntop.getCookieAttributes()` | string | Cookie security attributes string (e.g. `SameSite=Strict; Secure`) |
| `ntop.getAllPaths(path, pattern)` | table | Recursively find all files matching pattern under path |
| `ntop.getStartupEpoch()` | integer | ntopng start time as Unix epoch |
| `ntop.getStaticFileEpoch()` | integer | Epoch for static-file cache busting |
| `ntop.getHttpPrefix()` | string | HTTP path prefix (e.g. empty string or subpath) |
| `ntop.httpPurifyParam(s)` | string | Sanitize a string for safe use in URLs/HTML |
| `ntop.isShuttingDown()` | boolean | True if ntopng is in shutdown sequence |
| `ntop.limitResourcesUsage()` | nil | Throttle CPU usage of current thread |
| `ntop.getCurrentScriptsDir()` | string | Path of currently executing scripts directory |
| `ntop.getInstanceName()` | string | Configured instance name |
| `ntop.resetStats()` | nil | Reset per-interface statistics |
| `ntop.getDropPoolInfo()` | table | Drop pool statistics |

**Example — get version:**
```lua
local info = ntop.getInfo()
print(info["version"])   -- e.g. "6.1.230101"
```

**Example — get dirs:**
```lua
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
```

---

## 4. File System

| Lua call | Returns | Description |
|----------|---------|-------------|
| `ntop.isdir(path)` | boolean | True if path is a directory |
| `ntop.mkdir(path)` | nil | Create directory tree (like `mkdir -p`) |
| `ntop.notEmptyFile(path)` | boolean | True if file exists and has content |
| `ntop.exists(path)` | boolean | True if file or directory exists |
| `ntop.fileLastChange(path)` | integer | Modification time (Unix epoch), -1 if missing |
| `ntop.readdir(path)` | table | List of filenames in directory |
| `ntop.rmdir(path)` | boolean | Remove directory recursively |
| `ntop.unlink(path)` | boolean | Delete a file |
| `ntop.dumpFile(path)` | nil | Read text file and write to HTTP response |
| `ntop.dumpBinaryFile(path)` | nil | Read binary file and write to HTTP response |
| `ntop.listReports()` | table | List available report files |
| `ntop.setDefaultFilePermissions(path)` | nil | Apply default Unix permissions to file |

---

## 5. Redis / Cache

ntopng uses Redis for persistent key-value storage.  All user preferences,
session tokens, and many runtime values live here.

### Key conventions

| Prefix | Purpose |
|--------|---------|
| `ntopng.user.<username>.<field>` | Per-user settings |
| `ntopng.prefs.<key>` | System preferences |
| `sessions.<session_id>` | Active sessions (value: `user\|group\|csrf\|localuser`) |

### String operations

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.getCache(key)` | string | string\|nil | Get key value |
| `ntop.setCache(key, val [,ttl])` | string, string, int? | nil | Set key, optional TTL in seconds |
| `ntop.setnxCache(key, val)` | string, string | boolean | Set only if key absent |
| `ntop.delCache(key)` | string | nil | Delete key |
| `ntop.renameCache(old, new)` | string, string | nil | Rename key |
| `ntop.incrCache(key [,n])` | string, int? | integer | Atomic increment (default +1) |
| `ntop.flushCache()` | — | boolean | **DANGER**: flush all Redis data (admin only) |
| `ntop.getKeysCache(pattern)` | string | table | Keys matching glob pattern |
| `ntop.getCacheStatus()` | — | table | Redis connection info and statistics |
| `ntop.getCacheStats()` | — | table | Redis usage statistics |
| `ntop.hasDumpCache(key)` | string | boolean | True if key has a binary dump |
| `ntop.dumpCache(key)` | string | string\|nil | Binary dump of key |
| `ntop.restoreCache(key, dump)` | string, string | boolean | Restore key from binary dump |

### Hash operations

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.getHashCache(key, field)` | string, string | string\|nil | Get hash field |
| `ntop.setHashCache(key, field, val)` | string, string, string | nil | Set hash field |
| `ntop.delHashCache(key, field)` | string, string | nil | Delete hash field |
| `ntop.getHashKeysCache(key)` | string | table | All field names in hash |
| `ntop.getHashAllCache(key)` | string | table | All {field=value} pairs |

### List operations

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.lpushCache(key, val)` | string, string | nil | Push to list head |
| `ntop.rpushCache(key, val)` | string, string | nil | Push to list tail |
| `ntop.lpopCache(key)` | string | string\|nil | Pop from list head |
| `ntop.rpopCache(key)` | string | string\|nil | Pop from list tail |
| `ntop.lremCache(key, count, val)` | string, int, string | nil | Remove matching elements |
| `ntop.ltrimCache(key, start, stop)` | string, int, int | nil | Trim list to range |
| `ntop.lrangeCache(key, start, stop)` | string, int, int | table | Get range of elements |
| `ntop.llenCache(key)` | string | integer | List length |
| `ntop.listIndexCache(key, idx)` | string, int | string\|nil | Element at index |

### Set operations

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.setMembersCache(key, member)` | string, string | nil | Add member to set |
| `ntop.delMembersCache(key, member)` | string, string | nil | Remove member from set |
| `ntop.getMembersCache(key)` | string | table | All set members |

**Examples:**

```lua
-- Store per-user setting
ntop.setHashCache("ntopng.user.admin", "language", "it")

-- Read it back
local lang = ntop.getHashCache("ntopng.user.admin", "language")

-- Store JSON configuration
local json = require("dkjson")
ntop.setCache("ntopng.prefs.my_config", json.encode({enabled=true, threshold=100}))
local cfg = json.decode(ntop.getCache("ntopng.prefs.my_config") or "{}")
```

---

## 6. Preferences

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.setPref(key, val)` | string, string | nil | Write preference to Redis (`ntopng.prefs.<key>`) |
| `ntop.getPref(key)` | string | string\|nil | Read preference (alias for `getCache`) |
| `ntop.getPrefs()` | — | table | All preferences as a table |
| `ntop.reloadPreferences([set_defaults])` | bool? | nil | Reload preferences from Redis |

```lua
-- Save a preference
ntop.setPref("ntopng.prefs.my_feature_enabled", "1")

-- Read it back
local enabled = (ntop.getPref("ntopng.prefs.my_feature_enabled") == "1")
```

---

## 7. User Management & Authentication

These functions are admin-only unless otherwise noted.

### Querying users

| Lua call | Returns | Description |
|----------|---------|-------------|
| `ntop.getUsers()` | table | All users with their attributes |
| `ntop.getNologinUser()` | string | The special no-login username constant |
| `ntop.isAdministrator()` | boolean | True if current request is from an admin |
| `ntop.isPcapDownloadAllowed()` | boolean | True if current user may download PCAPs |
| `ntop.getAllowedNetworks()` | table | Networks visible to current user |
| `ntop.getAllowedHostPools()` | table | Host pools visible to current user |
| `ntop.isLoginDisabled()` | boolean | True if login is globally disabled |
| `ntop.isLoginBlacklisted(username)` | boolean | True if username is brute-force blocked |
| `ntop.isGuiAccessRestricted()` | boolean | True if GUI access is IP-restricted |
| `ntop.getUserObservationPointId(username)` | integer | Observation point assigned to user |

### Creating / modifying users

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.addUser(username, full_name, password, role, allowed_nets, allowed_iface [, host_pool, lang, pcap, history, alerts, pools])` | … | boolean | Create new user |
| `ntop.deleteUser(username)` | string | boolean | Delete user |
| `ntop.resetUserPassword(who, username, old_pw, new_pw)` | … | boolean | Change password |
| `ntop.changeUserRole(username, role)` | string, string | boolean | Change role (`administrator`/`unprivileged`/`captivePortal`) |
| `ntop.changeAllowedNets(username, nets)` | string, string | boolean | Update allowed networks (comma-separated CIDR) |
| `ntop.changeAllowedIfname(username, ifname)` | string, string | boolean | Update allowed interface |
| `ntop.changeUserHostPool(username, pool_id)` | string, string | boolean | Set captive portal host pool |
| `ntop.changeAllowedHostPools(username, pools)` | string, string | boolean | Set viewable host pools |
| `ntop.changeUserFullName(username, name)` | string, string | boolean | Update display name |
| `ntop.changeUserLanguage(username, lang)` | string, string | boolean | Update UI language |
| `ntop.changePcapDownloadPermission(username, allow)` | string, bool | boolean | Grant/revoke PCAP download |
| `ntop.changeHistoricalFlowPermission(username, allow)` | string, bool | boolean | Grant/revoke historical flows |
| `ntop.changeAlertsPermission(username, allow)` | string, bool | boolean | Grant/revoke alerts access |

### Sessions & tokens

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.createUserSession(username [, duration])` | string, int? | string | Create session, returns session id |
| `ntop.createUserAPIToken(username)` | string | string\|nil | Generate new API token |
| `ntop.getUserAPIToken(username)` | string | string\|nil | Read existing API token |

**Example — create user via REST endpoint:**
```lua
local ok = ntop.addUser(
  "analyst",                  -- username
  "Jane Analyst",             -- full name
  "s3cr3t",                   -- initial password
  "unprivileged",             -- role
  "192.168.1.0/24",          -- allowed networks
  "eth0",                     -- allowed interface
  nil,                        -- host pool (nil = all)
  "en",                       -- language
  false,                      -- pcap download
  true,                       -- historical flows
  true                        -- alerts
)
```

---

## 8. MFA / TOTP

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.generateTOTPSecret()` | — | string | Generate new base32 TOTP secret |
| `ntop.setUserTOTPSecret(username, secret)` | string, string | boolean | Store secret for user |
| `ntop.getUserTOTPSecret(username)` | string | string\|nil | Read secret (admin only) |
| `ntop.isTOTPEnabled(username)` | string | boolean | Check if TOTP is on |
| `ntop.setUserTOTPEnabled(username, enabled)` | string, bool | boolean | Enable/disable TOTP |
| `ntop.validateTOTP(username, code)` | string, string | boolean | Validate 6-digit code |
| `ntop.getTOTPProvisioningUri(username)` | string | string\|nil | QR-code URI for authenticator app setup |

---

## 9. Network & IP Utilities

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.ipToNumber(ip)` | string | integer | IPv4 string → 32-bit number |
| `ntop.inet_ntoa(n)` | integer\|string | string | 32-bit number → IPv4 string |
| `ntop.networkPrefix(ip, bits)` | string, int | string | Network address from IP + prefix length |
| `ntop.ipCmp(ip1, ip2)` | string, string | integer | Compare two IPs (-1/0/1) |
| `ntop.isIPv6(ip)` | string | boolean | True if address is IPv6 |
| `ntop.isLocalAddress(ip)` | string | boolean | True if in a configured local network |
| `ntop.isLocalInterfaceAddress(ip)` | string | boolean | True if IP belongs to a local NIC |
| `ntop.isAllowedInterface(ifname)` | string | boolean | True if current user may see this interface |
| `ntop.isAllowedNetwork(network)` | string | boolean | True if current user may see this network |
| `ntop.addLocalNetwork(cidr)` | string | nil | Add CIDR to local networks list |
| `ntop.getNetworks()` | — | table | All configured local networks |
| `ntop.getNetworkNameById(id)` | integer | string | Network name for index |
| `ntop.getNetworkIdByName(name)` | string | integer | Index for network name |
| `ntop.getAddressNetwork(ip)` | string | table | Network info for an IP |
| `ntop.getLocalNetworkAlias(cidr)` | string | string\|nil | Alias for a local network |
| `ntop.getLocalNetworkID(cidr)` | string | integer | ID for local network CIDR |
| `ntop.setResolvedAddress(ip, hostname)` | string, string | nil | Cache DNS reverse mapping |
| `ntop.checkNetworkPolicy(ip)` | string | table | Network policy for an IP |

---

## 10. Address Resolution

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.resolveName(ip)` | string | nil | Trigger async DNS resolution (see `ntop_utils.resolveAddress()`) |
| `ntop.getResolvedName(ip)` | string | string\|nil | Retrieve cached reverse DNS result |
| `ntop.resolveHost(hostname)` | string | string\|nil | Resolve hostname → IP |

> **Note:** use the Lua wrappers `resolveAddress()` / `getResolvedAddress()` from
> `lua_utils` instead of calling these directly.

---

## 11. HTTP Client

These functions let Lua scripts make outbound HTTP requests.

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.httpGet(url [, user, pass, timeout, return_content, no_verify_cert, use_compression, follow_redirects])` | … | string\|table | GET request; returns body or nil |
| `ntop.httpPost(url, data [, params])` | `data`: request body; `params`: optional table with `username`, `password`, `timeout`, `return_content`, `use_cookie_auth`, `bearer`, `x_api_key`, `extra_header` | table | POST request |
| `ntop.httpFetch(params_table)` | table | table | Full-featured HTTP fetch with all options |
| `ntop.httpGetAuthToken(url, token [, timeout, return_content, no_verify_cert])` | … | string | GET with Bearer token |
| `ntop.httpPostAuthToken(url, token, body [, timeout, content_type])` | … | string | POST with Bearer token |
| `ntop.httpPutAuthToken(url, token, body [, timeout])` | … | string | PUT with Bearer token |
| `ntop.httpPatchAuthToken(url, token, body [, timeout])` | … | string | PATCH with Bearer token |
| `ntop.postHTTPJsonData(url, body)` | string, string | boolean | POST JSON body |
| `ntop.postHTTPTextFile(url, file_path)` | string, string | boolean | POST text file content |
| `ntop.httpRedirect(url)` | string | nil | Issue HTTP 302 redirect (from page script) |
| `ntop.getRandomCSRFValue()` | — | string | CSRF token for form/AJAX protection |

**Example — calling an external REST API:**
```lua
local json = require("dkjson")
local body = ntop.httpGet("https://api.example.com/data", nil, nil, 5, true)
if body then
   local data = json.decode(body)
end
```

---

## 12. Logging

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.traceEvent(level, msg)` | integer, string | nil | Log a message at given level |
| `ntop.verboseTrace(msg)` | string | nil | Log at verbose level only if verbose mode on |
| `ntop.setLoggingLevel(level)` | string | nil | Set global log level (`"debug"`, `"normal"`, `"warning"`, etc.) |
| `ntop.syslog(level, msg)` | integer, string | nil | Write to syslog (Unix only) |

**Trace levels** (defined in `ntop_defines.h`):
```lua
TRACE_ERROR   = 0
TRACE_WARNING = 1
TRACE_NORMAL  = 2
TRACE_INFO    = 3
TRACE_DEBUG   = 4
```

```lua
ntop.traceEvent(TRACE_WARNING, "unexpected value: " .. tostring(v))
```

---

## 13. Historical Statistics (SQLite)

Used by housekeeping scripts to store per-interface time-series data.

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.insertMinuteSampling(ifid, data)` | int, string | nil | Insert minute-granularity sample |
| `ntop.insertHourSampling(ifid, data)` | int, string | nil | Insert hour-granularity sample |
| `ntop.insertDaySampling(ifid, data)` | int, string | nil | Insert day-granularity sample |
| `ntop.getMinuteSampling(ifid, epoch)` | int, int | string\|nil | Get minute sample for epoch |
| `ntop.getMinuteSamplingsFromEpoch(ifid, epoch)` | int, int | table | All minute samples from epoch |
| `ntop.getHourSamplingsFromEpoch(ifid, epoch)` | int, int | table | All hour samples from epoch |
| `ntop.getDaySamplingsFromEpoch(ifid, epoch)` | int, int | table | All day samples from epoch |
| `ntop.getMinuteSamplingsInterval(ifid, from, to)` | int, int, int | table | Minute samples in epoch range |
| `ntop.deleteMinuteStatsOlderThan(ifid, days)` | int, int | nil | Purge old minute data |
| `ntop.deleteHourStatsOlderThan(ifid, days)` | int, int | nil | Purge old hour data |
| `ntop.deleteDayStatsOlderThan(ifid, days)` | int, int | nil | Purge old day data |

---

## 14. RRD

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.rrd_create(path, step, start, ...)` | … | nil | Create RRD file |
| `ntop.rrd_update(path, timestamp, ...)` | … | nil | Update RRD with new values |
| `ntop.rrd_fetch(path, cf, start, stop [, step])` | … | table | Fetch consolidated data |
| `ntop.rrd_fetch_columns(path, cf, start, stop [, step])` | … | table | Fetch data column-oriented |
| `ntop.rrd_lastupdate(path)` | string | integer\|nil | Last update timestamp |
| `ntop.rrd_tune(path, ...)` | … | nil | Modify RRD parameters |
| `ntop.rrd_inc_num_drops(path)` | string | nil | Increment drop counter in RRD |
| `ntop.deleteOldRRDs()` | — | nil | Remove stale RRD files |

---

## 15. Alerts

### Alert store queries (ClickHouse / SQLite)

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.alert_store_query(query [, ifid, limit_rows])` | string, int?, bool? | nil | Execute raw alert DB query, streaming JSON result to response |
| `ntop.popInternalAlerts()` | — | table | Dequeue internal alert events |

### Score / severity mapping

See section [27. Score / Severity](#27-score--severity).

---

## 16. Recipient Queues

Recipient queues are used to distribute alert notifications to configured
notification channels (e.g. Slack, email, syslog).

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.recipient_register(id)` | string | nil | Register a recipient channel |
| `ntop.recipient_delete(id)` | string | nil | Unregister a recipient channel |
| `ntop.recipient_enqueue(id, notification)` | string, string | nil | Push notification JSON to queue |
| `ntop.recipient_dequeue(id)` | string | string\|nil | Pop next notification from queue |
| `ntop.recipient_stats()` | — | table | Queue length and throughput per recipient |
| `ntop.recipient_inc_stats(id, stat)` | string, string | nil | Increment named counter |
| `ntop.recipient_last_use(id)` | string | integer | Epoch of last dequeue |

---

## 17. nDPI / Protocol Classification

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.getnDPIProtoCategory(proto_id)` | integer | integer | Get category for nDPI protocol |
| `ntop.setnDPIProtoCategory(proto_id, cat)` | integer, integer | nil | Override protocol category |
| `ntop.isCustomApplication(proto_id)` | integer | boolean | True if protocol is user-defined |
| `ntop.matchCustomCategory(hostname)` | string | integer\|nil | Match hostname against custom categories |
| `ntop.initnDPIReload()` | — | nil | Begin nDPI category reload (housekeeping only) |
| `ntop.finalizenDPIReload()` | — | nil | Commit nDPI category reload |
| `ntop.loadCustomCategoryIp(cat, ip)` | integer, string | nil | Associate IP with custom category |
| `ntop.loadCustomCategoryHost(cat, host)` | integer, string | nil | Associate hostname with custom category |
| `ntop.loadCustomCategoryFile(cat, path)` | integer, string | nil | Load IPs/hosts from file into category |
| `ntop.setDomainMask(domain, mask)` | string, integer | nil | Apply mask to domain traffic |
| `ntop.addTrustedIssuerDN(dn)` | string | nil | Trust TLS certificate issuer DN |

---

## 18. SNMP

### Configuration

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.snmpv3available()` | — | boolean | True if SNMPv3 library present |
| `ntop.snmpsetavailable()` | — | boolean | True if SNMP SET supported |
| `ntop.snmpgetbulkavailable()` | — | boolean | True if SNMP GETBULK supported |
| `ntop.snmpMaxNumEngines()` | — | integer | Max concurrent SNMP engines |
| `ntop.snmpSetBulkMaxNumRepetitions(n)` | integer | nil | Set BULK repetitions |
| `ntop.snmpSetFatMibPollingMode(enabled)` | bool | nil | Enable full MIB polling |
| `ntop.snmpToggleTrapCollection(enabled)` | bool | nil | Enable/disable trap collection |
| `ntop.snmpSetInterfaceRole(ip_addr, interface_idx, role_id)` | - | nil | Set the SNMP interface role in memory that is then activated using ntop.snmpSetInterfaceRole() |
| `ntop.activateSnmpInterfaceRoles()` | - | nil | Activate the interface roles set with ntop.snmpSetInterfaceRole() |

### Synchronous (blocking)

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.snmpget(host, community, oid, version)` | … | table | SNMP GET (blocks) |
| `ntop.snmpgetnext(host, community, oid, version)` | … | table | SNMP GETNEXT (blocks) |
| `ntop.snmpgetnextbulk(host, community, oid, version)` | … | table | SNMP GETBULK (blocks) |
| `ntop.snmpset(host, community, oid, type, value, version)` | … | boolean | SNMP SET (blocks) |

### Asynchronous

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.snmpallocasnyncengine()` | — | integer | Allocate async engine, returns handle |
| `ntop.snmpfreeasnycengine(handle)` | integer | nil | Free async engine |
| `ntop.snmpgetasync(handle, host, community, oid, version)` | … | nil | Queue async GET |
| `ntop.snmpgetnextasync(handle, host, community, oid, version)` | … | nil | Queue async GETNEXT |
| `ntop.snmpgetnextbulkasync(handle, …)` | … | nil | Queue async GETBULK |
| `ntop.snmpreadasyncrsp(handle)` | integer | table\|nil | Read pending async responses |

### Batch

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.snmpGetBatch(params)` | table | nil | Submit batch SNMP GETs (v1/v2c/v3) |
| `ntop.snmpReadResponses()` | — | table | Collect batch responses |

---

## 19. Ping

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.isPingAvailable()` | — | boolean | True if raw socket ping works |
| `ntop.isPingIfaceAvailable(ifname)` | string | boolean | True if ping on interface works |
| `ntop.pingHost(host, is_v6, iface)` | string, bool, string | nil | Send ICMP ping |
| `ntop.collectPingResults()` | — | table | Collect RTT results from sent pings |
| `ntop.getPingIfNames()` | — | table | List interfaces usable for ping |

---

## 20. Traffic Recording & Extraction

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.runExtraction(id, ifid, from, to, filter [,max_bytes, timeline])` | … | nil | Start PCAP extraction job (admin only) |
| `ntop.stopExtraction(id)` | integer | nil | Stop extraction job |
| `ntop.isExtractionRunning()` | — | boolean | True if any extraction active |
| `ntop.getExtractionStatus()` | — | nil | (reserved) |
| `ntop.runLiveExtraction(ifid, from, to, bpf [, timeline])` | … | boolean | Start live PCAP stream |

---

## 21. IPS / nEdge

These are only available in non-nEdge builds (`#ifndef HAVE_NEDGE`).

| Lua call | Description |
|----------|-------------|
| `ntop.broadcastIPSMessage(msg)` | Broadcast message to IPS subsystem |
| `ntop.timeToRefreshIPSRules()` | Returns true if IPS rules need refreshing |
| `ntop.askToRefreshIPSRules()` | Request IPS rule refresh |
| `ntop.checkSubInterfaceSyntax(str)` | Validate sub-interface syntax (Pro) |
| `ntop.checkFilterSyntax(str)` | Validate BPF filter syntax (Pro) |
| `ntop.reloadProfiles()` | Reload traffic profiles (Pro) |

nEdge-only:

| Lua call | Description |
|----------|-------------|
| `ntop.setHTTPBindAddr(addr)` | Set HTTP listen address |
| `ntop.setHTTPSBindAddr(addr)` | Set HTTPS listen address |
| `ntop.setRoutingMode(enabled)` | Enable routing mode |
| `ntop.isRoutingMode()` | True if routing mode |
| `ntop.addLanInterface(ifname)` | Register LAN interface |
| `ntop.addWanInterface(ifname)` | Register WAN interface |
| `ntop.refreshDeviceProtocolsPoliciesConf()` | Refresh device-protocol policy config |

---

## 22. ZMQ

Available only in non-nEdge builds with `HAVE_ZMQ`.

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.zmq_connect(endpoint, topic)` | string, string | nil | Connect to ZMQ publisher |
| `ntop.zmq_disconnect()` | — | nil | Disconnect |
| `ntop.zmq_receive()` | — | string\|error | Receive next ZMQ message |

---

## 23. Time & Ticks

| Lua call | Returns | Description |
|----------|---------|-------------|
| `ntop.gettimemsec()` | number | Current time in milliseconds (float) |
| `ntop.getticks()` | integer | CPU tick counter |
| `ntop.gettickspersec()` | integer | CPU ticks per second |
| `ntop.tzset()` | nil | Refresh timezone information |
| `ntop.roundTime(epoch, secs [, timezone])` | integer | Round epoch down to multiple of `secs` |

```lua
local now_ms = ntop.gettimemsec()
local rounded = ntop.roundTime(os.time(), 60)  -- round to last minute
```

---

## 24. UDP / TCP Send

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.send_udp_data(host, port, data)` | string, int, string | nil | Send UDP datagram |
| `ntop.send_tcp_data(host, port, data)` | string, int, string | nil | Send TCP data (persistent connection) |
| `ntop.tcpProbe(host, port [, timeout])` | string, int, int? | boolean | Test TCP reachability |

---

## 25. ASN & Geolocation

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.hasGeoIP()` | — | boolean | True if MaxMind GeoIP databases loaded |
| `ntop.getASName(ip)` | string | string\|nil | ASN name for an IP |
| `ntop.getASNameFromASN(asn)` | integer | string\|nil | ASN name from ASN number |
| `ntop.getHostGeolocation(ip)` | string | table | Country, city, lat/lon for IP |
| `ntop.getMacManufacturer(mac)` | string | string\|nil | Vendor name from MAC OUI |
| `ntop.getHostInformation(ip)` | string | table | Combined host info table |

---

## 26. Bitmap Utilities

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.bitmapIsSet(bitmap, val)` | integer, integer | boolean | Test bit |
| `ntop.bitmapSet(bitmap, val)` | integer, integer | integer | Set bit, return new bitmap |
| `ntop.bitmapClear(bitmap, val)` | integer, integer | integer | Clear bit, return new bitmap |

```lua
local bm = 0
bm = ntop.bitmapSet(bm, 3)        -- set bit 3
if ntop.bitmapIsSet(bm, 3) then   -- test bit 3
   bm = ntop.bitmapClear(bm, 3)   -- clear bit 3
end
```

---

## 27. Score / Severity

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.mapScoreToSeverity(score)` | integer | integer | Convert numeric score → alert severity enum |
| `ntop.mapSeverityToScore(severity)` | integer | integer | Convert severity enum → numeric score |
| `ntop.getFlowAlertScore(alert_id)` | integer | integer | Default score for a flow alert type |
| `ntop.getFlowAlertRisk(alert_id)` | integer | integer | Risk identifier for a flow alert |

---

## 28. Edition / Platform Checks

### Edition

| Lua call | Returns | Description |
|----------|---------|-------------|
| `ntop.isForcedCommunity()` | boolean | Forced Community mode |
| `ntop.isPro()` | boolean | Pro or better |
| `ntop.isEnterprise()` | boolean | Enterprise M or better (alias `isEnterpriseM`) |
| `ntop.isEnterpriseM()` | boolean | Enterprise M |
| `ntop.isEnterpriseL()` | boolean | Enterprise L |
| `ntop.isEnterpriseXL()` | boolean | Enterprise XL |
| `ntop.isEnterpriseXXL()` | boolean | Enterprise XXL |
| `ntop.isnEdge()` | boolean | nEdge Pro |
| `ntop.isnEdgeEnterprise()` | boolean | nEdge Enterprise |
| `ntop.isPackage()` | boolean | Running from a package install |
| `ntop.isAppliance()` | boolean | Running on hardware appliance |
| `ntop.isIoTBridge()` | boolean | IoT Bridge mode |

### Platform

| Lua call | Returns | Description |
|----------|---------|-------------|
| `ntop.isWindows()` | boolean | Windows |
| `ntop.isFreeBSD()` | boolean | FreeBSD |
| `ntop.isLinux()` | boolean | Linux |

### Runtime features

| Lua call | Returns | Description |
|----------|---------|-------------|
| `ntop.hasGeoIP()` | boolean | GeoIP databases present |
| `ntop.hasRadiusSupport()` | boolean | RADIUS auth compiled in |
| `ntop.hasLdapSupport()` | boolean | LDAP auth compiled in |
| `ntop.isPingAvailable()` | boolean | ICMP ping usable |
| `ntop.isClickHouseEnabled()` | boolean | ClickHouse backend active |
| `ntop.hasSpeedtestSupport()` | boolean | Speedtest compiled in |
| `ntop.isIPSRulesPublisherConfigured()` | boolean | IPS rules publisher configured |
| `ntop.isFlowDedupEnabled()` | boolean | Flow deduplication active |
| `ntop.getLicenseLimits()` | table | License capacity limits |

---

## 29. Privilege Management

On Unix, ntopng may need elevated privileges for some operations (writing raw
sockets, packet capture) while running as a non-root user after privilege drop.

| Lua call | Returns | Description |
|----------|---------|-------------|
| `ntop.gainWriteCapabilities()` | boolean | Temporarily re-acquire write capabilities |
| `ntop.dropWriteCapabilities()` | boolean | Drop back to low-privilege mode |

---

## 30. Custom Categories & nDPI Reload

Called from `scripts/lua/housekeeping.lua` to hot-reload nDPI configuration.

```lua
-- Typical usage in housekeeping
ntop.initnDPIReload()
ntop.loadCustomCategoryIp(cat_id, "192.168.1.0/24")
ntop.loadCustomCategoryHost(cat_id, "ads.example.com")
ntop.loadCustomCategoryFile(cat_id, "/etc/ntopng/custom_hosts.txt")
ntop.setDomainMask("example.com", 0x1)
ntop.addTrustedIssuerDN("CN=MyCA,O=MyOrg")
ntop.finalizenDPIReload()
```

---

## 31. Flow / Host Checks & Risks

### Check management

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.reloadFlowChecks()` | — | nil | Hot-reload flow check scripts |
| `ntop.reloadHostChecks()` | — | nil | Hot-reload host check scripts |
| `ntop.reloadAlertExclusions()` | — | nil | Hot-reload alert exclusion rules |
| `ntop.getFlowChecksStats()` | — | table | Flow check execution statistics |
| `ntop.getFlowCheckInfo(check_id)` | integer | table | Metadata for a flow check |
| `ntop.getHostCheckInfo(check_id)` | integer | table | Metadata for a host check |

### Risk API

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.getRiskStr(risk_id)` | integer | string | Human-readable risk name |
| `ntop.getRiskList()` | — | table | All known risk ids and names |
| `ntop.getFlowRiskAlerts()` | — | table | Map of risk id → alert type |
| `ntop.shouldResolveHost(ip)` | string | boolean | True if host resolution is warranted |

### IEC 104 / Modbus (OT security)

| Lua call | Params | Description |
|----------|--------|-------------|
| `ntop.setIEC104AllowedTypeIDs(ids_table)` | table | Whitelist IEC 104 type IDs |
| `ntop.setModbusAllowedFunctionCodes(codes_table)` | table | Whitelist Modbus function codes (Pro) |
| `ntop.readModbusDeviceInfo(host, port)` | string, int | Query Modbus device identification |
| `ntop.readEthernetIPDeviceInfo(host, port)` | string, int | Query EtherNet/IP device identification |

---

## 32. In-Memory Lua Cache

A fast in-process cache shared across Lua VMs (does not survive restarts).

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.getLuaCache(key)` | string | any\|nil | Get value from in-process cache |
| `ntop.setLuaCache(key, value [, ttl])` | string, any, int? | nil | Store value with optional TTL |
| `ntop.dumpLuaCache()` | — | table | Dump all cache entries (debug) |

```lua
-- Cache expensive computation for 60 seconds
local cached = ntop.getLuaCache("my_expensive_result")
if not cached then
   cached = computeExpensiveResult()
   ntop.setLuaCache("my_expensive_result", cached, 60)
end
```

---

## 33. Miscellaneous

| Lua call | Params | Returns | Description |
|----------|--------|---------|-------------|
| `ntop.msleep(ms)` | integer | nil | Sleep N milliseconds |
| `ntop.md5(data)` | string | string | MD5 hex digest |
| `ntop.getservbyport(port, proto)` | int, string | string | Service name for port number |
| `ntop.getTLSVersionName(id)` | integer | string | TLS version string (e.g. `"TLSv1.3"`) |
| `ntop.getMac64(mac)` | string | string | Expand 48-bit MAC to 64-bit EUI-64 |
| `ntop.decodeMac64(mac64)` | string | string | Decode EUI-64 back to MAC |
| `ntop.isDeadlineApproaching()` | — | boolean | True if periodic script near deadline |
| `ntop.getDeadline()` | — | integer | Deadline epoch for current periodic script |
| `ntop.speedtest()` | — | table | Run speedtest and return results (Pro) |
| `ntop.getBlacklistStats()` | — | table | IP blacklist hit statistics |
| `ntop.resetBlacklistStats()` | — | nil | Reset blacklist counters |
| `ntop.isOffline()` | — | boolean | True if ntopng is in offline mode |
| `ntop.isForcedOffline()` | — | boolean | True if offline forced via CLI |
| `ntop.setOffline()` | — | nil | Enter offline mode |
| `ntop.setOnline()` | — | nil | Leave offline mode |
| `ntop.serviceRestart()` | — | nil | Restart ntopng service |
| `ntop.shutdown()` | — | nil | Shutdown ntopng (nEdge/Appliance) |
| `ntop.poolsLock()` | — | nil | Acquire pools write lock |
| `ntop.poolsUnlock()` | — | nil | Release pools write lock |
| `ntop.enableAssetsLog()` | — | nil | Enable asset logging |
| `ntop.assetsEnabled()` | — | boolean | True if asset discovery enabled |
| `ntop.overrideInterface(ifname)` | string | nil | Override current interface (Appliance) |
| `ntop.registerRuntimeInterface(params)` | table | nil | Register PCAP or DB runtime interface |
| `ntop.reloadHostPools()` | — | nil | Reload host pool configuration |
| `ntop.reloadDeviceProtocols()` | — | nil | Reload device-protocol rules |
| `ntop.reloadServersConfiguration()` | — | nil | Reload server configurations |
| `ntop.reloadASNConfiguration()` | — | nil | Reload custom ASN configuration |
| `ntop.reloadNetworksPolicyConfiguration()` | — | nil | Reload networks policy (Pro) |
| `ntop.execCmd(cmd)` | string | string\|nil | Execute shell command, return stdout |
| `ntop.execCmdAsync(cmd)` | string | integer | Start async shell command, return handle |
| `ntop.readResultCmdAsync(handle)` | integer | string\|nil | Read output of async command |
| `ntop.logRadius(info)` | table | nil | Log RADIUS authentication event |
| `ntop.updateRadiusLoginInfo(info)` | table | nil | Update RADIUS login state |
| `ntop.addBin(name, val, weight)` | string, number, number | nil | Add data point for similarity binning |
| `ntop.findSimilarities(name)` | string | table | Find similar bins by Euclidean distance |
| `ntop.publish(topic, msg)` | string, string | nil | Publish to message broker (Pro) |
| `ntop.rpcCall(topic, req)` | string, string | string\|nil | Synchronous RPC via message broker (Pro) |
| `ntop.sendKafkaMessage(topic, msg)` | string, string | nil | Send to Kafka topic (Pro+Kafka) |
| `ntop.sendMail(params)` | table | boolean | Send email via SMTP (if compiled) |
| `ntop.getInfluxDBInternalDBName()` | — | string | Internal InfluxDB name |
| `ntop.setInfluxDBInternalDBName(name)` | string | nil | Set internal InfluxDB name |
| `ntop.isInfluxDBInternalAvailable()` | — | boolean | True if internal InfluxDB ready |
| `ntop.setInfluxDBInternalAvailable(v)` | boolean | nil | Set internal InfluxDB availability |
| `ntop.elasticsearchConnection()` | — | table\|nil | Elasticsearch connection details |
| `ntop.toggleNewDeleteTrace(v)` | bool | nil | Debug: trace new/delete calls |
| `ntop.setMacDeviceType(mac, type)` | string, integer | nil | Set device type for MAC address |
| `ntop.checkNetworkPolicy(ip)` | string | table | Evaluate network policy for IP |

---

## Quick-Reference: Common REST API patterns

### Pattern 1 — Simple GET with interface context
```lua
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
local rest_utils = require("rest_utils")
require "lua_utils"

local ifid = _GET["ifid"]
if isEmptyString(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end
interface.select(ifid)
local data = interface.getStats()
rest_utils.answer(rest_utils.consts.success.ok, data)
```

### Pattern 2 — Admin-only POST endpoint
```lua
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
local rest_utils = require("rest_utils")
require "lua_utils"
local json = require("dkjson")

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local body = json.decode(_POST["JSON"] or "{}")
local username = body and body["username"]
if isEmptyString(username) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

local ok = ntop.addUser(username, body["full_name"] or "", body["password"] or "",
                        "unprivileged", "", "")
if ok then
   rest_utils.answer(rest_utils.consts.success.ok)
else
   rest_utils.answer(rest_utils.consts.err.internal_error)
end
```

### Pattern 3 — Redis-backed configuration
```lua
local CONF_KEY = "ntopng.prefs.my_feature"
local json = require("dkjson")
require "lua_utils"
local rest_utils = require("rest_utils")

-- GET: read config
local raw = ntop.getCache(CONF_KEY)
local conf = json.decode(raw or "{}") or {}
rest_utils.answer(rest_utils.consts.success.ok, conf)
```

```lua
-- POST: write config
local body = json.decode(_POST["JSON"] or "{}")
ntop.setCache(CONF_KEY, json.encode(body))
rest_utils.answer(rest_utils.consts.success.ok)
```

### Pattern 4 — Hash-based per-user settings
```lua
-- Store
ntop.setHashCache("ntopng.user." .. username, "my_setting", value)

-- Read
local v = ntop.getHashCache("ntopng.user." .. username, "my_setting")
```

---

*Generated from `src/LuaEngineNtop.cpp` — `_ntop_reg[]` table.*
