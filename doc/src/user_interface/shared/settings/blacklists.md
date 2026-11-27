---
title: "Blacklists"
description: "ntopng uses third party IP/domain lists to detect malicious hosts, the Category Lists."
outline: [2, 3]
lastUpdated: 2026-11-05T10:51:09+01:00
---

<a id="blacklists"></a>

# Blacklists {#blacklists}

ntopng uses third party IP/domain lists to detect malicious hosts, the Category Lists.
Each list contains a list of hosts which are associated to a particular [protocol category].

Examples of Category Lists are the malware and mining hosts blacklists, which are used by
ntopng to detect malicious hosts and generate [alerts].

::: info
Check out the [Custom Category Hosts docs] for a way to assign custom hosts to the ntopng categories.
:::

![Category Lists Configuration Page](../../../img/advanced_features_category_lists.png "The Category Lists Configuration Page")

Right now only some built-in lists are supported by user defined lists could be added in the
future. Lists are updated periodically based on the configured *Update Frequency*.
By clicking on the *Update Now* button it's possible to force the list update.
The *Num Hosts* column indicates the number of hosts loaded from the specified list.
The *Status* column indicates the list current status:

- *Enabled*: the list is enabled and will be used by ntopng
- *Disabled*: the list is disabled and will be ignore by ntopng
- *Error*: there was an error while downloading the list. Check out the ntopng log for details.

By clicking on the *Edit* button it's possible to edit the list update frequency and
to disable the list.

![Customize a Category List options](../../../img/advanced_features_category_lists_edit.png "Customize Category List options")

When a list is disabled, it will not be updated anymore.

## Custom Blacklists {#custom-blacklists}

In addition to the bundled list of categories, you can add your own custom category list.

Under `/usr/share/ntopng/httpdocs/misc/lists/builtin` you can find the blacklist files that come with ntopng. Below you can find an example of the expected syntax:

```bash
$:/usr/share/ntopng/httpdocs/misc/lists/builtin# cat nocoin.list
{"name":"NoCoin Filter List","format":"hosts","enabled":true,"update_interval":86400,"url":"https://raw.githubusercontent.com/hoshsadiq/adblock-nocoin-list/master/hosts.txt","category":"mining"}
```

There are various formats supported (field "format" in the list configuration file) including:

> - ip: each line contains a numeric IPv4 address
> - hosts: each line contains a symbolic hostname

Please have a look at the configuration files that ship with ntopng to see an example.

In order not to mix custom configuration files with the built-in ones, ntopng expects them to be stored in `/usr/share/ntopng/httpdocs/misc/lists/custom`

If the file format is correct, ntopng will download lists at startup or periodically according to the specified configutation.

[alerts]: /basic_concepts/alerts.md
[custom category hosts docs]: /user_interface/shared/settings/applications_and_categories.md
[protocol category]: /user_interface/shared/settings/applications_and_categories.md
