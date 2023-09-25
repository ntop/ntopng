
export const columns_formatter = (columns, scan_type_list, is_report) => {
    const visible_dict = {
          download: true,
          show_result: true
        };

    let map_columns = {
      "scan_type": (scan_type, row) => {
        return scan_type_f(scan_type, row, scan_type_list);
      },
      "last_scan": (last_scan, row) => {
        return last_scan_f(last_scan, row);
      },
  
      "duration": (last_scan, row) => {
        return duration_f(last_scan, row);
      },
      "scan_frequency" : (scan_frequency) => {
        return scan_frequency_f(scan_frequency);
      }, 
      "is_ok_last_scan": (is_ok_last_scan) => {
        return is_ok_last_scan_f(is_ok_last_scan);
        
      },
      "tcp_ports": (tcp_ports, row) => {
        return tcp_ports_f(tcp_ports, row);
        
      }/*,
      "udp_ports": (udp_ports) => {
        let label = "";
  
        if (udp_ports <= 0) {
          return label;
        }
  
        return udp_ports;
      },*/
    };
  
    columns.forEach((c) => {
      c.render_func = map_columns[c.data_field];
  
      if (c.id == "actions") {
              
        c.button_def_array.forEach((b) => {
            
          b.f_map_class = (current_class, row) => { 
            current_class = current_class.filter((class_item) => class_item != "link-disabled");
            // FIX ME with UDP ports check
            if((row.is_ok_last_scan == 3 || row.is_ok_last_scan == null || row.tcp_ports < 1) && visible_dict[b.id]) {
              current_class.push("link-disabled"); 
            }
            return current_class;
          }
        });
      }
    });
    
    return columns;
  };


export const scan_type_f = (scan_type, row, scan_type_list) => {
  if (scan_type !== undefined) {
    let label = scan_type
    const i18n_name = "hosts_stats.page_scan_hosts.scan_type_list."+scan_type;
    label = i18n(i18n_name);
    return label;
  }
}

export const last_scan_f = (last_scan, row) => {
  if (row.is_ok_last_scan == 2 || row.is_ok_last_scan == 4) {
    return ``;
  }
  if (last_scan !== undefined && last_scan.time !== undefined) {
    return last_scan.time;
  } else if (last_scan !== undefined) {
    return last_scan;
  } else {
    return i18n("hosts_stats.page_scan_hosts.not_yet");
  }
} 

export const duration_f = (last_scan, row) => {
  if (row.is_ok_last_scan == 2 || row.is_ok_last_scan == 4) {
    return ``;
  }
  if (row.last_scan !== undefined && row.last_scan.duration !== undefined) {
    return row.last_scan.duration;
  } else {
    return i18n("hosts_stats.page_scan_hosts.not_yet");
  }
}

export const scan_frequency_f = (scan_frequency) => {
  let label = "";
  if (scan_frequency == null || scan_frequency == "disabled") {
    return "";
  } else if (scan_frequency == "1day") {
    label =  i18n("hosts_stats.page_scan_hosts.daily");
  } else {
    label =  i18n("hosts_stats.page_scan_hosts.weekly");
  }
  return `<span class="badge bg-secondary" title="${label}">${label}</span>`;
}

export const is_ok_last_scan_f = (is_ok_last_scan) => {
  let label = ""
  if (is_ok_last_scan == 2) {
    // scheduled
    label = i18n("hosts_stats.page_scan_hosts.scheduled");
    return `<span class="badge bg-dark" title="${label}">${label}</span>`;
  } else if (is_ok_last_scan == 4) {
    // not scanned
    label = i18n("hosts_stats.page_scan_hosts.scanning");
    return `<span class="badge bg-info" title="${label}">${label}</span>`; 
  } else if (is_ok_last_scan == 3 || is_ok_last_scan == null) {
    // not scanned
    label = i18n("hosts_stats.page_scan_hosts.not_scanned");
    return `<span class="badge bg-primary" title="${label}">${label}</span>`;
  } else if (is_ok_last_scan == 1) {
    // success
    label = i18n("hosts_stats.page_scan_hosts.success");
    return `<span class="badge bg-success" title="${label}">${label}</span>`;
  } else if (is_ok_last_scan == 0) {
    // error
    label = i18n("hosts_stats.page_scan_hosts.error");
    return `<span class="badge bg-danger" title="${label}">${label}</span>`;
  } 
}

export const tcp_ports_f = (tcp_ports, row) => {
  if (tcp_ports == 0 && row.udp_ports == 0) {
    tcp_ports = row.num_open_ports;
  }
  let label = "";

  if (tcp_ports <= 0) {
    return label;
  }

  return tcp_ports;
}


export const hosts_f = (hosts, row) => {

  const hosts_list = hosts.split(", ");
  let label = "";

  hosts_list.forEach((item) => {
    label += item.split("-")[0];
    label += ", ";
  })
  return label.substring(0, label.length - 2);
}
