---
title: "Using nTap as Virtual Tap with ntopng"
description: "Sometimes you need to analyze traffic on a remote host, and NetFlow is not an option. In this case you need to enable a remote span that allows you to..."
outline: [2, 3]
lastUpdated: 2025-02-14T18:12:37+01:00
---

# Using nTap as Virtual Tap with ntopng {#using-ntap-as-virtual-tap-with-ntopng}

Sometimes you need to analyze traffic on a remote host, and NetFlow is not an option. In this case you need to enable a remote span that allows you to capture packets on a remote host and divert them to the host where ntopng runs. This task is usually carried on by a [virtual tap](https://en.wikipedia.org/wiki/Network_tap) that is often quite expensive.

ntop has developed [nTap](https://www.ntop.org/products/traffic-analysis/ntap/) that is a software virtual tap, suitable to be deployed in the cloud, in a VM, container or physical host. nTap is logically implemented with two components:

- a remote tap that captures traffic, encrypts it, and sends it to remote collector
- a central collector application that receives encryoted packets sent by the remote tap(s). The collector is not needed with ntopng Enterprise L as it natively includes nTap collection capabilities.

![nTap Integation with ntopng](../../img/ntap_ntopng.png)

A single ntopng instance can collect traffic from multiple remote taps.

Below you can find a summary of the commands that need to be used in order to collect nTap traffic. All commands need to be started by root or via sudo.

## ntopng Enterprise L {#ntopng-enterprise-l}

The Enterprise L edition of ntopng has native nTap support meaning that you do not need a nTap license as ntopng embeds the logic present in the nTap collector.

Suppose to start ntopng on host 1.2.3.4 and let it listen on port 5678, and encrypt traffic with key 'hello'. You can start the applications as follows:

- [ntopng host] ntopng -i ntap:5678:hello
- [remote host we want we want to monitor] tap -i eth0 -c 1.2.3.4:5678 -k hello

::: info
Due to nature of nTap, only one application can collect traffic sent by remote probes. In case of ntopng enterprise L, if you receive traffic with -i ntap:XXX:YYY those packets will be sent only to ntopng. This means that if you also want to enable n2disk/nProbe over ntap, you should start the ntap_collector (a nTap license is needed) and create a virtual ntap0 device to which ntopng, nProbe and n2disk can attach simultaneously.
:::

## All Other ntopng Editions {#all-other-ntopng-editions}

All other ntopng versions can collect nTap traffic via the collector component that instead require a separate license:

Suppose to start ntopng on host 1.2.3.4 and let it listen on port 5678, and encrypt traffic with key 'hello'. You can start the applications as follows:

- [ntopng host] collector -p 5678 -k hello -i ntap0
- [ntopng host] ntopng -i ntap0
- [remote host we want we want to monitor] tap -i eth0 -c 1.2.3.4:5678 -k hello
