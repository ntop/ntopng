# Asset Tags TTL (expiration)

This document describes how the tags of the assets expire. See
`README.tags.md` for the host tags themselves.

What has been tested, the current test status and how to repeat the tests
are in the "Tests" section at the end of this document.

---

## Overview

Each tag has a **TTL**, in days. A tag is removed from an asset when nothing
has confirmed it for longer than its TTL. A TTL of 0 (the default) means the
tag never expires.

Example: a host answering DNS queries gets the `DNS Server` tag. With a TTL of
30 days, the tag is removed from the asset when no DNS traffic has been seen
for 30 days.

Rules:

- The TTL is per tag, global, and applies to all the 64 tags (built-in 0–31
  and user-defined 32–63).
- A tag is **refreshed** every time it is observed: service seen again, flow
  with the Non-PQC risk, flow of an application or with a risk bound to the
  tag, tag assigned by hand.
- Tags assigned by hand expire too; nothing refreshes them after the
  assignment.
- Tags coming from a configured server list (DNS, NTP, DHCP, SMTP, SSH, RDP,
  PowerShell, FTP, gateway) never expire for the listed addresses. When an
  address is removed from the list, the tag expires a TTL after the last time
  it was observed.
- Changing a TTL applies to the tags already on the assets.
- Deleting (resetting) a user-defined tag removes it from the assets.
  Resetting a built-in tag only resets its configuration.
- The feature is about **assets**. A host in memory keeps its own tag bits
  (see "Host and asset").

Precision: the TTL is in days and a tag can outlive it by up to 12 hours (see
"Timing"). It never expires earlier.

### License

This feature needs **Enterprise L** or above. Without it, the tags of an
asset are simply the tags its host has when it is dumped, as before.

---

## Model

**The asset owns its tags.** For each tag it holds, an asset stores when the
tag was set, when it was last refreshed and where it comes from.

A host does not tell the asset what its tags are, but what happened to them
since its last message.

A tag leaves an asset in three cases only: its TTL has run out, a user removed
it, or the tag was deleted (reset).

Stored in the `json_info` column of the `assets` table (SQLite and
ClickHouse):

```
"tags": 8193,
"tags_info": {
  "0":  { "first": 1791000000, "last": 1791400000, "src": "observed" },
  "13": { "first": 1791000100, "last": 1791000100, "src": "observed" }
}
```

- `tags` is the bitmap of the tags, kept for the filters and the pages. It is
  a signed 64-bit integer (negative when tag 63 is set).
- `tags_info` is the per-tag record. `src` says how the tag was confirmed
  last, with the configuration taking precedence:

| `src` | Meaning |
|---|---|
| `observed` | Seen in the traffic of the host |
| `manual` | Assigned by the user in the host configuration |
| `config` | The host is in a configured server list |
| `seed` | Already set when the record was created |

---

## Architecture

```
                       HOST (C++, in memory)
  flows ──► Host::setService / addTags / setUserTags
              │  tag bits (host page, flows): unchanged
              │  LocalHost: tags_refreshed / tags_assigned / tags_removed
              ▼
        LocalHost::dumpAssetInfo
          when: asset info changed (at most once a minute), host destroyed,
                or pending refreshes of tags with a TTL and last dump older
                than CONST_ASSETS_TAGS_REFRESH_INTERVAL (6 hours)
              │
              ▼
   Redis queue  ntopng.assets_hosts_macs.queue.ifid_<id>
              │
              ▼
   pro/scripts/callbacks/minute-delayed/interface/assets.lua
     1. asset_utils.dumpQueuedEntries()  ──► asset_tags.apply()
     2. asset_utils.expireTags()         ──► asset_tags.expire()
              │
              ▼
   assets table: json_info.tags, json_info.tags_info

   Tag configuration: Redis hash ntopng.prefs.tags, field "ttl" of each tag
   Tag deleted: tag_badge_utils.deleteTag() ──► asset_utils.removeTagFromAssets()
```

### Tag configuration

Each tag record in the Redis hash `ntopng.prefs.tags` has a `ttl` field:

```
{"id":32,"name":"EDR","color":"#33d17a","description":"","reserved":"false",
 "protocols":[1025],"risks":[],"ttl":30}
```

A missing record or a missing `ttl` means 0. Built-in tags have no record
until they are edited.

The TTL is set in the tag modal (`pro/http_src/vue/modal-edit-tag.vue`): a
switch plus a number of days between 1 and 365 (`tag_badge_utils.MAX_TAG_TTL`),
sent as `tag_ttl` to `rest/v2/edit/tag/tag.lua`. `tag_badge_utils.editTag()`
keeps the current TTL when none is given. Saving a tag reloads the tag
configuration, so a new TTL is seen by the running ntopng; a record changed
with `redis-cli` is seen at the next reload or restart.

### Host side (C++)

The tag bits of the hosts are unchanged. A `LocalHost` has three more bitmaps
(24 bytes) describing what happened since its last asset dump:

| Bitmap | Set by | Meaning |
|---|---|---|
| `tags_refreshed_bitmap` | `Host::setService`, `Host::addTags`, `Host::setUserTags` | Tags observed, including tags the host already had |
| `tags_assigned_bitmap` | `Host::setUserTags(bitmap, by_user = true)` | Subset of the refreshed tags that the user has just set by hand |
| `tags_removed_bitmap` | `Host::setUserTags` | User tags the user has just unset |

`Host` has no-op hooks (`setTagsRefreshed`, `setTagsAssigned`,
`setTagsRemoved`) that `LocalHost` overrides, so remote hosts are not
affected.

`setService` and `addTags` must be called every time a service or a tag is
observed, even when the host already has it: the "already set" checks that
were in the callers have been removed.

`LocalHost::dumpAssetJson` (`pro/src/LocalHostPro.cpp`) adds to the snapshot:

| Field | Content |
|---|---|
| `tags` | Current tags of the host. Used only to initialise an asset that has no record yet |
| `tags_refreshed` | `tags_refreshed_bitmap` |
| `tags_assigned` | `tags_assigned_bitmap` |
| `tags_removed` | `tags_removed_bitmap` |
| `tags_pinned` | `Host::getConfiguredTags()`: tags of the services the host is configured for (`Prefs::getServerTypes()`: DNS, NTP, DHCP, SMTP, SSH, RDP, PowerShell, FTP, gateway) |

The three bitmaps are cleared when dumped.

A host is dumped when its asset info changes (as before), and also when it
has pending refreshes of tags with a TTL and its last dump is older than
`CONST_ASSETS_TAGS_REFRESH_INTERVAL` (6 hours). The set of tags with a TTL is
`Ntop::getTTLTagsBitmap()`, built by `TagsMapping` when it parses the tag
records and rebuilt on every `ntop.reloadTagsMapping()`. With no TTL
configured, no extra dump is sent.

How often a flow refreshes a tag:

- **Normal interfaces:** once per flow, when the tag or service is set (tags
  at protocol detection, services mostly at flow end).
- **View interfaces:** at every walker pass while the flow is alive. Viewed
  flows park tags and services on the flow's `IpAddress`, and
  `ViewInterface::viewed_flows_walker` copies them to the host of the view.
  `Host::updateView` does the same when the flow is destroyed.

### Asset side (Lua)

`pro/scripts/lua/modules/asset_tags.lua` is the only place where the tags of
an asset are changed. It has no dependency on the ntop API or on the
database, and every function returns the list of the changes (events):

| Function | Use |
|---|---|
| `apply(tags_info, changes, when)` | Apply a host snapshot |
| `expire(tags_info, ttls, pinned, now)` | Remove the expired tags |
| `remove(tags_info, tags, when, reason)` | Remove some tags (tag deleted) |

`asset_utils.updateData()` takes the tag fields out of the generic merge of
`json_info` and calls `apply()`:

- **Refreshed tag:** added if missing; otherwise `last` becomes the snapshot
  time (the host's `last_seen`) if it is not older. `src` becomes `config` if
  the tag is also pinned, `manual` if it is in `tags_assigned`, `observed`
  otherwise.
- **Pinned tag:** added if missing, with `src` = `config`; if the asset
  already has it, its `src` becomes `config`. Its `last` is not moved by the
  pin alone. The configuration takes precedence as source for as long as the
  host is listed; after it is removed from the list the record keeps saying
  `config` until the next observation.
- **Removed tag:** dropped.
- **First time:** when the asset has no `tags_info`, the record starts from
  the stored bitmap plus the host's current tags, dated with the snapshot
  time.
- Entries that are not host snapshots (e.g. Wazuh) leave the tags untouched.
- Information processed late or twice does not move a tag back in time.

### Expiration

`asset_utils.expireTags(ifid)` is called every minute, after the queue has
been drained, and:

- runs at most once every 6 hours per interface
  (`ntopng.cache.assets.tags_expire.last_run.ifid_<id>`), and only when some
  tag has a TTL;
- reads the host assets that have at least one tag with a TTL (the filter is
  in the SQL query), and for each one removes the tags
  with a TTL, not pinned, whose `last` is older than
  `TTL + 6 hours`. The 6 hours are the time a host can take to report an
  observation, so that a refresh on its way is not missed;
- evaluates the pinned tags at that moment, looking the address and VLAN of
  the asset up in the configured lists (`ntopng.prefs.nw_config_*_list`).
  Entries can be `<ip>`, `<ip>@<vlan>` or `<net>/<bits>`;
- gives a record, dated at that run, to the assets stored before this
  feature that it reads (the others get it at the next snapshot of their
  host);
- stops after 20 seconds and continues at the next run.

`asset_utils.removeTagFromAssets(tag_id)` removes a deleted user-defined tag
from the assets of all the interfaces. It is not called for built-in tags:
for them "delete" only resets the configuration of the tag.

Storage: on SQLite the `json_info` of the row is updated in place; on
ClickHouse a new version of the row is inserted.

### Host and asset

| Case | In sync? |
|---|---|
| Tag newly set on the host | Yes, within about a minute |
| Tag removed by the user on a host in memory | Yes |
| User tag (32–63) expired or deleted on the asset | Yes: `removeHostUserTags()` removes it from the host too |
| Built-in tag expired on the asset | No: the host keeps it until it is purged |
| Address removed from a configured list | No: the host loses the tag at once, the asset after the TTL |
| Tag added or removed by hand on a host not in memory | No: the asset is not updated |

A user tag bound to an application or risk that is removed from the host
comes back at the next matching flow, and then on the asset.

---

## Timing

| Event | Accuracy |
|---|---|
| Tag set | About a minute |
| Tag refreshed | Recorded up to 6 hours after the observation, never before |
| Tag removed by hand | About a minute |
| Tag expired | Between `TTL + 6 hours` and `TTL + 12 hours` after the recorded refresh |

---

## Test mode

To test without waiting days, set the Redis key
`ntopng.prefs.tags_ttl_test_mode` to `1` and restart ntopng:

| | Normal | Test mode |
|---|---|---|
| TTL unit | days | minutes |
| Refresh dump interval | 6 hours | 1 minute |
| Expiration frequency | 6 hours | 1 minute |
| Expiration margin | 6 hours | 1 minute |

ntopng logs a warning at startup when it is enabled. It needs a live
interface: periodic scripts do not run on pcap files.

Example:

```
redis-cli SET ntopng.prefs.tags_ttl_test_mode 1
redis-cli HSET ntopng.prefs.tags 0 '{"id":0,"name":"DNS Server","description":"","color":"#0d6efd","reserved":"true","risks":[],"protocols":[],"ttl":3}'
# restart ntopng, then query a local DNS server for a while and stop:
# the tag is removed from the asset 4-6 minutes after the last query
```

## Logs

With the assets log enabled (`ntopng.prefs.enable_assets_log`, toggle in the
preferences; a value changed with `redis-cli` is read at the next restart):

```
Assets stored for interface <name> [ifid: <id>]: <n>                    (startup)
Stored asset <key> [ip: ...][name: ...] tags: 0 [observed][first: ...][last: ...], ...
Asset <key>: tag <id> added [reason: observed|manual|config|seed][when: <epoch>]
Asset <key>: tag <id> refreshed [last: <old> -> <new>]
Asset <key>: tag <id> removed [reason: removed|expired|deleted][when: <epoch>]
Asset tags expiration [ifid: <id>]: <n> tags with a TTL, <n> assets with tags, <n> assets changed
```

The host snapshots can be seen in the Redis queue for up to a minute:

```
redis-cli LRANGE ntopng.assets_hosts_macs.queue.ifid_<id> 0 -1
```

---

## History of the tags (not implemented)

Every change to the tags of an asset goes through `asset_tags.lua`, which
returns events:

```
{ tag_id = 13, action = "add" | "remove", when = <epoch>, reason = <reason> }
```

Today they are only logged. Storing them in a table gives the history of the
tags of an asset; the two places are marked with a `TODO` in
`asset_utils.lua` (`applyTagChanges`, `changeAssetsTags`). A refresh is not
an event.

---

## Known limitations and open items

- **Long-lived flows (normal interfaces):** a tag set at the start of a flow
  is not refreshed while the flow stays open. If one flow lasts longer than
  the TTL, the tag expires while the flow is active and comes back with the
  next flow.
- **Hosts not in memory:** a tag added or removed by hand does not reach the
  asset. The same call looks hosts keyed by MAC up by IP, so the host sync
  can miss their persisted tags.
- **Built-in tags** are not removed from a host in memory when they expire on
  its asset.
- **Gateway tag:** it has no traffic source. When the address is removed from
  the list, the tag expires a TTL after it was first pinned.
- **IPv6 in the configured lists:** plain addresses are compared as text, so
  a non-canonical form does not match.
- **History** of the tags is not stored.

Unrelated issues found on the way:

- **DNS Server attribution.** `Flow::updateUDPHostServices()` requests a flow
  swap when it sees a DNS response in the client-to-server direction. When
  the dissection is ended by force (flow idle or destroyed) the direction
  passed is a fixed `true`, so a normal query/response flow whose response
  has no answers (NXDomain, ServFail) gets a swap request that is never
  executed, and the DNS Server service goes to the client. Candidate fix,
  tried and not applied: request the swap for a response only when no packet
  has been seen in the other direction.
- **Apostrophes and backslashes in asset values** are stored doubled
  (`it's` becomes `it''s`): they are escaped twice, in `cleanValues` and in
  `insertHost`. When an asset is updated the stored values go through
  `cleanValues` again, so a value that is not sent again by the host is
  doubled once more at every update. The tag expiration writes the asset
  without going through that path and does not add to it.

---

## Tests

### Current status

| Area | How | Status |
|---|---|---|
| `asset_tags.lua` (apply, expire, remove) | Standalone test, see below | 88 checks pass |
| Host snapshot fields: observed service, mapped tag, manual add and remove, configured list | pcap replay, snapshots read from the Redis queue | As expected |
| TTL mask parsing and reload when a tag is edited | Temporary trace | As expected |
| Asset side on SQLite and on ClickHouse (26.9): apply, expiry, pin check by address and by network, assets stored before the feature, host sync, rate limit, tag deletion, TTL kept on edit, list badges, tag filter with tag 63, expiry query limited to the assets with a tag that has a TTL | Synthetic snapshots pushed to the queue of a real ntopng | As expected |
| License gate, Lua side (asset update, expiry, TTL edit) | Same, with the license check forced to false | As expected |
| Live, normal interface, ClickHouse, test mode | Live tests 1 to 9 below | All pass |
| Live, view interface, ClickHouse, test mode | Live test 5 on `view:all` (and test 1 in passing) | Pass |
| e2e `tags_application_based_01`, `tags_host_user_defined_01`, `get_host_active_01`, `get_interface_address_01` | `tests/e2e/rest` | Pass |

Not tested:

- licenses below Enterprise L on the C++ side (compiled only);
- normal-mode timing (TTL in days, 6-hour intervals): test mode replaces it;
- SQLite on a live interface (only through the synthetic snapshots);
- live tests 2 to 4 and 6 to 9 on a view interface;
- the configuration as source of a tag that is also observed, on a live
  host (standalone test only);
- large tables (the 20-second budget of the expiration);
- collected flows (ZMQ).

Standalone test of `asset_tags.lua` (from the ntopng root):

```
third-party/lua-5.4.6/src/lua pro/tests/lua/asset_tags_test.lua
```

### Live tests

These are the tests run by hand, in test mode, with the assets stored in
ClickHouse and the TTLs set from the tag dialog. They are the checklist to
repeat after a change to this feature.

#### Overview

| # | Test | Why it is useful | What to expect | Result |
|---|---|---|---|---|
| 1 | A service tag (DNS Server) with a TTL, with traffic | The basic path: a host observation reaches the asset and keeps the tag alive | Tag added, then refreshed about once a minute | Pass |
| 2 | Same tag, traffic stopped | The feature itself: a tag nobody confirms goes away | Tag removed with reason `expired`, at the first pass after TTL + margin | Pass |
| 3 | Same tag on a host in the configured DNS list, then removed from the list | The exception: configured hosts never expire, and fall back to the last observation when unlisted | Tag kept while listed, whatever the TTL; removed at the next pass once unlisted | Pass |
| 4 | A user tag with a TTL assigned by hand | A manual tag is a temporary annotation; also checks that host and asset stay in sync | Added with reason `manual`, never refreshed, expired, removed from the host too | Pass |
| 5 | A user tag bound to an application, with traffic, then without, then one more flow | Tags used as rules ("hosts using X") must follow the behaviour of the host | Added with reason `observed`, refreshed by each flow, expired, added again by the new flow | Pass |
| 6 | A user tag without TTL assigned by hand, then removed by hand | TTL 0 must keep today's behaviour; manual removal must reach the asset | Never expires; removed with reason `removed` within a minute | Pass |
| 7 | Reset of a user tag that an asset has | A deleted tag must not survive on the assets | Removed at once with reason `deleted`, logged by the reset request | Pass |
| 8 | TTL raised just before the expiration, then lowered | A TTL change must apply to the tags already on the assets | Kept after raising the TTL; removed at the next pass after lowering it | Pass |
| 9 | Restart | The tags, with their times, must be stored | The startup listing shows the same tags, sources, `first` and `last` | Pass |

Test 5 has also been run on a view interface (see "View interface" below).

#### Setup

Requirements: Enterprise L (or above), a live interface, ClickHouse (or leave
`-F clickhouse` out to use SQLite), a frontend bundle that has the TTL field
in the tag dialog.

```
redis-cli SET ntopng.prefs.tags_ttl_test_mode 1
redis-cli SET ntopng.prefs.enable_assets_log 1
echo 'host:"sentinel.com"@Sentinel=1025' > ~/protos.txt

sudo ./ntopng --dont-change-user -i <iface> -p ~/protos.txt -F clickhouse \
     -m "<local network>,8.8.8.8/32" 2>&1 \
  | grep --line-buffered -E 'Asset |Stored asset|Assets stored|test mode'
```

- `-m ...,8.8.8.8/32` makes 8.8.8.8 a local host, hence an asset: it is a DNS
  server nothing else on the machine talks to, so its traffic is fully under
  control. The resolver of the machine cannot be used for test 2, as the
  system, ntopng itself and anything else running keep querying it.
- `-p ~/protos.txt` defines the application used in test 5.
- In test mode every TTL set in the tag dialog is in **minutes**, although
  the field says "Days".
- At startup the log shows the test-mode warning and the stored assets.

How to read the log:

- the time at the start of a line is when the asset script processed the
  information; the `when` / `last` values are when it happened on the host;
- every minute or so: `Asset tags expiration [ifid: N]: X tags with a TTL, Y
  assets with those tags, Z assets changed`. A run that comes less than 50
  seconds after the previous pass skips it;
- a tag with TTL N expires at the first pass later than N + 1 minutes after
  its `last`. For a service tag, `last` is about a minute after the last
  packet, as a service is recorded when the flow ends;
- names that do not resolve must be avoided in the DNS tests (see the DNS
  Server attribution issue in "Known limitations and open items").

To look at the stored assets:

```
clickhouse-client -d ntopng -q "SELECT key, version, JSONExtractInt(json_info,'tags') AS tags, JSONExtractRaw(json_info,'tags_info') AS info FROM assets WHERE type='host' ORDER BY key, version"
```

At the end: `redis-cli SET ntopng.prefs.tags_ttl_test_mode 0`, and restart.

#### Tests 1 and 2: service tag, refresh and expiration

1. Tags page: give `DNS Server` a TTL of 3.
2. `while true; do dig @8.8.8.8 example.com +short; sleep 10; done`
3. Expect `Asset 0_8.8.8.8@0: tag 0 added [reason: observed]`, then
   `tag 0 refreshed [last: ... -> ...]` about once a minute, and the tag on
   the Assets page. The summary line counts one more asset.
4. Stop the loop.
5. Expect `tag 0 removed [reason: expired]` 4 to 6 minutes after the last
   `last`, `1 assets changed` on that pass, and the tag gone from the Assets
   page. The asset of the machine's resolver keeps its tag.

#### Test 3: configured host

1. Network Configuration: add `8.8.8.8` to the DNS servers.
2. Run the loop of test 1 for a few minutes, stop it, wait 8 minutes.
3. Expect `tag 0 added` (reason `config`, or `observed` if a query ended
   first), refreshes while the loop runs, and **no** removal afterwards:
   every pass reports `0 assets changed`. The stored `src` is `config`.
4. Remove `8.8.8.8` from the list. (With ntopng stopped:
   `redis-cli SET ntopng.prefs.nw_config_dns_list ""`, then start it.)
5. Expect `tag 0 removed [reason: expired]` at the next pass.

#### Test 4: manual tag with a TTL

1. Tags page: edit a user tag (e.g. `Customizable_Tag_33`), TTL 2.
2. Host page of a local host, configuration: assign the tag.
3. Expect `tag 33 added [reason: manual]` within a minute or two, and no
   `tag 33 refreshed` line afterwards.
4. Expect `tag 33 removed [reason: expired]` 3 to 5 minutes after the
   assignment. After a reload the tag is gone from the host page and
   configuration too, and
   `redis-cli GET ntopng.prefs.host_tags_bitmap.<ifid>_<host key>` does not
   have its bit any more.

#### Test 5: tag bound to an application

1. Tags page: edit a user tag (e.g. `Customizable_Tag_32`), name `EDR`,
   Applications `Sentinel`, TTL 3.
2. `while true; do curl -s -o /dev/null https://www.sentinel.com; sleep 20; done`
   (the flow must be classified as `TLS.Sentinel`).
3. Expect `tag 32 added [reason: observed]` on the asset of the client, then
   `tag 32 refreshed` about once a minute.
4. Stop the loop: expect `tag 32 removed [reason: expired]` 4 to 6 minutes
   after the last `last`, and the tag gone from the host too.
5. One more `curl`: expect `tag 32 added [reason: observed]` again.

#### Test 6: tag without TTL

1. Assign by hand a user tag whose TTL is off.
2. Expect `added [reason: manual]`. Wait longer than any TTL in use: no
   removal, and the asset is not counted in the summary line unless it has
   another tag with a TTL.
3. Remove the tag from the host configuration.
4. Expect `removed [reason: removed]` within a minute or two.

#### Test 7: reset of a user tag

1. Edit a user tag (a tag never edited cannot be reset), TTL off, and assign
   it by hand to a host. Wait for `added [reason: manual]`.
2. Tags page: open the tag and press Reset.
3. Expect, within seconds, `tag <id> removed [reason: deleted]`, logged from
   `tag.lua` rather than from `assets.lua`. The tag is gone from the asset
   and, after a reload, from the host.

#### Test 8: TTL changed before the expiration

1. Assign by hand a user tag with TTL 2 (as in test 4). Note the time, T0.
2. Before T0 + 3 minutes, change the TTL of the tag to 10.
3. Until T0 + 7 minutes expect no removal.
4. Change the TTL back to 2.
5. Expect `removed [reason: expired]` at the next pass.

#### Test 9: restart

1. With some tags on the assets, restart ntopng.
2. Expect, in the startup listing, the same tags with the same sources,
   `first` and `last`.

#### View interface

Same tests, with a view: add `-i view:all` to the command line.

- The hosts and the assets are on the view: the log lines say `[ifid: <view
  id>]`, the asset keys start with the id of the view, and in the GUI the
  view has to be selected. The viewed interface reports `0 assets with those
  tags` and has no asset lines.
- The assets stored for the viewed interface when it was running alone stay
  in the database with no host behind them: their tags with a TTL expire.
- A tag is refreshed at every pass of the walker while its flow is alive, so
  the last refresh can be a minute or two after the traffic has stopped: the
  expiration has to be counted from the last `refreshed` line.
