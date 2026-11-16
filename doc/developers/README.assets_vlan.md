# Assets: the VLAN is not part of the key of the host assets (design)

A host asset is identified by its IP address, not by IP and VLAN: the hosts
with the same IP on several VLANs (one host per IP and VLAN in ntopng) update
one asset, and the VLAN is an attribute of the asset (issue #11208, "Ignore
VLAN In Assets").

User guide: `doc/src/user_interface/network_interface/interface/assets.rst`
("Hosts seen on several VLANs"). Journal: `README.assets_journal.md`
("VLANs").

## Decisions

| # | Decision |
|---|---|
| 1 | No preference: the VLAN is never part of the key of a host asset |
| 2 | Key: `<ifid>_<ip>@0`, whatever the VLAN (the key of the hosts without VLAN: nothing changes on the installations without VLANs) |
| 3 | The key is computed in Lua from the `ip` of the snapshot; C++ does not know about it. The persistent user tags of the hosts and the tags of the network configuration are per `ip@vlan` (the short key format of `LocalHost::getSerializationKey`, `TagsConfiguration`) |
| 4 | MAC-keyed assets (`<ifid>_<MAC>_v4/_v6`: hosts in the local broadcast domain, DHCP hosts) are not affected |
| 5 | VLANs of an asset: column `vlans` (list) and `vlan` (the VLAN seen last); details per VLAN in `json_info.vlans` |
| 6 | MAC and the fields that come from it: kept only when all the VLANs that report a MAC agree on it, otherwise none. No time window |
| 7 | Assets with a VLAN in the key (written by older versions) are converted at startup (see "Conversion"): afterwards no asset has a key with a VLAN |
| 8 | Different devices with the same IP on different VLANs (address spaces reused per VLAN) are merged: documented in the user guide |

## Key

`asset_keys.lua` (no ntopng dependencies, tested standalone):

| Function | Use |
|---|---|
| `hostKey(ifid, ip)` | `<ifid>_<ip>@0` |
| `normalizeHostKey(key)` | `<ifid>_<ip>@<vlan>` -> `<ifid>_<ip>@0`; other keys (MAC based) unchanged |
| `isIpHostKey(key)`, `isLegacyHostKey(key)` | Key made of the IP; IP key with a VLAN other than 0 (written by an older version) |
| `legacyKeySQL(is_clickhouse)` | SQL condition on the keys with a VLAN other than 0 (SQLite `LIKE`, ClickHouse `match`/`endsWith`) |

`asset_utils.insertHost` normalizes the key of every snapshot (also the ones
already queued), `import_assets` the keys of the imported host rows (exports
of older versions), `getHostAssetKey(ifid, ip, vlan)` finds the `@0` asset of
the IP or the MAC-keyed asset of that host.

## VLANs of an asset

- Column `vlans`: ClickHouse `Array(UInt16) DEFAULT []`, SQLite `TEXT`
  (`",15,188,"`, so that a VLAN is matched with `LIKE '%,15,%'`). In the
  three schemas (`db_schema_clickhouse.sql`, `db_schema_clickhouse_cluster.sql`,
  `alert_store_schema.sql`), added with `ALTER TABLE ... ADD` to the existing
  tables.
- `vlan`: the VLAN seen last (the lowest one when more are seen at the same
  time, so that it does not change at every snapshot).
- `json_info.vlans`: `{ "<vlan>": { last_seen, mac, router, tags, usernames } }`
  (`tags` with Enterprise M only), what the host of each VLAN reported last.
- An asset with an empty `vlans` and no `json_info.vlans` has the VLAN of its
  column `vlan`.
- CSV export/import: the list travels in `json_info`; the column is written
  again by the next snapshot of the host.

## Merge rules

`asset_merge.lua` (no ntopng dependencies, tested standalone), applied by
`asset_utils.updateData`:

| Field | Rule |
|---|---|
| `vlans`, `vlan` | Union of the VLANs (`mergeVlans`; a snapshot older than the stored info of its VLAN is ignored), the VLAN seen last |
| `last_seen` | `max(stored, snapshot)`; the journal keeps the time of the snapshot |
| `mac`, `manufacturer` | `chooseMac`: the MAC of all the VLANs that report one; when they disagree, none (cleared once: journal `field_cleared`), set again when the disagreement ends |
| `device_type`, `model`, `ssid`, `dhcp_fingerprint`, `router` (`MAC_FIELDS`, from the MAC: `Mac::dumpAssetInfo`) | Cleared with the MAC |
| Names (`dhcp_name`, `dns_name`, `mdns_*`, `tls_name`, `http_name`, `netbios_name`, `kerberos_name`), `os_type`, `model`, `device_type` | A value missing in a snapshot keeps the stored one (`keepMissing`): the stored names and these columns are not in the stored `json_info` (`partiallyFormatInfo`, `insertHost`), and the host of another VLAN may not report them |
| `name` column | One VLAN: the name of the host. More VLANs: `assetName` from the merged names (order of `Host::get_name()`: DHCP, DNS, mDNS TXT, mDNS, TLS, HTTP; the server name is not in the snapshots). Never an empty value or an address |
| Tags (`refreshed`, `assigned`, `removed`) | The changes reported by the host of any VLAN (see `asset_tags.lua`); the last seen time of a tag never moves back |
| Tags `pinned` (network configuration, per `ip@vlan`) | With more VLANs, the tags configured for the IP with any VLAN of the asset (merge and `expireTags`): the source stays "configuration" and the tags do not expire |
| `tags` with Enterprise M (the tags of an asset are the ones of its hosts) | `unionTags`: the union of the tags of its VLANs |
| `usernames` (`"<name> (<protocol>), ..."`, `LocalHost::setUsername`) | `unionUsernames`: the union of the usernames of its VLANs, sorted (the host sends its whole list in every snapshot: a username goes away when no VLAN reports it any more) |

Entries that are not snapshots of a host (the Wazuh update,
`wazuh_utils.lua`: `entry.from_asset`) keep the stored VLANs and MAC.

The SQLite upsert of `insertHost` updates all the columns, as ClickHouse
writes a new version of the whole row.

When the stored asset cannot be read (e.g. SQLite "database is locked",
ClickHouse not reachable) `updateData` skips the snapshot (warning "its update
is skipped"): written as a new asset, it would replace the stored one and lose
the other VLANs and the history of its tags. The host sends a new one later.

## Reading

| Place | Behaviour |
|---|---|
| Online status (`getHostsAssets`, `asset_details.lua`) | Online when the host of any VLAN of the asset is active (`hostAssetVlans`) |
| REST `get/host/assets.lua`, `get/host/asset_details.lua` | `host.vlans` / `vlans`: `[{ id, name, online }]`; `host.vlan` / `vlan` the VLAN seen last |
| VLAN filter (`build_where`, `getFilters`) | On any VLAN of the asset (`vlanCondition`); counts: ClickHouse `arrayJoin` on the latest version of the rows (`FINAL`), SQLite in Lua |
| User tags (`get/set host/config.lua`) | Read and written for `ip@vlan`. Set or removed on the hosts of every VLAN of the asset (`getIpAssetVlans`), live hosts and persistent keys, so that the asset and its hosts agree; one journal entry. The optional `ifid` is selected (`INVALID_INTERFACE` when it cannot be); a host not active on the interface answers `NOT_FOUND` |
| Tags removed from an asset (`removeHostUserTags`) | From the hosts of all its VLANs |
| `assets_total_traffic.lua` | One element per VLAN of the asset with traffic: `host` is `ip@vlan` (the plain IP on VLAN 0) |
| `local_hosts_report.lua` | The traffic of the host of the VLAN seen last (`ip@vlan`) |
| LLM tool `get_asset_info` | `vlan` matches any VLAN of the asset |
| Daily duplicates (`duplicatedHostAssets`) | A MAC-keyed asset and the `@0` asset of the same IP, when the VLAN of the first one is one of the VLANs of the second one: the one seen last is kept |
| Assets list (GUI) | `VLANs` column (`tables_config/assets.json`): up to 3 badges (online first, then by id, untagged last; a badge links to the live host when active) and a `+N` dropdown with the other VLANs, as the alerts of the live flows (4 VLANs: 4 badges, never `+1`). Dropped in `handleLoadedColumns` when the VLAN filter has no VLAN other than 0 (`TableWithConfig` passes its filters, loaded before the table mounts). The icon of the live host next to the IP links to the host when the asset has no VLANs; otherwise it is not a link, and its tooltip points to the badges |
| Asset details (GUI) | VLANs row with the same badges; the icon of the live host as in the list |
| Journal (GUI) | The Asset column shows the IP; historical flows open without VLAN filter |

## Conversion

Older versions recorded a host seen on several VLANs once per VLAN (key
`<ifid>_<ip>@<vlan>`). At startup (`pro/scripts/callbacks/system/startup.lua`,
before `asset_utils.init()`), `asset_utils.convertLegacyAssets()` converts them,
interface by interface:

- one query finds the IPs with such keys: when there are none, this query is
  the whole cost of a startup;
- the assets keyed by IP of each of those IPs (the ones with a VLAN, and the
  `@0` one if any) become one `@0` asset (`asset_merge.convertAssets`, pure,
  tested standalone), as if the hosts of all the VLANs had always updated it:
  `json_info.vlans` from each row, VLAN list, VLAN seen last, MAC only when the
  VLANs agree (otherwise none, with the fields that come from it), the newest
  value set of each column and `json_info` field, first/last seen min/max,
  usernames union, tags merged (`asset_tags.merge`: per tag the latest
  refresh and the earliest first time; one OS tag, the one refreshed last;
  Enterprise M: bitmap union), version + 1 on ClickHouse;
- the converted assets are written `CONVERTED_ASSETS_BATCH_SIZE` (500) per
  statement: on ClickHouse one part per batch, not per asset (10,000 assets
  and 100,000 journal entries: about 3 seconds);
- the rows with a VLAN are deleted; their journal entries moved to the `@0`
  key (SQLite `UPDATE`; ClickHouse `INSERT ... SELECT` with the new key, then
  `ALTER TABLE ... DELETE`, as the key is part of the sorting key);
- one journal entry with no key (`convertedAssetsEntry`, Update / vlan:
  "Assets recorded per VLAN by an older version (N) converted into one asset
  per IP address (M)"); in the log a line when the conversion starts and one
  when it ends, with its duration;
- on a write error the conversion stops before deleting anything: it is done
  again at the next startup (the merge gives the same `@0` asset).

The MAC-keyed assets are left as they are.

## Tests

- Standalone Lua tests (`pro/tests/lua/`): `asset_keys_test.lua`,
  `asset_merge_test.lua`, `asset_tags_test.lua`, `assets_journal_test.lua`.
- e2e (`tests/e2e/rest`): `assets_vlan_l2_01` and `assets_vlan_routed_01`
  check what the host of each VLAN reports. Pcaps made of 400 packets of
  192.168.1.93 from `test_01.pcap`: `assets_vlan_l2.pcap` (the same packets on
  VLAN 15, 188, 192) and `assets_vlan_routed.pcap` (VLAN 15, and VLAN 188 after
  a router: the MAC of the router on the side of the host, TTL decreased by
  one).
- The assets themselves cannot be checked by e2e (the queue of the assets is
  never processed on pcap interfaces): they need a live ntopng (e.g. a ZMQ
  collector fed by nProbe replaying the pcaps, as nProbe exports VLAN and
  MACs, or `--simulate-vlans`), on SQLite and ClickHouse, also with a view
  interface (`view:all`: the assets and the journal are written by the view
  only).

What the two pcaps show (host data per VLAN):

| | L2 copies | Routed: VLAN 15 | Routed: VLAN 188 |
|---|---|---|---|
| MAC | the one of the host | the one of the host | the one of the router |
| `router` | the router | the router | the router (= its own MAC) |
| `mac_meaningful` (pcap interface / ZMQ) | 1 / none | 1 / none | 1 / none |
| TCP fingerprint | `2_64_65535_2b6d3038` | the same | the same |

Neither `mac_meaningful` (also set by the networks of the interface and the
local networks) nor `router` (the gateway towards remote hosts, often missing
or the upstream gateway on a routed copy) tell the copies apart: hence the
rule "all the VLANs agree, or no MAC". The TCP fingerprint does not change with
the TTL decreased by one.

## Known limits

- Different devices with the same IP on different VLANs are one asset.
- A routed copy gives an asset without MAC (and manufacturer, model, device
  type).
- MAC-keyed assets: a routed host can have two assets (MAC key for the home
  copy, `@0` for the routed ones).
- `local_hosts_report.lua` reports the traffic of one VLAN of the asset (the
  one seen last).
