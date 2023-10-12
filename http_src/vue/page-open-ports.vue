<!--
  (C) 2013-22 - ntop.org
-->

<template>
  <div class="row">
    <div class="col-md-12 col-lg-12">
      <div class="card  card-shadow">
        <div class="card-body">
          
          
          <div id="open_ports">
            
            <TableWithConfig ref="table_open_ports" :table_id="table_id" :csrf="context.csrf"
              :f_map_columns="map_table_def_columns" :get_extra_params_obj="get_extra_params_obj"
              :f_sort_rows="columns_sorting" :f_map_config="map_config" @custom_event="on_table_custom_event">
              
            </TableWithConfig>

          </div>
          
        </div>
        

        

      </div>
    </div>
  </div>
</template>
  
<script setup>

/* Imports */ 
import { ref, onBeforeMount, onMounted } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import { ntopng_utility } from '../services/context/ntopng_globals_services';

/* ******************************************************************** */ 

/* Consts */ 
const _i18n = (t) => i18n(t);



const active_monitoring_url = `${http_prefix}/lua/vulnerability_scan.lua`;
 

const table_id = ref('open_ports');
const map_config = (config) => {
    return config;
};

const table_open_ports = ref();

const props = defineProps({
  context: Object,
});
const rest_params = {
  csrf: props.context.csrf
};
const context = ref({
  csrf: props.context.csrf,
  ifid: props.context.ifid,
  is_enterprise_l: props.context.is_enterprise_l
});

/* ******************************************************************** */ 



/* ******************************************************************** */ 

const get_extra_params_obj = () => {
  let extra_params = ntopng_url_manager.get_url_object();
  return extra_params;
};

/* ******************************************************************** */ 

/* Function to handle all buttons */
function on_table_custom_event(event) {
  
  let events_managed = {
    "click_button_show_hosts": click_button_show_hosts
  };
  if (events_managed[event.event_id] == null) {
    return;
  }
  events_managed[event.event_id](event);
}


function compare_by_port(r0,r1) {

  let col = {
      "data": {
          "title_i18n": "port",
          "data_field": "port",
          "sortable": true,
          "class": [
              "text-nowrap",
              "text-end"
          ]
      }
    };
  let r0_col = format_num_ports_for_sort(r0_col);
  let r1_col = format_num_ports_for_sort(r1_col);
  return r0_col - r1_col;
}

function columns_sorting(col, r0, r1) {

  if (col != null) {
    let r0_col = r0[col.data.data_field];
    let r1_col = r1[col.data.data_field];
    if(col.id == "port") {

      r0_col = format_num_ports_for_sort(r0_col);
      r1_col = format_num_ports_for_sort(r1_col);
      if (col.sort == 1) {
        return r0_col - r1_col;
      }
      return r1_col - r0_col;
    } else if(col.id == "count_host") {
      r0_col = format_cve_num(r0_col);
      r1_col = format_cve_num(r1_col);

      if (r0_col == r1_col) {
        return compare_by_port(r0,r1);
      }
      if (col.sort == 1) {
        return r0_col - r1_col;
      }
      return r1_col - r0_col;
    }
    else if(col.id == "cves") {
      r0_col = format_cve_num(r0_col);
      r1_col = format_cve_num(r1_col);

      if (r0_col == r1_col) {
        return compare_by_port(r0,r1);
      }
      if (col.sort == 1) {
        return r0_col - r1_col;
      }
      return r1_col - r0_col;
    }
    else if(col.id == "hosts") {
      /* It's an array */

      if (r0_col == r1_col) {
        return compare_by_port(r0,r1);
      }
      if (col.sort == 1) {
        return r0_col.localeCompare(r1_col);
      }
      return r1_col.localeCompare(r0_col);
    } 
   
  } else {
    return compare_by_port(r0,r1);
  }
  
}




function format_cve_num(num) {
  let value = 0;
  if (num === "" || num === null || num === NaN || num === undefined) {
    value = 0;
  } else {
    num = num.split(',').join("");
    value = parseInt(num);
  }

  return value;
}

function format_num_for_sort(num) {
  if (num === "" || num === null || num === NaN || num === undefined) {
    num = 0;
  } else {
    num = num.split(',').join("")
    num = parseInt(num);
  }

  return num;
}

function format_num_ports_for_sort(num) {
  if (num == "" || num == null || num == NaN || num == undefined) 
    num = 0;

  num = parseInt(num);;
  return num;
}




/* ******************************************************************** */ 


/* Function to map columns data */
const map_table_def_columns = (columns) => {
  const visible_dict = {
        download: true,
        show_result: true
      };
  let map_columns = {
    "hosts": (hosts, row) => {
      let label = ``;
      const hosts_splited = hosts.split(", ");
      const length = hosts_splited.length;
      let i = 0;
      while ( i < 5 && i < length) {
        const host_splitted = hosts_splited[i].split("|");
        const host = host_splitted[0];
        const scan_type = host_splitted[1];
        const date = host_splitted[2];

        let host_name = '';
        if (host_splitted.length > 3) {
          host_name = host_splitted[3];
        }

        let params = {
          host: host,
          scan_type: scan_type,
          scan_return_result: true,
          page: "show_result",
          scan_date: date

        };
        let url_params = ntopng_url_manager.obj_to_url_params(params);

        let url = `${active_monitoring_url}?${url_params}`;
        
        const host_label = host_name != ''? host_name : host;
        
        if (label == ``)
          label += `<a href="${url}">${host_label}</a>`;  
        else
          label += `, <a href="${url}">${host_label}</a>`;  

        i++;
      }
      
      if (length > 5) {
        label += `...`;
      } 

      return label;

    }
  }
    

  columns.forEach((c) => {
    c.render_func = map_columns[c.data_field];
  });
  
  return columns;
};

/* ******************************************************************** */ 






/* ************************** REST Functions ************************** */

/* Function to show all hosts during edit */

async function click_button_show_hosts(event) {
  let port = event.row.port;

  let params = {
    port: port,
  };

  let url_params = ntopng_url_manager.obj_to_url_params(params);

  let url = `${active_monitoring_url}?${url_params}`;
  ntopng_url_manager.go_to_url(url);
}


/* Function to download last vulnerability scan result */
async function click_button_download(event) {
  let params = {
    host: event.row.host,
    scan_type: event.row.scan_type
  };
  let url_params = ntopng_url_manager.obj_to_url_params(params);

  let url = `${scan_result_url}?${url_params}`;
  ntopng_utility.download_URI(url);
}

/* ******************************************************************** */ 

/* Function to show last vulnerability scan result */
async function click_button_show_result(event) {
  let host = event.row.host;
  let date = event.row.last_scan.time;

  let params = {
    host: host,
    scan_type: event.row.scan_type,
    scan_return_result: true,
    page: "show_result",
    scan_date: date

  };
  let url_params = ntopng_url_manager.obj_to_url_params(params);

  let url = `${active_monitoring_url}?${url_params}`;
  ntopng_url_manager.go_to_url(url);
}


/* ******************************************************************** */ 

</script>
  