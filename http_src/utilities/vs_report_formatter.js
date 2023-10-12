
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
    "max_score_cve": (max_score_cve, row) => {
      return max_score_cve_f(max_score_cve);
    },
    "tcp_ports": (tcp_ports, row) => {
      return tcp_ports_f(tcp_ports, row);
      
    },
    "udp_ports": (udp_ports, row) => {
      return udp_ports_f(udp_ports, row);
    },
  };

  columns.forEach((c) => {
    c.render_func = map_columns[c.data_field];

    if (c.id == "actions") {
            
      c.button_def_array.forEach((b) => {
          
        b.f_map_class = (current_class, row) => { 
          current_class = current_class.filter((class_item) => class_item != "link-disabled");
          // FIX ME with UDP ports check
          if((row.is_ok_last_scan == 3 || row.is_ok_last_scan == null || (row.tcp_ports < 1 && row.udp_ports < 1) ) && visible_dict[b.id]) {
            current_class.push("link-disabled"); 
          }
          return current_class;
        }
      });
    }
  });
  
  return columns;
};

export const max_score_cve_f = (max_score_cve, row) => {
  const score = Number(max_score_cve);
  let font_color = "";

  let label = "";
  if (max_score_cve != null) {

    if (score == 0) {
      font_color = "green";
    } else if(score < 3.9) {
      font_color = "grey";
    } else if(score < 7) {
      font_color = "yellow";
    } else  {
      font_color = "red";
    } 

    if (score != 0) {
      label = `<FONT COLOR=${font_color}>${max_score_cve}`;
    }
  }


  return label;
}


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

const ports_list_string = (port_list) => {
  let ports_string = "";
  if (port_list != null) {
    port_list.forEach((item) => {
      if(ports_string == "") {
        ports_string = item;
      } else {
        ports_string += `, ${item}`;
      }
    });
  }

  return ports_string;
}

const get_num_open_ports_icon = (diff_case, unused_port_list, filtered_port_list) => {

  let label = null;
  switch(diff_case) {
    case 4: {
      let unused_port_list_string = ports_list_string(unused_port_list);
      label = ` <span class="badge bg-secondary"><i class="fa-solid fa-ghost" title='${unused_port_list_string}'></i></span></div>`;
    }
      break;
    case 3: {
      let filtered_ports_list_string = ports_list_string(filtered_port_list);
      label = ` <span class="badge bg-secondary"><i class="fa-solid fa-filter" title='${filtered_ports_list_string}'></i></span>`;
    }
      break;
    default:
      break;
  }

  return label;
}

export const udp_ports_f = (udp_ports, row) => {
  if (udp_ports == 0 && row.udp_ports == 0 && row.scan_type.contains("udp")) {
    udp_ports = row.num_open_ports;
  }
  let label = "";

  if (udp_ports <= 0) {
    return label;
  }

  label = `${udp_ports}`;

  if (row.host_in_mem) {

    const num_ports_icon = get_num_open_ports_icon(row.udp_ports_case,row.udp_ports_unused, row.udp_filtered_ports);
    if(num_ports_icon != null) {
      label += num_ports_icon;
    }
  }

  return label;
}


export const tcp_ports_f = (tcp_ports, row) => {
  if (tcp_ports == 0 && row.tcp_ports == 0 && row.scan_type.contains("tcp")) {
    tcp_ports = row.num_open_ports;
  }
  let label = "";

  if (tcp_ports <= 0) {
    return label;
  }

  label = `${tcp_ports}`;

  if (row.host_in_mem) {

    const num_ports_icon = get_num_open_ports_icon(row.tcp_ports_case,row.tcp_ports_unused, row.tcp_ports_filtered);
    if(num_ports_icon != null) {
      label += num_ports_icon;
    }
  }

  return label;
}

export const tcp_port_f = (port, row) => {
  let rsp = port;
  if (row.port_label != null && row.port_label != port) {
    rsp += ` (${row.port_label})`
  }
  return rsp;
}
const find_badge = (port, row, ports_unused, ports_filtered) => {
  let result = ''
  if (ports_unused != null) {
    ports_unused.forEach((item) => {
      if(port == Number(item) ) {
        result = "unused";
      }
    })
  }

  if(result != '') {
    return result;
  }

  if (ports_filtered != null) {
    ports_filtered.forEach((item) => {
      if(port == Number(item)) {
        result = "filtered";
      }
    })
  }

  return result;
}

const get_icon_component = (item, row, ports_unused, ports_fitered) => {
  let port = item.split(" ")[0].split("/")[0];
  let port_badge = find_badge(Number(port), row, ports_unused, ports_fitered);
  let icon_comp = null;
  switch (port_badge) {
    case 'unused': 
        icon_comp = ` &nbsp;<span class="badge bg-secondary" title='${i18n('hosts_stats.page_scan_hosts.unused_port')}'><i class="fa-solid fa-ghost"></i></span>`;
      break;
    case 'filtered':
        icon_comp = ` &nbsp;<span class="badge bg-primary" title='${i18n('hosts_stats.page_scan_hosts.filtered_port')}'><i class="fa-solid fa-filter"></i></span>`;
      break;
    default: 
      break;
  }

  return icon_comp;
}

export const udp_ports_list_f = (udp_ports_list, row) => {
  if (udp_ports_list != null) {
    const ports = udp_ports_list.split(",");

    let label = "";
    ports.forEach((item) => {
      if(item != null && item != '') {

        if (row.host_in_mem) {
          const icon_comp = get_icon_component(item, row, row.udp_ports_unused, row.udp_ports_filtered);
          if(icon_comp != null) {
            item += icon_comp;
          }        
        }
        label += `<li>${item}</li>`;
      }
    });

    if (row.udp_filtered_ports != null) {
      row.udp_ports_filtered.forEach((item) => {

        item += `/udp`;
        if (row.host_in_mem) {
          item += ` <span class="badge bg-primary" title='${i18n('hosts_stats.page_scan_hosts.filtered_port')}'><i class="fa-solid fa-filter"></i></span>`;
        }
        label += `<li>${item}</li>`;
      });
    }
    return label;
  }
}

export const tcp_ports_list_f = (tcp_ports_list, row) => {

  if (tcp_ports_list != null ) {
    const ports = tcp_ports_list.split(",");
    let label = "";
    ports.forEach((item) => {
      if(item != null && item != '') {

        if (row.host_in_mem) {
          const icon_comp = get_icon_component(item, row, row.tcp_ports_unused, row.tcp_ports_filtered);
          if(icon_comp != null) {
            item += icon_comp;
          }
        }
        
        label += `<li>${item}</li>`;
      }
    });

    if (row.tcp_ports_filtered != null) {
      row.tcp_ports_filtered.forEach((item) => {

        item += `/tcp`;
        if (row.host_in_mem) {
          item += ` <span class="badge bg-primary" title='${i18n('hosts_stats.page_scan_hosts.filtered_port')}'><i class="fa-solid fa-filter"></i></span>`;
        }
        label += `<li>${item}</li>`;
      });
    }

    return label;
  } 

  return tcp_ports_list;

}


export const hosts_f = (hosts, row) => {

  const hosts_list = hosts.split(", ");
  let label = "";
  let hosts_map = new Map();
  hosts_list.forEach((item) => {
    let host_info = item.split("|");

    hosts_map.set(
      host_info[3] != null && host_info[3] != "" ? host_info[3] : host_info[0], 
      null)
  });

  hosts_map = new Map([...hosts_map.entries()].sort());


  hosts_map.forEach((values, keys) => {
    label += `<li> ${keys} </li>` ;
  })
  return label;
}

export const host_f = (host, row) => {
  let label = host;
  if (row.host_name != null && row.host_name != "") {
    label = row.host_name;
  }
  return label;
}

export const cves_f = (cves, row) => {
  let label = "";
  let index = 0;
  if (cves != null) {
    cves.forEach((item) => {
      if (index < 100) {
        let cve_details = item.split("|");

        if (cve_details.length > 1) {
          let badge_type = "";
          const score = Number(cve_details[1]);
          if (score == 0) {
            badge_type = "bg-success";
          } else if(score < 3.9) {
            badge_type = "bg-secondary";
          } else if(score < 7) {
            badge_type = "bg-warning";
          } else {
            badge_type = "bg-danger";
          }
          
          label += `<li><span class="badge ${badge_type}">${cve_details[0]} <span/></li>`;

        } else {
          label += `<li>${item}</li>`;
        }
        index++;
      } else {
        return label;
      }
    })
  }


  return label;
}

