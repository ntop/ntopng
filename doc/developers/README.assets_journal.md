# Assets journal (design)

## Goal

A journal of what happens to the assets: one entry per event, reporting a
change (the difference), not the state of the asset.

- One row per event.
- Every change of a field of an asset gives an event. The first version
  covers the host assets and some of their fields (see "Fields"); the code is
  ready for all the fields and for the other types of assets.
- Each entry tells when the event happened, who caused it (ntopng or a user),
  the kind of action, the asset, and a message as precise as possible: for an
  event caused by traffic, the flow (and the interface that saw it); otherwise
  the cause (TTL expiration, configuration, user, ...).
- Entries can also be written by other code (e.g. external integration) and,
  manually, by the users (free text).
- The entries are never deleted (no retention for now).
- The entries are read by asset and time interval only.
- ClickHouse and SQLite.

Decisions:

| Topic | Decision |
|---|---|
| Assets | Host assets first; the other types (MAC devices, SNMP devices, ...) later, with no change to the table or to the generic code |
| Granularity | One row per changed field; one row per item for lists (each tag, each server port) |
| Who | `ntopng` for automatic events; the username for events caused from the GUI or the REST API |
| Actions | `Baseline`, `New`, `Update`, `Delete`, `Manual` (see "Actions") |
| Timestamps | Two, in seconds (32 bits): when the event happened, and when the entry has been written |
| Message | A template with values (localized when read), or a plain text (stored and shown as is) |
| Flows | Every event caused by traffic reports the flow and the interface that saw it, and the evidence of the change (see "Causes") |
| Interfaces | Packet and ZMQ interfaces, with and without view interfaces |
| Writers | A generic Lua function (single entry and batch), used by the assets code, by the REST handlers, and by any other code (e.g. Wazuh). Concurrent calls are supported |
| Queries | By asset and time interval |
| Retention | None: entries are never deleted |
| License | Enterprise L or above |
| Preference | "Enable Assets Journal", enabled by default (it also requires the assets inventory) |

## Table

`assets_journal`

| Column | ClickHouse | SQLite | Content |
|---|---|---|---|
| `ifid` | `UInt8` | `INTEGER` | Interface of the asset |
| `asset_type` | `LowCardinality(String)` | `TEXT` | Type of the asset (`host`, later `mac`, `snmp`, ...) |
| `key` | `String` | `TEXT` | Key of the asset, as in the `assets` table (e.g. `2_192.168.1.20@0`) |
| `event_time` | `DateTime` | `INTEGER` (epoch, seconds) | When the event happened |
| `created_time` | `DateTime` | `INTEGER` (epoch, seconds) | When the entry has been written |
| `who` | `String` | `TEXT` | `ntopng`, or the username |
| `action` | `LowCardinality(String)` | `TEXT` | See "Actions" |
| `subaction` | `LowCardinality(String)` | `TEXT` | What the entry is about, see "Subactions" |
| `message_id` | `LowCardinality(String)` | `TEXT` | Template of the message (i18n key), empty for a plain text |
| `message_values` | `String` | `TEXT` | Values of the template, as JSON |
| `message` | `String` | `TEXT` | Plain text, when there is no template |
| `ntopng_instance_name` | `LowCardinality(String)` | - | As in the `assets` table |

ClickHouse:

```sql
CREATE TABLE IF NOT EXISTS `assets_journal` (
  `ifid` UInt8,
  `asset_type` LowCardinality(String),
  `key` String,
  `event_time` DateTime,
  `created_time` DateTime,
  `who` String,
  `action` LowCardinality(String),
  `subaction` LowCardinality(String) DEFAULT '',
  `message_id` LowCardinality(String),
  `message_values` String DEFAULT '',
  `message` String DEFAULT '',
  `ntopng_instance_name` LowCardinality(String)
) ENGINE = MergeTree()
PARTITION BY toYYYYMMDD(`created_time`)
ORDER BY (`ifid`, `key`, `event_time`);
```

SQLite (in `alert_store_schema.sql`, next to the `assets` table):

```sql
CREATE TABLE IF NOT EXISTS assets_journal (
  rowid INTEGER PRIMARY KEY AUTOINCREMENT,
  ifid INTEGER NOT NULL,
  asset_type TEXT NOT NULL,
  key TEXT NOT NULL,
  event_time INTEGER NOT NULL,
  created_time INTEGER NOT NULL,
  who TEXT NOT NULL,
  action TEXT NOT NULL,
  subaction TEXT NULL,
  message_id TEXT NULL,
  message_values TEXT NULL,
  message TEXT NULL
);
CREATE INDEX IF NOT EXISTS assets_journal_i_key_time
  ON assets_journal (ifid, key, event_time);
```

Notes:

- No retention: on ClickHouse the table is partitioned by day, and it is excluded from
  the partition drop of `clickhouse_retention.lua`, that otherwise applies the
  retention of flows and alerts to every table partitioned by day. The
  partition is on `created_time`, that never goes back in time, rather than
  on `event_time`.
- The entries of an asset are never deleted, not even when the asset is
  deleted (a `Delete` entry is written).
- The cluster schema (`db_schema_clickhouse_cluster.sql`) has the same table
  with `ON CLUSTER` and `ReplicatedMergeTree`.
- The times are in seconds (32 bits): milliseconds are not needed to read the
  journal, and the entries written together (e.g. a `New` entry and the
  fields of the new asset) have the same times anyway (see "Host assets").

## Actions

| Action | When | Who |
|---|---|---|
| `Baseline` | The journal starts (first time, or enabled again): one entry per asset already there. Message: e.g. "Asset recorded when the journal has been enabled", no details | `ntopng` |
| `New` | An asset is created. One entry for the creation itself, with the flow that created the host of the asset (see "Causes"), then one entry for each field with a value and for each tag of the new asset, with their details (`Update` action, same event time) | `ntopng` |
| `Update` | A field of an asset changes, automatically or by a user | `ntopng` or the user |
| `Delete` | An asset is deleted: by ntopng (e.g. not seen for too long) or by a user | `ntopng` or the user |
| `Manual` | A free text written by a user (e.g. "Asset removed from the network because too old") | The user |

## Subactions

What an entry is about (`subaction`), to filter the entries (e.g. the history
of the Operating System or of the MAC address of an asset):

| `subaction` | Entries |
|---|---|
| empty | The asset as a whole: Baseline, New (the creation), Delete, Manual |
| `os` | The Operating System: its tags (27-31, `asset_tags.os_tags`) |
| `tag` | The other tags |
| `<field>` | A field of the asset: its name (`ip`, `mac`, `vlan`, `tcp_fingerprint`, `dhcp_fingerprint`, `dns_name`; later `network`, `gateway_mac`, `model`, `device_type`, `manufacturer`, `mdns_name`, `dhcp_name`, `netbios_name`, `ssid`, `router`, `snmp_*`, `switch_*`, `server_ports`, `custom`) |

The field entries take the `name` of the field in `assets_journal.host_fields`
(or its `subaction`, e.g. `os` for `os_type`), so a new field has its
subaction without other changes. The entries written by other modules can use
their own values.

## Messages

A message is either:

- a **template** (`message_id`, an i18n key) with its **values**
  (`message_values`, JSON), localized when the entries are read. Used by
  the assets code;
- or a **plain text** (`message`), stored and shown as is: free text of the
  users (`Manual`), and any caller that prefers to pass the final text.

The message must always have as much information as possible about the
event (see "Causes"). Tags are reported with their id in decimal and in
hexadecimal, and their name. The cause is part of the values: a template with
its own values for the causes known to Lua (TTL, user, configuration, ...),
or the plain string sent by the host for the causes seen in the traffic
(evidence and flow, see "Flows"):

```json
{ "tag_id": 28, "tag_hex": "0x1c", "tag_name": "Linux",
  "cause": "TCP fingerprint 2_64_64240_789c1d1f (Linux) - TCP 172.16.1.137:39970->116.203.142.127:80 enp0s3 (0) [HTTP.ntop]" }
{ "tag_id": 8, "tag_hex": "0x08", "tag_name": "SSH Server",
  "cause": { "id": "assets_journal.cause_expired",
             "values": { "ttl": "30 days", "last_seen": "01/10/2026 10:00:00" } } }
```

Examples (English, from live tests):

| Event | Message |
|---|---|
| New asset | New asset: UDP 192.168.1.93:51409->192.168.1.1:53 enp0s3 (0) |
| Field of a new asset | Set MAC address to "10:13:31:F1:39:76": UDP 192.168.1.93:51409->192.168.1.1:53 enp0s3 (0) |
| Field changed | Update TCP fingerprint from "old_fp" to "2_64_64240_789c1d1f": TCP 172.16.1.137:39970->116.203.142.127:80 enp0s3 (0) [HTTP.ntop] |
| Service tag | Add tag 0 (0x00) DNS Server: UDP 192.168.1.93:52340->192.168.1.1:53 enp0s3 (0) [DNS] |
| Tag bound to a risk | Add tag 13 (0x0d) Non-PQC Compliant: risk Non PQC Compliant Flow - TCP 192.168.1.93:61562->92.122.247.92:443 enp0s3 (0) [TLS] |
| OS tag | Add tag 28 (0x1c) Linux: HTTP User-Agent "Mozilla/5.0 (X11; ...)" (Linux) - TCP 10.0.2.15:45734->192.168.160.8:3000 enp0s3 (0) [HTTP] |
| Tag replaced | Remove tag 31 (0x1f) Windows: replaced by tag 28 (0x1c) Linux, Linux (TCP Fingerprint) - TCP 172.16.1.137:39970->116.203.142.127:80 enp0s3 (0) |
| Tag set by a user | Add tag 40 (0x28) Test40: manually set (user in `who`) |
| Tag expired | Remove tag 8 (0x08) SSH Server: TTL (30 days) expiration, last seen on 01/10/2026 10:00:00 |
| Tag from the configuration | Add tag 0 (0x00) DNS Server: from network configuration |
| Name resolved by ntopng | Set DNS name to "precision-3591.lan": reverse DNS lookup by ntopng |
| Asset deleted by a user | Asset deleted |

## Causes

The cause of an event tells **what** made the change (the evidence) and,
when it comes from traffic, **where** it has been seen (the flow, and the
interface that saw it). A removal caused by a replacement reports the cause of
the new value (e.g. the Operating System tag replaced: the evidence of the new
Operating System).

| Change | Cause reported |
|---|---|
| Tag bound to an application | The flow (application detected) |
| Tag bound to a flow risk | The flow and the risk |
| Service tag (DNS Server, ...) | The flow where the host has been seen providing the service |
| Non-PQC Compliant tag | The flow and the risk information |
| Operating System (tag, `os_type`) | The evidence and its flow: TCP fingerprint, HTTP User-Agent, OS hint received from nProbe; or the DHCP fingerprint, the network discovery |
| Fingerprints, names | The flow they have been seen in (e.g. the DNS name: the DNS response) |
| Server ports | The flow where the host has been seen as server on the port |
| New asset | The flow that created the host of the asset |
| User actions | The user, in `who` (not repeated in the message) |
| Tag expired | The TTL of the tag and the last time it has been seen |
| Configuration | "from network configuration" |
| Seeding of the Operating System tags | The Operating System stored in the asset |
| Tag deleted | The tag deleted (by a user) |
| SNMP data | The SNMP device |

A flow is described with the short format of `Flow::print()` (see "The flow
string"), for flows seen on packet interfaces as well as for flows collected
from nProbe (ZMQ). The causes have been reviewed one by one on real examples
(see "Causes, case by case").

## Fields

First version (to ease the tests and the debugging): only these fields of the
host assets give events.

| Field | Where | Events |
|---|---|---|
| `ip`, `mac`, `vlan` | Columns | Value changed (old and new value) |
| Tags | `json_info.tags`, `tags_info` | One per tag added or removed, with the reason (observed, manual, configuration, seeding, TTL expiration, replaced, tag deleted) |
| `tcp_fingerprint`, `dhcp_fingerprint`, `dns_name` | `json_info` | Value changed |

The code is meant for the whole list below: the list of the fields is a table
(`assets_journal.host_fields`: name, where, `in_key`, `subaction`; the label is
the template `assets_journal.field_<name>`), so that adding a field is adding
an entry, and the code has comments at the points where the other fields will
be added.

| Field | Where | Notes |
|---|---|---|
| `network`, `gateway_mac` | Columns | |
| `os_type`, `model`, `device_type`, `manufacturer` | Columns | |
| `server_ports` (per protocol) | `json_info` | One event per port added or removed (the list is capped at 64) |
| `mdns_name`, `dhcp_name`, `netbios_name` | `json_info` | |
| `ssid`, `router` | `json_info` | |
| `snmp_name`, `snmp_descr`, `switch_ip`, `switch_port` | `json_info` | From the SNMP data |
| Custom fields | `json_info` | Set with `interface.addDataToLocalHostAssets()` |

Never giving events (noisy or internal): `last_seen`, `first_seen`,
`version`, `type`, `key`, `ifid`, `tags_info` (first/last/source of each
tag), `tags_refreshed`, `tags_assigned`, `tags_removed`, `tags_pinned`, the
`<service>_server` flags (same information as the service tags),
`mac_meaningful`, `tls_name`, `http_name`, `mdns_txt_name`, `wazuh_info`
(the Wazuh code writes its own entries).

Never journaled: `name` (column). It is not a value of its own but derived
from other fields: the first one set among the server, DHCP, DNS, mDNS, TLS
and HTTP names (`Host::get_name()`), computed when the host is dumped. A
change of the name is caused by a change of one of them, journaled one by
one instead (`dns_name` now, the others when they are added).

## Writing the entries

### Generic function

A Lua module (`pro/scripts/lua/modules/assets_journal.lua`):

| Function | Use |
|---|---|
| `add(entry)` | Write an entry |
| `addBatch(entries)` | Write many entries with a single statement (e.g. the baseline) |
| `get(ifid, key, from, to)` | The entries of an asset in a time interval (epochs in seconds), oldest first, with the messages localized |

An entry: `{ ifid, asset_type, key, event_time, who, action, subaction,
message_id, message_values }` or `{ ..., message }` for a plain text; `created_time` is
set when the entry is written, `who` defaults to `ntopng`.

Concurrent calls (e.g. from external/integration code and from the assets code) are
supported: every call is a self-contained insert, and nothing depends on the
order of the entries of different callers (each entry has its own times).
SQLite writes are serialized by ntopng; ClickHouse supports concurrent
inserts.

As for the other modules of the assets, the logic (building the statements,
the messages) has no dependency on ntopng, so that it can be tested
standalone and on real databases.

| Function (no dependency on ntopng) | Use |
|---|---|
| `normalizeEntry(entry, now)` | Check an entry and fill in its defaults (`asset_type` `host`, `who` `ntopng`, `event_time` now, epoch in seconds). Return `nil` and the reason when the entry is not valid |
| `buildInserts(entries, is_clickhouse, instance_name, created)` | The `INSERT` statements, at most 500 entries each |
| `buildQuery(params, is_clickhouse)` | The query of the entries of an asset in an interval (`ifid`, `key`, `from`, `to`), ordered by event time and then by the time they have been written |
| `toEntries(rows, translate)` | The rows read back, as entries with `text`: the template rendered with its values (a value can itself be a template, e.g. the cause), or the plain text. An unknown template gives its key and values, so that nothing is lost |
| `render(message_id, values, translate)` | Render a template |
| `template(id, values)` | A value that is itself a template (e.g. a cause) |
| `fieldEntries(base, fields, old, new, causes, default_cause)` | One `Update` entry per changed field (`subaction`: the name of the field) |
| `tagEntries(base, events, tag_names, extra, details)` | One `Update` entry per tag added or removed (`subaction`: `os` or `tag`); `details(event, events)` adds the cause sent by the host |
| `newEntries(base, cause, fields, asset, field_cause, tag_events, tag_names, field_causes, tag_extra, tag_details)` | `New` entry, then the fields (except the ones in the key) and the tags of the new asset |
| `newEntry`, `baselineEntry`, `deleteEntry` | The entries about the asset as a whole |

Database functions (they need ntopng, and run on the database of the current
interface, as the rest of the assets code):

| Function | Use |
|---|---|
| `add(entry)`, `addBatch(entries)` | Write. Nothing when the journal is disabled (license or preference `ntopng.prefs.assets_journal_enabled` set to `0`); invalid entries are skipped and logged; a failure is logged, never raised |
| `get(ifid, key, from, to)` | Read, with the messages localized (`i18n`) |
| `isEnabled()` | Enterprise L or above, the assets inventory, and the preference |
| `currentUser()` | The user of the current request (`_SESSION`), `ntopng` when there is none |

NOTE: the times are epochs in seconds (`DateTime` on ClickHouse, written with
`toDateTime()`, read with `toUnixTimestamp()`). On ClickHouse the query
returns them as `event_epoch` and `created_epoch`: an alias with the name of a column (`... AS event_time`) would
be used in place of the column in the `WHERE` clause too.

Tests (from the ntopng root):

```
third-party/lua-5.4.6/src/lua pro/tests/lua/assets_journal_test.lua
third-party/lua-5.4.6/src/lua pro/tests/lua/assets_journal_db_test.lua
```

The first one is standalone. The second one creates the table (from the
schema files) in a temporary SQLite database and, when `clickhouse-client` can
connect to a local server, in a scratch ClickHouse database (dropped at the
end), writes entries with the statements of the module (templates with a
nested cause, plain text with characters to be escaped, entries with the same
event time, other assets and interfaces, and 4 writers at the same time) and
reads them back with its query. It uses the `sqlite3` command, or the
`sqlite3` module of Python when the command is not installed.

### Host assets

When a host snapshot is merged into its asset (`asset_utils.lua`,
`updateData`), the fields of the list are compared with the stored ones: one
`Update` entry for each one that changed, and one per tag added or removed
(with the reason given by `asset_tags.lua`). A new asset gives a `New` entry,
then one `Update` entry for each field with a value ("Set ..."), except the
ones in the key of the asset (`ip`, `vlan`), and for each of its tags ("Add
tag ...").

The other places where the tags of an asset change write their entries too:
expiration of the tags (`expireTags`), tag deleted (`removeTagFromAssets`),
seeding of the Operating System tags.

`Delete`: before an asset is deleted (`deleteHost`, deletion of all the host
assets of an interface, deletion of the assets not seen since a time).

`Baseline` (one entry per asset, no details): once per interface, when the
journal is enabled (at startup, and by the one-minute callback of the assets,
so that enabling it at runtime writes the baseline within a minute). A key
per interface (`ntopng.prefs.assets_journal.baseline.ifid_<id>`) tells it has
been written; it is deleted when the journal is disabled, so that enabling it
again writes a new baseline, and with the other data of the interface. It is
always reset together with the key of the seeding of the OS tags
(`ntopng.prefs.assets.os_tags_seeded.ifid_<id>`). The start and the end are
always logged (number of assets, time): about 1 s per 5-7k assets on
ClickHouse.

Times of the entries: the `last_seen` of the snapshot; for a `New` entry (and
its fields and tags) the `first_seen` of the host, that can be older than a
previous `Delete` of the same asset (asset deleted while its host was in
memory). The entries of a batch have the same times: on ClickHouse their order
is not guaranteed (on SQLite, `rowid`).

Values missing in a snapshot: a host snapshot without MAC or without DNS name
keeps the stored value of the asset (and its manufacturer), see `updateData`,
rather than clearing it (snapshots of hosts being deleted, of hosts of a view
not yet bound to their MAC, of hosts not yet resolved).

Where (`pro/scripts/lua/modules/asset_utils.lua`, section "JOURNAL OF THE
ASSETS" for the helpers):

| Entry | Function | Cause (template) |
|---|---|---|
| `Baseline` | `updateJournalBaseline(ifid)`, called by `init` (all the interfaces, after the seeding of the OS tags) and by `callbacks/minute-delayed/interface/assets.lua` | - |
| `New` | `updateData`, `assets_journal.newEntries` | The flow that has created the host (`journal.created`), or `cause_host_seen` (first seen time) without it; then the causes of the fields and of the tags sent by the host (`cause_snapshot` without them) |
| `Update` (fields, tags) | `updateData` | The causes sent by the host (`cause_snapshot` without them); the tags: the cause sent by the host, or the reason of the tag (`cause_replaced` with the tag of the same group and its cause, ...) |
| `Update` (tags) | `expireTags` | `cause_expired` (TTL, last seen) |
| `Update` (tags) | `changeAssetsTags` / `removeTagFromAssets` | `cause_tag_deleted` |
| `Update` (tags) | `seedOSTags` (only when the Baseline of the interface has already been written: otherwise the Baseline, written just after, tells the state with the seeded tags) | `cause_os_seed` (Operating System stored in the asset) |
| `Delete` | `deleteHost`, `deleteAll` (host), `deleteAllEntriesSince` | none (`asset_deleted_plain`: "Asset deleted"), `cause_all_deleted`, `cause_not_seen_since`, `cause_duplicated` |

The deletions and the tag changes take an optional `who` (default `ntopng`),
given by the REST handlers (see "User actions").

### User actions

An event caused from the GUI or the REST API is written by the handler of the
request, that knows the user, at that time:

- tag added to or removed from a host;
- tag deleted (removed from all the assets);
- asset deleted;
- status of a MAC device changed (later, with the MAC assets);
- assets imported.

The changes made by users on the hosts (tags) reach the assets later, with a
host snapshot that does not tell who made them; they are marked as such in
the snapshot (`tags_assigned`, `tags_removed`), so the snapshot does not write
them again.

The user is `assets_journal.currentUser()` (`_SESSION["user"]`, `ntopng` when
there is none), in the `who` column only (not repeated in the message).

| Action | Handler | Function | Cause |
|---|---|---|---|
| Tags set/unset on a host | `scripts/lua/rest/v2/set/host/config.lua` | `asset_utils.journalHostUserTags` | `cause_user_tag_set` / `cause_user_tag_unset` |
| Tag deleted | `scripts/lua/rest/v2/delete/tag/tag.lua` -> `tag_badge_utils.deleteTag(id, who)` | `asset_utils.removeTagFromAssets(tag_id, who, tag_name)` | `cause_tag_deleted` |
| Asset(s) deleted | `pro/scripts/lua/rest/v2/delete/host/asset.lua` | `deleteHost` / `deleteAllAssets` / `deleteAllEntriesSince` | none ("Asset deleted") / `cause_all_deleted` / `cause_not_seen_since` |
| Assets imported | `pro/scripts/lua/rest/v2/add/assets/assets.lua` | `asset_utils.import_assets(assets, ifid, who)` (each host asset read before and after its row is imported) | `cause_imported`: `New` + one `Update` per field/tag for a new asset, `Update` for what has changed otherwise |

Tags set/unset on a host:

- only the user-defined tags (32-63) can be set by a user on a host;
- written only when the host is active and its asset exists, and only the
  changes of the tags of the asset (a tag already on the asset is not added
  again); otherwise the tags reach the asset with the snapshot (a new asset:
  its `New` entries);
- the snapshot skips the user-defined tags added as `manual` or removed as
  `removed` (`journalSnapshotTagEvents`): a user-defined tag is removed from a
  host only by a user. A tag that is not user-defined removed by the host (the
  Operating System changed to one without a tag) has the cause
  `cause_host_removed`.

The daily deletion of the duplicated host assets is not a user action: cause
`cause_duplicated` (the asset kept).

### Flows

Every event caused by traffic reports the flow and the interface that saw it
(with a view, the viewed interface: it can be other than the interface of the
asset), and the evidence (see "Causes"). It must work on packet and ZMQ
interfaces, with and without view interfaces. Every event has its own cause,
also when a snapshot carries several changes.

The assets only receive the snapshots of the hosts, that do not tell why
something changed. So the host (C++) keeps, for each change not dumped yet,
its cause, and sends it with the snapshot; the causes are freed when the
snapshot is sent, so the memory used is bounded.

#### The flow string

The short format of `Flow::print()` (`full_report` false) becomes one line
with the interface (its other callers are debug messages):

```
TCP 10.0.0.5:51234->1.2.3.4:443 enp0s3 (0) [TLS.Google]
UDP 10.0.0.5:68->255.255.255.255:67 enp0s3 (0) [DHCP]
TCP 10.0.0.5:51234->1.2.3.4:443 enp0s3 (0)
TCP [fe80::1]:51234->[2001:db8::1]:443 enp0s3 (0) [TLS]
ICMP 10.0.0.5->1.2.3.4 enp0s3 (0)
```

- L4 protocol, client and server (IPv6 addresses in brackets; no ports for
  protocols other than TCP/UDP);
- name and id of the interface of the flow (with a view, the viewed
  interface; with ZMQ, the collector interface);
- the application as given by nDPI (`MASTER.APP`, see
  `get_detected_protocol_name()`), only when it is not Unknown.

#### Pending causes on the host

`LocalHost` gets one pointer: the head of a list of pending causes, NULL when
nothing is pending. Each node is `{ what, tag_id, char *cause }`
(`AssetJournalCause`, `LocalHost.h`; `AssetJournalWhat` in `ntop_typedefs.h`;
both, as all the new code, under `NTOPNG_PRO`):

- `what` (`AssetJournalWhat`): "created" (also the cause of `ip`, `mac`,
  `vlan`), a field (`tcp_fingerprint`, `dhcp_fingerprint`, `dns_name`), "tag
  refreshed" or "tag removed" (the host does not know whether the asset has the tag: "Add tag"
  is decided in Lua);
- `tag_id`: the tag, for the tag ones (kept out of the string: Lua finds the
  cause of a tag by its id, and the dump keeps one cause per tag);
- `cause`: ONE string, composed once when the change happens: the evidence,
  when there is one, and the flow string.

The nodes are added by `LocalHost::addJournalCause(what, tag_id, flow,
evidence)`, the only place that allocates them; `Flow::print(..., false)` makes
the flow string.

No time is kept: the time of the entries is the `last_seen` of the snapshot.

When the snapshot is dumped, the nodes are written in its top-level `journal`
key and freed:

```json
"journal": {
  "created": "<cause>",
  "fields":  { "tcp_fingerprint": "<cause>", "dhcp_fingerprint": "<cause>", "dns_name": "<cause>" },
  "tags_refreshed": { "28": "<cause>", "0": "<cause>" },
  "tags_removed":   { "31": "<cause>" }
}
```

A cause is recorded only when something changes: a field when its value
changes, a tag the first time it is refreshed in the dump window (the bit is
not yet in `tags_refreshed_bitmap`), so `Flow::print()` is never called per
packet. One field changing more than once in the same window (A -> B -> C):
the snapshot carries C only, so the asset never sees B; the journal writes one
entry A -> C with the cause of C.

NOTE: the pending causes are written by the threads processing the flows and
read by the housekeeping thread that dumps the host: they need the same
protection as the other asset data of the host, that currently has none
(existing race on `asset_map` and on the tag bitmaps). To be handled later.

#### Causes, case by case (reviewed)

"flow" is the flow string above. The flow is passed explicitly to the setters
(`Flow*` argument, NULL by default), never taken from a "current flow"
context.

| Event | Recorded in | Cause string |
|---|---|---|
| `tcp_fingerprint` | `LocalHost::setTCPfingerprint(fp, os, flow)` | flow |
| `dhcp_fingerprint` | `LocalHost::offlineSetDhcpFingerprint(fp, flow)` | flow (the DHCP request) |
| `dns_name` from a DNS response | `setResolvedName(name, flow)` | flow (the PTR response) |
| `dns_name` without flow (ntopng reverse lookup, name cached from another flow) | `setResolvedName(name, NULL)` | "reverse DNS lookup by ntopng" |
| OS tag, TCP fingerprint | `setTCPfingerprint` -> `setOS(os, mode, flow)` | "TCP fingerprint <fp> (<OS>) - " + flow |
| OS tag, OS hint (nDPI, nProbe) | `Host::setnDPIOS(os, when, flow)` | "<OS> (TCP Fingerprint) - " + flow (no fingerprint, see "Known limits") |
| OS tag, HTTP User-Agent | `setOS(os, mode, flow)` | "HTTP User-Agent "<ua>" (<OS>) - " + flow |
| OS tag, DHCP | `setOS(os, mode, NULL)` (host init, from the MAC) | "DHCP fingerprint <fp> (<OS>)" |
| OS tag, set from Lua | `setOS(os, mode, NULL)` | "<OS> (Set by User via Lua)" |
| Service tag (DNS Server, ...) | `setService(s, flow)` | flow (the flow where the host is the server) |
| Tag bound to an application | `addTags(bitmap, flow)` | flow (the flow that matched: the application is in the flow string) |
| Tag bound to a risk, Non-PQC Compliant | `setCliTag(tag, evidence)` -> `addTags(bitmap, flow, evidence)` | "risk <name>" + flow (the flow that matched); on views the flow only (the evidence does not go through the tags of the IP address) |
| New asset, `ip`, `mac`, `vlan` | `setJournalCreatedBy(flow)`: the first flow of the host (`Flow` constructor; with a view, the view walker) | flow, printed when the host is created (no application yet; not refreshed later) |
| Tag removed by the host (OS replaced) | `setOS` | the cause of the new OS tag |

The risk of a tag bound to a risk is given by the code setting the tag
(`FlowPro`, Non-PQC): nothing is added to `Flow`.

Views: the view walker (`ViewInterface::viewed_flows_walker`) applies to the
hosts of the view the OS, the services and the tags of one viewed flow `f` at
a time: it passes `f`. To be verified: the DNS names on the viewed interfaces
(flows without hosts: names cached in Redis, reaching the view hosts without
flow).

#### Implementation notes

- The cause string is "<evidence> - <flow>" (each one if any), e.g.
  `risk Non PQC Compliant Flow - TCP 192.168.1.10:52346->192.168.1.20:22 eth0 (0) [SSH]`,
  `TCP fingerprint 2_64_64240_789c1d1f (Linux) - TCP ...`.
- One cause per what (and tag) on the host: a later cause replaces the
  previous one (`LocalHost::addJournalCause`), so the list is bounded.
- The causes are freed also when the host is not dumped (e.g. not a unicast
  host, see `LocalHost::dumpAssetInfo`) and with the other data of the host.
- `LocalHost` grows by 8 bytes (the pointer).
- A tag observed in the traffic: the cause sent by the host only, e.g.
  "Add tag 0 (0x00) DNS Server: UDP 192.168.1.93:52340->192.168.1.1:53 eth0 (0) [DNS]".
  Other reasons: the reason, then the cause (`cause_detail`: "<reason>,
  <cause>"), e.g. "Remove tag 31 (0x1f) Windows: replaced by tag 28 (0x1c)
  Linux, Linux (TCP Fingerprint) - TCP ...".
- Evidence of the OS tags: "TCP fingerprint <fp> (<OS>)", "HTTP User-Agent
  "<ua>" (<OS>)", "DHCP fingerprint <fp> (<OS>)", "<OS> (Set by User via
  Lua)"; "<OS> (TCP Fingerprint)" for the OS hint (nDPI, nProbe: the OS of the
  TCP fingerprint, `Host::setnDPIOS`), as the hint is applied before the flow
  has its fingerprint.
- A new asset: the New entry, then its fields except `ip` and `vlan` (in the
  key of the asset), and its tags.
- Other causes: "from network configuration", "manually set", "manually
  unset" (user in `who`); an asset deleted by a user: "Asset deleted" (no
  cause).

Known limits:

- The OS hint (`Host::setnDPIOS`) has no fingerprint in its evidence: the
  hint is applied before the flow has its TCP fingerprint (packets: hint in
  `Flow::processDetectedProtocol`, fingerprint in `Flow::freeDPIMemory`;
  ZMQ: `ParserInterface` sets the hint before the fingerprint). To be done
  later: apply the fingerprint before the hint (packets: call
  `setHostTCPFingerprint()` in `processDetectedProtocol()` before
  `setClientOSHint()`; ZMQ: move `setClientOSHint()` after the fingerprint).
- Hosts of a view created without MAC by `Flow::setAlertsMap` (it checks the
  alert exclusions of the hosts of the view, and creates the missing ones):
  the view walker sets their MAC on the first visit of a flow (e2e test
  `view_host_mac_01`); the ones never handled by the walker stay without MAC
  (their asset keeps its MAC, see "Host assets"). To be fixed: do not create
  hosts there.
- The last snapshots of the hosts at shutdown are dumped after the queue has
  been drained: they are written at the next start (entries dated before the
  restart, after the entries written at startup).
- The pending causes on the host are not protected from the concurrent access
  of the threads (see "Pending causes on the host").
- `mac`, `ip`, `vlan` have the cause of the flow that has created the host:
  a MAC changing later (`Host::set_mac`) has no cause ("reported by the host").
- The flow that has created the host is printed without application (not yet
  detected).

#### Lua

`updateData` (and the New path) take the `journal` key out of the snapshot
(never stored), and pass the causes to `fieldEntries` (per field),
`tagEntries` (per tag) and `newEntries` (`created`). A missing cause (older
snapshot, change coming from stored data) falls back to `cause_snapshot`.
New templates: the cause string is shown as it is.

## Preference

"Enable Assets Journal" (Settings > Preferences > Behaviour, section Assets,
`toggle_assets_journal`): enabled by default, Enterprise L or above.

- Redis key `ntopng.prefs.assets_journal_enabled` ("0" disabled, enabled when
  not set): `assets_journal.isEnabled()` in Lua,
  `Prefs::isAssetsJournalEnabled()` in C++ (`CONST_PREFS_ASSETS_JOURNAL_ENABLED`,
  reloaded with the other preferences). Both also require the assets
  inventory (`ntop.assetsEnabled()`, `Prefs::isAssetInventoryEnabled()`).
- Disabled: no entry is written, the hosts do not record the causes of their
  changes, and the baseline key of each interface is deleted (by the
  one-minute callback of the assets).
- Enabled again: a new baseline is written by the next run of the one-minute
  callback.

## Implementation steps

| # | Step | Repo | Status |
|---|---|---|---|
| 1 | This document | ntopng | Done |
| 2 | Table (ClickHouse, cluster, SQLite), excluded from the retention | ntopng, pro | Done |
| 3 | `assets_journal.lua`: add, batch, query, messages; standalone test and test on real databases | pro | Done |
| 4 | Host assets: fields, tags (with reasons), New, Baseline, Delete | pro | Done |
| 5 | User actions in the REST handlers | ntopng, pro | Done |
| 6 | Flows: C++ (including views), see "Flows" | ntopng, pro | Done (causes reviewed) |
| 7 | Preference | ntopng, pro | Done |
| 8 | Documentation (`doc/src/advanced_features/assets_journal.rst`), live tests | ntopng, pro | Done (see "Tests") |

## Tests

- Standalone test of the module (statements, messages, rendering).
- Test of the statements on real databases (SQLite, and ClickHouse when
  available), as for the previous history of the tags.
- Live tests on a running ntopng; a ZMQ collector interface needs no root,
  runs the one-minute callbacks and keeps its SQLite database on disk.

### Showing the entries

`pro/tools/assets_journal/show.sh` prints the entries of the journal with the
full English message (rendered by `assets_journal.lua` with `en.lua`), in the
order they have been written:

```
pro/tools/assets_journal/show.sh                         # ClickHouse, database ntopng
pro/tools/assets_journal/show.sh ch ntopng 0_10.0.0.1@0  # one asset
pro/tools/assets_journal/show.sh sqlite <datadir>/0/alerts/alert_store_v11.db [<key>]
```

### Live tests done (2026-10-21)

Without root and without nProbe license, in two halves:

- C++: ntopng reading the e2e pcaps (`non_pqc`, `dhcp`, `dns_contacts`,
  `host_os_change`, `test_01`, `tor`), also with a view on the pcap
  interface: the snapshots of the hosts left in the Redis queue at shutdown
  have the expected `journal` block (created, fields, tags_refreshed,
  tags_removed; interface of the flow, the viewed one with the view).
- Lua: those snapshots pushed to the queue of a ZMQ collector interface, on
  SQLite and on ClickHouse: New, Update (fields, tags, replaced tags), Delete
  (REST), Baseline, preference on/off, user actions (REST: tags of a host,
  tag deleted, asset deleted, import).

Found and fixed: empty addresses in the flow string (`IpAddress::print`
returns a pointer inside the buffer), "[Unknown]" while the protocol is being
detected, a tag replaced on the asset but never set on the host (view) without
cause (now the cause of the tag replacing it).

### Live tests done with nProbe (2026-10-22)

A separate ntopng (ZMQ collector, own data directory and Redis DB, scratch
ClickHouse database) fed by nProbe reading the e2e pcaps
(`nprobe -i <pcap> --zmq tcp://127.0.0.1:5599 --zmq-probe-mode`, default ZMQ
encryption key on both sides; no root needed):

1. ZMQ, ClickHouse: New with the creating flow, MACs, TCP fingerprints, OS
   tag, service tags; the flows report the collector interface
   (`tcp://127.0.0.1:5599c (0)`).
2. ZMQ with a view on top: the assets of the view, the causes report the
   viewed interface, the hosts of the view have their MAC.
3. ZMQ, SQLite: as 1.
4. REST on active hosts: user tags set/unset (one entry each, the user in
   `who`, nothing written again by the snapshot), asset deleted, preference
   off (nothing written) and on (Baseline), restart.
5. Tags expiration (TTL in minutes, test mode): "TTL (1 minutes) expiration,
   last seen on ...".

Not covered by these pcaps through nProbe: the DHCP fingerprint, a DNS name
from a PTR response, the Non-PQC risk (not exported by nProbe), an OS change.

e2e test: `view_host_mac_01` (hosts of a view with their MAC).

### Live tests still to be done (real interfaces)

1. Packet interface (root), Enterprise L, journal enabled: new hosts give New
   with the creating flow; a DNS server gives "Add tag 0 (0x00) DNS Server:
   <flow> [DNS]"; a Windows/Linux host gives the OS tag with "TCP fingerprint
   <fp> (<OS>) - <flow>".
2. Same with a view interface on top of it: the causes report the viewed
   interface.
3. Change of OS of a host (e.g. `host_os_change.pcap` replayed with
   tcpreplay): "Remove tag 31 ... replaced by tag 28 ..., <evidence> - <flow>".
4. GUI: set/unset user tags on a host (who = the user), delete a tag, delete
   assets, import assets; disable/enable the preference (Baseline after the
   next minute).
5. A DNS PTR response for a local host: "Set DNS name to ...: <DNS flow>".
