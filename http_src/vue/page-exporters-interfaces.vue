x2<template>
  <div class="container-fluid p-3">
    <div class="row">
      <div class="col-md-4 mb-2">
        <div ref="nprobeComponent" class="bg-success text-white p-3 d-flex justify-content-between align-items-center">
          <BadgeComponent id="probesCounter" :params="probesCounterParams" :ifid="props.context.ifid.toString()"
            :get_component_data="get_component_data_func(probesCounterParams)"
            :set_component_attr="set_component_attr_func(probesCounterParams)" :filters="{}">
          </BadgeComponent>
        </div>
      </div>
      <div class="col-md-4 mb-2">
        <div ref="exporterComponent" class="bg-success text-white p-3 d-flex justify-content-between align-items-center">
          <BadgeComponent id="exportersCounter" :params="exportersCounterParams" :ifid="props.context.ifid.toString()"
            :get_component_data="get_component_data_func(exportersCounterParams)"
            :set_component_attr="set_component_attr_func(exportersCounterParams)" :filters="{}">
          </BadgeComponent>
        </div>
      </div>
      <div class="col-md-4 mb-2">
        <div ref="interfaceComponent" class="bg-success text-white p-3 d-flex justify-content-between align-items-center">
          <BadgeComponent id="interfacesCounter" :params="interfacesCounterParams" :ifid="props.context.ifid.toString()"
            :get_component_data="get_component_data_func(interfacesCounterParams)"
            :set_component_attr="set_component_attr_func(interfacesCounterParams)" :filters="{}">
          </BadgeComponent>
        </div>
      </div>
    </div>

    <TableWithConfig ref="table_exporters_details" :table_id="table_id" :csrf="csrf"
      :f_map_columns="map_table_def_columns" :f_sort_rows="columns_sorting"
      :get_extra_params_obj="get_extra_params_obj">
    </TableWithConfig>
  </div>
</template>

<script setup>
import { ref, reactive } from "vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as BadgeComponent } from "./dashboard-badge.vue";
import { ntopng_url_manager } from "../services/context/ntopng_globals_services.js";

const props = defineProps({
  context: Object
});

const table_id = ref('exporters_interfaces');
const table_exporters_details = ref(null);
const csrf = props.context.csrf;
const components_info = reactive({});
const exporterComponent = ref(null);
const interfaceComponent = ref(null);
const nprobeComponent = ref(null);

const exporter_notes_url = `${http_prefix}/lua/pro/rest/v2/get/exporters/exporter_notes.lua?`
const flowdevice_interface_url = `${http_prefix}/lua/pro/enterprise/flowdevice_interface_details.lua?`
const exporter_ip_url = `${http_prefix}/lua/pro/enterprise/exporter_details.lua?`
const nprobe_ip_url = `${http_prefix}/lua/pro/enterprise/exporters.lua?probe_uuid=`
const exporters_counter_url = "/lua/pro/rest/v2/get/exporters/exporters_count.lua"

const interfaces_counter_str = "interfaces_count"
const exporters_counter_str = "exporters_count"
const probes_counter_str = "probes_count"

const interfaces_limit_str = "interfaces_limit"
const exporters_limit_str = "exporters_limit"

// used for dashboard badges
const badgeParams = {
  "i18n_name": "",
  "counter_formatter": "no_formatting",
  "component_resp_field": "",
  "counter_path": "",
  "url_params": {},
  "url": ""
}

const probesCounterParams = reactive({ ...badgeParams, componentRef: nprobeComponent, url: exporters_counter_url, current_value: probes_counter_str, i18n_name: create_18n_str(probes_counter_str), counter_path: probes_counter_str })
const exportersCounterParams = reactive({ ...badgeParams, componentRef: exporterComponent, url: exporters_counter_url, current_value: exporters_counter_str, limit_value: exporters_limit_str, i18n_name: create_18n_str(exporters_counter_str), counter_path: exporters_counter_str })
const interfacesCounterParams = reactive({ ...badgeParams, componentRef: interfaceComponent, url: exporters_counter_url, current_value: interfaces_counter_str, limit_value: interfaces_limit_str, i18n_name: create_18n_str(interfaces_counter_str), counter_path: interfaces_counter_str })
const loading = ref(false);

function create_18n_str(i18n_name) {
  return "flow_devices." + i18n_name
}

function get_component_data_func(component) {
  const get_component_data = async (url, url_params, post_params) => {
    let info = {};
    if (!components_info[component.url]) {
      components_info[component.url] = {};
    }
    info = components_info[component.url];

    if (info.data) {
      await info.data;
    }

    const data_url = `${component.url}${url_params ? '?' + url_params : ''}`;

    loading.value = true;
    if (post_params) {
      info.data = ntopng_utility.http_post_request(data_url, post_params);
    } else {
      info.data = ntopng_utility.http_request(data_url);
    }

    info.data = info.data.then((response) => {
      loading.value = false;
      if (response.are_limits_exceeded) {
        if (response[component.current_value] === response[component.limit_value]) {
          component.componentRef.classList.add('bg-danger')
          component.componentRef.classList.remove('bg-success')
        }
      } else if(response[component.current_value] === response[component.limit_value]) {
        component.componentRef.classList.add('bg-warning')
        component.componentRef.classList.remove('bg-success')
      }
      const value = `${response[component.current_value]}${component.limit_value ? " / " + response[component.limit_value] : ""}`;
      const resKey = component.counter_path

      return { [resKey]: value }
    });

    return info.data;
  };
  return get_component_data;
}

function set_component_attr_func(component) {
  const set_component_attr = async (attr, value) => {
    component[attr] = value;
  }
  return set_component_attr;
}
const get_extra_params_obj = () => {
  let extra_params = ntopng_url_manager.get_url_object();
  return extra_params;
};

const map_table_def_columns = (columns) => {
  let map_columns = {
    "probe_ip": (value, row) => {
      return value
    },
    "exporter_ip": (value, row) => {
      return value
    }
  };

  columns.forEach((c) => {
    c.render_func = map_columns[c.data_field];
  });

  return columns;
};

function columns_sorting(col, r0, r1) {
  if (col != null) {
    if (col.id == "probe_ip") {
      return sortingFunctions.sortByIP(r0.probe_ip, r1.probe_ip, col.sort);
    } else if (col.id == "exporter_ip") {
      return sortingFunctions.sortByName(r0.exporter_ip, r1.exporter_ip, col.sort);
    } else if (col.id == "interface_name") {
      return sortingFunctions.sortByName(r0.interface_name, r1.interface_name, col.sort);
    } else if (col.id == "probe_edition") {
      return sortingFunctions.sortByName(r0.probe_edition, r1.probe_edition, col.sort);
    } else if (col.id == "probe_maintenance") {
      return sortingFunctions.sortByName(r0.probe_maintenance, r1.probe_maintenance, col.sort);
    }
  }
}

</script>