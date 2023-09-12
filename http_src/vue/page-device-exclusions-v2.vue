<template>
  

<div class="row">
  <div class="col-md-12 col-lg-12">
    <div class="alert alert-danger d-none" id='alert-row-buttons' role="alert">
    </div>
    <div class="card">
      <div class="card-body">
        <div v-if="is_learning_status" class="alert alert-info">
          {{ learning_message }}
        </div>
      	<div id="table_devices_vue">
          <modal-delete-confirm ref="modal_delete_confirm"
            :title="title_delete"
            :body="body_delete"
            @delete="delete_row">
          </modal-delete-confirm>
          <modal-delete-confirm ref="modal_delete_all"
            :title="title_delete_all"
            :body="body_delete_all"
            @delete="delete_all">
          </modal-delete-confirm>
          <modal-add-device-exclusion ref="modal_add_device"
            :title="title_add"
            :body="body_add"
            :footer="footer_add"
            :list_notes="list_notes_add"
            @add="add_device_rest">
          </modal-add-device-exclusion>
          <modal-edit-device-exclusion ref="modal_edit_device"
            :title="title_edit"
            :title_edit_all="title_edit_all"
            @edit="edit_row">
          </modal-edit-device-exclusion>
            
          <TableWithConfig ref="table_device_exclusions"
				        :csrf="csrf"
				        :table_id="table_id"
                :f_map_columns="map_table_def_columns"
				        :get_extra_params_obj="get_extra_params_obj"
                :f_map_config="map_config"
                :f_sort_rows="columns_sorting"
                @custom_event="on_table_custom_event">
                <template v-slot:custom_header>
                <button class="btn btn-link" type="button" ref="add_device" @click="add_device"><i
                    class='fas fa-plus'></i></button>
              </template>
          </TableWithConfig>
        </div>
      </div>
      <div class="card-footer">
        <button type="button" @click="delete_all_confirm"  class="btn btn-danger me-1">
          <i class='fas fa-trash'></i> {{ _i18n("edit_check.delete_all_device_exclusions") }}
        </button>
        <button type="button" @click="edit_all_devices_confirm"  class="btn btn-secondary">
          <i class='fas fa-edit'></i> {{ _i18n("edit_check.edit_all_devices_status") }}
        </button>
      </div>
    </div>
  </div>
</div>
</template>

<script setup>
import  TableWithConfig  from "./table-with-config.vue";
import  ModalDeleteConfirm  from "./modal-delete-confirm.vue";
import  ModalAddDeviceExclusion  from "./modal-add-device-exclusion.vue";
import  ModalEditDeviceExclusion  from "./modal-edit-device-exclusion.vue";
import { ref, onMounted } from "vue";


const table_device_exclusions = ref();
const modal_delete_confirm = ref();
const modal_delete_all = ref();
const modal_add_device = ref();
const modal_edit_device = ref();

const table_id = ref('device_exclusions');

const add_url             = `${http_prefix}/lua/pro/rest/v2/add/device/exclusion.lua`;
const delete_url          = `${http_prefix}/lua/pro/rest/v2/delete/device/exclusion.lua`;
const edit_url            = `${http_prefix}/lua/pro/rest/v2/edit/device/exclusion.lua`;
const learning_status_url = `${http_prefix}/lua/pro/rest/v2/get/device/learning_status.lua`;
const is_learning_status = ref(false);
const _i18n = (t) => i18n(t);

let title_delete= '';
let body_delete= '';
let title_delete_all= _i18n('edit_check.delete_all_device_exclusions');
let body_delete_all=  _i18n('edit_check.delete_all_device_exclusions_message');
let title_add= _i18n('edit_check.add_device_exclusion');
let body_add= _i18n('edit_check.add_device_exclusion_message');
let footer_add= _i18n('edit_check.add_device_exclusion_notes');
let list_notes_add= _i18n('edit_check.add_device_exclusion_list_notes');
let title_edit= _i18n('edit_check.edit_device_exclusion');
let title_edit_all= _i18n('edit_check.edit_all_devices_status');
let learning_message= _i18n('edit_check.learning');
let row_to_delete= ref(null);
let row_to_edit= ref(null);


const props = defineProps({
  page_csrf: String,
  is_clickhouse_enabled: Boolean
});

const rest_params = {
  csrf: props.page_csrf
};


/* ******************************************************************** */ 

/* Function to handle all buttons */
function on_table_custom_event(event) {
  
  let events_managed = {
    "click_button_edit_device": click_button_edit_device,
    "click_button_historical_flows": click_button_historical_flows,
    "click_button_delete": click_button_delete,
  };
  if (events_managed[event.event_id] == null) {
    return;
  }
  events_managed[event.event_id](event);
}

async function click_button_delete(event) {
  let body = `${i18n('edit_check.delete_device_exclusion')} ${event.row.mac_address.mac}`;
  row_to_delete.value = event.row;

  body_delete = body;

  title_delete = i18n('edit_check.device_exclusion');
  modal_delete_confirm.value.show(body_delete, title_delete);    
  
}

async function click_button_edit_device(event) {
  row_to_edit.value = event.row;
  modal_edit_device.value.show(row_to_edit.value);  
}

function click_button_historical_flows(event) {
  const rowData = event.row;
  const url = `${http_prefix}/lua/pro/db_search.lua?epoch_begin=${rowData.first_seen.timestamp}&epoch_end=${rowData.last_seen.timestamp}&mac=${rowData.mac_address.mac};eq&aggregated=false`
  window.open(url, '_blank');
}

onMounted(async () => {

  await learning_status();

})

const csrf = props.crsf;

/* Function to delete device */
const delete_row = async function () {
  const row = row_to_delete.value;

  const url = NtopUtils.buildURL(delete_url, {
    device: row.mac_address.mac,
  })

  rest_params.device = {
    mac: row.mac_address.mac
  };
  await ntopng_utility.http_post_request(url, rest_params);
  refresh();

}

const delete_all_confirm = async function() {
  modal_delete_all.value.show();
}

const edit_all_devices_confirm = async function() {
  modal_edit_device.value.show();
}

/* Function to delete all devices */
const delete_all = async function () {
  const url = NtopUtils.buildURL(delete_url, {
    device: 'all',
  })

  await ntopng_utility.http_post_request(url, rest_params);
  refresh();

};

const learning_status = async function() {
    
  const rsp = await ntopng_utility.http_request(learning_status_url);
  if(rsp.learning_done) {
    is_learning_status.value = false;
  } else {
    is_learning_status.value = true;
  }
}

const refresh = async function() {
  await learning_status();
  table_device_exclusions.value.refresh_table();
}

function add_device() {
  modal_add_device.value.show();
}

const add_device_rest = async function (set_params_in_url) {
  let params = set_params_in_url;
  params.mac_list = params.mac_list.replace(/(?:\t| )/g,'')
  params.mac_list = params.mac_list.replace(/(?:\r\n|\r|\n)/g, ',');

  const url = NtopUtils.buildURL(add_url, {
    ...params
  })

  await ntopng_utility.http_post_request(url, rest_params);
  refresh();
          
};

const edit_row = async function(params) {
  let row = row_to_edit.value;
  if(row != null)
    params.mac_alias = params.mac_alias.replace(/(?:\t| )/g,'');   
  if(row != null)
    params.mac = row.mac_address.mac;
  

  const url = NtopUtils.buildURL(edit_url, {
    ...params
  })

  await ntopng_utility.http_post_request(url, rest_params);

  refresh();
};


function columns_sorting(col, r0, r1) {
  if (col != null) {
    let r0_col = r0[col.data.data_field];
    let r1_col = r1[col.data.data_field];
    if(col.id == "last_ip") {
      if (r0_col != '') {
        r0_col = take_ip(r0_col);
        r0_col = NtopUtils.convertIPAddress(r0_col);
      } 
      if (r1_col != '') {
        r1_col = take_ip(r1_col);
        r1_col = NtopUtils.convertIPAddress(r1_col);
      }
      if (col.sort == 1) {
        return r0_col.localeCompare(r1_col);
      }
      return r1_col.localeCompare(r0_col);
    } else if(col.id == "manufacturer" ) {
      if (r0_col === undefined) r0_col = '';
      if (r1_col === undefined) r1_col = '';
      if (col.sort == 1) {
        return r0_col.localeCompare(r1_col);
      }
      return r1_col.localeCompare(r0_col);
    } else if(col.id == "mac_address") {
      r0_col = r0_col.mac;
      r1_col = r1_col.mac;
      if (col.sort == 1) {
        return r0_col.localeCompare(r1_col);
      }
      return r1_col.localeCompare(r0_col);
    }else if(col.id == "first_seen") {
      r0_col = r0["first_seen"]["timestamp"] == 0 ? '' : r0["first_seen"]["data"];
      r1_col = r1["first_seen"]["timestamp"] == 0 ? '' : r1["first_seen"]["data"];
      if (col.sort == 1) {
        return r0_col.localeCompare(r1_col);
      }
      return r1_col.localeCompare(r0_col);
    } else if(col.id == "last_seen") {
      r0_col = r0["last_seen"]["timestamp"] == 0 ? '' : r0["last_seen"]["data"];
      r1_col = r1["last_seen"]["timestamp"] == 0 ? '' : r1["last_seen"]["data"];
      if (col.sort == 1) {
        return r0_col.localeCompare(r1_col);
      }
      return r1_col.localeCompare(r0_col);
    } else if (col.id == "status") {
      if (col.sort == 1) {
        return r0_col.localeCompare(r1_col);
      }
      return r1_col.localeCompare(r0_col);
    } else if (col.id == "trigger_alert") {
      r0_col = format_bool(r0_col);
      r1_col = format_bool(r1_col);

      if (col.sort == 1) {
        return r0_col.localeCompare(r1_col);
      }
      return r1_col.localeCompare(r0_col);
    }
  }
  
}

function take_ip(r_col) {
  const ip = r_col.split('host=')[1].split("\'")[0];
  return ip;
}

function format_bool(r_col) {
  if (r_col) {
    return 'true';
  }

  if (!r_col) {
    return 'false';
  }

  if (r_col == 'true') {
    return r_col;
  }

  if (r_col == 'false') {
    return r_col;
  }
}

const map_table_def_columns = async (columns) => {
    
  let map_columns = {
    "mac_address": (data, row) => {
      let label = data.mac;
      let alias = data.alias;

      if ((data.symbolic_mac) && (data.symbolic_mac != label))
        label = data.symbolic_mac;

      if ((alias != null) && (alias != label))
        label = `${label} (${alias})`;

      if (data.url != null)
        label = `<a href='${data.url}' title='${data.mac}'>${label}</a>`;

      return label;
    },
    "first_seen": (first_seen, row) => {
      if (first_seen.timestamp == 0) {
        return '';
      } else {
        return first_seen.data;
      }
    }, 
    "last_seen": (last_seen, row) => {
      if (last_seen.timestamp == 0) {
        return '';
      } else {
        return last_seen.data;
      }
    },
    "status": (status, row) => {
      //<span class="badge bg-success" title="${label}">${label}</span>
      //<span class="badge bg-danger" title="${label}">${label}</span>
      const label = _i18n(status);
      if (status == "allowed") {
        return `<span class="badge bg-success" title="${label}">${label}</span>`
      } else {
        return `<span class="badge bg-danger" title="${label}">${label}</span>`
      }

    },
    "trigger_alert": (trigger_alert, row) => {
      let is_enabled = false;
      if (trigger_alert == "false") 
        is_enabled = false;
      else
        is_enabled = trigger_alert;
      return is_enabled ? `<i class="fas fa-check text-success"></i>` : `<i class="fas fa-times text-danger"></i>`;
    }
  }
  columns.forEach((c) => {
    c.render_func = map_columns[c.data_field];

    /*if (c.id == "actions") {
            
      c.button_def_array.forEach((b) => {
          
        b.f_map_class = (current_class, row) => { 
          current_class = current_class.filter((class_item) => class_item != "link-disabled");
          if((row.is_ok_last_scan == 4 || row.is_ok_last_scan == null || row.num_open_ports < 1) && visible_dict[b.id]) {
            current_class.push("link-disabled"); 
          }
          return current_class;
        }
      });
    }*/
  });
    // console.log(columns);
  return columns;
};

const get_extra_params_obj = () => {
    /*let params = get_url_params(active_page, per_page, columns_wrap, map_search, first_get_rows);
    set_params_in_url(params);*/
    let params = get_url_params();
    return params;
};

function get_url_params() {
    let actual_params = {
        ifid: ntopng_url_manager.get_url_entry("ifid") || 1,
    };    

    return actual_params;
}

const map_config = (config) => {
    return config;
};

/*export default {
    components: {	  
        'page-navbar': PageNavbar,	      
        'datatable': Datatable,
        'modal-delete-confirm': ModalDeleteConfirm,
        'modal-add-device-exclusion': ModalAddDeviceExclusion,
        'modal-edit-device-exclusion': ModalEditDeviceExclusion,
    },
    props: {
	page_csrf: String,
	is_clickhouse_enabled: Boolean,
    },
    
    created() {
	start_datatable(this);
    },
    mounted() {
      const mac = ntopng_url_manager.get_url_entry("mac");
      if(mac) {
        const table = this.get_active_table();
        table.search_value(mac)
      }
      this.learning_status();
      $("#btn-delete-all-devices").click(() => this.show_delete_all_dialog());
      $("#btn-edit-all-devices-status").click(() => this.show_edit_all_dialog());

    },    
    data() {
	return {
	    i18n: (t) => i18n(t),
	    config_devices: null,
            navbar_context: {
		main_title: {
      label: i18n("edit_check.device_exclusion_list"),
      icon: "fas fa-bell-slash",
    },
		base_url: "#",
		// help_link: "https://www.ntop.org/guides/ntopng/web_gui/checks.html",
		items_table: [
		    { active: true, label: i18n('devices'), id: "devices" },
		],
            },
	    
            title_delete: '',
            body_delete: '',
            title_delete_all: i18n('edit_check.delete_all_device_exclusions'),
            body_delete_all: i18n('edit_check.delete_all_device_exclusions_message'),
            title_add: i18n('edit_check.add_device_exclusion'),
            body_add: i18n('edit_check.add_device_exclusion_message'),
            footer_add: i18n('edit_check.add_device_exclusion_notes'),
            list_notes_add: i18n('edit_check.add_device_exclusion_list_notes'),
            title_edit: i18n('edit_check.edit_device_exclusion'),
            title_edit_all: i18n('edit_check.edit_all_devices_status'),
            learning_message: i18n('edit_check.learning'),
            row_to_delete: null,
            row_to_edit: null,
        };
    },
    methods: {
        add_device: async function(params) {
          params.mac_list = params.mac_list.replace(/(?:\t| )/g,'')
          params.mac_list = params.mac_list.replace(/(?:\r\n|\r|\n)/g, ',');
          params.csrf = this.$props.page_csrf;
          let url = `${http_prefix}/lua/pro/rest/v2/add/device/exclusion.lua`;
          try {
            let headers = {
              'Content-Type': 'application/json'
            };
            await ntopng_utility.http_request(url, { method: 'post', headers, body: JSON.stringify(params) });
            this.reload_table();
          } catch(err) {
            console.error(err);
          }
        },
        delete_all: async function() {
          let url = `${http_prefix}/lua/pro/rest/v2/delete/device/exclusion.lua`;
          let params = {
            device: 'all',
            csrf: this.$props.page_csrf,
          };
          try {
            let headers = {
              'Content-Type': 'application/json'
            };
            await ntopng_utility.http_request(url, { method: 'post', headers, body: JSON.stringify(params) });
            this.reload_table();
          } catch(err) {
            console.error(err);
          }      
        },
        delete_row: async function() {      
          let row = this.row_to_delete;
          let params = { device: row.mac_address, csrf: this.$props.page_csrf };
          let url = `${http_prefix}/lua/pro/rest/v2/delete/device/exclusion.lua`;
          try {
            let headers = {
              'Content-Type': 'application/json'
            };
            await ntopng_utility.http_request(url, { method: 'post', headers, body: JSON.stringify(params) });
            setTimeout(() => this.reload_table(), 300);
          } catch(err) {
            console.error(err);
          }
        },
        edit_row: async function(params) {    
          let row = this.row_to_edit;
          if(row != null)
            params.mac_alias = params.mac_alias.replace(/(?:\t| )/g,'')   
          params.csrf = this.$props.page_csrf
          if(row != null)
            params.mac = row.mac_address.mac
          let url = `${http_prefix}/lua/pro/rest/v2/edit/device/exclusion.lua`;
          try {
            let headers = {
              'Content-Type': 'application/json'
            };
            await ntopng_utility.http_request(url, { method: 'post', headers, body: JSON.stringify(params) });
            setTimeout(() => this.reload_table(), 300);
          } catch(err) {
            console.error(err);
          }
        },
        learning_status: async function() {
          let url = `${http_prefix}/lua/pro/rest/v2/get/device/learning_status.lua`;
          try {
            let headers = {
              'Content-Type': 'application/json'
            };
            const rsp = await ntopng_utility.http_request(url, { method: 'get', headers });
            if(rsp.learning_done) {
              $(`#devices-learning-status`).attr('hidden', 'hidden')
            } else {
              $(`#devices-learning-status`).removeAttr('hidden')  
            }
          } catch(err) {
            console.error(err);
          }      
        },
        reload_table: function() {
          let table = this.get_active_table();
          table.reload();
          this.learning_status();
        },
        get_active_table: function() {
          return this.$refs[`table_devices_exclusion`];
        },
        show_add_device_dialog: function() {
          this.$refs["modal_add_device"].show();
        },
        show_edit_device_dialog: function(row) {
          this.row_to_edit = row
          this.$refs["modal_edit_device"].show(row);
        },
        show_edit_all_dialog: function() {
          this.$refs["modal_edit_device"].show();
        },
        show_delete_all_dialog: function() {
          this.$refs["modal_delete_all"].show();
        },
        show_delete_dialog: function(title, body, row) {
          this.row_to_delete = row;
          this.title_delete = title;
          this.body_delete = body;
          this.$refs["modal_delete_confirm"].show();
        }
      },
    }  

function start_datatable(DatatableVue) {
  const datatableButton = [];

  datatableButton.push({
    text: '<i class="fas fa-plus"></i>',
    className: 'btn-link',
    action: function (e, dt, node, config) {
      DatatableVue.show_add_device_dialog();
    }
  });

  datatableButton.push({
    text: '<i class="fas fa-sync"></i>',
    className: 'btn-link',
    action: function (e, dt, node, config) {
      DatatableVue.reload_table();
    }
  });

  let defaultDatatableConfig = {
    table_buttons: datatableButton,
    columns_config: [],
    data_url: `${http_prefix}/lua/pro/rest/v2/get/device/exclusion.lua`,
    enable_search: true,
  };

    let configDevices = ntopng_utility.clone(defaultDatatableConfig);
    configDevices.table_buttons = defaultDatatableConfig.table_buttons;
    configDevices.data_url = `${configDevices.data_url}`;
    configDevices.columns_config = [
    {
      columnName: i18n('edit_check.device'),
      sortable: true,
      searchable: true,
      visible: true,
      data: 'mac_address',
      createdCell: DataTableRenders.applyCellStyle,
      responsivePriority: 1,
      render: function (data, _, rowData) {
        let label = data.mac;
        let alias = data.alias;

        if ((data.symbolic_mac) && (data.symbolic_mac != label))
          label = data.symbolic_mac;

        if ((alias != null) && (alias != label))
          label = `${label} (${alias})`;

        if (data.url != null)
          label = `<a href='${data.url}' title='${data.mac}'>${label}</a>`;

        return label
      },
      responsivePriority: 1,
    }, {
      columnName: i18n('ip_address'),
      data: 'last_ip',
      className: 'text-nowrap',
      sortable: false,
      searchable: true,
      responsivePriority: 1,
    }, {
      columnName: i18n('mac_stats.manufacturer'),
      data: 'manufacturer',
      className: 'text-nowrap',
      sortable: true,
      searchable: true,
      responsivePriority: 1,
    }, {
      columnName: i18n('first_seen'),
      data: 'first_seen',
      type: 'time',
      sortable: true,
      searchable: true,
      className: 'text-nowrap text-center',
      responsivePriority: 1,
      render: function (rowData, type, script) {
        if (rowData.timestamp == 0) {
          return ''
        } else {
          return rowData.data
        }
      }
    }, {
      columnName: i18n('last_seen'),
      data: 'last_seen',
      type: 'time',
      sortable: true,
      searchable: true,
      className: 'text-nowrap text-center',
      responsivePriority: 1,
      render: function (rowData, type, script) {
        if (rowData.timestamp == 0) {
          return ''
        } else {
          return rowData.data
        }
      }
    }, {
      columnName: i18n('edit_check.device_status'),
      data: 'status',
      type: 'status',
      sortable: true,
      searchable: true,
      className: 'text-nowrap text-center',
      responsivePriority: 1,
      render: function (rowData, type, script) {
        return i18n(rowData)
      }
    }, {
      columnName: i18n('edit_check.trigger_alert'),
      data: 'trigger_alert',
      type: 'boolean',
      sortable: true,
      searchable: true,
      className: 'text-nowrap text-center',
      responsivePriority: 1,
      render: function (rowData, type, script) {
        return rowData ? `<i class="fas fa-check text-success"></i>` : `<i class="fas fa-times text-danger"></i>`
      }
    }, {
      targets: -1,
      columnName: i18n("action"),
      data: null,
      name: 'actions',
      className: 'text-center text-nowrap',
      sortable: false,
      responsivePriority: 1,
      render: function (rowData, type, script) {
        let delete_handler = {
          handlerId: "delete_device",
          onClick: () => {
            let body = `${i18n('edit_check.delete_device_exclusion')} ${rowData.mac_address_label}`;
            DatatableVue.show_delete_dialog(i18n('edit_check.device_exclusion'), body, rowData);
          },
        };
        let edit_handler = {
          handlerId: "edit_device",
          onClick: () => {
            DatatableVue.show_edit_device_dialog(rowData);
          },
        };
        let jump_to_historical_flow = {
          onClick: () => {
            const url = `${http_prefix}/lua/pro/db_search.lua?epoch_begin=${rowData.first_seen.timestamp}&epoch_end=${rowData.last_seen.timestamp}&mac=${rowData.mac_address.mac};eq`
            window.open(url, '_blank');
          },
        };

        return DataTableUtils.createActionButtons([
          { class: `pointer`, handler: jump_to_historical_flow, icon: 'fa-stream', title: i18n('db_explorer.historical_data'), hidden: !isClickhouseEnabled },
          { class: `pointer`, handler: edit_handler, icon: 'fa-edit', title: i18n('edit') },
          { class: `pointer`, handler: delete_handler, icon: 'fa-trash', title: i18n('delete') },
        ]);
      },
    }
  ];
  DatatableVue.config_devices = configDevices;
}*/


</script>
