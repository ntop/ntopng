---
title: "Overview"
description: "ntopng core is extensible by means of scripts. Users and programmers with basic scripting skills are able to extend ntopng to implement custom features."
outline: [2, 3]
lastUpdated: 2023-10-06T16:58:32+02:00
---
# Overview {#overview}

## Introduction {#introduction}

ntopng core is extensible by means of scripts. Users and programmers with basic scripting skills are able to extend ntopng to implement custom features.

## Capabilities {#capabilities}

Scripts offer the following capabilities.

### Monitoring an Analysis {#monitoring-an-analysis}

Scripts provide mechanisms to watch and analyze network traffic, flows, hosts and other network elements. They also enable the monitoring of the health and status of ntopng, as well as of the system on top of which ntopng is running.

### Alerts Generation {#alerts-generation}

Scripts enable the generation of custom alerts. Generated alerts appear within the ntopng web GUI and are propagated towards external alert endpoints.

### Custom Pages {#custom-pages}

Scripts enable the creation of custom pages. Custom pages are shown within the ntopng web GUI and have links in the menu.

### Timeseries {#timeseries}

Scripts enable the generation of timeseries for custom metrics. Points of custom metrics are written from inside the script. ntopng charts show custom metrics points over time.

## What is a Script {#what-is-a-script}

A script is a collection of Lua scripts with a predefined structure.

## Availability {#availability}

ntopng community scripts are open source and available on the [ntopng
GitHub scripts page](https://github.com/ntop/ntopng/tree/dev/scripts).
