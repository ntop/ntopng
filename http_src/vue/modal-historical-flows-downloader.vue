<template>
    <modal :id="id_modal" ref="modal">
        <template v-slot:title>{{ _i18n('export.select_cols') }}</template>
        <template v-slot:body>
            <!-- Description -->
            <div class="alert alert-info py-2 mb-2 small" v-html="description"></div>

            <!-- Column toggles -->
            <div class="columns-scroll">
                <div class="columns-grid">
                    <div v-for="column in availableColumns" :key="column.id">
                        <div class="form-check form-switch mb-0">
                            <input :id="`column_${column.id}`" v-model="selectedColumns" :value="column.id"
                                type="checkbox" class="form-check-input" />
                            <label :for="`column_${column.id}`" class="form-check-label small">
                                {{ column.name || column.id }}
                            </label>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Action buttons -->
            <div class="d-flex gap-2 mt-2">
                <button type="button" @click="selectDefaultCols" class="btn btn-sm btn-primary">
                    {{ _i18n('export.select_default') }}
                </button>
                <button type="button" @click="selectAllCols" class="btn btn-sm btn-outline-secondary">
                    {{ _i18n('export.select_all') }}
                </button>
                <button type="button" @click="deselectCols" class="btn btn-sm btn-outline-secondary">
                    {{ _i18n('export.select_none') }}
                </button>
            </div>
        </template>

        <!-- Download button -->
        <template v-slot:footer>
            <a v-if="selectedColumns.length > 0" :href="downloadUrl" class="btn btn-success btn-sm me-2" target="_blank"
                @click="close">
                <i class="fas fa-download me-1"></i>{{ _i18n('export.download') }}
            </a>
        </template>
    </modal>
</template>

<script setup>
import { ntopng_url_manager } from "../services/context/ntopng_globals_services";
import { ref, computed, watch } from 'vue';
import { default as Modal } from "./modal.vue";

const _i18n = (t) => i18n(t);

// Default columns
const DEFAULT_COLUMN_IDS = [
    'cli_ip', 'srv_ip',
    'cli_port', 'srv_port',
    'vlan_id',
    'l4proto',
    'l7proto', 'l7cat',
    'bytes', 'packets',
    'first_seen', 'last_seen',
];

const props = defineProps({
    id: {
        type: String,
        required: true
    }
});

const modal = ref(null);
const availableColumns = ref([]);
const selectedColumns = ref([]);
const description = ref("");
const id_modal = computed(() => `${props.id}_modal`);

const downloadUrl = computed(() => {
    if (selectedColumns.value.length === 0) return '#';

    try {
        const entries = ntopng_url_manager.get_url_entries();
        let epoch_begin = ntopng_url_manager.get_url_entry("epoch_begin");
        let epoch_end = ntopng_url_manager.get_url_entry("epoch_end");

        let base_url = `${http_prefix}/lua/pro/rest/v2/get/host/flows/download_flow_records.lua?epoch_begin=${epoch_begin}&epoch_end=${epoch_end}`;
        base_url += `&visible_columns=${selectedColumns.value.join(',')}`;

        const addedParams = new Set(['epoch_begin', 'epoch_end', 'visible_columns']);
        for (const [key, value] of entries) {
            if (!addedParams.has(key)) {
                base_url += `&${encodeURIComponent(key)}=${encodeURIComponent(value)}`;
            }
        }
        return base_url;
    } catch (error) {
        console.error('Error parsing download URL:', error);
        return '#';
    }
});

watch(selectedColumns, () => { updateDescription(); }, { deep: true });

const selectDefaultCols = () => {
    const availableIds = new Set(availableColumns.value.map(col => col.id));
    selectedColumns.value = DEFAULT_COLUMN_IDS.filter(id => availableIds.has(id));
};

const selectAllCols = () => {
    selectedColumns.value = availableColumns.value.map(col => col.id);
};

const deselectCols = () => {
    selectedColumns.value = [];
};

const updateDescription = () => {
    if (selectedColumns.value.length === 0) {
        description.value = _i18n('export.select_cols_to_export');
    } else {
        description.value = `${_i18n('export.about_to_download')} ${selectedColumns.value.length}`;
    }
};

const close = () => { modal.value?.close(); };

const show = (columns = null) => {
    if (!columns) {
        console.error('No columns provided');
        return;
    }

    if (!Array.isArray(columns)) {
        columns = Object.entries(columns).map(([id, name]) => ({ id, name }));
    }

    columns.sort((a, b) => (a.name || a.id).toLowerCase().localeCompare((b.name || b.id).toLowerCase()));
    availableColumns.value = columns;

    // Select default columns on open
    selectDefaultCols();

    updateDescription();
    modal.value?.show();
};

defineExpose({ show, close });
</script>

<style scoped>
.columns-scroll {
    max-height: 260px;
    overflow-y: auto;
    padding: 0.5rem;
    border: 1px solid var(--bs-border-color, #dee2e6);
    border-radius: 0.375rem;
}

.form-check-label {
    cursor: pointer;
    user-select: none;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 100%;
}

.columns-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 0.25rem;
}
</style>
