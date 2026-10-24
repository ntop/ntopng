---
name: ntopng
description: Evidence-first network monitoring UI; Bootstrap 5 + Vue 3, ntop orange signal on tonal light/dark surfaces.
colors:
  ntop-orange: "#FF8F00"
  ntop-orange-light: "#FFC046"
  ntop-orange-dark: "#C56000"
  rail-orange: "#FF7500"
  ntop-blue: "#37474F"
  ntop-blue-light: "#62717B"
  ntop-blue-dark: "#101F27"
  on-accent: "#000000"
  light-base: "#F5F7FA"
  light-surface: "#FFFFFF"
  light-elevated: "#F8F9FA"
  light-sunken: "#F1F3F5"
  light-border: "#DEE2E6"
  light-border-subtle: "#E9ECEF"
  light-text: "#111111"
  dark-base: "#0D1117"
  dark-surface: "#161B22"
  dark-elevated: "#21262D"
  dark-border: "#30363D"
  dark-text: "#E6EDF3"
  dark-muted: "#8B949E"
  rail-bg: "#212529"
  topbar-dark: "#1A1D21"
typography:
  body:
    fontFamily: "Inter, Segoe UI, -apple-system, BlinkMacSystemFont, sans-serif"
  mono:
    fontFamily: "ui-monospace, SFMono-Regular, SF Mono, Menlo, Consolas, monospace"
rounded:
  lg: ".5rem"
spacing:
  rail-collapsed: "4rem"
  rail-expanded: "14.5rem"
  navbar-height: "3rem"
components:
  button-primary:
    backgroundColor: "{colors.ntop-orange}"
    textColor: "{colors.on-accent}"
  button-primary-hover:
    backgroundColor: "#FFA026"
  button-secondary:
    backgroundColor: "{colors.ntop-blue}"
    textColor: "#FFFFFF"
  button-secondary-hover:
    backgroundColor: "#2F3C43"
---

# Design System: ntopng

## Overview

**Creative North Star: "The Packet Ledger"**

Data is the decoration. Screens read like a ledger: tables, counters and charts on quiet tonal surfaces, with ntop orange reserved as the signal that something is selectable, active or needs attention. Layout is dense and exact; controls are compact with thin borders and no ornament.

Light and dark themes are equal siblings, switched via `data-bs-theme`. The dark palette is a cool GitHub-style stack; the light palette is white surfaces on a faint grey-blue base. Nothing is theme-only.

**Key Characteristics:**
- Tonal layering instead of shadows
- Single orange accent, black text on it
- Inter for UI, monospace for addresses, ports and payloads
- Fixed left rail plus slim top bar (app shell)
- Bootstrap 5 components as the base vocabulary

## Colors

Cool-neutral surfaces with one warm accent; the secondary slate-blue anchors secondary actions.

### Primary
- **ntop Orange** (#FF8F00): primary buttons, active states, key emphasis. Always paired with black text (#000000), never white.
- **Signal Amber** (#FFC046): light variant for alert text and highlights in dark theme.
- **Burnt Orange** (#C56000): dark variant for pressed/low-emphasis accent on light.
- **Rail Orange** (#FF7500): active link in the sidebar rail only.

### Secondary
- **Slate Blue** (#37474F): secondary buttons and muted text on light. Lighter (#62717B) and darker (#101F27) steps exist.

### Neutral
- **Light:** base #F5F7FA, surface #FFFFFF, elevated #F8F9FA, sunken #F1F3F5, border #DEE2E6, subtle border #E9ECEF, text #111111.
- **Dark:** base #0D1117, surface #161B22, elevated #21262D, border #30363D, text #E6EDF3, muted #8B949E.
- **Chrome:** sidebar rail #212529, dark top bar #1A1D21.

### Named Rules
**The One Signal Rule.** Orange marks interactivity or attention. If a screen is mostly orange, nothing stands out.
**The Black-On-Orange Rule.** Text on orange fills is #000000. White on orange fails AA contrast.

## Typography

**Body Font:** Inter (with Segoe UI, system sans fallbacks)
**Mono Font:** ui-monospace / SFMono / Menlo / Consolas

**Character:** Neutral, legible, tabular. Mono carries IPs, MACs, ports and hashes so columns align.

### Hierarchy
- **Body** (400, Bootstrap default size): table cells, forms, descriptions.
- **Label** (muted colour, small): column headers, field labels, panel section labels (muted rail label rgba(255,255,255,.35) on dark).
- **Mono** (400): identifiers and raw values.

Sizes follow Bootstrap defaults; no custom display scale has been observed.

### Named Rules
**The Aligned Numbers Rule.** Numeric and identifier columns use mono or tabular figures so values compare vertically.

## Layout

App shell: fixed left rail (4rem collapsed, 14.5rem expanded) with a flyout panel, and a 3rem top bar. Content is dense Bootstrap grid and dashboard grids (grid-layout-plus). Pages are Operate-mode: tables and charts first, filters in a row above. Spacing follows Bootstrap's scale.

## Elevation & Depth

Flat by default. Depth comes from tonal layering: base, then surface, then elevated, with 1px borders (#DEE2E6 light / #30363D dark) separating regions. Focus uses Bootstrap's 0.25rem ring tinted from the button colour (orange ring `#D97A0080`, slate `#55636980`).

### Named Rules
**The Border-Not-Shadow Rule.** Separate regions with tonal steps and hairline borders, not drop shadows.

## Shapes

Bootstrap rounding: `--bs-border-radius-lg` is .5rem; default controls use Bootstrap's standard small radius. Corners are modest and consistent; no pills except badges.

## Components

Restrained and exact: compact controls, thin borders, no ornament.

### Buttons
- **Primary:** ntop Orange fill, black text; hover #FFA026, active #FFA533.
- **Secondary:** Slate Blue fill, white text; hover #2F3C43.
- **Focus:** 0.25rem ring in a translucent shade of the fill.

### Alerts
- Tinted background (orange at ~10% on `alert-primary`), border at ~28%, text in the light accent in dark theme.

### Badges
- Dark badge uses amber (#FFA026) in dark theme; info badge text is white.

### Navigation
- Dark rail (#212529) in both themes, link colour rgba(226,226,226,.82), hover #2C3034, active Rail Orange. Top bar is white in light theme and #1A1D21 in dark. Dropdowns and panels take theme-matched backgrounds with 1px translucent borders.

### Tables / Datatables
- Bootstrap tables and datatables are the core pattern; header in muted label style, rows on surface, hover on elevated.

## Do's and Don'ts

### Do:
- **Do** build with Bootstrap 5 components and the existing CSS variables (`--bg-*`, `--border-color`, `--ntop-*`).
- **Do** verify every new view in both light and dark themes.
- **Do** use black text on orange fills and keep AA contrast everywhere.
- **Do** use monospace for IPs, MACs, ports and hashes.

### Don't:
- **Don't** introduce another accent colour for decoration; status colours only for status.
- **Don't** use drop shadows to separate regions.
- **Don't** hard-code hex values in new components when a variable exists.
- **Don't** swap or add a UI framework; Bootstrap 5 + Vue 3 stays.
