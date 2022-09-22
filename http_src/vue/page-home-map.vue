{#
  (C) 2022 - ntop.org
  This template is used by the `SSH host details` page inside the `Hosts`.    
#}

<template>

<page-navbar
  id="page_navbar"
  :main_title="navbar_context.main_title"
  :secondary_title_list="navbar_context.secondary_title_list"
  :help_link="navbar_context.help_link"
  :items_table="navbar_context.items_table"
  @click_item="click_item">
</page-navbar>

<page-service-map v-if="active_tab == 'service_map' && page == 'graph'" ref="service_map_graph"
  :page_csrf="page_csrf"
  :url_params="url_params"
  :ifid="ifid"
  :is_admin="is_admin"
  :map_id="map_id"
  :all_filter_list="service_map_filter_list">
</page-service-map>

<page-service-table v-if="active_tab == 'service_map' && page == 'table'" ref="service_map_table"
  :page_csrf="page_csrf"
  :url_params="url_params"
  :view="updated_view"
  :table_filters="service_table_filter_list"
  :is_admin="is_admin"
  :service_acceptance="service_acceptance">
</page-service-table>

<page-periodicity-map v-if="active_tab == 'periodicity_map' && page == 'graph'" ref="periodicity_map_graph"
  :page_csrf="page_csrf"
  :url_params="url_params"
  :ifid="ifid"
  :is_admin="is_admin"
  :map_id="map_id"
  :all_filter_list="periodicity_map_filter_list">
</page-periodicity-map>

<page-periodicity-table v-if="active_tab == 'periodicity_map' && page == 'table'" ref="periodicity_map_table"
  :page_csrf="page_csrf"
  :url_params="url_params"
  :view="updated_view"
  :table_filters="periodicity_table_filter_list"
  :is_admin="is_admin">
</page-periodicity-table>

<template v-if="asset_map_filter_list && asset_table_filter_list">
  <page-asset-map v-if="active_tab == 'asset_map' && page == 'graph'" ref="asset_map_graph"
    :page_csrf="page_csrf"
    :url_params="url_params"
    :ifid="ifid"
    :is_admin="is_admin"
    :map_id="map_id"
    :all_filter_list="asset_map_filter_list">
  </page-asset-map>

  <page-asset-table v-if="active_tab == 'asset_map' && page == 'table'" ref="asset_map_table"
    :page_csrf="page_csrf"
    :url_params="url_params"
    :view="updated_view"
    :table_filters="asset_table_filter_list">
  </page-asset-table>
</template>

</template>

<script>
  import { default as PagePeriodicityTable } from "./page-periodicity-table.vue";
  import { default as PagePeriodicityMap } from "./page-periodicity-map.vue";
  import { default as PageAssetTable } from "./page-asset-table.vue";
  import { default as PageAssetMap } from "./page-asset-map.vue";
  import { default as PageServiceTable } from "./page-service-table.vue";
  import { default as PageServiceMap } from "./page-service-map.vue";
  import { default as PageNavbar } from "./page-navbar.vue";
import { ntopng_url_manager } from '../services/context/ntopng_globals_services';
  const change_map_event = "change_map_event";

  export default {
    components: {	  
      'page-periodicity-map': PagePeriodicityMap,
      'page-periodicity-table': PagePeriodicityTable,
      'page-asset-map': PageAssetMap,
      'page-asset-table': PageAssetTable,
      'page-service-map': PageServiceMap,
      'page-service-table': PageServiceTable,
      'page-navbar': PageNavbar,
    },
    props: {
      page_csrf: String,
      base_url_params: Object,
      ifid: Number,
      is_admin: Boolean,
      map_id: String,
      view: String,
      navbar_info: Object,
      service_acceptance: Array,
      service_map_filter_list: Object,
      service_table_filter_list: Array,
      periodicity_map_filter_list: Object,
      periodicity_table_filter_list: Array,
      asset_map_filter_list: Object,
      asset_table_filter_list: Array,
    },
    /**
     * First method called when the component is created.
     */
    created() {
      this.url_params = this.$props.base_url_params
      this.active_tab = this.$props.map_id
      this.page = this.url_params.page
      this.updated_view = this.$props.view

      if(asset_map_filter_list && asset_table_filter_list) {
        this.navbar_context.items_table.push({ active: false, label: i18n('asset_map'), id: "asset_map", page: "graph" })
        this.navbar_context.items_table.push({ active: false, label: i18n('asset_table'), id: "asset_map", page: "table" })
      }

      this.navbar_context.items_table.forEach((i) => {
        (i.id == this.active_tab && i.page == this.page) ? i.active = true : i.active = false
      });
    },
    mounted() {
      
      const format_navbar = this.format_navbar_title;
      format_navbar(this.$props.navbar_info);

      ntopng_events_manager.on_custom_event("page_navbar", ntopng_custom_events.CHANGE_PAGE_TITLE, (node) => {
        format_navbar({ selected_iface: this.$props.navbar_info.selected_iface, selected_host: node });
      });

      ntopng_events_manager.on_custom_event("change_service_table_tab", change_map_event, (tab) => {
        ntopng_url_manager.set_key_to_url('map', tab.id);
        ntopng_url_manager.set_key_to_url('page', tab.page);
        if(tab.page == 'table')
          this.destroy()
        
        this.active_tab = tab.id
        this.page = tab.page
        this.url_params.map = tab.id
        this.url_params.page = tab.page
        this.updated_view = ntopng_url_manager.get_url_entry('view')
        format_navbar(this.$props.navbar_info)
     });
    },    
    data() {
      return {
        i18n: (t) => i18n(t),
        active_tab: null,
        page: null,
        url_params: {},
        updated_view: null,
        navbar_context: {
          main_title: {
            label: ' ' + i18n("maps"),
            icon: "fas fa-map",
          },
          secondary_title_list: [],
          items_table: [
            { active: true, label: i18n('service_map'), id: "service_map", page: "graph" },
            { active: false, label: i18n('service_table'), id: "service_map", page: "table" },
            { active: false, label: i18n('periodicity_map'), id: "periodicity_map", page: "graph" },
            { active: false, label: i18n('periodicity_table'), id: "periodicity_map", page: "table" },
          ],
        },
      };
    },
    methods: { 
      destroy: function() {
        let current_tab = this.get_active_tab();
        current_tab.destroy()
      },
      format_navbar_title: function(data) {
        this.navbar_context.secondary_title_list = [
          { label: data.selected_iface.label, title: NtopUtils.shortenLabel(`${data.selected_iface.label}`, 16) }
        ]

        if(data.selected_host && data.selected_host.id != '') {
          this.navbar_context.secondary_title_list[0]['href'] = `${http_prefix}/lua/pro/enterprise/network_maps.lua?map=${this.active_tab}&page=${this.page}&ifid=${this.$props.ifid}`
          this.navbar_context.secondary_title_list.push({
            label: NtopUtils.shortenLabel(`${data.selected_host.label}`, 16, '.'),
            title: `${data.selected_host.label}`,
            href: data.selected_host.is_active ? `${http_prefix}/lua/host_details.lua?host=${data.selected_host.id}` : null,
            target_blank: "true",
          })
        }  
      },
      get_active_tab: function() {
        return this.$refs[this.active_tab + "_" + this.page];
      },
      /* Method used to switch active table tab */
      click_item: function(item) {
        this.navbar_context.items_table.forEach((i) => i.active = false);
        item.active = true;
        ntopng_events_manager.emit_custom_event(change_map_event, item);
      },
    },
  }  
</script>






