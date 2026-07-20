<!--
  (C) 2026 - ntop.org
  Exporters table for the sites dashboard "exporters" tab. Used both at site
  scope (all exporters for the site) and network scope (exporters belonging
  to one network) — the caller decides which list to pass in.
  Props:
    - exporters: Array — rows to render (already scoped by the caller)
    - loading: Boolean — hierarchy fetch in flight (suppresses the NoData empty state)
    - titleLink: Object|null — DashboardCard title-link (see dashboard-card.vue)
  Emits:
    - select(exporter): an exporter row was clicked
-->
<template>
    <DashboardCard :title="_i18n('sites_dashboard.exporters')" icon="bi bi-hdd-network" :titleLink="titleLink"
        noPadding>
        <NoData v-if="!loading && exporters.length === 0" :show="true" />
        <div v-else class="sites-dashboard-clickable-table" @click="(ev) => onRowClick(ev, exporters, (e) => emit('select', e))">
            <BootstrapTable :id="'sites_dashboard_exporters'" :columns="columns" :rows="exporters"
                :print_html_column="printColumn" :print_html_row="printRow" />
        </div>
    </DashboardCard>
</template>

<script setup>
import { default as DashboardCard } from "../dashboard-card.vue";
import { default as NoData } from "../no-data.vue";
import { default as BootstrapTable } from "../../bootstrap-table.vue";
import { onRowClick } from "../../../utilities/sites-dashboard-utils.js";

const _i18n = (t) => i18n(t);

defineProps({
    exporters: { type: Array, default: () => [] },
    loading: Boolean,
    titleLink: { type: Object, default: null },
});

const emit = defineEmits(["select"]);

const columns = [
    { id: "name", label: _i18n("sites_dashboard.exporter") },
    { id: "id", label: _i18n("sites_dashboard.ip_address") },
];
function printColumn(col) { return col.label; }
function printRow(col, row) {
    if (col.id === "name") return `<a href="#" class="sites-dashboard-row-link">${row.name}</a>`;
    return row[col.id];
}
</script>
