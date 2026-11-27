---
title: "Filesystem API"
description: "The Filesystem API provides file system utilities. Filesystem API in the ntopng User's Guide."
outline: [2, 3]
lastUpdated: 2018-06-15T15:52:05+02:00
---
# Filesystem API {#filesystem-api}

The Filesystem API provides file system utilities.

### `ntop.isdir(string path)` {#ntop-isdir}

Check if the specified path is a directory.

**Parameters**

- `path`: to check.

**Returns**: true if it's a direcory, false otherwise.

### `ntop.mkdir(string path)` {#ntop-mkdir}

Create the specified directory structure.

**Parameters**

- `path`: the directory tree to create.

**Returns**: true on success, false otherwise.

### `ntop.notEmptyFile(string filename)` {#ntop-notemptyfile}

Check if the specified file is not empty.

**Parameters**

- `filename`: the file to check.

**Returns**: true if file is not empty, false otherwise.

### `ntop.exists(string path)` {#ntop-exists}

Check if the specified file or directory exists.

**Parameters**

- `path`: the path to check.

**Returns**: true if the path exists, false otherwise.

### `ntop.fileLastChange(string filename)` {#ntop-filelastchange}

Get the last time the specified file has changed.

**Parameters**

- `filename`: the file to query.

**Returns**: last modification time on success, -1 otherwise.

### `ntop.readdir(string path)` {#ntop-readdir}

List directory files and dirs contents.

**Parameters**

- `path`: the directory to traverse.

**Returns**: table (entry_name -> entry_name) on success, nil otherwise.

### `ntop.rmdir(string path)` {#ntop-rmdir}

Recursively remove a file or directory.

**Parameters**

- `path`: the path to remove.

### `ntop.dumpBinaryFile(string path)` {#ntop-dumpbinaryfile}

Dump a file contents to the webserver.

**Parameters**

- `path`: the file path.

### `ntop.setDefaultFilePermissions(string file_path)` {#ntop-setdefaultfilepermissions}

Set the default ntopng file permissions on the given path.

**Parameters**

- `file_path`: the path to the file

::: info
this function can fix some permission mismatches on Ubuntu 18.
:::

### `ntop.deleteOldRRDs(string ifpath, int deadline)` {#ntop-deleteoldrrds}

Delete RRDs older than the specified deadline.

**Parameters**

- `ifpath`: starting path for the delete operation
- `deadline`: maximum modification date for the files
