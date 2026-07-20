/* (C) 2026 - ntop.org
   Shared helpers for the sites dashboard and its per-node sub-components
   (network/exporters/exporter-traffic dashboards). */

/* Resolves a click anywhere inside a BootstrapTable row to the underlying
   data row and invokes handler(row) with it. */
export function onRowClick(event, rows, handler) {
    const tr = event.target.closest("tbody tr");
    if (!tr) return;
    if (event.target.closest("a")) event.preventDefault();
    const index = Array.from(tr.parentElement.children).indexOf(tr);
    if (rows[index]) handler(rows[index]);
}

const RECENT_ACTIVITY_WINDOW_SECS = 5 * 60;

/* True if timeLastUsed (unix seconds) falls within the last 5 minutes. */
export function isRecentlyActive(timeLastUsed) {
    if (!timeLastUsed) return false;
    return (Date.now() / 1000 - timeLastUsed) <= RECENT_ACTIVITY_WINDOW_SECS;
}
