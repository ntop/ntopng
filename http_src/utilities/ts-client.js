/**
 * (C) 2026 - ntop.org
 *
 * Timeseries client — replaces metrics-manager.js + timeseries-utils.js + metrics-consts.js
 *
 * Public API:
 *   fetchTimeseries(queries, epochBegin, epochEnd, csrf)  → { meta, results }
 *   getCatalog(entity?)                                   → cached catalog object
 *   getSchemaInfo(schema)                                 → schema descriptor
 *   buildQuery(id, ts_schema, ts_query, opts?)            → query object for fetchTimeseries
 */

import { ntopng_utility } from "../services/context/ntopng_globals_services.js";

const http_prefix = window.http_prefix || "";

// ── catalog cache (session-scoped, epoch-independent) ────────────────────────
let _catalogPromise = null;

// ── public API ────────────────────────────────────────────────────────────────

/**
 * Fetch N timeseries in a single POST.
 *
 * @param {Array}  queries    - Array of query objects, each: { id, ts_schema, ts_query, compare?, limit? }
 * @param {number} epochBegin - Unix epoch start
 * @param {number} epochEnd   - Unix epoch end
 * @param {string} csrf       - CSRF token
 * @returns {Promise<{meta: Object, results: Object}>}
 *   meta:    { epoch_begin, epoch_end, date_format }
 *   results: { [query_id]: { series, metadata, error } }
 *
 * @example
 *   const { meta, results } = await fetchTimeseries([
 *     buildQuery("iface_traffic", "iface:traffic", "ifid:1"),
 *     buildQuery("host_traffic",  "host:traffic",  "ifid:1,host:192.168.1.5"),
 *   ], epochBegin, epochEnd, csrf);
 *   // results["iface_traffic"].series  →  chart data
 */
export async function fetchTimeseries(queries, epochBegin, epochEnd, csrf) {
    const url = `${http_prefix}/lua/rest/v2/get/timeseries/batch.lua`;
    return ntopng_utility.http_post_request(url, {
        csrf,
        epoch_begin: epochBegin,
        epoch_end:   epochEnd,
        queries,
    });
}

/**
 * Get the timeseries catalog (all available schemas per entity).
 * Result is cached for the lifetime of the page.
 *
 * @param {string} [entity] - Optional: "host", "iface", "asn", etc.
 * @returns {Promise<Object>} - { host: [...], iface: [...], ... }
 *
 * @example
 *   const catalog = await getCatalog("host");
 *   // catalog.host[0].schema  →  "host:traffic"
 *   // catalog.host[0].metrics →  [{id:"bytes_sent",label:"Sent"}, ...]
 */
export async function getCatalog(entity = null) {
    if (!_catalogPromise) {
        const url = entity
            ? `${http_prefix}/lua/rest/v2/get/timeseries/catalog.lua?entity=${encodeURIComponent(entity)}`
            : `${http_prefix}/lua/rest/v2/get/timeseries/catalog.lua`;
        _catalogPromise = ntopng_utility.http_request(url);
    }
    return _catalogPromise;
}

/**
 * Get detailed info for a single schema (for AI agents / tooling).
 *
 * @param {string} schema - e.g. "host:traffic"
 * @returns {Promise<Object>} - { schema, entity, tags_required, metrics, step, example_query }
 */
export async function getSchemaInfo(schema) {
    const url = `${http_prefix}/lua/rest/v2/get/timeseries/schema_info.lua?schema=${encodeURIComponent(schema)}`;
    return ntopng_utility.http_request(url);
}

/**
 * Build a query object for fetchTimeseries.
 *
 * @param {string} id        - Unique ID for this query (used to key results)
 * @param {string} ts_schema - Schema name, e.g. "host:traffic"
 * @param {string} ts_query  - Tag string, e.g. "ifid:1,host:192.168.1.5"
 * @param {Object} [opts]    - Optional: { compare, limit, tskey, ts_unify }
 * @returns {Object}
 */
export function buildQuery(id, ts_schema, ts_query, opts = {}) {
    return { id, ts_schema, ts_query, ...opts };
}

/**
 * Invalidate the catalog cache (call after interface changes).
 */
export function invalidateCatalogCache() {
    _catalogPromise = null;
}

/**
 * Convert a batch result entry to Dygraph-compatible options.
 * Handles the series array returned by ts_data.get_timeseries.
 *
 * @param {Object} result - One entry from batch.results[id]
 * @param {Object} meta   - The batch.meta object (for date_format)
 * @returns {Object|null} - Dygraph options object, or null if no data
 */
export function resultToDygraphOptions(result, meta) {
    if (!result || !result.series || result.series.length === 0) {
        return null;
    }
    // The backend already returns dygraph-compatible options from graph_utils
    // Just merge in the meta date_format for axis labels
    return {
        ...result,
        _date_format: meta?.date_format || "DD/MM/YYYY HH:mm:ss",
    };
}
