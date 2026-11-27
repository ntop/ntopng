---
title: "Basic Concepts"
description: "Here is a brief introduction to some fundamental concepts of the API. A schema can be seen as a table of a database. It specifies the data format and types."
outline: [2, 3]
lastUpdated: 2019-03-25T11:07:36+01:00
---
# Basic Concepts {#basic-concepts}

Here is a brief introduction to some fundamental concepts of the API.

## Schema {#schema}

A schema can be seen as a table of a database. It specifies the data format and types.
A schema is identified by it's name and contains the following informations:

> - Step: the expected interval, in seconds, between raw data points.
> - Tags: a tag is a label which can be used to filter data. Example of tags are
>   the interface name, host name and nDPI protocol name.
> - Metrics: a metric is a particual value which is being measured. Example of metrics are
>   the host bytes sent traffic, interface number of flows and ASN round trip time.
>   All metrics must be consistent with the specified type (see below).
> - Type: the type for all the metrics of the schema. Currently "counter" or "gauge".
> - Options: some driver specific options.

All the ntopng defined schemas can be found in `scripts/lua/modules/timeseries/schemas`.
Schemas are split into 3 files, one for each periodic script, to avoid wasting time loading
unnecessary schemas. Nevertheless, by including the `ts_utils` module, all the available
schemas are loaded automatically.

## Schema Name {#schema-name}

A schema name is made up of two parts:
: - A schema prefix, for example "host"
  - A schema suffix, for example "ndpi"

The two parts are separated by a single `:`, so for example "host:ndpi" is a valid
schema name and indicates the nDPI application traffic of an host. Only a single
colon is allowed and no spaces are allowed.
For new schemas, it is important to choose a consistent schema name.

Here are some common schema prefixes used:

> - `iface`: schemas for network interfaces (e.g. `iface:traffic`)
> - `host`: schemas for local hosts
> - `mac`: schemas for L2 devices
> - `asn`: schemas for autonomous systems
> - `subnet`: schemas for local networks
> - `country`: schemas for countries
> - `vlan`: schemas for VLANs

Here are some common schema suffixes used:

> - `traffic`: schemas for bytes timeseries (e.g. `host:traffic`)
> - `ndpi`: schemas for nDPI application timeseries
> - `ndpi_categories`: schemas for nDPI category timeseries

Usually the schema prefix appears also as a tag in the timeseries and it's used
to identify the element (e.g. the schema `asn:ndpi` as a tag `asn` which holds the
AS number).

## Metric Types {#metric-types}

ntopng provides metrics of two types, namely gauges and
counters. Timeseries can be created out of gauges and counters,
transparently. The only thing that is necessary is to tell the
timeseries engine the actual type, then the rest will be handled automatically.

- Counters are for continuous incrementing metrics such as the total
  number of bytes (e.g., `bytes.sent`,
  `bytes.rcvd`). This is the most common metric type for networks.
- Gauges are metrics such as the number of active flows
  (e.g., `active_flows.as_client`, `active_flows.as_server`) or active
  hosts at a certain point in time.

## Driver {#driver}

A timeseries *driver* implements a well defined interface to provide support for a
specific database. Currently ntopng provides the RRD and InfluxDB drivers to communicate
with the respective datatabases.
