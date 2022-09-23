{#
  (C) 2022 - ntop.org
  This template is used by the `Asset Map` page inside the `Hosts` menu.    
#}

<template>
<div class="row">
  <div class="col-md-12 col-lg-12">
    <div class="card card-shadow">
      <div class="overlay justify-content-center align-items-center position-absolute h-100 w-100">
        <div class="text-center">
          <div class="spinner-border text-primary mt-5" role="status">
            <span class="sr-only position-absolute">Loading...</span>
          </div>
        </div>
      </div>
      <div class="card-body">
      	<div id="table_asset">
          <div class="d-flex align-items-center justify-content-end mb-2">
            <button id="max-entries-reached" type="button" class="btn btn-link" :title=max_entry_title disabled hidden>
              <i class="text-danger fa-solid fa-triangle-exclamation"></i>
            </button>
            <div class="d-flex ms-auto">
              <div class="m-1" v-for="(_, index) in filter_list">
                <select-search
                  v-model:selected_option="active_filter_list[index]"
                  :options="filter_list[index]"
                  @select_option="click_item">
                </select-search>
              </div>
            </div>
            <button type="button" id="reload-graph" class="btn btn-link btn-reload-graph">
              <i class='fas fa-sync'></i>
            </button>
            <button type="button" id='autolayout' class='btn btn-link btn-stabilize'>
              <i class="fas fa-magic"></i>
            </button>
          </div>

          <modal-delete-confirm ref="modal_delete_all"
            :title="title_delete"
            :body="body_delete"
            @delete="delete_all">
          </modal-delete-confirm>

          <modal-autolayout-confirm ref="modal_autolayout"
            :title="title_autolayout"
            :body="body_autolayout"
            @autolayout="reload_map">
          </modal-autolayout-confirm>

          <network-map ref="asset_map"
            :empty_message="no_services_message"
            :event_listeners="event_listeners"
            :page_csrf="page_csrf"
            :url="get_url"
            :url_params="url_params"
            :map_id="map_id">
          </network-map>
        </div>
      </div>
      <div class="card-footer">
        <button type="button" id='btn-delete-all' class="btn btn-danger me-1"><i class='fas fa-trash'></i> {{ i18n("map_page.delete_services") }}</button>
        <a v-bind:href="download_url" class="btn btn-primary" role="button" aria-disabled="true"  download="asset_map.json" target="_blank"><i class="fas fa-download"></i></a>
      </div>
    </div>
  </div>
</div>
</template>

<script>
import { default as NetworkMap } from "./network-map.vue";
import { default as ModalDeleteConfirm } from "./modal-delete-confirm.vue";
import { default as ModalAutolayoutConfirm } from "./modal-autolayout-confirm.vue";
import { default as SelectSearch } from "./select-search.vue"
import { ntopng_events_manager, ntopng_url_manager } from '../services/context/ntopng_globals_services';
const change_filter_event = "change_filter_event";

export default {
  components: {	  
    'network-map': NetworkMap,
    'modal-delete-confirm': ModalDeleteConfirm,
    'modal-autolayout-confirm': ModalAutolayoutConfirm,
    'select-search': SelectSearch,
  },
  props: {
    page_csrf: String,
    ifid: Number,
    url_params: Object,
    map_id: String,
    is_admin: Boolean,
    all_filter_list: Object,
  },
  /**
   * First method called when the component is created.
   */
  created() {
    start_vis_network_map(this)
  },
  mounted() {
    const max_entries_reached = this.max_entry_reached
    const reload_map = this.reload_map
    if(this.$props.url_params.host && this.$props.url_params.host != '') {
      this.hide_dropdowns();
    }

    ntopng_events_manager.on_custom_event("page_service_map", ntopng_custom_events.CHANGE_PAGE_TITLE, (node) => {
      this.hide_dropdowns();
    });

    ntopng_events_manager.on_custom_event("change_filter_event", change_filter_event, (filter) => {
	    this.active_filter_list[filter.id] = filter;
      ntopng_url_manager.set_key_to_url(filter.filter_name, filter.key);
      this.url_params[filter.filter_name] = filter.key;
      this.update_and_reload_map();
    });

    ntopng_events_manager.on_custom_event(this.get_map(), ntopng_custom_events.VIS_DATA_LOADED, (filter) => {
      if(max_entries_reached()) {
        $(`#max-entries-reached`).removeAttr('hidden')
      } else {
        $(`#max-entries-reached`).attr('hidden', 'hidden')
      }
    });

    /* Remove invalid filters */
    let entries = ntopng_url_manager.get_url_entries();
    for(const [key, value] of entries) {
      this.url_params[key] = value;
    }

    this.update_and_reload_map()
    
    $(`#reload-graph`).click(function(e){
      reload_map();
    });
    
    NtopUtils.hideOverlays();

    $("#btn-delete-all").click(() => this.show_delete_all_dialog());
    $("#autolayout").click(() => this.show_autolayout_dialog());
  },    
  data() {
    return {
      i18n: (t) => i18n(t),
      container: null,
      update_view_state_id: null,
      get_url: null,
      download_url: null,
      filter_list: [],
      active_filter_list: [],
      event_listeners: {},
      title_delete: i18n('map_page.delete_services'),
      body_delete: i18n('map_page.delete_services_message'),
      title_autolayout: i18n('map_page.autolayout_services'),
      body_autolayout: i18n('map_page.autolayout_services_message'),
      no_services_message: i18n('map_page.no_services'),
      max_entry_title: i18n('max_entries_reached'),
    };
  },
  methods: { 
    destroy: function() {
      let map = this.get_map();
      map.destroy();
    },
    /* Method used to switch active table tab */
    click_item: function(filter) {
      ntopng_events_manager.emit_custom_event(change_filter_event, filter);
    },
    get_map: function() {
      return this.$refs[`asset_map`];
    },
    hide_dropdowns: function() {
      $(`#network_dropdown`).attr('hidden', 'hidden')
      $(`#vlan_id_dropdown`).attr('hidden', 'hidden')
    }, 
    max_entry_reached: function() {
      let map = this.get_map();
      return map.is_max_entry_reached();
    },
    reload_map: async function() {
      NtopUtils.showOverlays();
      let map = this.get_map();
      await map.reload();
      NtopUtils.hideOverlays();
    },
    update_and_reload_map: async function() {
      let map = this.get_map();
      NtopUtils.showOverlays();
      map.update_url_params(this.url_params)
      await map.reload();
      NtopUtils.hideOverlays();
    },
    autolayout: function() {
      let map = this.get_map();
      map.autolayout();
    },
    show_delete_all_dialog: function() {
      this.$refs["modal_delete_all"].show();
    },  
    show_autolayout_dialog: function() {
      this.$refs["modal_autolayout"].show();
    },  
    delete_all: async function() {
      let url = `${http_prefix}/lua/pro/enterprise/network_maps.lua`;
      let params = {
        ifid: this.url_params.ifid,
        action: 'reset',
        csrf: this.$props.page_csrf,
        map: this.url_params.map
      };
      try {
        let headers = {
          'Content-Type': 'application/json'
        };
        await ntopng_utility.http_request(url, { method: 'post', headers, body: JSON.stringify(params) });
      } finally {
        NtopUtils.showOverlays();
        this.reload_map();
        NtopUtils.hideOverlays();
      }      
    },
  },
}  

function start_vis_network_map(NetworkMapVue) {
  /* Format the filter list, to add the dropdowns */
  for (const filter_name in NetworkMapVue.$props.all_filter_list) {
    NetworkMapVue.filter_list.push(NetworkMapVue.$props.all_filter_list[filter_name]);
    const active_filter = ntopng_url_manager.get_url_entry(filter_name)
    /* Put the filter name into the filters */
    for(let [_, value] of Object.entries(NetworkMapVue.$props.all_filter_list[filter_name])) {
      value['filter_name'] = filter_name
      if(active_filter) {
        /* If there is a filter selected in the url push that as active */
        if(value.id == active_filter) 
          NetworkMapVue.active_filter_list.push(value);
      } else {
        /* push the default filter as active */
        if(value.currently_active == true) 
          NetworkMapVue.active_filter_list.push(value);
      }
    }
  }

  NetworkMapVue.get_url = `${http_prefix}/lua/pro/rest/v2/get/interface/map/data.lua`
  NetworkMapVue.download_url = NtopUtils.buildURL(NetworkMapVue.get_url, NetworkMapVue.$props.url_params)
  NetworkMapVue.event_listeners = {};
}
</script>






