---
name: ntop-rest-endpoint-scaffolder
description: >
  Scaffolds new ntopng v2 REST endpoints from inline Lua code, existing module
  functions, or a plain description of what data is needed. Use this skill whenever
  the user says "create a REST endpoint", "put this inline Lua in a REST API",
  "add a v2 endpoint for X", "modernize this REST endpoint", or when the
  ntop-lua-to-vue-porter skill flags a missing endpoint. Navigates the project
  dependency tree, inlines required module logic, and produces a complete,
  ready-to-use v2 endpoint file. Does NOT fire for editing existing endpoints
  that already work, for Vue component work, or for Lua page bootstraps.
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# ntop REST Endpoint Scaffolder

Creates a complete, ready-to-use ntopng v2 REST endpoint. Navigates the dependency
tree, inlines or requires the relevant logic, and outputs a file indistinguishable
from a human-written v2 endpoint.

---

## STOP IMMEDIATELY and ask if any of these are missing

- **No description or inline code given** → ask: "What should this endpoint return? Paste the inline Lua block or describe the data needed."
- **No verb known** → infer from context (`get` for read-only, `set` for writes, `delete`, etc.) and confirm with user if ambiguous.
- **No noun/path known** → propose a path based on the data domain (e.g., license data → `get/ntopng/license.lua`) and confirm before writing.
- **Community vs Pro unclear** → ask: "Is this endpoint community or Pro-only?"

---

## Step 0 — Determine file path

### Path convention
```
Community:  scripts/lua/rest/v2/<verb>/<noun>/<action>.lua
Pro:        pro/scripts/lua/rest/v2/<verb>/<noun>/<action>.lua
```

### Verb selection
| User intent | Verb directory |
|---|---|
| Read / fetch data | `get` |
| Write / update settings | `set` |
| Create a new resource | `add` or `create` |
| Remove a resource | `delete` |
| Run an action | `exec` or `trigger` |

### Noun selection
Match the data domain to an existing noun directory by running:
```
Glob: scripts/lua/rest/v2/<verb>/
```
Reuse an existing noun directory if the domain fits. Propose a new one only if
nothing matches. Confirm the full path with the user before writing.

### Conflict check
If the target file already exists → stop, tell the user the exact path, and ask
whether to overwrite or choose a different name.

---

## Step 1 — Read and understand the input

The input is one of:

**A) Inline Lua block** (pasted from a page being ported)
- Read it directly.
- Identify every `require`, module function call, `_GET`/`_POST` param, and
  `ntop.*` / `interface.*` call present.

**B) Module path(s) provided**
- Read each file at the given path.
- Build a dependency map: for each `require "x"`, locate
  `scripts/lua/modules/x.lua` (or `pro/scripts/lua/modules/x.lua` for Pro) and
  read it too, recursively until the full call chain needed is resolved.
- Identify which specific functions are needed for the endpoint's output.

**C) Plain description only**
- Search for candidate modules:
  ```
  Grep: scripts/lua/modules/ for keywords from the description
  Grep: pro/scripts/lua/modules/ if Pro
  ```
- Read the most relevant module file(s).
- Navigate their `require` chains as in (B) until the needed logic is found.
- If no suitable module exists, the logic will be written inline from scratch.

---

## Step 2 — Resolve the dependency tree

For every function or utility needed in the endpoint:

1. Check if it lives in a `require`-able module → keep the `require` at the top,
   call the function normally.
2. Check if it is scattered ad-hoc Lua (no dedicated module function) → inline
   the logic directly into the endpoint file, cleaned up and self-contained.
3. Check if it calls `ntop.*` or `interface.*` directly → keep those calls; they
   are always available in the endpoint execution context.

**Never** inline an entire module file. Only inline the specific logic needed.
If a module function is reusable and clean, `require` it — do not copy it.

---

## Step 3 — Write the endpoint file

Follow this exact structure (modelled on `get/asn/get_as_data.lua`):

```lua
--
-- (C) 2013-26 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "http_lint"
-- require only what is actually used
local rest_utils = require "rest_utils"
-- local <module> = require "<module>"

--
-- <One-line description of what this endpoint returns>
-- Example: curl -u admin:admin -H "Content-Type: application/json" http://localhost:3000/lua/rest/v2/<verb>/<noun>/<action>.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

-- Parameter extraction
local ifid = _GET["ifid"] or interface.getId()
-- local <param> = _GET["<param>"]

-- Interface selection (include only if endpoint is interface-scoped)
interface.select(ifid)

local res = {}
local rc = rest_utils.consts.success.ok

-- Validation (include only params that are truly required)
-- if isEmptyString(<required_param>) then
--   rest_utils.answer(rest_utils.consts.err.invalid_args)
--   return
-- end

-- Core logic
-- <inlined or module-called logic here>
-- Build res as a flat table of plain values

rest_utils.answer(rc, res)
```

### Output rules (strictly enforced)
| ✅ Return in `res` | ❌ Never return |
|---|---|
| Numbers, booleans, timestamps | HTML tags or fragments |
| Raw string identifiers / keys | CSS color strings |
| URLs (path strings) | Translated label strings (`i18n(...)`) |
| Nested objects where structure is meaningful | Inline `style=` or `class=` attributes |
| `breakdown = { bytes_sent = x, bytes_rcvd = y }` style sub-objects | Formatted/humanized strings (e.g. "1.2 MB") |

### Parameter rules
- Always use `_GET["param"] or <default>` pattern when a sensible default exists.
- Use `isEmptyString(x)` for required param validation, not `x == nil`.
- `ifid` is almost always needed; default to `interface.getId()` if not provided.
- `interface.select(ifid)` only if the endpoint queries interface-specific data.

### Pro endpoints
- File goes in `pro/scripts/lua/rest/v2/<verb>/<noun>/<action>.lua`
- Add a Pro guard at the top after requires:
  ```lua
  if not ntop.isPro() then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
  end
  ```

---

## Step 4 — Validate with lua-lsp

After writing the file, invoke the **lua-lsp plugin** on the new endpoint file.

Fix any errors it reports before proceeding — common issues when inlining logic:
- Undefined globals (a `require` was missed)
- Wrong number of arguments to a module function
- Variable shadowing from inlined blocks
- Scope issues (local declared inside a block, used outside)

Re-run lua-lsp after each fix until the file is clean. Only then proceed to the checklist.

---

## Step 5 — Final checklist

Before finishing, verify:

- [ ] File is at the correct path (community vs Pro)
- [ ] `require "http_lint"` is present
- [ ] `local rest_utils = require "rest_utils"` is present
- [ ] Only modules that are actually used are required
- [ ] `res` contains no HTML, no color strings, no translated labels
- [ ] All required `_GET` params are validated with `isEmptyString`
- [ ] Optional params use `or <default>` fallback pattern
- [ ] `interface.select(ifid)` present only when endpoint is interface-scoped
- [ ] Pro guard present if Pro endpoint
- [ ] File ends with `rest_utils.answer(rc, res)`
- [ ] curl example comment reflects the actual file path
- [ ] lua-lsp reports no errors

---

## Edge cases

| Situation | Handling |
|---|---|
| Inline code calls functions from multiple modules | Require each module; inline only truly ad-hoc fragments |
| Module function does not exist yet | Scaffold it in the appropriate module file and note the addition to the user |
| Endpoint needs both live and historical data paths | Model after `get_as_data.lua` — branch on an `is_live` param |
| Data requires ClickHouse (historical) | Add `hasClickHouseSupport()` guard before historical branch |
| Target file already exists | Stop, report path, ask user whether to overwrite |
| Pro module required in community endpoint | Flag to user — move endpoint to Pro path |
| `res` naturally has nested structure | Allowed only for meaningful sub-objects (e.g. `breakdown`); flatten everything else |