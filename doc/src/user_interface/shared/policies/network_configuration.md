---
title: "Host Policy"
description: "ntopng is able to specify an host policy for selected devices that have special requirements including restrictions on host they contact."
outline: [2, 3]
lastUpdated: 2025-02-12T16:12:50+01:00
---

<a id="networkconfiguration"></a>

# Host Policy {#host-policy}

ntopng is able to specify an host policy for selected devices that have special requirements including restrictions on host they contact.

A typical example is a network device such as a router or switch that should not initiate any type of traffic except some rare exceptions (e.g. contact the NTP server or check for updates). When relevant network hosts perform unexpected traffic, it is very likely that something wrong happened and this behaviour needs to be detected.

::: info
This feature is available with Enterprise L License or better.
:::

## Configuration {#configuration}

In order to enable this feature, the 'Host Policy' behavioural check needs to be anabled.

![Host Policy Check](../../../img/host_policy_behaviour.png "Host Policy Check")

Done this, you need to configure the host policies that are specified under Settings -> Network Configuration

![Host Policy Configuration](../../../img/host_policy_configuration.png "Host Policy Configuration")

The configuration page allows you three type of host devices:

- Restricted Hosts (e.g. Servers, VPN servers).
- Core Hosts (e.g. Routers, Switches).
- Whitelisted Hosts: hosts that everyone can connect to (e.g. the local DNS server).

## Alert Generation {#alert-generation}

An 'Host Policy' critical alert is triggered whenever:

- A restricted host connects to a public IP address not whitelisted.
- A restricted host connects to a core host.
- A core host connects to any non whitelisted address.

In case an alert is generated, the exact problem detection is reported

![Host Policy Alert](../../../img/host_policy_alert.png "Host Policy Alert")
