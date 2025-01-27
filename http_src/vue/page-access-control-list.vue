<!-- (C) 2024 - ntop.org     -->
<template>
  <div class="m-2 mb-3">
    <template v-if="(!props.context.is_check_enabled)">
      <div class="alert alert-warning" role="alert" id='error-alert' v-html:="error_message">
      </div>
    </template>
    <div :class="[(!props.context.is_check_enabled) ? 'ntopng-gray-out' : '']">
      <TableWithConfig ref="table_access_control_list" :table_id="table_id" :csrf="context.csrf"
        :f_map_columns="map_table_def_columns" :get_extra_params_obj="get_extra_params_obj"
        :f_sort_rows="columns_sorting" @custom_event="on_table_custom_event">
        <template v-slot:custom_buttons>
          <button class="btn btn-link" type="button" @click="add_rule">
            <i class="fas fa-plus" data-bs-toggle="tooltip" data-bs-placement="top"
              :title="_i18n('policy.add_rule')"></i>
          </button>
        </template>
        <template v-slot:custom_header>
          <div class="dropdown me-3 d-inline-block" v-for="item in filter_table_array">
            <span class="no-wrap d-flex align-items-center my-auto me-2 filters-label"><b>{{ item["basic_label"]
                }}</b></span>
            <SelectSearch v-model:selected_option="item['current_option']" theme="bootstrap-5" dropdown_size="small"
              :options="item['options']" @select_option="add_table_filter">
            </SelectSearch>
          </div>
          <div class="d-flex justify-content-center align-items-center">
            <div class="btn btn-sm btn-primary mt-2 me-3" type="button" @click="reset_filters">
              {{ _i18n('reset') }}
            </div>
          </div>
        </template> <!-- Dropdown filters -->
      </TableWithConfig>
      <div class="card-footer mt-3">
        <button type="button" ref="delete_all_rules" @click="delete_all_rules" class="btn btn-danger">
          <i class="fas fa-trash"></i>
          {{ _i18n("acl_page.delete_all_rules") }}
        </button>
        <button type="button" ref="export_rules" @click="export_rules" class="btn btn-primary ms-1">
          <i class="fas fa-file-export"></i>
          {{ _i18n("acl_page.export_rules") }}
        </button>
      </div>
      <NoteList :note_list="notes"></NoteList>
    </div>
  </div>
  <ModalAddACLRule ref="modal_add" :context="context" :url_request="url_add_request" :l4_proto_list="l4_proto"
    :l7_proto_list="l7_proto" @add="refresh_table">
  </ModalAddACLRule>
  <ModalEditACLRule ref="modal_edit" :context="context" :url_request="url_edit_request" :l4_proto_list="l4_proto"
    :l7_proto_list="l7_proto" @edit="refresh_table">
  </ModalEditACLRule>
  <ModalDeleteACLRule ref="modal_delete" :context="context" @delete_rule="refresh_table">
  </ModalDeleteACLRule>
  <ModalDeleteAllACLRules ref="modal_delete_all" :context="context" @delete_rules="refresh_table">
  </ModalDeleteAllACLRules>
  <!--
  <ModalDeleteInactiveHost ref="modal_delete" :context="context" @delete_host="refresh_table"></ModalDeleteInactiveHost>
  <ModalDeleteInactiveHostEpoch ref="modal_delete_older" :context="context" @delete_host="refresh_table">
  </ModalDeleteInactiveHostEpoch>
  <ModalDownloadInactiveHost ref="modal_download" :context="context"></ModalDownloadInactiveHost>
-->
</template>

<script setup>
import { ref, nextTick, onMounted, onBeforeMount } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as dataUtils } from "../utilities/data-utils.js";
import { default as ModalAddACLRule } from "./modal-add-acl-rule.vue";
import { default as ModalEditACLRule } from "./modal-edit-acl-rule.vue";
import { default as ModalDeleteACLRule } from "./modal-delete-acl-rule.vue";
import { default as ModalDeleteAllACLRules } from "./modal-delete-all-acl-rules.vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as NoteList } from "./note-list.vue";

const _i18n = (t) => i18n(t);
const table_access_control_list = ref(null);
const modal_add = ref(null);
const modal_edit = ref(null);
const modal_delete = ref(null);
const modal_delete_all = ref(null);
const filter_table_array = ref([]);
const error_message = i18n('acl_page.check_disabled') + " <a href='" + http_prefix + "/lua/admin/edit_configset.lua?subdir=all#disabled'><i class='fas fa-cog fa-sm'></i></a>";
const table_id = ref('access_control_list');
const url_add_request = '/lua/pro/rest/v2/add/system/access_control_list_rules.lua'
const url_edit_request = '/lua/pro/rest/v2/add/system/edit_access_control_list_rule.lua'
const date_format = ref(null)
const l4_proto = ref([])
const l7_proto = ref([])
const notes = [
  _i18n("acl_page.acl_use"),
  _i18n("acl_page.non_blocking_rules"),
  _i18n("acl_page.add_new_rule"),
  _i18n("acl_page.action_column"),
  _i18n("acl_page.action_delete_all_rules")
]

/* ************************************** */

const props = defineProps({
  context: Object,
});

/* ******************************************************************** */

/* Function to add a new host to scan */
function add_rule() {
  if (props.context.host != null && props.context.host != "")
    modal_add.value.show(null, props.context.host);
  else modal_add.value.show();
}

/* ************************************** */

const map_table_def_columns = (columns) => {
  let map_columns = {
    "proto": (value, row) => {
      if (value)
        return value.name

      return ""
    },
    "l7_proto": (value, row) => {
      if (value)
        return value.name

      return ""
    },
    "client": (value, row) => {
      return value
    },
    "server": (value, row) => {
      return value
    },
    "port": (value, row) => {
      return value
    },
    "creation_timestamp": (value, row) => {
      if (value > 0) {
        return ntopng_utility.from_utc_to_server_date_format(value * 1000, date_format.value)
      }
      return ''
    }
  };

  columns.forEach((c) => {
    c.render_func = map_columns[c.data_field];
    if (c.id == "actions") {
      const visible_dict = {
        edit_rule: true,
        delete_rule: true,
      };
      c.button_def_array.forEach((b) => {
        if (!visible_dict[b.id]) {
          b.class.push("link-disabled");
        }
      });
    }
  });

  return columns;
};

/* ************************************** */

function column_data(col, row) {
  return row[col.data.data_field];
}

/* ************************************** */

function columns_sorting(col, r0, r1) {
  if (col != null) {
    let r0_col = column_data(col, r0);
    let r1_col = column_data(col, r1);

    /* In case the values are the same, sort by IP */
    if (col.id == "proto") {
      let val0 = r0_col
      let val1 = r1_col
      if (r0_col) val0 = r0_col.name
      if (r1_col) val1 = r1_col.name
      return sortingFunctions.sortByName(val0, val1, col.sort);
    } else if (col.id == "l7_proto") {
      let val0 = r0_col
      let val1 = r1_col
      if (r0_col) val0 = r0_col.name
      if (r1_col) val1 = r1_col.name
      return sortingFunctions.sortByName(val0, val1, col.sort);
    } else if (col.id == "client") {
      return sortingFunctions.sortByIP(r0_col, r1_col, col.sort);
    } else if (col.id == "server") {
      return sortingFunctions.sortByIP(r0_col, r1_col, col.sort);
    } else if (col.id == "port") {
      const lower_value = 0;
      return sortingFunctions.sortByNumberWithNormalizationValue(r0_col, r1_col, col.sort, lower_value);
    } else if (col.id == "creation_timestamp") {
      const lower_value = 0;
      return sortingFunctions.sortByNumberWithNormalizationValue(r0_col, r1_col, col.sort, lower_value);
    } else if (col.id == "annotation") {
      return sortingFunctions.sortByName((r0_col || ""), (r1_col || ""), col.sort);
    }
  }
}

/* ************************************** */

/* This function is used to load the filters for the table */
async function load_table_filters_array() {
  let extra_params = get_extra_params_obj();
  let url_params = ntopng_url_manager.obj_to_url_params(extra_params);
  const url = `${http_prefix}/lua/pro/rest/v2/get/system/acl_filters.lua?${url_params}`;
  // Get the filters
  let res = await ntopng_utility.http_request(url);

  // Load them as an array, that is going to update automatically the filters
  return res.map((t) => {
    const key_in_url = ntopng_url_manager.get_url_entry(t.name);
    if (dataUtils.isEmptyOrNull(key_in_url)) {
      ntopng_url_manager.set_key_to_url(t.name, ``);
    }
    return {
      id: t.name,
      label: t.label,
      title: t.tooltip,
      options: t.value,
      hidden: (t.value.length == 1)
    };
  });
}

/* ************************************** */

function reset_filters() {
  filter_table_array.value.forEach((el, index) => {
    /* Getting the currently selected filter */
    ntopng_url_manager.set_key_to_url(el.id, ``);
  })
  load_table_filters_array();
  refresh_table();
}

/* ************************************** */

/* This function is automatically called whenever a filter is set, going to update the
 * filter label and refresh the table
 */
async function add_table_filter(opt) {
  ntopng_url_manager.set_key_to_url(opt.key, `${opt.value}`);
  refresh_table();
  filter_table_array.value = await load_table_filters_array();
  set_filter_array_label()
}

/* ************************************** */

/* This function is going to set the label shown on the dropdown */
function set_filter_array_label() {
  filter_table_array.value.forEach((el, index) => {
    /* Setting the basic label */
    if (el.basic_label == null) {
      el.basic_label = el.label;
    }

    /* Getting the currently selected filter */
    const url_entry = ntopng_url_manager.get_url_entry(el.id)
    el.options.forEach((option) => {
      if (option.value.toString() === url_entry) {
        el.current_option = option;
      }
    })
  })
}

/* ************************************** */

const get_extra_params_obj = () => {
  let extra_params = ntopng_url_manager.get_url_object();
  return extra_params;
};

/* ************************************** */

function click_button_edit_rule(event) {
  const row = event.row;
  modal_edit.value.show(row);
}

/* ************************************** */

function click_button_delete_rule(event) {
  const row = event.row;
  modal_delete.value.show(row);
}

/* ************************************** */

function delete_all_rules() {
  modal_delete_all.value.show();
}

/* ************************************** */

function export_rules() {
  const url = `${http_prefix}/lua/pro/rest/v2/get/system/access_control_list.lua?`
  const params = ntopng_url_manager.get_url_params()
  window.open(url + params + '&download=true');
}

/* ************************************** */

function on_table_custom_event(event) {
  let events_managed = {
    "click_button_edit_rule": click_button_edit_rule,
    "click_button_delete_rule": click_button_delete_rule,
  };
  if (events_managed[event.event_id] == null) {
    return;
  }
  events_managed[event.event_id](event);
}

/* ************************************** */

async function load_protocols() {
  let url = `${http_prefix}/lua/rest/v2/get/l4/protocol/consts.lua`;
  let rsp = await ntopng_utility.http_request(url);
  l4_proto.value = rsp.map((t) => {
    return {
      id: t.id,
      label: t.name,
      title: t.name,
    };
  })
  /* *** Special case *** */
  l4_proto.value.unshift({
    id: 'arp',
    label: 'ARP',
    title: 'ARP',
  })
  url = `${http_prefix}/lua/rest/v2/get/l7/application/consts.lua`;
  rsp = await ntopng_utility.http_request(url);
  l7_proto.value = rsp.map((t) => {
    return {
      id: t.appl_id,
      label: t.name,
      title: t.name,
    };
  })
}

/* ************************************** */

function refresh_table() {
  table_access_control_list.value.refresh_table(true);
}

onBeforeMount(async () => {
  date_format.value = await ntopng_utility.get_date_format(false, props.context.csrf, http_prefix);
})

/* ************************************** */

onMounted(async () => {
  filter_table_array.value = await load_table_filters_array();
  set_filter_array_label()
  await load_protocols()
});

/* ************************************** */

</script>
