---
title: "nDPI API"
description: "The nDPI API exposes functions for dealing with nDPI protocols and categories."
outline: [2, 3]
lastUpdated: 2018-06-15T15:52:05+02:00
---
# nDPI API {#ndpi-api}

The nDPI API exposes functions for dealing with nDPI protocols and categories.

### `interface.getnDPIProtoName(int proto)` {#interface-getndpiprotoname}

Convert a nDPI protocol id to a protocol name

**Parameters**

- `proto`: the protocol id to convert

**Returns**: the protocol name on success, nil otherwise.

### `interface.getnDPIProtoId(string proto)` {#interface-getndpiprotoid}

Convert a protocol name to the corresponding nDPI protocol id

**Parameters**

- `proto`: the protocol name to convert

**Returns**: the protocol id on success, nil otherwise.

### `interface.getnDPICategoryId(string category)` {#interface-getndpicategoryid}

Convert a category name to the corresponding nDPI category id

**Parameters**

- `category`: the category name to convert

**Returns**: the category id on success, nil otherwise.

### `interface.getnDPICategoryName(int category)` {#interface-getndpicategoryname}

Convert a nDPI category id to a category name

**Parameters**

- `category`: the category id to convert

**Returns**: the category name on success, nil otherwise.

### `interface.getnDPIProtoBreed(int proto)` {#interface-getndpiprotobreed}

Get the nDPI protocol breed associated to the protocol

**Parameters**

- `proto`: the protocol id to query

**Returns**: the protocol breed string on success, nil otherwise.

### `interface.getnDPIProtocols(int category_filter=nil, bool skip_critical=false)` {#interface-getndpiprotocols}

Get the available nDPI protocols

**Parameters**

- `category_filter`: only show protocols of this category
- `skip_critical`: if true, skip protocols marked as critical for a network (e.g. DNS)

**Returns**: a table (proto_name -> proto_id) on success, nil otherwise.

### `interface.getnDPICategories()` {#interface-getndpicategories}

Get the available nDPI categories

**Returns**: a table (category_name -> category_id) on success, nil otherwise.
