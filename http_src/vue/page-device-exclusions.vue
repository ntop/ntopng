<template>
<div id="navbar">
<page-navbar
	id="page_navbar"
	:main_icon="navbar_context.main_icon"
	:main_title="navbar_context.main_title"
	:base_url="navbar_context.base_url"
	:help_link="navbar_context.help_link"
	:items_table="navbar_context.items_table"
	@click_item="click_item">
</page-navbar>
</div>

<div class="row">
  <div class="col-md-12 col-lg-12">
    <div class="alert alert-danger d-none" id='alert-row-buttons' role="alert">
    </div>
    <div class="card">
      <div class="card-body">
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
            @add="add_device">
          </modal-add-device-exclusion>
          <modal-edit-device-exclusion ref="modal_edit_device"
            :title="title_edit"
            @edit="edit_row">
          </modal-edit-device-exclusion>
            
          <datatable ref="table_devices_exclusion"
            :table_buttons="config_devices.table_buttons"
            :columns_config="config_devices.columns_config"
            :data_url="config_devices.data_url"
            :enable_search="config_devices.enable_search">
          </datatable>
        </div>
      </div>
      <div class="card-footer">
        <button type="button" id='btn-delete-all-devices' class="btn btn-danger">
          <i class='fas fa-trash'></i> {{ i18n("edit_check.delete_all_device_exclusions") }}
        </button>
      </div>
    </div>
  </div>
</div>
</template>

<script>
import { default as PageNavbar } from "./page-navbar.vue";
import { default as Datatable } from "./datatable.vue";
import { default as ModalDeleteConfirm } from "./modal-delete-confirm.vue";
import { default as ModalAddDeviceExclusion } from "./modal-add-device-exclusion.vue";
import { default as ModalEditDeviceExclusion } from "./modal-edit-device-exclusion.vue";

export default {
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
    /**
     * First method called when the component is created.
     */
    created() {
	start_datatable(this);
    },
    mounted() {
        $("#btn-delete-all-devices").click(() => this.show_delete_all_dialog());
    },    
    data() {
	return {
	    i18n: (t) => i18n(t),
	    config_devices: null,
            navbar_context: {
		main_icon: "fas fa-bell-slash",
		main_title: i18n("edit_check.device_exclusion_list"),
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
          params.mac_alias = params.mac_alias.replace(/(?:\t| )/g,'')   
          params.csrf = this.$props.page_csrf
          params.mac = row.mac_address
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
        reload_table: function() {
          let table = this.get_active_table();
          table.reload();
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

    /* Manage the buttons close to the search box */
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
        sortable: false,
        searchable: false,
        visible: false,
        data: 'mac_address',
        type: 'mac-address',
        responsivePriority: 1,
      }, {
        columnName: i18n('edit_check.excluded_device'),
        data: 'mac_address_label',
        type: 'mac-address',
        className: 'text-nowrap',
        sortable: true,
        searchable: true,
        createdCell: DataTableRenders.applyCellStyle,
        responsivePriority: 1,
        render: function(rowData, type, script) {
          let label = rowData.label
          if(rowData.label !== rowData.mac)
            label = label + ' [' + rowData.mac + ']'

          if(rowData.url)
            label = `<a href='${rowData.url}' title='${rowData.mac}'>${label}</a>`

          return label
        }
      }, {
        columnName: i18n('first_seen'),
        data: 'first_seen',
        type: 'time',
        sortable: true,
        searchable: true,
        className: 'text-nowrap text-center',
        responsivePriority: 1,
        render: function(rowData, type, script) {
          return rowData.data
        }
      }, {
        columnName: i18n('last_seen'),
        data: 'last_seen',
        type: 'time',
        sortable: true,
        searchable: true,
        className: 'text-nowrap text-center',
        responsivePriority: 1,
        render: function(rowData, type, script) {
          return rowData.data
        }
      }, {
        columnName: i18n('edit_check.device_status'),
        data: 'status',
        type: 'status',
        sortable: true,
        searchable: true,
        className: 'text-nowrap text-center',
        responsivePriority: 1,
        render: function(rowData, type, script) {
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
        render: function(rowData, type, script) {
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
              let body = `${i18n('edit_check.delete_device_exclusion')} ${rowData.mac_address_label.label}`;
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
              const url = `${http_prefix}/lua/pro/db_search.lua?epoch_begin=${rowData.first_seen.timestamp}&epoch_end=${rowData.last_seen.timestamp}&mac=${rowData.mac_address};eq`
              window.open(url, '_blank');
            },
          };
          
          return DataTableUtils.createActionButtons([
            { class: `pointer`, handler: jump_to_historical_flow, icon: 'fa-stream', title: i18n('db_explorer.historical_data'), hidden: !isClickhouseEnabled },
            { class: `btn-secondary`, handler: edit_handler, icon: 'fa-edit', title: i18n('edit'), class: "pointer" },
            { class: `btn-danger`, handler: delete_handler, icon: 'fa-trash', title: i18n('delete'), class: "pointer" },
          ]);
        },
      }
    ];
    DatatableVue.config_devices = configDevices;
}

</script>
