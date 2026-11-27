---
title: "Monitoring Large Networks"
description: "ntopng is designed to process a few million packet/sec per interface. With adequate hardware you can monitor up to 10 Gbit when splitting the traffic..."
outline: [2, 3]
lastUpdated: 2021-06-17T18:57:00+02:00
---
# Monitoring Large Networks {#monitoring-large-networks}

ntopng is designed to process a few million packet/sec per interface. With adequate hardware you can monitor up to 10 Gbit when splitting the traffic across multiple interfaces, for instance using techniques such as RSS. If you want to push ntopng in the 10 Gbit+ land, it is necessary to use a different approach. Namely preprocess traffic using [nProbe Cento](https://www.ntop.org/products/netflow/nprobe-cento/) that acts as a probe, and use ntopng as flow collector. This way cento preprocesses the traffic letting ntopng to do the collection and visualization, and thus reducing the load with respect to ingesting packets directly in ntopng. You can [read more here](https://www.ntop.org/guides/cento/usecases.html#integration-with-ntopng) about integrating nProbe Cento with ntopng.

::: info
An nProbe Cento and PF_RING \_ZC license is required to operate Cento at high speed.
:::
