<!-- (C) 2026 - ntop.org -->
<template>
  <div class="m-2 mb-3">
    <TableWithConfig ref="exporter_sites_list" :table_id="table_id" :csrf="csrf" :showLoading="true"
      @custom_event="on_table_custom_event" :f_map_columns="map_table_def_columns"
      :get_extra_params_obj="get_extra_params_obj"
      :f_sort_rows="columns_sorting">
        <template v-slot:custom_buttons>
            <button class="btn btn-link" type="button" @click="addExporterSite">
            <i class="fas fa-plus" data-bs-toggle="tooltip" data-bs-placement="top"
                :title="_i18n('exporter_sites_page.add_exporter_site')"></i>
            </button>
        </template>
    </TableWithConfig>
    <ModalEditExporterSite 
        ref="exporterSiteModal" 
        :errorMessage="modalErrorMessage"
        @edit="handleEditExporterSite" @add="handleAddExporterSite"> 
    </ModalEditExporterSite>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as dataUtils } from "../utilities/data-utils.js";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as ModalEditExporterSite } from "./modal-edit-exporter-site.vue";


/* ************************************** */

const _i18n = (t) => i18n(t);
const props = defineProps({ context: Object });

/* ************************************** */
const loading = ref(false);
const table_id = ref("exporter_sites_list");
const exporter_sites_list = ref(null);
const editingExporterSiteId = ref(null);
const modalErrorMessage = ref("");
const csrf = props.context.csrf;
const exporterSiteModal = ref(null);
const edit_exporter_site_url = `${http_prefix}/lua/pro/rest/v2/edit/exporter_site/exporter_site.lua`;
const add_exporter_site_url = `${http_prefix}/lua/pro/rest/v2/add/exporter_site/exporter_site.lua`;
const delete_exporter_site_url = `${http_prefix}/lua/pro/rest/v2/delete/exporter_site/exporter_site.lua`;

/* ************************************** */

const map_table_def_columns = (columns) => {
    let map_columns = {
        "name": (value, row) => {
            return value
        },
        "description": (value, row) => {
            return value
        },
        "location": (value, row) => {
            let location = ''
            if (!dataUtils.isZeroOrEmptyString(row.latitude) && !dataUtils.isZeroOrEmptyString(row.longitude)) {
                location = `${row.latitude}° ${_i18n('exporter_sites_page.exporter_site_latitude')}, ${row.longitude}° ${_i18n('exporter_sites_page.exporter_site_longitude')}`
            }
            return location
        },
    };

    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
        if (c.id === "actions") {
            c.button_def_array.forEach((b) => {
                b.f_map_class = (current_class, row) => {
                    if (row.id === 0) {
                        current_class.push("disabled");
                    }
                    return current_class;
                };
            });
        }
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
        "click_button_edit_exporter_site": click_button_edit_exporter_site,
        "click_button_delete_exporter_site": click_button_delete_exporter_site
    };
    if (events_managed[event.event_id] == null) {
        return;
    }
    events_managed[event.event_id](event);
}

const click_button_edit_exporter_site = (event) => {
    if(event.row.id === 0) return;
    editingExporterSiteId.value = event.row.id;
    
    const exporter_site_data = {
        exporter_site_name: event.row.name,
        exporter_site_description: event.row.description,
        exporter_site_lat: event.row.latitude,
        exporter_site_lng: event.row.longitude,
        exporter_site_reserved: event.row.reserved,
    };

    showEditModal(exporter_site_data);
};

async function click_button_delete_exporter_site(event) {
    if(event.row.id === 0) return;
    const exporter_site = event.row.id;

    const requestParams = {
        csrf: props.context.csrf,
        exporter_site: exporter_site
    };

    const headers = { 'Content-Type': 'application/json' };

    try {
        await ntopng_utility.http_request(delete_exporter_site_url, {
            method: 'post',
            headers,
            body: JSON.stringify(requestParams)
        });

        // Refresh table after delete
        exporter_sites_list.value.refresh_table(true);
    } catch (e) {
        console.error('Error deleting exporter site:', e);
        exporter_sites_list.value.refresh_table(true);
    }
}


/* ************************************** */

const showEditModal = (item) => {
    exporterSiteModal.value.showEdit(item);
};

/* ************************************** */

function addExporterSite() {
    exporterSiteModal.value.showAdd();
}


/* ************************************** */

const handleEditExporterSite = async (data) => {
    modalErrorMessage.value = "";
    
    const exporter_site_id = editingExporterSiteId.value;
    const new_exporter_site_name = data.exporter_site_name;
    const new_exporter_site_description = data.exporter_site_description;
    const new_exporter_site_lat = data.exporter_site_lat;
    const new_exporter_site_lng = data.exporter_site_lng;

    const headers = {
        'Content-Type': 'application/json'
    };

    try {
        const addParams = {
            csrf: props.context.csrf,
            exporter_sites: [{
                exporter_site_id: exporter_site_id,
                exporter_site_name: new_exporter_site_name,
                exporter_site_description: new_exporter_site_description,
                latitude: new_exporter_site_lat,
                longitude: new_exporter_site_lng
            }]
        };

        const rsp = await ntopng_utility.http_request(edit_exporter_site_url, {
            method: 'post',
            headers,
            body: JSON.stringify(addParams)
        });

        if (rsp?.success === false) {
            modalErrorMessage.value = rsp.msg || _i18n("error");
            return;
        }

        exporter_sites_list.value.refresh_table(true);
        exporterSiteModal.value.close();

        // Refresh table
        exporter_sites_list.value.refresh_table(true);

    } catch (e) {
        console.error('Error during exporter site edit:', e);
    }
};

/* ************************************** */

const handleAddExporterSite = async (data) => {
    modalErrorMessage.value = "";
    
    const headers = { 'Content-Type': 'application/json' };

    const addParams = {
        csrf: props.context.csrf,
        exporter_sites: [{
            exporter_site_name: data.exporter_site_name,
            exporter_site_description: data.exporter_site_description,
            latitude: data.exporter_site_lat,
            longitude: data.exporter_site_lng
        }]
    };

    try {
        const res = await ntopng_utility.http_request(add_exporter_site_url, {
            method: 'post',
            headers,
            body: JSON.stringify(addParams)
        });
        
        if (res?.success === false) {
            modalErrorMessage.value = res.msg || _i18n("error");
            return;
        }

        exporter_sites_list.value.refresh_table(true);
        exporterSiteModal.value.close();

    } catch (e) {
        console.error('Error adding exporter site:', e);
    }
};

/* ************************************** */

onMounted(async () => {
});

</script>
