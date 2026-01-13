<!-- (C) 2026 - ntop.org -->
<template>
  <div class="m-2 mb-3">
    <TableWithConfig ref="labels_list" :table_id="table_id" :csrf="csrf" :showLoading="true"
      @custom_event="on_table_custom_event" :f_map_columns="map_table_def_columns"
      :get_extra_params_obj="get_extra_params_obj"
      :f_sort_rows="columns_sorting">
    </TableWithConfig>
    <ModalEditLabel ref="labelModal" @edit="handleEditLabel"> </ModalEditLabel>
  </div>
</template>

<script setup>
import { ref, onMounted, nextTick } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as SelectSearch } from "./select-search.vue";
import { default as dataUtils } from "../utilities/data-utils.js";
import { default as Spinner } from "./spinner.vue";
import formatterUtils from "../utilities/formatter-utils";
import { default as ModalEditLabel } from "./modal-edit-label.vue";


/* ************************************** */

const _i18n = (t) => i18n(t);
const props = defineProps({ context: Object });

/* ************************************** */
const loading = ref(false);
const table_id = ref("labels_list");
const labels_list = ref(null);
const csrf = props.context.csrf;
const labelModal = ref(null);
const edit_label_url = `${http_prefix}/lua/rest/v2/edit/label/label.lua`;
/* ************************************** */

const map_table_def_columns = (columns) => {
    let map_columns = {
        "name": (value, row) => {
            return "<span class='badge' style='background-color:"+ row.color +"'>" +
                    value + "</span> "
        },
        "description": (value, row) => {
            return value
        },
    };

    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
    });

    return columns;
};

/* ************************************** */

function columns_sorting(col, r0, r1) {
    if (col != null) {
        if (col.id == "name") {
            return sortingFunctions.sortByName(r0.name, r1.name, col.sort);
        }
    }
 }

/* ************************************** */

const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};

/* ************************************** */

function on_table_custom_event(event) {
    let events_managed = {
        "click_button_edit_label": click_button_edit_label
    };
    if (events_managed[event.event_id] == null) {
        return;
    }
    events_managed[event.event_id](event);
}

const click_button_edit_label = (event) => {
    const label_data = {
        label_name: event.row.name,
        label_color: event.row.color,
        label_description: event.row.description,
        label_reserved: event.row.reserved,
    };

    showEditModal(label_data);
};

/* ************************************** */

const showEditModal = (item) => {
    labelModal.value.showEdit(item);
};

/* ************************************** */

const handleEditLabel = async (data) => {
    const old_label_name = data.item.label_name;
    const new_label_name = data.label_name;
    const new_label_color = data.label_color;
    const new_label_description = data.label_description;

    const headers = {
        'Content-Type': 'application/json'
    };

    try {
        const addParams = {
            csrf: props.context.csrf,
            labels: [{
                old_name: old_label_name,
                name: new_label_name,
                color: new_label_color,
                description: new_label_description
            }]
        };

        await ntopng_utility.http_request(edit_label_url, {
            method: 'post',
            headers,
            body: JSON.stringify(addParams)
        });

        // Refresh table
        labels_list.value.refresh_table(true);

    } catch (e) {
        console.error('Error during label edit:', e);
        labels_list.value.refresh_table(true);
    }
};

/* ************************************** */

onMounted(async () => {
});

</script>
