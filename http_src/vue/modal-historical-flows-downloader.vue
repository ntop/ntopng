<template>
    <modal :id="id_modal" ref="modal">
        <template v-slot:title>{{ _i18n('export.select_cols') }}</template>
        <template v-slot:body>
            <!-- Description of how many columns are selected -->
            <div class="alert alert-info" v-html="description"></div>

            <!-- Show all columns and toggle switch -->
            <form style="height: 95%;">
                <div class="tab-content" style="height: 100%;">
                    <div class="row">
                        <div class="col-md-12">
                            <div class="form-group mb-3">
                                <label class="form-label">{{ _i18n('export.select_cols_to_export') }}:</label>
                                <div class="d-flex flex-wrap gap-2 mt-2">
                                    <!-- Display all available columns to toggle -->
                                    <div v-for="column in availableColumns" :key="column.id"
                                        class="form-check form-switch">
                                        <!-- Toggle button -->
                                        <input :id="`column_${column.id}`" v-model="selectedColumns" :value="column.id"
                                            type="checkbox" class="form-check-input" />
                                        <!-- Column name -->
                                        <label :for="`column_${column.id}`" class="form-check-label ms-2">
                                            {{ column.name || column.id }}
                                        </label>
                                    </div>
                                </div>
                            </div>

                            <!-- Buttons to select or deselect all columsn-->
                            <div class="form-group mb-3">
                                <div class="d-flex gap-2">
                                    <button type="button" @click="selectAllCols" class="btn btn-sm btn-outline-primary">
                                        {{ _i18n('export.select_all') }}
                                    </button>
                                    <button type="button" @click="deselectCols" class="btn btn-sm btn-outline-secondary">
                                        {{ _i18n('export.select_none') }}
                                    </button>
                                </div>
                            </div>

                        </div>
                    </div>
                </div>
            </form>
        </template>

        <!-- Download button -->
        <template v-slot:footer>
            <a v-if="selectedColumns.length > 0" :href="downloadUrl" class="btn btn-success me-2" target="_blank"
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
    // no col selected
    if (selectedColumns.value.length === 0) {
        return '#';
    }
    // create url for download
    try {

        let epoch_begin = ntopng_url_manager.get_url_entry("epoch_begin")
        let epoch_end = ntopng_url_manager.get_url_entry("epoch_end")
        let base_url = `${http_prefix}/lua/pro/rest/v2/get/host/flows/download_flow_records.lua?epoch_begin=${epoch_begin}&epoch_end=${epoch_end}`

        // add visible columns url
        base_url += `&visible_columns=${selectedColumns.value.join(',')}`
        
        return base_url;

    } catch (error) {
        console.error('Error parsing download URL:', error);
        return '#';
    }
});

// update counter of selected columns description on top
watch(selectedColumns, () => {
    updateDescription();
}, { deep: true });

// select all columns to export
const selectAllCols = () => {
    selectedColumns.value = availableColumns.value.map(col => col.id);
};

// deselect all
const deselectCols = () => {
    selectedColumns.value = [];
};

//compute description based on selected columns length
const updateDescription = () => {
    if (selectedColumns.value.length === 0) {
        description.value = _i18n('export.select_cols_to_export');
    } else {
        description.value = `${_i18n('export.about_to_download')} ${selectedColumns.value.length}`;
    }
};

const close = () => {
    modal.value?.close();
};

const show = (columns = null) => {
    if (!columns) {
        console.error('No columns provided');
        return;
    }

    // convert columns to array
    if (!Array.isArray(columns)) {
        columns = Object.entries(columns).map(([id, name]) => ({
            id,
            name
        }));
    }

    // sort by ascending name
    columns.sort((a, b) => {
        const nameA = (a.name).toLowerCase();
        const nameB = (b.name).toLowerCase();
        return nameA.localeCompare(nameB);
    });

    availableColumns.value = columns;

    // set all columns as selected by default
    selectedColumns.value = availableColumns.value
        .map(col => col.id);

    updateDescription();
    modal.value?.show();
};


// expose methods like all modals
defineExpose({
    show,
    close
});
</script>

<style scoped>
.form-check {
    min-width: 200px;
    margin-bottom: 0.5rem;
}

.form-check-input {
    margin-top: 0.125rem;
}

.form-check-label {
    cursor: pointer;
    user-select: none;
}

.gap-2 {
    gap: 0.5rem;
}

.d-flex {
    display: flex;
}

.flex-wrap {
    flex-wrap: wrap;
}

.me-1 {
    margin-right: 0.25rem;
}

.me-2 {
    margin-right: 0.5rem;
}

.ms-2 {
    margin-left: 0.5rem;
}

.mt-2 {
    margin-top: 0.5rem;
}
</style>