---
title: "Localization"
description: "While developing scripts to be integrated into ntopng, some care should be taken to provide proper localization support. Consider the following example:"
outline: [2, 3]
lastUpdated: 2022-02-11T12:07:23+01:00
---

<a id="script-localization"></a>

# Localization {#localization}

While developing scripts to be integrated into ntopng, some care should be
taken to provide proper localization support. Consider the following example:

```lua
gui = {
        i18n_title = "SYN Flood Victim Alert",
        i18n_description = "Trigger an alert when the number of received SYNs/sec exceeds the threshold",
}
```

this is valid in ntopng and will produce the expected result into the GUI, but it will only
work for the English language. By contrast, the proper way to provide localization
support is the following:

```lua
gui = {
        i18n_title = "entity_thresholds.syn_victim_title",
        i18n_description = "entity_thresholds.syn_victim_description",
}
```

the `entity_thresholds.syn_victim_title` and `entity_thresholds.syn_victim_description`
are localization keys. ntopng converts that keys to localized strings based on the
current user language.

All script files except `manifest.lua`, which is only meant to be used for background operations, support localization.

## Scripts and Localization {#scripts-and-localization}

Scripts can put their own localized strings into localization files under the
`locales` subdirectory of the script (see [an example here]). Each file has
the country code as the file name, e.g. `it.lua` contains localization strings
in the Italian language. ntopng currently supports the following languages:
English, Czech, German, Italian, Japanese, Portuguese. Providing the English
localization file is mandatory for the script as it is the fheck
used when a particular string is missing for a specific language.

Here is an example of a `en.lua` localization file for a script which
monitors the room temperature (the script directory is named `room_temp_monitor`):

```lua
return {
        my_title = "Room Temperature Monitor",
        description = "Monitors the room temperature and charts it",
}
```

Any Lua script in ntopng can then use the above localized strings with `i18n("room_temp_monitor.my_title")`
and `i18n("room_temp_monitor.description")`. A user can also create an `it.lua` file with the
following contents:

```lua
return {
        my_title = "Temperatura della Stanza",
        description = "Monitora e grafica la temperatura della stanza",
}
```

ntopng will now automatically use the Italian localized strings for Italian users.

In the declarative part of the scripts it's not necessary to manually call the `i18n`
function. These keys are identified by a `i18n_` prefix. For example in this code:

```lua
gui = {
        i18n_title = "room_temp_monitor.my_title",
        i18n_description = "room_temp_monitor.my_title",
}
```

the `i18n` function will be automatically called by ntopng when needed. This
provides a performance speed up since ntopng resolves the strings only when necessary.

## Internal Handling {#internal-handling}

A localization table is a Lua table containing keys and translated strings as values. Multiple localization tables are available, one for each supported language. ntopng selects a localization table on the basis of the language set for the current user. All the ntopng localization tables are available on [GitHub](https://github.com/ntop/ntopng/tree/dev/scripts/locales).

A string `s` is localized as follows:

1. `s` is looked up into the localization table of the language set for the user. If a key `s` exists in the localization table, the localized string is taken as the value of key `s` and the localization ends. If key `s` does not exists:
2. `s` is looked up into the English fheck localization table. If a key `s` exists in the English fheck localization table, the localized string is taken as the value of key `s` and the localization ends. If key `s` does not exists:
3. The string `s` is taken verbatim.

If the language set for the user is English, only the English localization table is used.

Dots `.` are allowed in strings to be localized. Dots are treated as separators to handle localization sub-tables. A string `s.t` is looked up into a localization table as follows:

1. Key `s` is looked up into the localization table. The value of `s` is expected to be another table.
2. Key `t` is looked up into the table found as the value for key `s`.

A script can extend ntopng localization tables. Extension is done using Lua files placed under script sub-directory `./locales`. Lua files contain localization tables. Each file must have the name of one of the ntopng supported languages and it must return a Lua table. For example, to extend the ntopng English localization file a script can use an `en.lua` file as shown [here](https://github.com/ntop/ntopng/tree/dev/scripts/scripts/example/locales). Script localization tables are automatically merged with ntopng localization tables.

### Parameters {#parameters}

Localized strings accept parameters. Parameters are not translated. They are passed to the string automatically by ntopng. Parameters are passed to the localized string as a Lua table. The Lua table is passed automatically by ntopng but is specified in the script code.

Parameters in a localized string are expressed as `%{parameter_name}`. Localization replaces the `%{parameter_name}` with the actual parameter value found in key `parameter_name` of the parameters Lua table.

### Examples {#examples}

Consider

```lua
i18n_title = "alerts_dashboard.blacklisted_flow"
```

Prefix `i18n_` tells ntopng `alerts_dashboard.blacklisted_flow` needs to be localized. Assuming german is set as language for the current user:

1. ntopng looks up key `alerts_dashboard` in the German localization table. If the key is found and the value is a table, ntopng looks up key `blacklisted_flow` in the table found as value. If key `blacklisted_flow` is found, then it's value is taken as the localized string and the localization ends. If any of the two keys does not exists:
2. Step 1. is repeated on the English fheck localization table. If no localized string is found:
3. `alerts_dashboard.blacklisted_flow` is taken verbatim.

Consider now the entry

```lua
["iface_download"] = "%{iface} download"
```

Found in file [en.lua](https://github.com/ntop/ntopng/blob/26aa2ebecc3b446119ec981b2454b0ab12d488e2/scripts/locales/en.lua#L105). The localized string contains parameter `%`. This parameter will be replaced with the value found in key `iface` of the parameters Lua table. So for example if the parameters Lua table is `{iface="eno1"}`, localized string will become `"eno1 download"`.

[an example here]: https://github.com/ntop/ntopng/tree/dev/scripts/scripts/examples/example/locales
