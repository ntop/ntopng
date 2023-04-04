<!--
  (C) 2013-22 - ntop.org
-->

<template>    
  <div class="overlay justify-content-center align-items-center position-absolute h-100 w-100">
    <div class="text-center">
      <div class="spinner-border text-primary mt-5" role="status">
        <span class="sr-only position-absolute">Loading...</span>
      </div>
    </div>
  </div>

  <div v-show="!hidden" ref="update_message" class="alert alert-info">{{ message }}</div>

  <ModalAddApplication ref="modal_add_application"
    :category_list="category_list"
    :page_csrf="page_csrf"
    :ifid="ifid"
    @add="_add">
  </ModalAddApplication>
  <ModalDeleteApplication ref="modal_delete_application"
    @remove="_remove">
  </ModalDeleteApplication>

  <Datatable ref="applications_table"
    :table_buttons="config_applications_table.table_buttons"
    :columns_config="config_applications_table.columns_config"
    :data_url="config_applications_table.data_url"
    :enable_search="config_applications_table.enable_search"
    :table_config="config_applications_table.table_config">
  </Datatable>
</template>
  
<script setup>
import { ref, onUnmounted, onBeforeMount, onMounted } from "vue";
import { default as Datatable } from "./datatable.vue";
import { default as ModalAddApplication } from "./modal-add-application.vue";
import { default as ModalDeleteApplication } from "./modal-delete-application.vue";

const applications_table = ref(null);
const modal_delete_application = ref(null);
const modal_add_application = ref(null);
const config_applications_table = ref({});
const category_list = ref([]);
const update_message = ref(null);
const hidden = ref(true);
let message = ''

const category_list_url = `${http_prefix}/lua/rest/v2/get/l7/category/consts.lua`
const add_application_url = `${http_prefix}/lua/rest/v2/edit/application/application.lua`
const delete_application_url = `${http_prefix}/lua/rest/v2/delete/application/application.lua`

const _i18n = (t) => i18n(t);
const props = defineProps({
  page_csrf: String,
  ifid: String,
  has_protos_file: Boolean,
})

const _remove = async (params) => {  
  const url_params = {
    csrf: props.page_csrf,
    ifid: props.ifid
  }

  const url = NtopUtils.buildURL(delete_application_url, {
    ...url_params,
    ...params
  })

  await $.get(url, function(rsp, status){
    show_message(i18n('custom_categories.succesfully_removed'));
  });
}

const open_delete_modal = (row) => {
  modal_delete_application.value.show(row);
}

const _add = async (params) => {
  const is_edit_page = params.is_edit_page;
  params.is_edit_page = null;

  const url_params = {
    csrf: props.page_csrf,
    ifid: props.ifid
  }

  const url = NtopUtils.buildURL(add_application_url, {
    ...url_params,
    ...params
  })
  
  await $.get(url, function(rsp, status){
    if(status == 'success') {
      if(is_edit_page)
        show_message(i18n('custom_categories.succesfully_edited'));
      else
        show_message(i18n('custom_categories.succesfully_added'));
    }
  });
}

const open_add_modal = (row) => {
  modal_add_application.value.show(row);
}

const show_message = (_message) => {
  message = _message;
  hidden.value = false;
  setTimeout(() => {
    hidden.value = true;
    reload_table();
  }, 4000);
}

const destroy = () => {
  applications_table.value.destroy_table();
}

const reload_table = () => {
  applications_table.value.reload();
}

const load_categories = async () => {
  await $.get(category_list_url, function(rsp, status){
    category_list.value = rsp.rsp;
  });
  modal_add_application.value.loadCategoryList(category_list.value);
}
    
onBeforeMount(async () => {
  start_datatable();
});

onMounted(async () => {
  await load_categories();
})

onUnmounted(async () => {
  destroy()
});


const add_action_column = function (rowData) {
  let edit_handler = {
    handlerId: "edit_rule",
    onClick: () => {
      open_add_modal(rowData);
    },
  }

  const actions = [
    { class: `btn-secondary`, handler: edit_handler, icon: 'fa-edit', title: i18n('edit'), class: "pointer" },
  ]

  if(rowData.is_custom) {
    let delete_handler = {
      handlerId: "delete_rule",
      onClick: () => {
        open_delete_modal(rowData);
      },
    }
  
    actions.push(    
      { class: `btn-secondary`, handler: delete_handler, icon: 'fa-trash', title: i18n('delete'), class: "pointer" },
    )
  }
  return DataTableUtils.createActionButtons(actions);
}

function start_datatable() {
  const datatableButton = [];

  if(props.has_protos_file) {
    datatableButton.push({
      text: '<i class="fas fa-plus"></i>',
      className: 'btn-link',
      action: function () {
        open_add_modal();
      }
    });
  }

  datatableButton.push({
    text: '<i class="fas fa-sync"></i>',
    className: 'btn-link',
    action: function () {
      reload_table();
    }
  });
    
  let defaultDatatableConfig = {
    table_buttons: datatableButton,
    data_url: NtopUtils.buildURL(`${http_prefix}/lua/rest/v2/get/ntopng/applications.lua`, { ifid: props.ifid }),
    enable_search: true,
    table_config: { 
      serverSide: false, 
      order: [[ 0 /* application column */, 'asc' ]],
    }
  };
  
  /* Applications table configuration */  

  let columns = [
    { columnName: i18n("application"), name: 'application', data: 'application', className: 'text-nowrap', responsivePriority: 1 },
    { columnName: i18n("category"), name: 'category', data: 'category', className: 'text-nowrap', responsivePriority: 1, render: function (data, type, rowData) { return data } },
    { columnName: i18n("custom_categories.custom_hosts"), name: 'custom_rules', data: 'custom_rules', className: 'text-nowrap', responsivePriority: 2 },
    { visible: false, name: 'application_hosts', data: 'application_hosts' },
    { visible: false, name: 'application_id', data: 'application_id' },
    { visible: false, name: 'category_id', data: 'category_id' },
    { columnName: _i18n("actions"), width: '5%', name: 'actions', className: 'text-center', orderable: false, responsivePriority: 0, render: function (_, type, rowData) { return add_action_column(rowData) } }
  ];

  let trafficConfig = ntopng_utility.clone(defaultDatatableConfig);
  trafficConfig.columns_config = columns;
  config_applications_table.value = trafficConfig;
}
</script>






