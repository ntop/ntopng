# User-Defined Host Tags

This document describes the implementation of user-defined host tags.

---

## Overview

Host tags allow operators to tag individual hosts with one or more named tags
for filtering, classification, and display purposes.  Tags are stored as a
64-bit bitmap on each host; bits 0–31 are reserved for ntop-internal use, while
**bits 32–63 are user-customizable**.

---

## Architecture

The feature spans three layers: the C++ core, the Lua scripting layer, and the
Vue.js frontend.

```
┌────────────────────────────────────────────────────┐
│  Frontend (Vue)  page-host-config.vue              │
│  REST calls:  GET  /lua/rest/v2/get/host/config.lua│
│               POST /lua/rest/v2/set/host/config.lua│
│               GET  /lua/rest/v2/get/tag/           │
│                        tags_list.lua               │
└───────────────────────┬────────────────────────────┘
                        │ HTTP / JSON
┌───────────────────────▼────────────────────────────┐
│  Lua layer                                         │
│  interface.getHostTags(ip)    →  bitmap (integer)  │
│  interface.setHostTags(ip, bitmap)                 │
└───────────────────────┬────────────────────────────┘
                        │ C-API
┌───────────────────────▼────────────────────────────┐
│  C++ core                                          │
│  NetworkInterface::host_tags  (TagsConfiguration)  │
│  Redis  ntopng.prefs.host_tags_bitmap.<iface>_<key>│
│  Host::tags_bitmap  (per-host field)               │
└────────────────────────────────────────────────────┘
```

---

## Bitmap Layout

| Bits  | Owner             | Description                         |
|-------|-------------------|-------------------------------------|
| 0–31  | ntop (reserved)   | Internal / system-defined tags      |
| 32–63 | User-customizable | Operator-defined tags via the UI    |

The built-in tag IDs for bits 0–31 are defined by the `HostTagId` enum in
`include/ntop_defines.h` (e.g. `HOST_TAG_DNS_SERVER = 0`,
`HOST_TAG_PROFINET_SERVER = 12`).

The default tag table (`tag_badge_utils.lua`) initialises slots 32–63 with
placeholder entries (`Customizable_Tag_<N>`).  Operators customise names and
colors through the Tags page in the GUI.

The mask for user-customizable bits is `HOST_USER_TAGS_MASK` (defined in
`include/ntop_defines.h`).

---

## C++ Layer

### `TagsConfiguration` (`include/TagsConfiguration.h`, `src/TagsConfiguration.cpp`)

Manages per-interface host-tag bitmaps in memory using a `VLANAddressTree`,
with Redis persistence.

| Symbol | Description |
|--------|-------------|
| `u_int64_t getTags(const char* mac)` | Lookup by MAC address string. |
| `u_int64_t getTags(const IpAddress* ip, u_int16_t vlan)` | Lookup by IP + VLAN. |
| `u_int64_t getTags(const char* key)` | Lookup by raw key string. |
| `void setTags(const char* key, u_int64_t bitmap)` | Update in-memory tree and persist to Redis. Deletes the key when `bitmap == 0`. |
| `void loadFromRedis(int iface_id)` | Called from `NetworkInterface::startPacketPolling()`. Scans Redis for all matching keys and populates the in-memory tree. |

**Redis key format** (defined in `include/ntop_defines.h`):

```
ntopng.prefs.host_tags_bitmap.<iface_id>_<key>   (full key for a specific host)
ntopng.prefs.host_tags_bitmap.                    (prefix used for wildcard scan)
```

### `NetworkInterface` (`include/NetworkInterface.h`, `src/NetworkInterface.cpp`)

| Symbol | Description |
|--------|-------------|
| `TagsConfiguration host_tags` | Per-interface tag store. |
| `u_int64_t getHostTags(Host* h)` | Returns the tag bitmap for the given host (dispatches to `host_tags.getTags()` by MAC or IP+VLAN). |
| `void setHostTags(Host* h, u_int64_t bitmap)` | Updates the tag store and propagates to the live `Host` object. |

### `Host` (`include/Host.h`, `src/Host.cpp`)

| Symbol | Description |
|--------|-------------|
| `u_int64_t tags_bitmap` | Per-host field, initialised from `iface->getHostTags(this)` inside `Host::initialize()`. |
| `u_int64_t getTags() const` | Returns the full bitmap (built-in + user tags). |
| `u_int64_t getUserTags() const` | Returns only user-defined bits (`tags_bitmap & HOST_USER_TAGS_MASK`). |
| `void setTags(u_int64_t bitmap)` | Updates the in-memory field and delegates to `iface->setHostTags()` for persistence. |
| `void lua_get_tags(lua_State* vm)` | Pushes `"tags"` → bitmap into the Lua table built by `Host::lua()`. |

### `Flow` (`include/Flow.h`, `src/Flow.cpp`)

`Flow::getTags()` ORs the bitmaps of the client and server hosts so that the
combined tag set is available for flow-level filtering and display:

```cpp
u_int64_t Flow::getTags() {
    u_int64_t bm = 0;
    if (cli) bm |= cli->getTags();
    if (srv) bm |= srv->getTags();
    return bm;
}
```

The combined bitmap is pushed under the key `"tags"` (top-level flow table) and
`"cli.tags"` / `"srv.tags"` (per-endpoint info table).

### ClickHouse (`pro/include/FlowsTable.h`, `pro/src/ClickHouseDB.cpp`)

The `FLOWS_TAGS_MAP` column (`TAGS_MAP` in the DB schema) stores the flow tag
bitmap as a hex string, written by `ClickHouseDB` during flow export.

---

## Lua Layer

### `interface.*` C-API bindings (`src/LuaEngineInterface.cpp`)

| Lua function | Description |
|---|---|
| `interface.getHostTags(ip)` | Returns the full tag bitmap for a host (integer). |
| `interface.getUserDefinedHostTags(ip)` | Returns only user-defined bits. |
| `interface.setHostTags(ip, bitmap)` | Persists a new tag bitmap for a host. |

All functions accept an optional `@vlan` suffix on the IP string.

### `tag_badge_utils.lua` (`scripts/lua/modules/tag_badge_utils.lua`)

Central module for managing tag definitions stored in Redis under
`ntopng.prefs.tags`.

| Function | Description |
|---|---|
| `getTags()` | Returns the full tag list (built-in + user-defined). |
| `editTag(id, name, color, description, reserved, protocols, risks, ttl)` | Create or update a tag entry. `ttl` is the number of days (1-365) after which the tag expires, 0 means never. |
| `deleteTag(id)` | Remove a user-defined tag (resets to default placeholder name). |

### REST endpoints

| Verb | Path | Description |
|------|------|-------------|
| `GET`  | `/lua/rest/v2/get/tag/tags_list.lua`   | Returns the full tag list from `tag_badge_utils.getTags()`. |
| `GET`  | `/lua/rest/v2/get/host/config.lua`     | Includes `tags` (full bitmap) and `user_tags` (user bits only) fields. |
| `POST` | `/lua/rest/v2/set/host/config.lua`     | Reads `host_tags_bitmap` POST parameter and calls `interface.setHostTags()`. |
| `GET`  | `/lua/rest/v2/get/host/host_filters.lua` | Appends a `tags` filter group built from the configured tag list. |
| `GET`  | `/lua/rest/v2/edit/tag/tag.lua`        | Create or update a tag via `tag_badge_utils.editTag()`. |
| `DELETE` | `/lua/rest/v2/delete/tag/tag.lua`    | Delete a tag via `tag_badge_utils.deleteTag()`. |

### `http_lint.lua` (`scripts/lua/modules/http_lint.lua`)

Validated parameters related to tags:

| Parameter | Validator | Notes |
|-----------|-----------|-------|
| `tag_id` | `validateNumber` | Bit index identifying a tag |
| `tag_name` | `validateUnquoted` | Display name for a tag |
| `host_tags_bitmap` | `validateNumber` | 64-bit bitmap submitted from the host-config page |

---

## Data Flow Summary

```
Startup
  NetworkInterface::startPacketPolling()
    host_tags.loadFromRedis(iface_id)
      Redis scan "ntopng.prefs.host_tags_bitmap.<iface_id>_*"
      → populate VLANAddressTree

Host creation
  Host::initialize()
    tags_bitmap = iface->getHostTags(this)   // tree lookup, no Redis read

User assigns tags via GUI
  POST /lua/rest/v2/set/host/config.lua  {host_tags_bitmap: "N"}
    interface.setHostTags(ip, N)               // Lua API
      NetworkInterface::setHostTags(h, N)
        host_tags.setTags(key, N)              // update in-memory tree
        redis->set("ntopng.prefs.host_tags_bitmap.<iface>_<key>", "N")
        h->setTags(N)                          // update active Host object

Host display / filtering
  Host::lua()  →  "tags" key in Lua table
  Flow::lua()  →  "tags", "cli.tags", "srv.tags" keys

ClickHouse export
  Flow::getTags()  →  TAGS_MAP column (hex string)
```

---

## Adding New Tags

1. Add an entry to the tag table managed by `tag_badge_utils.lua` choosing a
   bit index in the range **32–63**.
2. Assign a `name`, `color`, and optionally `description`.
3. The tag will automatically appear in the host-config dropdown and the
   active-hosts filter without any further C++ changes.

To add a system/reserved tag (bits 0–31), add a new value to the `HostTagId`
enum in `include/ntop_defines.h`, update the C++ code that sets that bit on the
`Host` object, and add a corresponding built-in entry in `tag_badge_utils.lua`.
