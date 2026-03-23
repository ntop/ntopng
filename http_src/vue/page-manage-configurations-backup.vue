<!--
  (C) 2013-26 - ntop.org
-->
<template>
  <div>
    <TableWithConfig
      table_config_id="manage_configurations_backup"
      :f_map_columns="map_columns"
      :f_sort_rows="columns_sorting"
      @custom_event="on_table_event"
    />
  </div>
</template>

<script setup>
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";

const props = defineProps({
  context: Object,
});

// Format epoch to a human-readable date using the row's date_format field
function format_epoch(epoch, date_format) {
  const ms = epoch * 1000;
  let fmt = "HH:MM:SS";
  if (date_format === "little_endian") {
    fmt = "DD/MM/YYYY " + fmt;
  } else if (date_format === "middle_endian") {
    fmt = "MM/DD/YYYY " + fmt;
  } else {
    fmt = "YYYY/MM/DD " + fmt;
  }
  return ntopng_utility.from_utc_to_server_date_format(ms, fmt);
}

async function map_columns(columns) {
  columns.forEach((c) => {
    if (c.id === "date") {
      c.render_func = (_data, row) => format_epoch(row.epoch, row.date_format);
    }
  });
  return columns;
}

const SORT_FIELDS = {
  date:    { getter: (r) => r.epoch,        fn: sortingFunctions.sortByNumber },
  version: { getter: (r) => r.ntopng_version || "", fn: sortingFunctions.sortByName  },
};

function columns_sorting(col, r0, r1) {
  if (!col) return 0;
  const def = SORT_FIELDS[col.id];
  if (!def) return 0;
  return def.fn(def.getter(r0), def.getter(r1), col.sort);
}

function on_table_event({ event_id, row }) {
  if (event_id === "click_button_download") {
    window.open(
      `${http_prefix}/lua/rest/v2/get/system/configurations/download_backup.lua?epoch=${row.epoch}&download=true`
    );
  }
}
</script>
