<!--
  (C) 2026 - ntop.org
  Networks table for the sites dashboard "networks" tab: lists every network
  grouping reported for the current site and lets the user drill into one.
  Props:
    - networks: Array<{id, name}> — rows to render
    - loading: Boolean — hierarchy fetch in flight (suppresses the NoData empty state)
    - titleLink: Object|null — DashboardCard title-link (see dashboard-card.vue)
  Emits:
    - select(network): a network row was clicked
-->
<template>
    <DashboardCard :title="_i18n('sites_dashboard.networks')" icon="bi bi-diagram-3-fill" :titleLink="titleLink"
        noPadding>
        <NoData v-if="!loading && networks.length === 0" :show="true" />
        <div v-else class="sites-dashboard-clickable-table" @click="(ev) => onRowClick(ev, networks, (n) => emit('select', n))">
            <BootstrapTable :id="'sites_dashboard_networks'" :columns="columns" :rows="networks"
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
    networks: { type: Array, default: () => [] },
    loading: Boolean,
    titleLink: { type: Object, default: null },
});

const emit = defineEmits(["select"]);

const columns = [
    { id: "name", label: _i18n("sites_dashboard.network") },
];
function printColumn(col) { return col.label; }
function printRow(col, row) { return `<a href="#" class="sites-dashboard-row-link">${row.name}</a>`; }
</script>
