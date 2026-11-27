---
title: "View Interfaces"
description: "Ntopng can aggregate two or more physical interfaces into logical units, the so called Interface Views."
outline: [2, 3]
lastUpdated: 2026-10-06T15:02:58+02:00
---
# View Interfaces {#view-interfaces}

Ntopng can aggregate two or more physical interfaces into logical units, the so called Interface Views.
Interface views are seen and treated in the web GUI as if they were real interfaces. In the background,
ntopng collects statistics and traffic for every physical interface underlying an interface view, and reduce
these multi-source stream of information into a single logical aggregate.

Interface views are specified via command line (or configuration file), using the same -i modified that is
used for physical interfaces. An extra view: string must be added right after the -i modifier to tell ntopng
that it is going to read a view. Physical interfaces must be indicated in a comma separated list that follows
the view: string.

For example an interface view that merges physical interfaces en0 and en4 can be created using the
following syntax:

```bash
ntopng -i en0 -i en4 -i view:en0,en4
```

::: warning
Interfaces that are part of a view must also be specified separately as physical interfaces. This
means that you cannot omit the -i en0 -i en4 from the example above.
:::

A convenient way to create a view of all the other network interfaces is to use the `view:all` identified:

```bash
ntopng -i tcp://127.0.0.1:5556 -i tcp://127.0.0.1:5557 -i view:all
```

Upon successful startup, ntopng shows, in the top toolbar ‘Interfaces’ menu, the interface view together
with other physical interfaces. An eye is show next to each view, which can be clicked and selected as if it
was a physical interface.

![View Interfaces Dropdown](../../img/advanced_features_view_ifaces_dropdown.png "The Interfaces Dropdown Menu in the Top Toolbar")

::: info
To see the combined data of all the interfaces without configuring a view, the
[Overview](/user_interface/index.md) entry of the Interfaces dropdown
can be used. The Overview entry is hidden when a View Interface is configured.
:::
