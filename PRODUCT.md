# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users
Network admins/ops, network/SOC analysts, and MSP/multi-site operators. They work in the ntopng web UI daily to monitor traffic, investigate flows, hosts and alerts, watch interfaces/SNMP/exporters, and configure the system. Multi-site operators move between many sites and exporters.

## Product Purpose
ntopng is a network traffic monitoring and analysis platform by ntop.org (C++ core, Lua server layer, Vue 3 frontend). The web UI lets operators see live and historical traffic, find the cause of anomalies and alerts, and manage the monitoring setup.

## Positioning
Deep packet/flow visibility (nDPI application detection, NetFlow/sFlow/IPFIX, packet capture) with behavioural analysis and alerting, from a single self-hosted tool.

## Operating Context
Data-dense Operate-mode screens: tables, charts, filters, drill-down from dashboard to host to flow. Used in long sessions, often on large monitors, in NOC/SOC settings.

## Capabilities and Constraints
- Design work scope: new Vue pages only (source in pro/http_src); legacy Lua-rendered pages are out of scope.
- Stack is fixed: Bootstrap 5 + Vue 3. No framework swap.
- Both light and dark themes must work.
- Frontend builds with `npm run build` (full build).

## Brand Commitments
Existing ntop brand (name, logo, colors) is binding; no rebrand.

## Evidence on Hand
Running dev instance and existing Vue pages in pro/http_src. No testimonials or customer claims on hand; do not fabricate any.

## Product Principles
- Scanability and data density over decoration; the operator's task comes first.
- New pages stay consistent with existing ntopng patterns and Bootstrap 5 components.
- Every page works in light and dark themes.
- Drill-down paths stay short from overview to host to flow.

## Accessibility & Inclusion
WCAG AA required.
