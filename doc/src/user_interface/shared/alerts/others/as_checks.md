---
title: "Autonomous Systems Behavioural Checks"
description: "Autonomous Systems checks are designed to spot changes in the traffic of the configured Autonomous Systems."
outline: [2, 3]
lastUpdated: 2026-11-05T16:44:55+01:00
---
# Autonomous Systems Behavioural Checks {#autonomous-systems-behavioural-checks}

Autonomous Systems checks are designed to spot changes in the traffic of the configured Autonomous Systems.

______________________________________________________________________

## AS Exporter Ranking Changed {#as-exporter-ranking-changed}

Checks the flow exporter ranking of the configured Autonomous Systems.

The check runs every hour. The alert is sent when a configured AS (Policies -> Network Configuration -> ASN Config) changes its flow exporter ranking.

*Interface: Packet & ZMQ*

*Category: Network*

*Not Enabled by Default*
