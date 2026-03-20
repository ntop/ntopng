<!-- (C) 2026 - ntop.org -->
<template>
  <div class="m-2 mb-3">
    <!-- IP Version Filter -->
    <div class="d-flex flex-wrap align-items-center mb-2 gap-1">
      <div class="dropdown me-3 d-flex">
        <span class="no-wrap d-flex align-items-center filters-label me-2">
          <b>{{ _i18n("icmp_page.icmp_version") }}: </b>
        </span>
        <SelectSearch
          v-model:selected_option="current_ip_version"
          theme="bootstrap-5"
          :options="ip_version_options"
          @select_option="add_version_filter"
          :dropdown_size="'small'"
        />
      </div>
    </div>

    <!-- ICMP Table -->
    <div class="position-relative">
      <div class="widget-name"><h6 class="m-0">{{ _i18n("icmp_page.icmp_stats") }}</h6></div>
      <TableWithConfig
        ref="table_icmp"
        :table_id="table_id"
        :csrf="context.csrf"
        :showLoading="true"
        :f_map_columns="map_table_def_columns"
        :get_extra_params_obj="get_extra_params_obj"
        :f_sort_rows="columns_sorting"
      />
    </div>
    <!-- Top Hosts Table -->
    <div class="position-relative mt-4">
      <div class="widget-name"><h6 class="m-0">{{ _i18n("icmp_page.top_icmp_hosts") }}</h6></div>
      <TableWithConfig
        ref="table_icmp_hosts"
        :table_id="table_id_hosts"
        :csrf="context.csrf"
        :showLoading="true"
        :f_map_columns="map_table_def_columns_hosts"
        :get_extra_params_obj="get_extra_params_obj"
        :f_sort_rows="columns_sorting_hosts"
      />
    </div>
  </div>
</template>

<script setup>
import { ref, onBeforeMount } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import formatterUtils from "../utilities/formatter-utils";

/* ************************************** */

const _i18n = (t) => i18n(t);

const props = defineProps({
  context: Object,
});

/* ************************************** */

const table_id = ref("icmp_list");
const table_id_hosts = ref("top_icmp_hosts");
const table_icmp = ref(null);
const table_icmp_hosts = ref(null);

// IP Version Filter Options
const ip_version_options = ref([
  { key: "version", value: "4", label: _i18n("icmpv4") },
  { key: "version", value: "6", label: _i18n("icmpv6") },
]);

const current_ip_version = ref(ip_version_options.value[0]);

/* ************************************** */

/**
 * Loads IP version filter from URL parameters or sets default (v4)
 */
const loadVersionFilter = () => {
  const selected_version = ntopng_url_manager.get_url_entry("version");
  if (selected_version) {
    const option = ip_version_options.value.find((el) => el.value === selected_version);
    if (option) {
      current_ip_version.value = option;
    }
  } else {
    current_ip_version.value = ip_version_options.value[0];
  }
  ntopng_url_manager.set_key_to_url(
    current_ip_version.value.key,
    current_ip_version.value.value
  );
};

/* ************************************** */
// ICMP Stats Table
/* ************************************** */

/**
 * Handles IP version filter selection and refreshes the table
 * @param {Object} value - Selected filter option
 */
const add_version_filter = (value) => {
  current_ip_version.value = value;
  ntopng_url_manager.set_key_to_url(
    current_ip_version.value.key,
    current_ip_version.value.value
  );
  table_icmp.value.refresh_table(false);
  table_icmp_hosts.value.refresh_table(false);
};

/* ************************************** */

const map_table_def_columns = (columns) => {
  let map_columns = {
    "icmp_message": (value, row) => {
      return `<a href="${value.url}">${value.label}</a>`;
    },
    "icmp_type": (value, row) => {
      return value;
    },
    "icmp_code": (value, row) => {
      return value;
    },
    "packets": (value, row) => {
      return formatterUtils.getFormatter("full_number")(value);
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
    if (col.id === "icmp_message") {
      return sortingFunctions.sortByName(r0.icmp_message.label, r1.icmp_message.label, col.sort);
    } else if (col.id === "icmp_type") {
      return sortingFunctions.sortByNumber(r0.icmp_type, r1.icmp_type, col.sort);
    } else if (col.id === "icmp_code") {
      return sortingFunctions.sortByNumber(r0.icmp_code, r1.icmp_code, col.sort);
    } else if (col.id === "packets") {
      return sortingFunctions.sortByNumber(r0.packets, r1.packets, col.sort);
    }
  }
}

/* ************************************** */
// Top Hosts Table
/* ************************************** */

const map_table_def_columns_hosts = (columns) => {
  let map_columns = {
    "host": (value, row) => {
      return `<a href="${value.url}">${value.label}</a>`;
    },
    "packets": (value, row) => {
      return formatterUtils.getFormatter("full_number")(value);
    },
  };

  columns.forEach((c) => {
    c.render_func = map_columns[c.data_field];
  });

  return columns;
};

/* ************************************** */

function columns_sorting_hosts(col, r0, r1) {
  if (col != null) {
    if (col.id === "host") {
      return sortingFunctions.sortByName(r0.host.label, r1.host.label, col.sort);
    } else if (col.id === "packets") {
      return sortingFunctions.sortByNumber(r0.packets, r1.packets, col.sort);
    }
  }
}

const get_extra_params_obj = () => {
  let extra_params = ntopng_url_manager.get_url_object();
  return extra_params;
};

/* ************************************** */

onBeforeMount(() => {
  loadVersionFilter();
});

/* ************************************** */
</script>