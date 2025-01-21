--
-- (C) 2014-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

local ts_utils = require "ts_utils"
require "lua_utils_generic"
require "label_utils"
require "lua_utils_get"

local timeseries_info = {}

-- #################################

local series_extra_info = {
    alerts = {
        color = '#2d99bd'
    },
    bytes = {
        color = '#1f77b4'
    },
    packets = {
        color = '#1f77b4'
    },
    bytes_sent = {
        color = '#c6d9fd'
    },
    bytes_rcvd = {
        color = '#90ee90'
    },
    devices = {
        color = '#ac9ddf'
    },
    flows = {
        color = '#8c6f94'
    },
    hosts = {
        color = '#ff7f0e'
    },
    score = {
        color = '#ff3231'
    },
    cli_score = {
        color = '#690504'
    },
    srv_score = {
        color = '#f5a2a2'
    },
    default = {
        color = '#c6d9fd'
    },
    usage_sent = {
        color = '#b3abd6'
    },
    usage_rcvd = {
        color = '#2f4241'
    }
}

-- #################################

local timeseries_id = {
    iface = "iface",
    host = "host",
    mac = "mac",
    network = "subnet",
    asn = "asn",
    country = "country",
    os = "os",
    vlan = "vlan",
    host_pool = "host_pool",
    pod = "pod",
    container = "container",
    hash_state = "ht",
    system = "system",
    profile = "profile",
    redis = "redis",
    influxdb = "influxdb",
    active_monitoring = "am",
    snmp_interface = "snmp_interface",
    snmp_device = "snmp_device",
    observation_point = "obs_point",
    flow_dev = "flowdev",
    flow_port = "flowdev_port",
    blacklist = "blacklist",
    nedge = "nedge"
}

-- #################################

function timeseries_info.get_timeseries_color(subject)
    if series_extra_info[subject] then
        return series_extra_info[subject].color
    end

    -- Safety check, if an improper value is given,
    -- then return a default color
    return series_extra_info.default.color
end

-- #################################

-- Timeseries list
local community_timeseries = { {
    schema = "iface:traffic_rxtx",
    id = timeseries_id.iface,
    label = i18n("graphs.traffic_rxtx"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n("graphs.metric_labels.traffic"),
    timeseries = {
        bytes_sent = {
            label = i18n('graphs.metric_labels.sent'),
            color = timeseries_info.get_timeseries_color('bytes_sent')
        },
        bytes_rcvd = {
            invert_direction = true,
            label = i18n('graphs.metric_labels.rcvd'),
            color = timeseries_info.get_timeseries_color('bytes_rcvd')
        }
    },
    always_visibile = true,
    default_visible = true
}, {
    schema = "iface:traffic_ip",
    id = timeseries_id.iface,
    label = i18n("graphs.traffic_ip"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n("graphs.metric_labels.traffic"),
    timeseries = {
        bytes_ipv4 = {
            label = i18n('graphs.metric_labels.ipv4'),
            color = timeseries_info.get_timeseries_color('bytes_sent')
        },
        bytes_ipv6 = {
            label = i18n('graphs.metric_labels.ipv6'),
            color = timeseries_info.get_timeseries_color('bytes_rcvd')
        }
    },
    always_visibile = true,
    draw_stacked = true
}, {
    schema = "iface:flows",
    id = timeseries_id.iface,
    label = i18n("graphs.active_flows"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        num_flows = {
            label = i18n('graphs.metric_labels.num_flows'),
            color = timeseries_info.get_timeseries_color('flows')
        }
    }
}, {
    schema = "top:blacklist_v2:hits",
    chart_type = "line",
    id = timeseries_id.blacklist,
    label = i18n('graphs.metric_labels.top_blacklist_hits'),
    type = "top",
    draw_stacked = true,
    priority = 2,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.blacklist_hits'),
    timeseries = {
        hits = {
            use_serie_name = true,
            label = i18n('graphs.metric_labels.blacklist_num_hits'),
        }
    },
    default_visible = true,
    always_visibile = true,
}, {
    schema = "iface:new_flows",
    id = timeseries_id.iface,
    label = i18n("graphs.new_flows"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        new_flows = {
            label = i18n('graphs.metric_labels.num_flows'),
            color = timeseries_info.get_timeseries_color('flows')
        }
    }
}, {
    schema = "iface:remote2local",
    id = timeseries_id.iface,
    label = i18n("graphs.remote2local"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n('graphs.metric_labels.bytes'),
    timeseries = {
        bytes = {
            label = i18n('graphs.metric_labels.bytes'),
            color = timeseries_info.get_timeseries_color('bytes')
        }
    }
}, {
    schema = "iface:local2remote",
    id = timeseries_id.iface,
    label = i18n("graphs.local2remote"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n('graphs.metric_labels.bytes'),
    timeseries = {
        bytes = {
            label = i18n('graphs.metric_labels.bytes'),
            color = timeseries_info.get_timeseries_color('bytes')
        }
    }
}, {
    schema = "iface:alerted_flows",
    id = timeseries_id.iface,
    label = i18n("graphs.total_alerted_flows"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        num_flows = {
            label = i18n('graphs.metric_labels.num_flows'),
            color = timeseries_info.get_timeseries_color('flows')
        }
    }
}, {
    schema = "iface:hosts",
    id = timeseries_id.iface,
    label = i18n("graphs.active_hosts"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.hosts'),
    timeseries = {
        num_hosts = {
            label = i18n('graphs.metric_labels.num_hosts'),
            color = timeseries_info.get_timeseries_color('hosts')
        }
    }
}, {
    schema = "iface:engaged_alerts",
    id = timeseries_id.iface,
    label = i18n("graphs.engaged_alerts"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.alerts'),
    timeseries = {
        engaged_alerts = {
            label = i18n('graphs.engaged_alerts'),
            color = timeseries_info.get_timeseries_color('alerts')
        }
    }
}, {
    schema = "iface:dropped_alerts",
    id = timeseries_id.iface,
    label = i18n("graphs.dropped_alerts"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.alerts'),
    timeseries = {
        dropped_alerts = {
            label = i18n('graphs.dropped_alerts'),
            color = timeseries_info.get_timeseries_color('alerts')
        }
    }
}, {
    schema = "iface:devices",
    id = timeseries_id.iface,
    label = i18n("graphs.active_devices"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.devices'),
    timeseries = {
        num_devices = {
            label = i18n('graphs.metric_labels.num_devices'),
            color = timeseries_info.get_timeseries_color('devices')
        }
    }
}, {
    schema = "iface:http_hosts",
    id = timeseries_id.iface,
    label = i18n("graphs.active_http_servers"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.servers'),
    timeseries = {
        num_devices = {
            label = i18n('graphs.num_servers'),
            color = timeseries_info.get_timeseries_color('devices')
        }
    },
    nedge_exclude = true
}, {
    schema = "iface:traffic",
    id = timeseries_id.iface,
    label = i18n("graphs.traffic"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n("graphs.metric_labels.traffic"),
    timeseries = {
        bytes = {
            label = i18n('graphs.metric_labels.traffic'),
            color = timeseries_info.get_timeseries_color('bytes')
        }
    },
    nedge_exclude = true
}, {
    schema = "iface:throughput_bps",
    id = timeseries_id.iface,
    label = i18n("graphs.throughput_bps"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n("graphs.metric_labels.traffic"),
    timeseries = {
        bps = {
            label = i18n('graphs.metric_labels.throughput'),
            color = timeseries_info.get_timeseries_color('bytes')
        }
    }
}, {
    schema = "iface:throughput_pps",
    id = timeseries_id.iface,
    label = i18n("graphs.throughput_pps"),
    priority = 0,
    measure_unit = "pps",
    scale = i18n("graphs.metric_labels.traffic"),
    timeseries = {
        pps = {
            label = i18n('graphs.metric_labels.throughput'),
            color = timeseries_info.get_timeseries_color('bytes')
        }
    }
}, {
    schema = "iface:score",
    id = timeseries_id.iface,
    label = i18n("graphs.score"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.score'),
    timeseries = {
        cli_score = {
            label = i18n('graphs.cli_score'),
            color = timeseries_info.get_timeseries_color('cli_score')
        },
        srv_score = {
            label = i18n('graphs.srv_score'),
            color = timeseries_info.get_timeseries_color('srv_score')
        }
    }
}, {
    schema = "iface:packets_vs_drops",
    id = timeseries_id.iface,
    label = i18n("graphs.packets_vs_drops"),
    priority = 0,
    measure_unit = "number",
    scale = i18n("graphs.packets_vs_drops"),
    timeseries = {
        packets = {
            label = i18n('graphs.metric_labels.packets'),
            color = timeseries_info.get_timeseries_color('bytes')
        },
        drops = {
            label = i18n('graphs.metric_labels.drops'),
            draw_type = "line",
            color = timeseries_info.get_timeseries_color('default')
        }
    }
}, {
    schema = "iface:nfq_pct",
    id = timeseries_id.iface,
    label = i18n("graphs.num_nfq_pct"),
    priority = 0,
    measure_unit = "percentage",
    scale = i18n('graphs.metric_labels.load'),
    timeseries = {
        num_nfq_pct = {
            label = i18n('graphs.num_nfq_pct'),
            color = timeseries_info.get_timeseries_color('default')
        }
    },
    nedge_only = true
}, {
    schema = "iface:hosts_anomalies",
    id = timeseries_id.iface,
    label = i18n("graphs.hosts_anomalies"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.anomalies'),
    timeseries = {
        num_loc_hosts_anom = {
            label = i18n('graphs.loc_host_anomalies'),
            color = timeseries_info.get_timeseries_color('hosts')
        },
        num_rem_hosts_anom = {
            label = i18n('graphs.rem_host_anomalies'),
            draw_type = "line",
            color = timeseries_info.get_timeseries_color('hosts')
        }
    }
}, {
    schema = "iface:disc_prob_bytes",
    id = timeseries_id.iface,
    label = i18n("graphs.discarded_probing_bytes"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n('graphs.metric_labels.bytes'),
    timeseries = {
        bytes = {
            label = i18n('graphs.metric_labels.drops'),
            color = timeseries_info.get_timeseries_color('bytes')
        }
    },
    nedge_exclude = true
}, {
    schema = "iface:disc_prob_pkts",
    id = timeseries_id.iface,
    label = i18n("graphs.discarded_probing_packets"),
    priority = 0,
    measure_unit = "pps",
    scale = i18n('graphs.metric_labels.packets'),
    timeseries = {
        packets = {
            label = i18n('graphs.metric_labels.drops'),
            color = timeseries_info.get_timeseries_color('packets')
        }
    },
    nedge_exclude = true
}, {
    schema = "iface:dumped_flows",
    id = timeseries_id.iface,
    label = i18n("graphs.dumped_flows"),
    priority = 0,
    measure_unit = "fps",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        dumped_flows = {
            label = i18n('graphs.dumped_flows'),
            color = timeseries_info.get_timeseries_color('flows')
        },
        dropped_flows = {
            label = i18n('graphs.dropped_flows'),
            color = timeseries_info.get_timeseries_color('flows')
        }
    }
}, {
    schema = "iface:zmq_recv_flows",
    id = timeseries_id.iface,
    label = i18n("graphs.zmq_received_flows"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        flows = {
            label = i18n('graphs.zmq_received_flows'),
            color = timeseries_info.get_timeseries_color('flows')
        }
    }
}, {
    schema = "iface:zmq_flow_coll_drops",
    id = timeseries_id.iface,
    label = i18n("graphs.zmq_flow_coll_drops"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        drops = {
            label = i18n('graphs.zmq_flow_coll_drops'),
            color = timeseries_info.get_timeseries_color('default')
        }
    },
    nedge_exclude = true
}, {
    schema = "iface:zmq_flow_coll_udp_drops",
    id = timeseries_id.iface,
    label = i18n("graphs.zmq_flow_coll_udp_drops"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        drops = {
            label = i18n('graphs.zmq_flow_coll_udp_drops'),
            color = timeseries_info.get_timeseries_color('default')
        }
    },
    nedge_exclude = true
}, {
    schema = "iface:tcp_lost",
    id = timeseries_id.iface,
    label = i18n("graphs.tcp_packets_lost"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.packets'),
    timeseries = {
        packets = {
            label = i18n('graphs.tcp_packets_lost'),
            color = timeseries_info.get_timeseries_color('packets')
        }
    },
    nedge_exclude = true
}, {
    schema = "iface:tcp_out_of_order",
    id = timeseries_id.iface,
    label = i18n("graphs.tcp_packets_ooo"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.packets'),
    timeseries = {
        packets = {
            label = i18n('graphs.tcp_packets_ooo'),
            color = timeseries_info.get_timeseries_color('packets')
        }
    },
    nedge_exclude = true
}, {
    schema = "iface:tcp_retransmissions",
    id = timeseries_id.iface,
    label = i18n("graphs.tcp_packets_retr"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.packets'),
    timeseries = {
        packets = {
            label = i18n('graphs.tcp_packets_retr'),
            color = timeseries_info.get_timeseries_color('packets')
        }
    },
    nedge_exclude = true
}, {
    schema = "iface:tcp_keep_alive",
    id = timeseries_id.iface,
    label = i18n("graphs.tcp_packets_keep_alive"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.packets'),
    timeseries = {
        packets = {
            label = i18n('graphs.tcp_packets_keep_alive'),
            color = timeseries_info.get_timeseries_color('packets')
        }
    },
    nedge_exclude = true
}, {
    schema = "iface:tcp_syn",
    id = timeseries_id.iface,
    label = i18n("graphs.tcp_syn_packets"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.packets'),
    timeseries = {
        packets = {
            label = i18n('graphs.tcp_syn_packets'),
            color = timeseries_info.get_timeseries_color('packets')
        }
    },
    nedge_exclude = true
}, {
    schema = "iface:tcp_synack",
    id = timeseries_id.iface,
    label = i18n("graphs.tcp_synack_packets"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.packets'),
    timeseries = {
        packets = {
            label = i18n('graphs.tcp_syn_packets'),
            color = timeseries_info.get_timeseries_color('packets')
        }
    },
    nedge_exclude = true
}, {
    schema = "iface:tcp_finack",
    id = timeseries_id.iface,
    label = i18n("graphs.tcp_finack_packets"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.packets'),
    timeseries = {
        packets = {
            label = i18n('graphs.tcp_finack_packets'),
            color = timeseries_info.get_timeseries_color('packets')
        }
    },
    nedge_exclude = true
}, {
    label = i18n("graphs.zmq_msg_rcvd"),
    id = timeseries_id.iface,
    schema = "iface:zmq_rcvd_msgs",
    priority = 0,
    measure_unit = "number",
    timeseries = {
        msgs = {
            label = i18n('graphs.metric_labels.rcvd_msgs'),
            color = timeseries_info.get_timeseries_color('default')
        }
    }
}, {
    label = i18n("graphs.zmq_msg_dropped"),
    id = timeseries_id.iface,
    schema = "iface:zmq_msg_drops",
    priority = 0,
    measure_unit = "number",
    timeseries = {
        msgs = {
            label = i18n('graphs.metric_labels.dropped_msgs'),
            color = timeseries_info.get_timeseries_color('default')
        }
    }
}, {
    schema = "iface:tcp_rst",
    id = timeseries_id.iface,
    label = i18n("graphs.tcp_rst_packets"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.packets'),
    timeseries = {
        packets = {
            label = i18n('graphs.tcp_rst_packets'),
            color = timeseries_info.get_timeseries_color('packets')
        }
    },
    nedge_exclude = true
}, -- host_details.lua (HOST): --
    {
        schema = "host:traffic",
        id = timeseries_id.host,
        label = i18n("graphs.traffic_rxtx"),
        priority = 0,
        measure_unit = "bps",
        scale = i18n('graphs.metric_labels.traffic'),
        timeseries = {
            bytes_sent = {
                label = i18n('graphs.metric_labels.sent'),
                color = timeseries_info.get_timeseries_color('bytes_sent')
            },
            bytes_rcvd = {
                invert_direction = true,
                label = i18n('graphs.metric_labels.rcvd'),
                color = timeseries_info.get_timeseries_color('bytes_rcvd')
            }
        },
        always_visibile = true,
        default_visible = true
    }, {
    schema = "host:score",
    id = timeseries_id.host,
    label = i18n("graphs.score"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.score'),
    timeseries = {
        score_as_cli = {
            label = i18n('graphs.cli_score'),
            color = timeseries_info.get_timeseries_color('cli_score')
        },
        score_as_srv = {
            label = i18n('graphs.srv_score'),
            color = timeseries_info.get_timeseries_color('srv_score')
        }
    }
}, {
    schema = "host:active_flows",
    id = timeseries_id.host,
    label = i18n("graphs.active_flows"),
    priority = 0,
    measure_unit = "fps",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        flows_as_client = {
            label = i18n('graphs.flows_as_client'),
            color = timeseries_info.get_timeseries_color('flows')
        },
        flows_as_server = {
            label = i18n('graphs.flows_as_server'),
            color = timeseries_info.get_timeseries_color('flows')
        }
    }
}, {
    schema = "host:total_flows",
    id = timeseries_id.host,
    label = i18n("graphs.total_flows"),
    priority = 0,
    measure_unit = "fps",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        flows_as_client = {
            label = i18n('graphs.flows_as_client'),
            color = timeseries_info.get_timeseries_color('flows')
        },
        flows_as_server = {
            label = i18n('graphs.flows_as_server'),
            color = timeseries_info.get_timeseries_color('flows')
        }
    }
}, {
    schema = "host:num_blacklisted_flows",
    id = timeseries_id.host,
    label = i18n("graphs.num_blacklisted_flows"),
    priority = 0,
    measure_unit = "fps",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        flows_as_client = {
            label = i18n('graphs.flows_as_client'),
            color = timeseries_info.get_timeseries_color('flows')
        },
        flows_as_server = {
            label = i18n('graphs.flows_as_server'),
            color = timeseries_info.get_timeseries_color('flows')
        }
    }
}, {
    schema = "host:alerted_flows",
    id = timeseries_id.host,
    label = i18n("graphs.total_alerted_flows"),
    priority = 0,
    measure_unit = "fps",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        flows_as_client = {
            label = i18n('graphs.flows_as_client'),
            color = timeseries_info.get_timeseries_color('flows')
        },
        flows_as_server = {
            label = i18n('graphs.flows_as_server'),
            color = timeseries_info.get_timeseries_color('flows')
        }
    }
}, {
    schema = "host:unreachable_flows",
    id = timeseries_id.host,
    label = i18n("graphs.total_unreachable_flows"),
    priority = 0,
    measure_unit = "fps",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        flows_as_client = {
            label = i18n('graphs.flows_as_client'),
            color = timeseries_info.get_timeseries_color('flows')
        },
        flows_as_server = {
            label = i18n('graphs.flows_as_server'),
            color = timeseries_info.get_timeseries_color('flows')
        }
    }
}, {
    schema = "host:host_unreachable_flows",
    id = timeseries_id.host,
    label = i18n("graphs.host_unreachable_flows"),
    priority = 0,
    measure_unit = "fps",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        flows_as_client = {
            label = i18n('graphs.flows_as_client'),
            color = timeseries_info.get_timeseries_color('flows')
        },
        flows_as_server = {
            label = i18n('graphs.flows_as_server'),
            color = timeseries_info.get_timeseries_color('flows')
        }
    }
}, {
    schema = "host:contacts",
    id = timeseries_id.host,
    label = i18n("graphs.active_host_contacts"),
    priority = 0,
    measure_unit = "fps",
    scale = i18n('graphs.metric_labels.contacts'),
    timeseries = {
        num_as_clients = {
            label = i18n('graphs.metric_labels.as_cli'),
            color = timeseries_info.get_timeseries_color('flows')
        },
        num_as_server = {
            label = i18n('graphs.metric_labels.as_srv'),
            color = timeseries_info.get_timeseries_color('flows')
        }
    }
}, {
    schema = "host:contacts_behaviour",
    id = timeseries_id.host,
    label = i18n("graphs.host_contacts_behaviour"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.contacts'),
    timeseries = {
        value = {
            label = i18n('graphs.score'),
            color = timeseries_info.get_timeseries_color('score')
        },
        lower_bound = {
            label = i18n('graphs.lower_bound'),
            draw_type = "line",
            color = timeseries_info.get_timeseries_color('score')
        },
        upper_bound = {
            label = i18n('graphs.upper_bound'),
            draw_type = "line",
            color = timeseries_info.get_timeseries_color('score')
        }
    },
    nedge_exclude = true
}, {
    schema = "host:total_alerts",
    id = timeseries_id.host,
    label = i18n("graphs.alerts"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.alerts'),
    timeseries = {
        alerts = {
            label = i18n('graphs.tcp_rst_packets'),
            color = timeseries_info.get_timeseries_color('packets')
        }
    }
}, {
    schema = "host:engaged_alerts",
    id = timeseries_id.host,
    label = i18n("graphs.engaged_alerts"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.alerts'),
    timeseries = {
        alerts = {
            label = i18n('graphs.tcp_rst_packets'),
            color = timeseries_info.get_timeseries_color('packets')
        }
    }
}, {
    schema = "host:dns_qry_sent_rsp_rcvd",
    id = timeseries_id.host,
    label = i18n("graphs.dns_qry_sent_rsp_rcvd"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.queries'),
    timeseries = {
        queries_pkts = {
            label = i18n('graphs.metric_labels.queries_pkts'),
            color = timeseries_info.get_timeseries_color('default')
        },
        replies_ok_pkts = {
            label = i18n('graphs.metric_labels.ok_pkts'),
            color = timeseries_info.get_timeseries_color('default')
        },
        replies_error_pkts = {
            label = i18n('graphs.metric_labels.error_pkts'),
            color = timeseries_info.get_timeseries_color('default')
        }
    }
}, {
    schema = "host:dns_qry_rcvd_rsp_sent",
    id = timeseries_id.host,
    label = i18n("graphs.dns_qry_rcvd_rsp_sent"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.queries'),
    timeseries = {
        queries_pkts = {
            label = i18n('graphs.metric_labels.queries_pkts'),
            color = timeseries_info.get_timeseries_color('default')
        },
        replies_ok_pkts = {
            label = i18n('graphs.metric_labels.ok_pkts'),
            color = timeseries_info.get_timeseries_color('default')
        },
        replies_error_pkts = {
            label = i18n('graphs.metric_labels.error_pkts'),
            color = timeseries_info.get_timeseries_color('default')
        }
    }
}, {
    schema = "host:tcp_rx_stats",
    id = timeseries_id.host,
    label = i18n("graphs.tcp_rx_stats"),
    priority = 0,
    measure_unit = "pps",
    scale = i18n('graphs.metric_labels.rcvd'),
    timeseries = {
        retran_pkts = {
            label = i18n('graphs.metric_labels.retra_pkts'),
            color = timeseries_info.get_timeseries_color('packets')
        },
        out_of_order_pkts = {
            label = i18n('graphs.metric_labels.ooo_pkts'),
            color = timeseries_info.get_timeseries_color('packets')
        },
        lost_packets = {
            label = i18n('graphs.metric_labels.lost_pkts'),
            color = timeseries_info.get_timeseries_color('packets')
        }
    }
}, {
    schema = "host:tcp_tx_stats",
    id = timeseries_id.host,
    label = i18n("graphs.tcp_tx_stats"),
    priority = 0,
    measure_unit = "pps",
    scale = i18n('graphs.metric_labels.sent'),
    timeseries = {
        retran_pkts = {
            label = i18n('graphs.metric_labels.retra_pkts'),
            color = timeseries_info.get_timeseries_color('packets')
        },
        out_of_order_pkts = {
            label = i18n('graphs.metric_labels.ooo_pkts'),
            color = timeseries_info.get_timeseries_color('packets')
        },
        lost_packets = {
            label = i18n('graphs.metric_labels.lost_pkts'),
            color = timeseries_info.get_timeseries_color('packets')
        }
    }
}, {
    schema = "host:udp_pkts",
    id = timeseries_id.host,
    label = i18n("graphs.udp_packets"),
    priority = 0,
    measure_unit = "pps",
    scale = i18n('graphs.metric_labels.packets'),
    timeseries = {
        packets_sent = {
            label = i18n('graphs.metric_labels.sent'),
            color = timeseries_info.get_timeseries_color('packets')
        },
        packets_rcvd = {
            label = i18n('graphs.metric_labels.rcvd'),
            color = timeseries_info.get_timeseries_color('packets')
        }
    }
}, {
    schema = "host:echo_reply_packets",
    id = timeseries_id.host,
    label = i18n("graphs.echo_reply_packets"),
    priority = 0,
    measure_unit = "pps",
    scale = i18n('graphs.metric_labels.packets'),
    timeseries = {
        packets_sent = {
            label = i18n('graphs.metric_labels.sent'),
            color = timeseries_info.get_timeseries_color('packets')
        },
        packets_rcvd = {
            label = i18n('graphs.metric_labels.rcvd'),
            color = timeseries_info.get_timeseries_color('packets')
        }
    }
}, {
    schema = "host:echo_packets",
    id = timeseries_id.host,
    label = i18n("graphs.echo_request_packets"),
    priority = 0,
    measure_unit = "pps",
    scale = i18n('graphs.metric_labels.packets'),
    timeseries = {
        packets_sent = {
            label = i18n('graphs.metric_labels.sent'),
            color = timeseries_info.get_timeseries_color('packets')
        },
        packets_rcvd = {
            label = i18n('graphs.metric_labels.rcvd'),
            color = timeseries_info.get_timeseries_color('packets')
        }
    }
}, {
    schema = "host:tcp_packets",
    id = timeseries_id.host,
    label = i18n("graphs.tcp_packets"),
    priority = 0,
    measure_unit = "pps",
    scale = i18n('graphs.metric_labels.packets'),
    timeseries = {
        packets_sent = {
            label = i18n('graphs.metric_labels.sent'),
            color = timeseries_info.get_timeseries_color('packets')
        },
        packets_rcvd = {
            label = i18n('graphs.metric_labels.rcvd'),
            color = timeseries_info.get_timeseries_color('packets')
        }
    }
}, {
    schema = "host:udp_sent_unicast",
    id = timeseries_id.host,
    label = i18n("graphs.udp_sent_unicast_vs_non_unicast"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n('graphs.metric_labels.bytes'),
    timeseries = {
        bytes_sent_unicast = {
            label = i18n('graphs.metric_labels.sent_uni'),
            color = timeseries_info.get_timeseries_color('bytes_sent')
        },
        bytes_sent_non_uni = {
            label = i18n('graphs.metric_labels.sent_non_uni'),
            color = timeseries_info.get_timeseries_color('bytes_sent')
        }
    }
}, {
    schema = "host:dscp",
    id = timeseries_id.host,
    label = i18n("graphs.dscp_classes"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n('graphs.metric_labels.bytes'),
    timeseries = {
        bytes_sent = {
            label = i18n('graphs.metric_labels.sent'),
            color = timeseries_info.get_timeseries_color('bytes_sent')
        },
        bytes_rcvd = {
            label = i18n('graphs.metric_labels.rcvd'),
            color = timeseries_info.get_timeseries_color('bytes_rcvd')
        }
    }
}, {
    schema = "host:host_tcp_unidirectional_flows",
    id = timeseries_id.host,
    label = i18n("graphs.unidirectional_tcp_flows"),
    priority = 0,
    measure_unit = "fps",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        flows_as_client = {
            label = i18n('graphs.flows_as_client'),
            color = timeseries_info.get_timeseries_color('flows')
        },
        flows_as_server = {
            label = i18n('graphs.flows_as_server'),
            color = timeseries_info.get_timeseries_color('flows')
        }
    }
}, -- mac_details.lua (MAC): --
    {
        schema = "mac:traffic",
        id = timeseries_id.mac,
        label = i18n("graphs.traffic_rxtx"),
        priority = 0,
        measure_unit = "bps",
        scale = i18n('graphs.metric_labels.traffic'),
        timeseries = {
            bytes_sent = {
                label = i18n('graphs.metric_labels.sent'),
                color = timeseries_info.get_timeseries_color('bytes_sent')
            },
            bytes_rcvd = {
                invert_direction = true,
                label = i18n('graphs.metric_labels.rcvd'),
                color = timeseries_info.get_timeseries_color('bytes_rcvd')
            }
        },
        always_visibile = true,
        default_visible = true
    }, -- network_details.lua (SUBNET): --
    {
        schema = "subnet:traffic",
        id = timeseries_id.network,
        label = i18n("graphs.traffic"),
        measure_unit = "bps",
        scale = i18n('graphs.metric_labels.traffic'),
        timeseries = {
            bytes_egress = {
                label = i18n('graphs.metrics_suffixes.egress'),
                color = timeseries_info.get_timeseries_color('bytes')
            },
            bytes_ingress = {
                label = i18n('graphs.metrics_suffixes.ingress'),
                color = timeseries_info.get_timeseries_color('bytes')
            },
            bytes_inner = {
                label = i18n('graphs.metrics_suffixes.inner'),
                color = timeseries_info.get_timeseries_color('bytes')
            }
        },
        always_visibile = true,
        default_visible = true
    }, {
    schema = "subnet:broadcast_traffic",
    id = timeseries_id.network,
    label = i18n("broadcast_traffic"),
    measure_unit = "bps",
    scale = i18n('graphs.metric_labels.traffic'),
    timeseries = {
        bytes_egress = {
            label = i18n('graphs.metrics_suffixes.egress'),
            color = timeseries_info.get_timeseries_color('bytes')
        },
        bytes_ingress = {
            label = i18n('graphs.metrics_suffixes.ingress'),
            color = timeseries_info.get_timeseries_color('bytes')
        },
        bytes_inner = {
            label = i18n('graphs.metrics_suffixes.inner'),
            color = timeseries_info.get_timeseries_color('bytes')
        }
    }
}, {
    schema = "subnet:engaged_alerts",
    id = timeseries_id.network,
    label = i18n("show_alerts.engaged_alerts"),
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.alerts'),
    timeseries = {
        alerts = {
            label = i18n('graphs.engaged_alerts')
        }
    }
}, {
    schema = "subnet:score",
    id = timeseries_id.network,
    label = i18n("score"),
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.score'),
    timeseries = {
        score = {
            label = i18n('score')
        },
        scoreAsClient = {
            label = i18n('score_as_client')
        },
        scoreAsServer = {
            label = i18n('score_as_server')
        }
    }
}, {
    schema = "subnet:tcp_retransmissions",
    id = timeseries_id.network,
    label = i18n("graphs.tcp_packets_retr"),
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.packets'),
    timeseries = {
        packets_ingress = {
            label = i18n('if_stats_overview.ingress_packets')
        },
        packets_egress = {
            label = i18n('if_stats_overview.egress_packets')
        },
        packets_inner = {
            label = 'Inner Packets'
        }
    }
}, {
    schema = "subnet:tcp_out_of_order",
    id = timeseries_id.network,
    label = i18n("graphs.tcp_packets_ooo"),
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.packets'),
    timeseries = {
        packets_ingress = {
            label = i18n('if_stats_overview.ingress_packets')
        },
        packets_egress = {
            label = i18n('if_stats_overview.egress_packets')
        },
        packets_inner = {
            label = 'Inner Packets'
        }
    }
}, {
    schema = "subnet:tcp_lost",
    id = timeseries_id.network,
    label = i18n("graphs.tcp_packets_lost"),
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.packets'),
    timeseries = {
        packets_ingress = {
            label = i18n('if_stats_overview.ingress_packets'),
            color = timeseries_info.get_timeseries_color('bytes')
        },
        packets_egress = {
            label = i18n('if_stats_overview.egress_packets'),
            color = timeseries_info.get_timeseries_color('bytes')
        },
        packets_inner = {
            label = 'Inner Packets',
            color = timeseries_info.get_timeseries_color('bytes')
        }
    }
}, {
    schema = "subnet:tcp_keep_alive",
    id = timeseries_id.network,
    label = i18n("graphs.tcp_packets_keep_alive"),
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.packets'),
    timeseries = {
        packets_ingress = {
            label = i18n('if_stats_overview.ingress_packets'),
            color = timeseries_info.get_timeseries_color('bytes')
        },
        packets_egress = {
            label = i18n('if_stats_overview.egress_packets'),
            color = timeseries_info.get_timeseries_color('bytes')
        },
        packets_inner = {
            label = 'Inner Packets',
            color = timeseries_info.get_timeseries_color('bytes')
        }
    }
}, {
    schema = "subnet:rtt",
    id = timeseries_id.network,
    label = i18n("graphs.rtt"),
    priority = 0,
    measure_unit = "ms",
    scale = i18n('graphs.metric_labels.rtt'),
    timeseries = {
        millis_rtt = {
            label = i18n('graphs.metric_labels.rtt'),
            color = timeseries_info.get_timeseries_color('default')
        }
    },
    nedge_exclude = true
}, -- as_details.lua (ASN): --
    {
        schema = "asn:traffic",
        id = timeseries_id.asn,
        label = i18n("graphs.traffic_rxtx"),
        priority = 0,
        measure_unit = "bps",
        scale = i18n('graphs.metric_labels.traffic'),
        timeseries = {
            bytes_sent = {
                label = i18n('graphs.metric_labels.sent'),
                color = timeseries_info.get_timeseries_color('bytes_sent')
            },
            bytes_rcvd = {
                invert_direction = true,
                label = i18n('graphs.metric_labels.rcvd'),
                color = timeseries_info.get_timeseries_color('bytes_rcvd')
            }
        },
        always_visibile = true,
        default_visible = true
    }, {
    schema = "asn:rtt",
    id = timeseries_id.asn,
    label = i18n("graphs.rtt"),
    priority = 0,
    measure_unit = "ms",
    scale = i18n('graphs.metric_labels.rtt'),
    timeseries = {
        millis_rtt = {
            label = i18n('graphs.metric_labels.rtt'),
            color = timeseries_info.get_timeseries_color('default')
        }
    },
    nedge_exclude = true
}, {
    schema = "asn:traffic_sent",
    id = timeseries_id.asn,
    label = i18n("graphs.traffic_sent"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n('graphs.metric_labels.sent'),
    timeseries = {
        bytes = {
            label = i18n('graphs.metric_labels.sent'),
            color = timeseries_info.get_timeseries_color('bytes_sent')
        }
    },
    nedge_exclude = true
}, {
    schema = "asn:traffic_rcvd",
    id = timeseries_id.asn,
    label = i18n("graphs.traffic_rcvd"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n('graphs.metric_labels.rcvd'),
    timeseries = {
        bytes = {
            label = i18n('graphs.metric_labels.rcvd'),
            color = timeseries_info.get_timeseries_color('bytes_rcvd')
        }
    },
    nedge_exclude = true
}, {
    schema = "asn:score",
    id = timeseries_id.asn,
    label = i18n("graphs.score"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.score'),
    timeseries = {
        score = {
            label = i18n('graphs.metric_labels.score'),
            color = timeseries_info.get_timeseries_color('score')
        },
        cli_score = {
            label = i18n('graphs.metric_labels.cli_score'),
            color = timeseries_info.get_timeseries_color('cli_score')
        },
        srv_score = {
            label = i18n('graphs.metric_labels.srv_score'),
            color = timeseries_info.get_timeseries_color('srv_score')
        }
    }
}, {
    schema = "asn:tcp_retransmissions",
    id = timeseries_id.asn,
    label = i18n("graphs.tcp_packets_retr"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.packets'),
    timeseries = {
        packets_sent = {
            label = i18n('graphs.metric_labels.sent'),
            color = timeseries_info.get_timeseries_color('packets')
        },
        packets_rcvd = {
            label = i18n('graphs.metric_labels.rcvd'),
            color = timeseries_info.get_timeseries_color('packets')
        }
    },
    nedge_exclude = true
}, {
    schema = "asn:tcp_keep_alive",
    id = timeseries_id.asn,
    label = i18n("graphs.tcp_packets_keep_alive"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.packets'),
    timeseries = {
        packets_sent = {
            label = i18n('graphs.metric_labels.sent'),
            color = timeseries_info.get_timeseries_color('packets')
        },
        packets_rcvd = {
            label = i18n('graphs.metric_labels.rcvd'),
            color = timeseries_info.get_timeseries_color('packets')
        }
    },
    nedge_exclude = true
}, {
    schema = "asn:tcp_out_of_order",
    id = timeseries_id.asn,
    label = i18n("graphs.tcp_packets_ooo"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.tcp_packets_ooo'),
    timeseries = {
        packets_sent = {
            label = i18n('graphs.metric_labels.sent'),
            color = timeseries_info.get_timeseries_color('packets')
        },
        packets_rcvd = {
            label = i18n('graphs.metric_labels.rcvd'),
            color = timeseries_info.get_timeseries_color('packets')
        }
    },
    nedge_exclude = true
}, {
    schema = "asn:tcp_lost",
    id = timeseries_id.asn,
    label = i18n("graphs.tcp_packets_lost"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.tcp_packets_lost'),
    timeseries = {
        packets_sent = {
            label = i18n('graphs.metric_labels.sent'),
            color = timeseries_info.get_timeseries_color('packets')
        },
        packets_rcvd = {
            label = i18n('graphs.metric_labels.rcvd'),
            color = timeseries_info.get_timeseries_color('packets')
        }
    },
    nedge_exclude = true
}, -- country_details.lua (Country): --
    {
        schema = "country:traffic",
        id = timeseries_id.country,
        label = i18n("graphs.traffic"),
        priority = 0,
        measure_unit = "bps",
        scale = i18n('graphs.metric_labels.traffic'),
        timeseries = {
            bytes_egress = {
                label = i18n('graphs.metrics_suffixes.egress'),
                color = timeseries_info.get_timeseries_color('bytes')
            },
            bytes_ingress = {
                label = i18n('graphs.metrics_suffixes.ingress'),
                color = timeseries_info.get_timeseries_color('bytes')
            },
            bytes_inner = {
                label = i18n('graphs.metrics_suffixes.inner'),
                color = timeseries_info.get_timeseries_color('bytes')
            }
        },
        always_visibile = true,
        default_visible = true
    }, {
    schema = "country:score",
    id = timeseries_id.country,
    label = i18n("score"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.score'),
    timeseries = {
        score = {
            label = i18n('score')
        },
        scoreAsClient = {
            label = i18n('score_as_client')
        },
        scoreAsServer = {
            label = i18n('score_as_server')
        }
    }
}, -- os_details.lua (Operating System): --
    {
        schema = "os:traffic",
        id = timeseries_id.os,
        label = i18n("graphs.traffic_rxtx"),
        priority = 0,
        measure_unit = "bps",
        scale = i18n('graphs.metric_labels.traffic'),
        timeseries = {
            bytes_egress = {
                label = i18n('graphs.metrics_suffixes.egress'),
                color = timeseries_info.get_timeseries_color('bytes_sent')
            },
            bytes_ingress = {
                label = i18n('graphs.metrics_suffixes.ingress'),
                color = timeseries_info.get_timeseries_color('bytes_rcvd')
            }
        },
        always_visibile = true,
        default_visible = true
    }, -- vlan_details.lua (VLAN): --
    {
        schema = "vlan:traffic",
        id = timeseries_id.vlan,
        label = i18n("graphs.traffic_rxtx"),
        priority = 0,
        measure_unit = "bps",
        scale = i18n('graphs.metric_labels.traffic'),
        timeseries = {
            bytes_sent = {
                label = i18n('graphs.metric_labels.sent'),
                color = timeseries_info.get_timeseries_color('bytes_sent')
            },
            bytes_rcvd = {
                invert_direction = true,
                label = i18n('graphs.metric_labels.rcvd'),
                color = timeseries_info.get_timeseries_color('bytes_rcvd')
            }
        },
        always_visibile = true,
        default_visible = true
    }, {
    schema = "vlan:score",
    id = timeseries_id.vlan,
    label = i18n("score"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.score'),
    timeseries = {
        score = {
            label = i18n('score')
        },
        scoreAsClient = {
            label = i18n('score_as_client')
        },
        scoreAsServer = {
            label = i18n('score_as_server')
        }
    }
}, -- pool_details.lua (Host Pool): --
    {
        schema = "host_pool:traffic",
        id = timeseries_id.host_pool,
        label = i18n("graphs.traffic_rxtx"),
        priority = 0,
        measure_unit = "bps",
        scale = i18n('graphs.metric_labels.traffic'),
        timeseries = {
            bytes_sent = {
                label = i18n('graphs.metric_labels.sent'),
                color = timeseries_info.get_timeseries_color('bytes_sent')
            },
            bytes_rcvd = {
                invert_direction = true,
                label = i18n('graphs.metric_labels.rcvd'),
                color = timeseries_info.get_timeseries_color('bytes_rcvd')
            }
        },
        always_visibile = true,
        default_visible = true
    }, {
    schema = "host_pool:blocked_flows",
    id = timeseries_id.host_pool,
    label = i18n("graphs.blocked_flows"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        num_flows = {
            label = i18n('graphs.metric_labels.num_flows'),
            color = timeseries_info.get_timeseries_color('default')
        }
    }
}, {
    schema = "host_pool:hosts",
    id = timeseries_id.host_pool,
    label = i18n("graphs.active_hosts"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.hosts'),
    timeseries = {
        num_hosts = {
            label = i18n('graphs.metric_labels.num_hosts'),
            color = timeseries_info.get_timeseries_color('default')
        }
    }
}, {
    schema = "host_pool:devices",
    id = timeseries_id.host_pool,
    label = i18n("graphs.active_devices"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.devices'),
    timeseries = {
        num_devices = {
            label = i18n('graphs.metric_labels.num_devices'),
            color = timeseries_info.get_timeseries_color('default')
        }
    }
}, -- pod_details.lua (Pod): --
    {
        schema = "pod:num_flows",
        id = timeseries_id.pod,
        label = i18n("graphs.active_flows"),
        priority = 0,
        measure_unit = "fps",
        scale = i18n('graphs.metric_labels.flows'),
        timeseries = {
            as_client = {
                label = i18n('graphs.flows_as_client'),
                color = timeseries_info.get_timeseries_color('flows')
            },
            as_server = {
                label = i18n('graphs.flows_as_server'),
                color = timeseries_info.get_timeseries_color('bytes_rcvd')
            }
        },
        always_visibile = true,
        default_visible = true
    }, {
    schema = "pod:num_containers",
    id = timeseries_id.pod,
    label = i18n("containers_stats.containers"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.contaniers'),
    timeseries = {
        num_containers = {
            label = i18n('graphs.metric_labels.num_containers'),
            color = timeseries_info.get_timeseries_color('default')
        }
    }
}, {
    schema = "pod:rtt",
    id = timeseries_id.pod,
    label = i18n("containers_stats.avg_rtt"),
    priority = 0,
    measure_unit = "ms",
    scale = i18n('graphs.metric_labels.rtt'),
    timeseries = {
        as_client = {
            label = i18n('graphs.rtt_as_client'),
            color = timeseries_info.get_timeseries_color('default')
        },
        as_server = {
            label = i18n('graphs.rtt_as_server'),
            color = timeseries_info.get_timeseries_color('default')
        }
    }
}, {
    schema = "pod:rtt_variance",
    id = timeseries_id.pod,
    label = i18n("containers_stats.avg_rtt_variance"),
    priority = 0,
    measure_unit = "ms",
    scale = i18n('graphs.metric_labels.rtt'),
    timeseries = {
        as_client = {
            label = i18n('graphs.variance_as_client'),
            color = timeseries_info.get_timeseries_color('default')
        },
        as_server = {
            label = i18n('graphs.variance_as_server'),
            color = timeseries_info.get_timeseries_color('default')
        }
    }
}, -- container_details.lua (Container): --
    {
        schema = "container:num_flows",
        id = timeseries_id.container,
        label = i18n("graphs.active_flows"),
        priority = 0,
        measure_unit = "fps",
        scale = i18n('graphs.metric_labels.flows'),
        timeseries = {
            as_client = {
                label = i18n('graphs.flows_as_client'),
                color = timeseries_info.get_timeseries_color('flows')
            },
            as_server = {
                label = i18n('graphs.flows_as_server'),
                color = timeseries_info.get_timeseries_color('bytes_rcvd')
            }
        },
        always_visibile = true,
        default_visible = true
    }, {
    schema = "container:rtt",
    id = timeseries_id.container,
    label = i18n("containers_stats.avg_rtt"),
    priority = 0,
    measure_unit = "ms",
    scale = i18n('graphs.metric_labels.rtt'),
    timeseries = {
        as_client = {
            label = i18n('graphs.rtt_as_client'),
            color = timeseries_info.get_timeseries_color('default')
        },
        as_server = {
            label = i18n('graphs.rtt_as_server'),
            color = timeseries_info.get_timeseries_color('default')
        }
    }
}, {
    schema = "container:rtt_variance",
    id = timeseries_id.container,
    label = i18n("containers_stats.avg_rtt_variance"),
    priority = 0,
    measure_unit = "ms",
    scale = i18n('graphs.metric_labels.rtt'),
    timeseries = {
        as_client = {
            label = i18n('graphs.variance_as_client'),
            color = timeseries_info.get_timeseries_color('default')
        },
        as_server = {
            label = i18n('graphs.variance_as_server'),
            color = timeseries_info.get_timeseries_color('default')
        }
    }
}, -- hash_table_details.lua (Hash Table): --
    {
        schema = "ht:state",
        id = timeseries_id.hash_state,
        label = i18n("about.cpu_load"),
        priority = 0,
        measure_unit = "number",
        chart_type = "bar",
        ts_query = "CountriesHash",
        scale = i18n('graphs.metric_labels.hash_entries'),
        timeseries = {
            num_idle = {
                label = i18n('graphs.metric_labels.num_idle'),
                color = timeseries_info.get_timeseries_color('default')
            },
            num_active = {
                label = i18n('graphs.metric_labels.num_active'),
                color = timeseries_info.get_timeseries_color('default')
            }
        },
        always_visibile = true,
        default_visible = true
    }, {
    schema = "ht:state",
    id = timeseries_id.hash_state,
    label = i18n("hash_table.HostHash"),
    priority = 0,
    measure_unit = "number",
    ts_query = "HostHash",
    scale = i18n('graphs.metric_labels.hash_entries'),
    timeseries = {
        num_idle = {
            label = i18n('graphs.metric_labels.num_idle'),
            color = timeseries_info.get_timeseries_color('default')
        },
        num_active = {
            label = i18n('graphs.metric_labels.num_active'),
            color = timeseries_info.get_timeseries_color('default')
        }
    },
    default_visible = true
}, {
    schema = "ht:state",
    id = timeseries_id.hash_state,
    label = i18n("hash_table.MacHash"),
    priority = 0,
    measure_unit = "number",
    ts_query = "MacHash",
    scale = i18n('graphs.metric_labels.hash_entries'),
    timeseries = {
        num_idle = {
            label = i18n('graphs.metric_labels.num_idle'),
            color = timeseries_info.get_timeseries_color('default')
        },
        num_active = {
            label = i18n('graphs.metric_labels.num_active'),
            color = timeseries_info.get_timeseries_color('default')
        }
    },
    default_visible = true
}, {
    schema = "ht:state",
    id = timeseries_id.hash_state,
    label = i18n("hash_table.FlowHash"),
    priority = 0,
    measure_unit = "number",
    ts_query = "FlowHash",
    scale = i18n('graphs.metric_labels.hash_entries'),
    timeseries = {
        num_idle = {
            label = i18n('graphs.metric_labels.num_idle'),
            color = timeseries_info.get_timeseries_color('default')
        },
        num_active = {
            label = i18n('graphs.metric_labels.num_active'),
            color = timeseries_info.get_timeseries_color('default')
        }
    },
    default_visible = true
}, {
    schema = "ht:state",
    id = timeseries_id.hash_state,
    label = i18n("hash_table.AutonomousSystemHash"),
    priority = 0,
    measure_unit = "number",
    ts_query = "AutonomousSystemHash",
    scale = i18n('graphs.metric_labels.hash_entries'),
    timeseries = {
        num_idle = {
            label = i18n('graphs.metric_labels.num_idle'),
            color = timeseries_info.get_timeseries_color('default')
        },
        num_active = {
            label = i18n('graphs.metric_labels.num_active'),
            color = timeseries_info.get_timeseries_color('default')
        }
    },
    default_visible = true
}, {
    schema = "ht:state",
    id = timeseries_id.hash_state,
    label = i18n("hash_table.ObservationPointHash"),
    priority = 0,
    measure_unit = "number",
    ts_query = "ObservationPointHash",
    scale = i18n('graphs.metric_labels.hash_entries'),
    timeseries = {
        num_idle = {
            label = i18n('graphs.metric_labels.num_idle'),
            color = timeseries_info.get_timeseries_color('default')
        },
        num_active = {
            label = i18n('graphs.metric_labels.num_active'),
            color = timeseries_info.get_timeseries_color('default')
        }
    },
    default_visible = true
}, {
    schema = "ht:state",
    id = timeseries_id.hash_state,
    label = i18n("hash_table.VlanHash"),
    priority = 0,
    measure_unit = "number",
    ts_query = "VlanHash",
    scale = i18n('graphs.metric_labels.hash_entries'),
    timeseries = {
        num_idle = {
            label = i18n('graphs.metric_labels.num_idle'),
            color = timeseries_info.get_timeseries_color('default')
        },
        num_active = {
            label = i18n('graphs.metric_labels.num_active'),
            color = timeseries_info.get_timeseries_color('default')
        }
    },
    default_visible = true
}, -- system_stats.lua (System Stats): --
    {
        schema = "system:cpu_states",
        id = timeseries_id.system,
        label = i18n("about.cpu_load"),
        priority = 0,
        measure_unit = "percentage",
        chart_type = "bar",
        scale = i18n('graphs.metric_labels.load'),
        timeseries = {
            iowait_pct = {
                label = i18n('about.iowait'),
                color = timeseries_info.get_timeseries_color('default')
            },
            idle_pct = {
                label = i18n('about.idle'),
                color = timeseries_info.get_timeseries_color('default'),
                hidden = true
            },
            active_pct = {
                label = i18n('about.active'),
                color = timeseries_info.get_timeseries_color('default')
            }
        },
        always_visibile = true,
        default_visible = true,
        draw_stacked = true
    }, {
    schema = "process:resident_memory",
    id = timeseries_id.system,
    label = i18n("graphs.process_memory"),
    priority = 0,
    measure_unit = "bytes",
    scale = i18n('graphs.metric_labels.bytes'),
    timeseries = {
        resident_bytes = {
            label = i18n('graphs.metric_labels.bytes'),
            color = timeseries_info.get_timeseries_color('bytes')
        }
    },
    always_visibile = true
}, {
    schema = "process:num_alerts",
    id = timeseries_id.system,
    label = i18n("graphs.process_alerts"),
    priority = 0,
    measure_unit = "alertps",
    scale = i18n('graphs.metric_labels.bytes'),
    timeseries = {
        written_alerts = {
            label = i18n('about.alerts_stored'),
            color = timeseries_info.get_timeseries_color('default')
        },
        alerts_queries = {
            label = i18n('about.alert_queries'),
            color = timeseries_info.get_timeseries_color('default')
        },
        dropped_alerts = {
            label = i18n('about.alerts_dropped'),
            color = timeseries_info.get_timeseries_color('default')
        }
    }
},
    -- { schema = "iface:engaged_alerts",          id = timeseries_id.system, label = i18n("graphs.engaged_alerts"),            priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.alerts'), timeseries = { engaged_alerts     = { label = i18n('graphs.engaged_alerts'),            color = timeseries_info.get_timeseries_color('alerts') }}},
    -- { schema = "iface:dropped_alerts",          id = timeseries_id.system, label = i18n("graphs.dropped_alerts"),            priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.alerts'), timeseries = { dropped_alerts     = { label = i18n('graphs.dropped_alerts'),            color = timeseries_info.get_timeseries_color('alerts') }}},

    -- profile_details.lua (Profile): --
    {
        schema = "profile:traffic",
        id = timeseries_id.profile,
        label = i18n("graphs.traffic"),
        priority = 0,
        measure_unit = "bps",
        scale = i18n('graphs.metric_labels.traffic'),
        timeseries = {
            bytes = {
                label = i18n('graphs.metric_labels.bytes'),
                color = timeseries_info.get_timeseries_color('bytes')
            }
        },
        always_visibile = true
    }, {
    schema = "redis:memory",
    id = timeseries_id.redis,
    label = i18n("about.ram_memory"),
    priority = 0,
    measure_unit = "bytes",
    scale = i18n('graphs.metric_labels.bytes'),
    timeseries = {
        resident_bytes = {
            label = i18n('graphs.metric_labels.bytes'),
            color = timeseries_info.get_timeseries_color('bytes')
        }
    },
    always_visibile = true
}, {
    schema = "redis:keys",
    id = timeseries_id.redis,
    label = i18n("system_stats.redis.redis_keys"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.keys'),
    timeseries = {
        num_keys = {
            label = i18n('graphs.metric_labels.keys'),
            color = timeseries_info.get_timeseries_color('default')
        }
    }
}, -- influxdb_monitor.lua (Influx DB): --
    {
        schema = "influxdb:storage_size",
        id = timeseries_id.influxdb,
        label = i18n("traffic_recording.storage_utilization"),
        priority = 0,
        measure_unit = "bytes",
        scale = i18n('graphs.metric_labels.bytes'),
        timeseries = {
            disk_bytes = {
                label = i18n('graphs.metric_labels.bytes'),
                color = timeseries_info.get_timeseries_color('bytes')
            }
        },
        always_visibile = true
    }, {
    schema = "influxdb:memory_size",
    id = timeseries_id.influxdb,
    label = i18n("about.ram_memory"),
    priority = 0,
    measure_unit = "bytes",
    scale = i18n('graphs.metric_labels.bytes'),
    timeseries = {
        mem_bytes = {
            label = i18n('graphs.metric_labels.bytes'),
            color = timeseries_info.get_timeseries_color('bytes')
        }
    }
}, {
    schema = "influxdb:write_successes",
    id = timeseries_id.influxdb,
    label = i18n("system_stats.write_througput"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.throughput'),
    timeseries = {
        points = {
            label = i18n('graphs.metric_labels.num_points'),
            color = timeseries_info.get_timeseries_color('default')
        }
    }
}, {
    schema = "influxdb:exports",
    id = timeseries_id.influxdb,
    label = i18n("system_stats.exports_label"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.exports'),
    timeseries = {
        num_exports = {
            label = i18n('system_stats.exports_label'),
            color = timeseries_info.get_timeseries_color('default')
        }
    }
}, {
    schema = "influxdb:exported_points",
    id = timeseries_id.influxdb,
    label = i18n("system_stats.exported_points"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.exports'),
    timeseries = {
        points = {
            label = i18n('graphs.metric_labels.num_points'),
            color = timeseries_info.get_timeseries_color('default')
        }
    }
}, {
    schema = "influxdb:dropped_points",
    id = timeseries_id.influxdb,
    label = i18n("system_stats.dropped_points"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.drops'),
    timeseries = {
        points = {
            label = i18n('graphs.metric_labels.num_points'),
            color = timeseries_info.get_timeseries_color('default')
        }
    }
}, {
    schema = "influxdb:rtt",
    id = timeseries_id.influxdb,
    label = i18n("graphs.num_ms_rtt"),
    priority = 0,
    measure_unit = "ms",
    scale = i18n('graphs.metric_labels.rtt'),
    timeseries = {
        millis_rtt = {
            label = i18n('graphs.num_ms_rtt'),
            color = timeseries_info.get_timeseries_color('default')
        }
    }
} }

-- #################################

local function add_active_monitoring_timeseries(tags, timeseries)
    local am_utils = require "am_utils"

    -- google.com,metric:cicmp
    local data = split(tags.host, ',')
    local metric = split(data[2], ':')[2]

    local host = am_utils.getHost(data[1], metric)
    local measurement_info = {}

    local label = i18n("graphs.num_ms_rtt")
    local measure_label = i18n("flow_details.round_trip_time")
    local measure_unit = 'ms'

    if host then
        measurement_info = am_utils.getMeasurementInfo(host.measurement) or {}
    end

    if measurement_info then
        label = i18n(measurement_info.i18n_am_ts_label) or measurement_info.i18n_am_ts_label
        measure_label = i18n(measurement_info.i18n_am_ts_metric) or measurement_info.i18n_am_ts_metric
        if (measurement_info.i18n_unit) and (measurement_info.i18n_unit == 'field_units.mbits') then
            measure_unit = 'bps'
        elseif (measurement_info.i18n_unit) and (measurement_info.i18n_unit == 'field_units.percentage') then
            measure_unit = 'percentage'
        end
    end

    if measurement_info.force_host then
        -- Special case of speedtest
        timeseries[#timeseries + 1] = {
            schema = "am_host:val_hour",
            id = timeseries_id.active_monitoring,
            label = label,
            priority = 0,
            measure_unit = measure_unit,
            scale = measure_label,
            timeseries = {
                value = {
                    label = measure_label,
                    color = timeseries_info.get_timeseries_color('default')
                }
            }
        }
    else
        timeseries[#timeseries + 1] = {
            schema = "am_host:val_min",
            id = timeseries_id.active_monitoring,
            label = label,
            priority = 0,
            measure_unit = measure_unit,
            scale = measure_label,
            timeseries = {
                value = {
                    label = measure_label,
                    color = timeseries_info.get_timeseries_color('default')
                }
            }
        }
    end

    if (measurement_info) and (table.len(measurement_info.additional_timeseries) > 0) then
        for _, ts_information in ipairs(measurement_info.additional_timeseries) do
            timeseries[#timeseries + 1] = {
                schema = ts_information.schema .. "_min",
                id = timeseries_id.active_monitoring,
                label = ts_information.label,
                priority = 0,
                measure_unit = "ms",
                scale = i18n('graphs.metric_labels.ms')
            }
            local am_schema_info = {}

            if ts_information.schema == 'am_host:jitter_stats' then
                am_schema_info = {
                    latency = {
                        label = i18n('flow_details.mean_rtt'),
                        color = timeseries_info.get_timeseries_color('default')
                    },
                    jitter = {
                        label = i18n('flow_details.rtt_jitter'),
                        color = timeseries_info.get_timeseries_color('default')
                    }
                }
            elseif ts_information.schema == 'am_host:cicmp_stats' then
                am_schema_info = {
                    min_rtt = {
                        label = i18n('graphs.min_rtt'),
                        color = timeseries_info.get_timeseries_color('default')
                    },
                    max_rtt = {
                        label = i18n('graphs.max_rtt'),
                        color = timeseries_info.get_timeseries_color('default')
                    }
                }
            elseif ts_information.schema == 'am_host:http_stats' then
                am_schema_info = {
                    lookup_ms = {
                        label = i18n('graphs.name_lookup'),
                        color = timeseries_info.get_timeseries_color('default')
                    },
                    other_ms = {
                        label = i18n('other'),
                        color = timeseries_info.get_timeseries_color('default')
                    }
                }
            elseif ts_information.schema == 'am_host:upload' then
                -- Speedtest specialcase
                am_schema_info = {
                    speed = {
                        label = i18n('active_monitoring_stats.upload_speed'),
                        color = timeseries_info.get_timeseries_color('bytes')
                    }
                }
                timeseries[#timeseries]['measure_unit'] = 'bps'
            elseif ts_information.schema == 'am_host:latency' then
                -- Speedtest specialcase
                am_schema_info = {
                    latency = {
                        label = ts_information.metrics_labels[1],
                        color = timeseries_info.get_timeseries_color('number')
                    }
                }
            end

            if measurement_info.force_host then
                -- Speedtest special case
                timeseries[#timeseries]['schema'] = ts_information.schema .. "_hour"
            end

            timeseries[#timeseries]['timeseries'] = am_schema_info
        end
    end

    return timeseries
end

-- #################################

local function add_top_blacklist_hits_timeseries(tags, timeseries)
    local series = ts_utils.listSeries("blacklist_v2:hits", table.clone(tags), tags.epoch_begin) or {}
    local tmp_tags = table.clone(tags)

    --    if table.empty(series) then
    --        return;
    --    end
    for _, serie in pairs(series or {}) do
        tmp_tags.blacklist_name = serie.blacklist_name
        timeseries[#timeseries + 1] = {
            schema = "blacklist_v2:hits",
            id = timeseries_id.blacklist,
            chart_type = "line",
            group = i18n("graphs.metric_labels.blacklist_num_hits"),
            priority = 0,
            query = "blacklist_name:" .. serie.blacklist_name,
            label = serie.blacklist_name:gsub("_", " "),
            measure_unit = "number",
            scale = i18n('graphs.metric_labels.blacklist_hits'),
            timeseries = {
                hits = {
                    use_serie_name = true,
                    label = i18n('graphs.metric_labels.blacklist_num_hits'),
                }
            }
        }
    end
    return timeseries
end

-- #################################

local function add_top_vlan_timeseries(tags, timeseries)
    local vlan_ts_enabled = ntop.getCache("ntopng.prefs.vlan_rrd_creation")

    -- Top l7 Protocols
    if vlan_ts_enabled then
        local series = ts_utils.listSeries("vlan:ndpi", table.clone(tags), tags.epoch_begin) or {}
        local tmp_tags = table.clone(tags)

        if not table.empty(series) then
            for _, serie in pairs(series or {}) do
                local tot = 0
                tmp_tags.protocol = serie.protocol
                local tot_serie = ts_utils.queryTotal("vlan:ndpi", tags.epoch_begin, tags.epoch_end, tmp_tags)
                -- Remove serie with no data
                for _, value in pairs(tot_serie or {}) do
                    tot = tot + tonumber(value)
                end

                if (tot > 0) then
                    timeseries[#timeseries + 1] = {
                        schema = "top:vlan:ndpi",
                        group = i18n("graphs.l7_proto"),
                        priority = 2,
                        query = "protocol:" .. serie.protocol,
                        label = serie.protocol,
                        measure_unit = "bps",
                        scale = i18n('graphs.metric_labels.traffic'),
                        timeseries = {
                            bytes_sent = {
                                label = serie.protocol .. " " .. i18n('graphs.metric_labels.sent'),
                                color = timeseries_info.get_timeseries_color('bytes')
                            },
                            bytes_rcvd = {
                                label = serie.protocol .. " " .. i18n('graphs.metric_labels.rcvd'),
                                color = timeseries_info.get_timeseries_color('bytes')
                            }
                        }
                    }
                end
            end
        end
    end

    return timeseries
end

-- #################################

local function add_top_host_pool_timeseries(tags, timeseries)
    local host_pool_ts_enabled = ntop.getCache("ntopng.prefs.host_pools_rrd_creation")

    -- Top l7 Protocols
    if host_pool_ts_enabled then
        local series = ts_utils.listSeries("host_pool:ndpi", table.clone(tags), tags.epoch_begin) or {}
        local tmp_tags = table.clone(tags)

        if not table.empty(series) then
            for _, serie in pairs(series or {}) do
                local tot = 0
                tmp_tags.protocol = serie.protocol
                local tot_serie = ts_utils.queryTotal("host_pool:ndpi", tags.epoch_begin, tags.epoch_end, tmp_tags)
                -- Remove serie with no data
                for _, value in pairs(tot_serie or {}) do
                    tot = tot + tonumber(value)
                end

                if (tot > 0) then
                    timeseries[#timeseries + 1] = {
                        schema = "top:host_pool:ndpi",
                        group = i18n("graphs.l7_proto"),
                        priority = 2,
                        query = "protocol:" .. serie.protocol,
                        label = serie.protocol,
                        measure_unit = "bps",
                        scale = i18n('graphs.metric_labels.traffic'),
                        timeseries = {
                            bytes_sent = {
                                label = serie.protocol .. " " .. i18n('graphs.metric_labels.sent'),
                                color = timeseries_info.get_timeseries_color('bytes')
                            },
                            bytes_rcvd = {
                                label = serie.protocol .. " " .. i18n('graphs.metric_labels.rcvd'),
                                color = timeseries_info.get_timeseries_color('bytes')
                            }
                        }
                    }
                end
            end
        end
    end

    return timeseries
end

-- #################################

local function add_top_asn_timeseries(tags, timeseries)
    local asn_ts_enabled = ntop.getCache("ntopng.prefs.asn_rrd_creation")

    -- Top l7 Protocols
    if asn_ts_enabled then
        local series = ts_utils.listSeries("asn:ndpi", table.clone(tags), tags.epoch_begin) or {}
        local tmp_tags = table.clone(tags)

        if not table.empty(series) then
            for _, serie in pairs(series or {}) do
                local tot = 0
                tmp_tags.protocol = serie.protocol
                local tot_serie = ts_utils.queryTotal("asn:ndpi", tags.epoch_begin, tags.epoch_end, tmp_tags)
                -- Remove serie with no data
                for _, value in pairs(tot_serie or {}) do
                    tot = tot + tonumber(value)
                end

                if (tot > 0) then
                    timeseries[#timeseries + 1] = {
                        schema = "top:asn:ndpi",
                        group = i18n("graphs.l7_proto"),
                        priority = 2,
                        query = "protocol:" .. serie.protocol,
                        label = serie.protocol,
                        measure_unit = "bps",
                        scale = i18n('graphs.metric_labels.traffic'),
                        timeseries = {
                            bytes_sent = {
                                label = serie.protocol .. " " .. i18n('graphs.metric_labels.sent'),
                                color = timeseries_info.get_timeseries_color('bytes')
                            },
                            bytes_rcvd = {
                                label = serie.protocol .. " " .. i18n('graphs.metric_labels.rcvd'),
                                color = timeseries_info.get_timeseries_color('bytes')
                            }
                        }
                    }
                end
            end
        end
    end

    return timeseries
end

-- #################################

local function add_top_mac_timeseries(tags, timeseries)
    local mac_ts_enabled = ntop.getCache("ntopng.prefs.l2_device_rrd_creation")
    local mac_top_ts_enabled = ntop.getCache("ntopng.prefs.l2_device_ndpi_timeseries_creation")

    -- Top l7 Categories
    if mac_ts_enabled and mac_top_ts_enabled then
        local series = ts_utils.listSeries("mac:ndpi_categories", table.clone(tags), tags.epoch_begin) or {}
        local tmp_tags = table.clone(tags)

        if not table.empty(series) then
            for _, serie in pairs(series or {}) do
                local category_name = getCategoryLabel(serie.category, interface.getnDPICategoryId(serie.category))
                local tot = 0
                tmp_tags.category = category_name
                local tot_serie = ts_utils.queryTotal("mac:ndpi_categories", tags.epoch_begin, tags.epoch_end, tmp_tags)
                -- Remove serie with no data
                for _, value in pairs(tot_serie or {}) do
                    tot = tot + tonumber(value)
                end

                if (tot > 0) then
                    timeseries[#timeseries + 1] = {
                        schema = "top:mac:ndpi_categories",
                        group = i18n("graphs.category"),
                        priority = 3,
                        query = "category:" .. category_name,
                        label = category_name,
                        measure_unit = "bps",
                        scale = i18n('graphs.metric_labels.traffic'),
                        timeseries = {
                            bytes = {
                                label = category_name,
                                color = timeseries_info.get_timeseries_color('bytes')
                            }
                        }
                    }
                end
            end
        end
    end

    return timeseries
end

-- #################################

local function add_top_network_timeseries(tags, timeseries)
    local network_top_ts_enabled = ntop.getPref("ntopng.prefs.intranet_traffic_rrd_creation")

    -- Top l7 Categories
    if network_top_ts_enabled and tags.subnet then
        network.select(tonumber(ntop.getLocalNetworkID(tags.subnet)))
        local net_stats = network.getNetworkStats() or {}
        if table.len(net_stats) > 0 then
            for second_subnet, _ in pairs(net_stats["intranet_traffic"]) do
                local label_1 = getFullLocalNetworkName(tags.subnet)
                local label_2 = getFullLocalNetworkName(second_subnet)

                timeseries[#timeseries + 1] = {
                    schema = "subnet:intranet_traffic_min",
                    priority = 3,
                    query = "subnet_2:" .. second_subnet,
                    label = i18n("graphs.intranet_traffic", {
                        net_1 = label_1,
                        net_2 = label_2
                    }),
                    measure_unit = "bps",
                    scale = i18n('graphs.metric_labels.traffic'),
                    timeseries = {
                        bytes_sent = {
                            label = i18n('graphs.metric_labels.sent'),
                            color = timeseries_info.get_timeseries_color('bytes')
                        },
                        bytes_rcvd = {
                            invert_direction = true,
                            label = i18n('graphs.metric_labels.rcvd'),
                            color = timeseries_info.get_timeseries_color('bytes')
                        }
                    }
                }
            end
        end
    end

    return timeseries
end

-- #################################

local function add_top_host_timeseries(tags, timeseries)
    local host_ts_creation = ntop.getPref("ntopng.prefs.hosts_ts_creation")
    local host_ts_enabled = ntop.getCache("ntopng.prefs.host_ndpi_timeseries_creation")
    local has_top_protocols = (host_ts_enabled == "both" or host_ts_enabled == "per_protocol") and
        (host_ts_creation == "full")
    local has_top_categories = (host_ts_enabled == "both" or host_ts_enabled == "per_category") and
        (host_ts_creation == "full")

    -- L4 Protocols
    if host_ts_creation == "full" then
        local series = ts_utils.listSeries("host:l4protos", table.clone(tags), tags.epoch_begin) or {}
        local tmp_tags = table.clone(tags)

        if not table.empty(series) then
            for _, serie in pairs(series or {}) do
                local tot = 0
                tmp_tags.l4proto = serie.l4proto
                local tot_serie = ts_utils.queryTotal("host:l4protos", tags.epoch_begin, tags.epoch_end, tmp_tags)
                -- Remove serie with no data
                for _, value in pairs(tot_serie or {}) do
                    tot = tot + tonumber(value)
                end

                if (tot > 0) then
                    timeseries[#timeseries + 1] = {
                        schema = "top:host:l4protos",
                        group = i18n("graphs.l4_proto"),
                        priority = 2,
                        query = "l4proto:" .. serie.l4proto,
                        label = i18n(serie.l4proto) or serie.l4proto,
                        measure_unit = "bps",
                        scale = i18n('graphs.metric_labels.traffic'),
                        timeseries = {
                            bytes_sent = {
                                label = serie.l4proto .. " " .. i18n('graphs.metric_labels.sent'),
                                color = timeseries_info.get_timeseries_color('bytes')
                            },
                            bytes_rcvd = {
                                label = serie.l4proto .. " " .. i18n('graphs.metric_labels.rcvd'),
                                color = timeseries_info.get_timeseries_color('bytes')
                            }
                        }
                    }
                end
            end
        end
    end

    -- Top l7 Protocols
    if has_top_protocols then
        local series = ts_utils.listSeries("host:ndpi", table.clone(tags), tags.epoch_begin) or {}
        local tmp_tags = table.clone(tags)

        if not table.empty(series) then
            for _, serie in pairs(series or {}) do
                local tot = 0
                tmp_tags.protocol = serie.protocol
                local tot_serie = ts_utils.queryTotal("host:ndpi", tags.epoch_begin, tags.epoch_end, tmp_tags)
                -- Remove serie with no data
                for _, value in pairs(tot_serie or {}) do
                    tot = tot + tonumber(value)
                end

                if (tot > 0) then
                    timeseries[#timeseries + 1] = {
                        schema = "top:host:ndpi",
                        group = i18n("graphs.l7_proto"),
                        priority = 2,
                        query = "protocol:" .. serie.protocol,
                        label = serie.protocol,
                        measure_unit = "bps",
                        scale = i18n('graphs.metric_labels.traffic'),
                        timeseries = {
                            bytes_sent = {
                                label = serie.protocol .. " " .. i18n('graphs.metric_labels.sent'),
                                color = timeseries_info.get_timeseries_color('bytes')
                            },
                            bytes_rcvd = {
                                label = serie.protocol .. " " .. i18n('graphs.metric_labels.rcvd'),
                                color = timeseries_info.get_timeseries_color('bytes')
                            }
                        }
                    }
                end
            end
        end
    end

    -- Top Categories
    if has_top_categories then
        local series = ts_utils.listSeries("host:ndpi_categories", table.clone(tags), tags.epoch_begin) or {}
        local tmp_tags = table.clone(tags)

        if not table.empty(series) then
            for _, serie in pairs(series or {}) do
                local category_name = getCategoryLabel(serie.category, interface.getnDPICategoryId(serie.category))
                local tot = 0
                tmp_tags.category = category_name
                local tot_serie =
                    ts_utils.queryTotal("host:ndpi_categories", tags.epoch_begin, tags.epoch_end, tmp_tags)
                -- Remove serie with no data
                for _, value in pairs(tot_serie or {}) do
                    tot = tot + tonumber(value)
                end

                if (tot > 0) then
                    timeseries[#timeseries + 1] = {
                        schema = "top:host:ndpi_categories",
                        group = i18n("graphs.category"),
                        priority = 3,
                        query = "category:" .. category_name,
                        label = category_name,
                        measure_unit = "bps",
                        scale = i18n('graphs.metric_labels.traffic'),
                        timeseries = {
                            bytes = {
                                label = category_name,
                                color = timeseries_info.get_timeseries_color('bytes')
                            }
                        }
                    }
                end
            end
        end
    end

    return timeseries
end

-- #################################

local function add_top_interface_timeseries(tags, timeseries)
    local interface_ts_enabled = ntop.getCache("ntopng.prefs.interface_ndpi_timeseries_creation")
    local has_top_protocols = interface_ts_enabled == "both" or interface_ts_enabled == "per_protocol" or
        interface_ts_enabled ~= "0"
    local has_top_categories = interface_ts_enabled == "both" or interface_ts_enabled == "per_category"

    -- Top Traffic Profiles
    if ntop.isPro() then
        local series = ts_utils.listSeries("profile:traffic", table.clone(tags), tags.epoch_begin) or {}
        local tmp_tags = table.clone(tags)

        if not table.empty(series) then
            for _, serie in pairs(series or {}) do
                local tot = 0
                tmp_tags.profile = serie.profile
                local tot_serie = ts_utils.queryTotal("profile:traffic", tags.epoch_begin, tags.epoch_end, tmp_tags)
                -- Remove serie with no data
                for _, value in pairs(tot_serie or {}) do
                    tot = tot + tonumber(value)
                end

                if (tot > 0) then
                    timeseries[#timeseries + 1] = {
                        schema = "top:profile:traffic",
                        group = i18n("graphs.top_profiles"),
                        priority = 2,
                        query = "profile:" .. serie.profile,
                        label = serie.profile,
                        measure_unit = "bps",
                        scale = i18n('graphs.metric_labels.traffic'),
                        timeseries = {
                            bytes = {
                                label = serie.profile,
                                color = timeseries_info.get_timeseries_color('bytes')
                            }
                        }
                    }
                end
            end
        end
    end

    -- L4 Protocols
    if interface_ts_enabled then
        local series = ts_utils.listSeries("iface:l4protos", table.clone(tags), tags.epoch_begin) or {}
        local tmp_tags = table.clone(tags)

        if not table.empty(series) then
            for _, serie in pairs(series or {}) do
                local tot = 0
                tmp_tags.l4proto = serie.l4proto
                local tot_serie = ts_utils.queryTotal("iface:l4protos", tags.epoch_begin, tags.epoch_end, tmp_tags)
                -- Remove serie with no data
                for _, value in pairs(tot_serie or {}) do
                    tot = tot + tonumber(value)
                end

                if (tot > 0) then
                    timeseries[#timeseries + 1] = {
                        schema = "top:iface:l4protos",
                        group = i18n("graphs.l4_proto"),
                        priority = 2,
                        query = "l4proto:" .. serie.l4proto,
                        label = i18n(serie.l4proto) or serie.l4proto,
                        measure_unit = "bps",
                        scale = i18n('graphs.metric_labels.traffic'),
                        timeseries = {
                            bytes = {
                                label = serie.l4proto,
                                color = timeseries_info.get_timeseries_color('bytes')
                            }
                        }
                    }
                end
            end
        end
    end

    -- Top l7 Protocols
    if has_top_protocols then
        local series = ts_utils.listSeries("iface:ndpi", table.clone(tags), tags.epoch_begin) or {}
        local tmp_tags = table.clone(tags)

        if not table.empty(series) then
            for _, serie in pairs(series or {}) do
                local tot = 0
                tmp_tags.protocol = serie.protocol
                local tot_serie = ts_utils.queryTotal("iface:ndpi", tags.epoch_begin, tags.epoch_end, tmp_tags)
                -- Remove serie with no data
                for _, value in pairs(tot_serie or {}) do
                    tot = tot + tonumber(value)
                end

                if (tot > 0) then
                    timeseries[#timeseries + 1] = {
                        schema = "top:iface:ndpi",
                        group = i18n("graphs.l7_proto"),
                        priority = 2,
                        query = "protocol:" .. serie.protocol,
                        label = serie.protocol,
                        measure_unit = "bps",
                        scale = i18n('graphs.metric_labels.traffic'),
                        timeseries = {
                            bytes = {
                                label = serie.protocol,
                                color = timeseries_info.get_timeseries_color('bytes')
                            }
                        }
                    }
                end
            end
        end
    end

    -- Top Categories
    if has_top_categories then
        local series = ts_utils.listSeries("iface:ndpi_categories", table.clone(tags), tags.epoch_begin) or {}
        local tmp_tags = table.clone(tags)

        if not table.empty(series) then
            for _, serie in pairs(series or {}) do
                local tot = 0
                tmp_tags.category = serie.category
                local tot_serie = ts_utils.queryTotal("iface:ndpi_categories", tags.epoch_begin, tags.epoch_end,
                    tmp_tags)
                -- Remove serie with no data
                for _, value in pairs(tot_serie or {}) do
                    tot = tot + tonumber(value)
                end

                if (tot > 0) then
                    local category_name = getCategoryLabel(serie.category, interface.getnDPICategoryId(serie.category))
                    timeseries[#timeseries + 1] = {
                        schema = "top:iface:ndpi_categories",
                        group = i18n("graphs.category"),
                        priority = 3,
                        query = "category:" .. category_name,
                        label = category_name,
                        measure_unit = "bps",
                        scale = i18n('graphs.metric_labels.traffic'),
                        timeseries = {
                            bytes = {
                                label = category_name,
                                color = timeseries_info.get_timeseries_color('bytes')
                            }
                        }
                    }
                end
            end
        end
    end

    return timeseries
end

-- #################################

local function add_top_obs_point_timeseries(tags, timeseries)
    local top_protocols_pref = ntop.getPref("ntopng.prefs.interface_ndpi_timeseries_creation")

    -- Top l7 Protocols
    if top_protocols_pref == 'both' or top_protocols_pref == 'per_protocol' then
        local series = ts_utils.listSeries("obs_point:ndpi", table.clone(tags), tags.epoch_begin) or {}
        local tmp_tags = table.clone(tags)

        if not table.empty(series) then
            for _, serie in pairs(series or {}) do
                local tot = 0
                tmp_tags.protocol = serie.protocol
                local tot_serie = ts_utils.queryTotal("obs_point:ndpi", tags.epoch_begin, tags.epoch_end, tmp_tags)
                -- Remove serie with no data
                for _, value in pairs(tot_serie or {}) do
                    tot = tot + tonumber(value)
                end

                if (tot > 0) then
                    timeseries[#timeseries + 1] = {
                        schema = "top:obs_point:ndpi",
                        group = i18n("graphs.l7_proto"),
                        priority = 2,
                        query = "protocol:" .. serie.protocol,
                        label = serie.protocol,
                        measure_unit = "bps",
                        scale = i18n("graphs.metric_labels.traffic"),
                        timeseries = {
                            bytes_sent = {
                                label = serie.protocol .. " " .. i18n('graphs.metric_labels.sent'),
                                color = timeseries_info.get_timeseries_color('bytes')
                            },
                            bytes_rcvd = {
                                label = serie.protocol .. " " .. i18n('graphs.metric_labels.rcvd'),
                                color = timeseries_info.get_timeseries_color('bytes')
                            }
                        }
                    }
                end
            end
        end
    end

    return timeseries
end

-- #################################

local function add_flowdev_interfaces_timeseries(tags, timeseries)
    require "lua_utils_gui"
    local ts_suffix = "" -- this is used just for influxdb
    local are_l7_ts_enabled = areExportersTimeseriesPerApplicationEnabled()
    if highExporterTimeseriesResolution() and ts_utils.getDriverName() == "influxdb" then
        ts_suffix = "_min"
    end

    if ntop.getPref("ntopng.prefs.snmp_devices_rrd_creation") == "1" then
        local tmp_tags = table.clone(tags)
        tmp_tags.ifid = getSystemInterfaceId()
        tmp_tags.port = nil
        tmp_tags.protocol = nil
        -- Add this unique serie if snmp timeseries are enabled
        timeseries[#timeseries + 1] = {
            schema = "top:snmp_if:traffic_min",
            id = timeseries_id.flow_dev,
            label = i18n("page_stats.top.top_traffic_snmp"),
            type = "top",
            draw_stacked = true,
            priority = 2,
            measure_unit = "bps",
            scale = i18n("graphs.metric_labels.traffic"),
            timeseries = {
                bytes = {
                    label = i18n('graphs.metric_labels.traffic'),
                    draw_type = "line",
                    color = timeseries_info.get_timeseries_color('bytes')
                }
            },
            always_visibile = true
        }
    end
    local series = ts_utils.listSeries("flowdev:ndpi" .. ts_suffix, table.clone(tags), tags.epoch_begin) or {}
    if not table.empty(series) and are_l7_ts_enabled then
        timeseries[#timeseries + 1] = {
            schema = "top:flowdev:ndpi" .. ts_suffix,
            chart_type = "line",
            id = timeseries_id.flow_dev,
            label = i18n("db_search.top_l7proto"),
            draw_stacked = true,
            priority = 2,
            type = "top",
            measure_unit = "bps",
            scale = i18n("graphs.metric_labels.traffic"),
            timeseries = {
                bytes = {
                    label = i18n('graphs.metric_labels.traffic'),
                    draw_type = "line",
                    color = timeseries_info.get_timeseries_color('bytes')
                }
            },
        }
        local tmp_tags = table.clone(tags)

        for _, serie in pairs(series or {}) do
            local tot = 0
            tmp_tags.protocol = serie.protocol
            local tot_serie = ts_utils.queryTotal("flowdev:ndpi" .. ts_suffix, tags.epoch_begin, tags.epoch_end, tmp_tags)
            -- Remove serie with no data
            for _, value in pairs(tot_serie or {}) do
                tot = tot + tonumber(value)
            end

            if (tot > 0) then
                timeseries[#timeseries + 1] = {
                    schema = "top:flowdev:ndpi" .. ts_suffix,
                    group = i18n("graphs.l7_proto"),
                    priority = 2,
                    query = "protocol:" .. serie.protocol,
                    label = serie.protocol,
                    measure_unit = "bps",
                    scale = i18n("graphs.metric_labels.traffic"),
                    timeseries = {
                        bytes_sent = {
                            label = serie.protocol .. " " .. i18n('graphs.metric_labels.sent'),
                            color = timeseries_info.get_timeseries_color('bytes_sent')
                        },
                        bytes_rcvd = {
                            invert_direction = true,
                            label = serie.protocol .. " " .. i18n('graphs.metric_labels.rcvd'),
                            color = timeseries_info.get_timeseries_color('bytes_rcvd')
                        }
                    }
                }
            end
        end
    end

    local ports_table = interface.getFlowDeviceInfoByIP(tags.device) or {}
    for _, ports in pairs(ports_table) do
        for port_idx, _ in pairs(ports) do
            local ifname = format_portidx_name(tags.device, port_idx, true, true)
            timeseries[#timeseries + 1] = {
                schema = "flowdev_port:traffic",
                group = i18n("graphs.interfaces"),
                priority = 2,
                query = "port:" .. port_idx,
                label = i18n('graphs.interface_label_traffic', {
                    if_name = ifname
                }),
                measure_unit = "bps",
                scale = i18n("graphs.metric_labels.traffic"),
                timeseries = {
                    bytes_sent = {
                        label = ifname .. " " .. i18n('graphs.metric_labels.sent'),
                        color = timeseries_info.get_timeseries_color('bytes_sent')
                    },
                    bytes_rcvd = {
                        invert_direction = true,
                        label = ifname .. " " .. i18n('graphs.metric_labels.rcvd'),
                        color = timeseries_info.get_timeseries_color('bytes_rcvd')
                    }
                }
            }
        end
    end

    return timeseries
end

-- #################################

local function add_snmp_interfaces_timeseries(tags, timeseries)
    local snmp_cached_dev = require "snmp_cached_dev"
    local snmp_utils = require "snmp_utils"

    local cached_device = snmp_cached_dev:get_interfaces(tags.device)

    local snmp_dev_ts = { {
        schema = "snmp_dev:cpu_states",
        id = timeseries_id.snmp_device,
        label = i18n("about.cpu_load"),
        priority = 0,
        measure_unit = "number",
        scale = i18n('graphs.metric_labels.load'),
        timeseries = {
            user_pct = {
                label = i18n("snmp.cpuUser"),
                color = timeseries_info.get_timeseries_color('default')
            },
            system_pct = {
                label = i18n("snmp.cpuSystem"),
                color = timeseries_info.get_timeseries_color('default')
            },
            idle_pct = {
                label = i18n("snmp.cpuIdle"),
                color = timeseries_info.get_timeseries_color('default')
            }
        }
    }, {
        schema = "snmp_dev:avail_memory",
        id = timeseries_id.snmp_device,
        label = i18n("snmp.memAvailReal"),
        priority = 0,
        measure_unit = "number",
        scale = i18n('graphs.metric_labels.memory'),
        timeseries = {
            avail_bytes = {
                label = i18n("snmp.memAvailReal"),
                color = timeseries_info.get_timeseries_color('default')
            }
        }
    }, {
        schema = "snmp_dev:swap_memory",
        id = timeseries_id.snmp_device,
        label = i18n("snmp.memTotalReal"),
        priority = 0,
        measure_unit = "number",
        scale = i18n('graphs.metric_labels.memory'),
        timeseries = {
            swap_bytes = {
                label = i18n("snmp.memTotalReal"),
                color = timeseries_info.get_timeseries_color('default')
            }
        }
    }, {
        schema = "snmp_dev:total_memory",
        id = timeseries_id.snmp_device,
        label = i18n("snmp.memTotalSwap"),
        priority = 0,
        measure_unit = "number",
        scale = i18n('graphs.metric_labels.memory'),
        timeseries = {
            total_bytes = {
                label = i18n("snmp.memTotalSwap"),
                color = timeseries_info.get_timeseries_color('default')
            }
        }
    } }

    for _, timeserie in pairs(snmp_dev_ts) do
        if table.len(ts_utils.listSeries(timeserie.schema, table.clone(tags), os.time() - 1800) or {}) > 0 then
            timeseries[#timeseries + 1] = timeserie
        end
    end

    if not table.empty(cached_device) and cached_device["interfaces"] then
        for interface_index, interface_info in pairs(cached_device["interfaces"] or {}) do
            local ifname = snmp_utils.get_snmp_interface_label(interface_info)
            timeseries[#timeseries + 1] = {
                schema = "snmp_if:traffic",
                group = i18n("graphs.interfaces"),
                priority = 2,
                query = "if_index:" .. interface_index,
                label = i18n('graphs.interface_label_traffic', {
                    if_name = ifname
                }),
                measure_unit = "bps",
                scale = i18n("graphs.metric_labels.traffic"),
                timeseries = {
                    bytes_sent = {
                        label = ifname .. " " .. i18n('graphs.metric_labels.sent'),
                        color = timeseries_info.get_timeseries_color('bytes_sent')
                    },
                    bytes_rcvd = {
                        invert_direction = true,
                        label = ifname .. " " .. i18n('graphs.metric_labels.rcvd'),
                        color = timeseries_info.get_timeseries_color('bytes_rcvd')
                    }
                }
            }
        end
    end

    return timeseries
end

-- #################################

local function choose_traffic_serie(tags, timeseries)
    local tot = 0
    local tot_serie = ts_utils.queryTotal("snmp_if:traffic_min", tags.epoch_begin, tags.epoch_end, tags)
    for _, value in pairs(tot_serie or {}) do
        tot = tot + tonumber(value)
    end

    if (tot > 0) then
        timeseries[#timeseries + 1] = {
            schema = "snmp_if:traffic_min",
            id = timeseries_id.snmp_interface,
            label = i18n("graphs.traffic_rxtx"),
            priority = 2,
            measure_unit = "bps",
            scale = i18n("graphs.metric_labels.traffic"),
            timeseries = {
                bytes_sent = {
                    label = i18n('graphs.metric_labels.out_bytes'),
                    color = timeseries_info.get_timeseries_color('bytes_sent')
                },
                bytes_rcvd = {
                    invert_direction = true,
                    label = i18n('graphs.metric_labels.in_bytes'),
                    color = timeseries_info.get_timeseries_color('bytes_rcvd')
                }
            },
            always_visibile = true,
            default_visible = true
        }
    else
        timeseries[#timeseries + 1] = {
            schema = "snmp_if:traffic",
            id = timeseries_id.snmp_interface,
            label = i18n("graphs.traffic_rxtx"),
            priority = 2,
            measure_unit = "bps",
            scale = i18n("graphs.metric_labels.traffic"),
            timeseries = {
                bytes_sent = {
                    label = i18n('graphs.metric_labels.out_bytes'),
                    color = timeseries_info.get_timeseries_color('bytes_sent')
                },
                bytes_rcvd = {
                    invert_direction = true,
                    label = i18n('graphs.metric_labels.in_bytes'),
                    color = timeseries_info.get_timeseries_color('bytes_rcvd')
                }
            },
            always_visibile = true,
            default_visible = true
        }
    end

    return timeseries
end

-- #################################

local function add_top_flow_port_timeseries(tags, timeseries)
    local tmp_tags = table.clone(tags)
    local ts_suffix = "" -- this is used just for influxdb
    local are_l7_ts_enabled = areExportersTimeseriesPerApplicationEnabled()
    local series = ts_utils.listSeries("flowdev_port:ndpi" .. ts_suffix, table.clone(tags), tags.epoch_begin) or {}
    
    if highExporterTimeseriesResolution() and ts_utils.getDriverName() == "influxdb" then
        ts_suffix = "_min"
    end

    if not table.empty(series) and are_l7_ts_enabled then
        timeseries[#timeseries + 1] = {
            schema = "top:flowdev_port:ndpi" .. ts_suffix,
            chart_type = "line",
            id = timeseries_id.snmp_device,
            label = i18n("db_search.top_l7proto"),
            draw_stacked = true,
            priority = 2,
            type = "top",
            measure_unit = "bps",
            scale = i18n("graphs.metric_labels.traffic"),
            timeseries = {
                bytes = {
                    label = i18n('graphs.metric_labels.traffic'),
                    draw_type = "line",
                    color = timeseries_info.get_timeseries_color('bytes')
                }
            },
        }

        for _, serie in pairs(series or {}) do
            local tot = 0
            tmp_tags.protocol = serie.protocol
            local tot_serie = ts_utils.queryTotal("flowdev_port:ndpi" .. ts_suffix, tags.epoch_begin, tags.epoch_end, tmp_tags)
            -- Remove serie with no data
            for _, value in pairs(tot_serie or {}) do
                tot = tot + tonumber(value)
            end

            if (tot > 0) then
                timeseries[#timeseries + 1] = {
                    schema = "top:flowdev_port:ndpi" .. ts_suffix,
                    group = i18n("graphs.l7_proto"),
                    priority = 2,
                    query = "protocol:" .. serie.protocol,
                    label = serie.protocol,
                    measure_unit = "bps",
                    scale = i18n("graphs.metric_labels.traffic"),
                    timeseries = {
                        bytes_sent = {
                            label = serie.protocol .. " " .. i18n('graphs.metric_labels.sent'),
                            color = timeseries_info.get_timeseries_color('bytes_sent')
                        },
                        bytes_rcvd = {
                            invert_direction = true,
                            label = serie.protocol .. " " .. i18n('graphs.metric_labels.rcvd'),
                            color = timeseries_info.get_timeseries_color('bytes_rcvd')
                        }
                    }
                }
            end
        end
    end

    if ntop.getPref("ntopng.prefs.snmp_devices_rrd_creation") == "1" then
        tmp_tags.if_index = tags.port
        tmp_tags.ifid = getSystemInterfaceId()
        tmp_tags.port = nil
        tmp_tags.protocol = nil
        local tot = 0
        local tot_serie = ts_utils.queryTotal("snmp_if:traffic_min", tags.epoch_begin, tags.epoch_end, tmp_tags)
        for _, value in pairs(tot_serie or {}) do
            tot = tot + tonumber(value)
        end

        if (tot > 0) then
            add_standard_traffic = false
            -- Add this unique serie if snmp timeseries are enabled
            timeseries[#timeseries + 1] = {
                schema = "snmp_if:traffic_min",
                id = timeseries_id.flow_port,
                label = i18n("graphs.traffic_rxtx_snmp_min"), -- i18n("graphs.traffic_rxtx")
                priority = 2,
                measure_unit = "bps",
                scale = i18n("graphs.metric_labels.traffic"),
                timeseries = {
                    bytes_sent = {
                        label = i18n('graphs.metric_labels.out_bytes'),
                        color = timeseries_info.get_timeseries_color('bytes_sent')
                    },
                    bytes_rcvd = {
                        invert_direction = true,
                        label = i18n('graphs.metric_labels.in_bytes'),
                        color = timeseries_info.get_timeseries_color('bytes_rcvd')
                    }
                },
                always_visibile = true,
                default_visible = true
            }
        end
    end

    return timeseries
end

-- #################################

local function add_top_timeseries(tags, prefix, timeseries)
    if prefix == 'iface' then
        -- Add the top interface timeseries
        timeseries = add_top_interface_timeseries(tags, timeseries)
    elseif prefix == 'host' then
        -- Add the top host timeseries
        timeseries = add_top_host_timeseries(tags, timeseries)
    elseif prefix == 'asn' then
        -- Add the top asn timeseries
        timeseries = add_top_asn_timeseries(tags, timeseries)
    elseif prefix == 'host_pool' then
        -- Add the top host pool timeseries
        timeseries = add_top_host_pool_timeseries(tags, timeseries)
    elseif prefix == 'vlan' then
        -- Add the top vlan timeseries
        timeseries = add_top_vlan_timeseries(tags, timeseries)
    elseif prefix == 'mac' then
        -- Add the top mac timeseries
        timeseries = add_top_mac_timeseries(tags, timeseries)
    elseif prefix == 'am' then
        -- Add the active monitoring timeseries
        timeseries = add_active_monitoring_timeseries(tags, timeseries)
    elseif prefix == 'subnet' then
        -- Add the active monitoring timeseries
        timeseries = add_top_network_timeseries(tags, timeseries)
    elseif prefix == timeseries_id.observation_point then
        -- Add top observation points timeseries
        timeseries = add_top_obs_point_timeseries(tags, timeseries)
    elseif prefix == timeseries_id.snmp_interface then
        timeseries = choose_traffic_serie(tags, timeseries)
    elseif prefix == timeseries_id.snmp_device then
        -- Add the interfaces timeseries
        timeseries = add_snmp_interfaces_timeseries(tags, timeseries)
    elseif prefix == timeseries_id.flow_dev then
        -- Add the interfaces timeseries
        timeseries = add_flowdev_interfaces_timeseries(tags, timeseries)
    elseif prefix == timeseries_id.flow_port then
        -- Add the top interface timeseries
        timeseries = add_top_flow_port_timeseries(tags, timeseries)
    elseif prefix == timeseries_id.blacklist then
        -- Add the top interface timeseries
        timeseries = add_top_blacklist_hits_timeseries(tags, timeseries)
    end
    if timeseries ~= nil then
    end
    return timeseries
end

-- #################################

function timeseries_info.retrieve_specific_timeseries(tags, prefix)
    local timeseries_list = community_timeseries
    local timeseries = {}

    if ntop.isPro() then
        package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
        local timeseries_info_ext = require "timeseries_info_ext"
        local pro_timeseries = timeseries_info_ext.retrieve_pro_timeseries(tags, prefix)

        timeseries_list = table.merge(community_timeseries, pro_timeseries)
    end

    for _, info in pairs(timeseries_list) do
        if (prefix ~= nil) then
            if info.id ~= prefix then
                goto skip
            end

            -- Remove from nEdge the timeseries only for ntopng
            if (info.nedge_exclude) and (ntop.isnEdge()) then
                goto skip
            end

            -- Remove from ntopng the timeseries only for nEdge
            if (info.nedge_only) and (not ntop.isnEdge()) then
                goto skip
            end

            timeseries[#timeseries + 1] = info
        end

        ::skip::
    end

    timeseries = add_top_timeseries(tags, prefix, timeseries)
    return timeseries
end

-- #################################

function timeseries_info.get_traffic_rules_schema(rule_type)
    if rule_type == "host" then
        local host_ts_enabled = ntop.getCache("ntopng.prefs.host_ndpi_timeseries_creation")
        local has_top_protocols = (host_ts_enabled == "both" or host_ts_enabled == "per_protocol")
        local has_top_categories = (host_ts_enabled == "both" or host_ts_enabled == "per_category")

        local metric_list = { {
            title = i18n('graphs.traffic_rxtx'),
            group = i18n('generic_data'),
            label = i18n('graphs.traffic_rxtx'),
            id = 'host:traffic' --[[ here the ID is the schema ]],
            show_volume = true
        }, {
            title = i18n('graphs.traffic_rcvd'),
            group = i18n('generic_data'),
            label = i18n('graphs.traffic_rcvd'),
            id = 'host:traffic-RX' --[[ here the ID is the schema ]],
            show_volume = true
        }, {
            title = i18n('graphs.traffic_sent'),
            group = i18n('generic_data'),
            label = i18n('graphs.traffic_sent'),
            id = 'host:traffic-TX' --[[ here the ID is the schema ]],
            show_volume = true
        }, {
            title = i18n('score'),
            group = i18n('generic_data'),
            label = i18n('score'),
            id = 'host:score' --[[ here the ID is the schema ]],
            show_volume = false
        } }

        if has_top_protocols then
            local application_list = interface.getnDPIProtocols()
            for application, _ in pairsByKeys(application_list or {}, asc) do
                metric_list[#metric_list + 1] = {
                    label = application,
                    group = i18n('applications_long'),
                    title = application,
                    id = 'top:host:ndpi',
                    extra_metric = 'protocol:' .. application --[[ here the schema is the ID ]],
                    show_volume = true
                }
            end
        end

        if has_top_categories then
            local category_list = interface.getnDPICategories()
            for category, _ in pairsByKeys(category_list or {}, asc) do
                metric_list[#metric_list + 1] = {
                    label = category,
                    group = i18n('categories'),
                    title = category,
                    id = 'top:host:ndpi_categories',
                    extra_metric = 'category:' .. category --[[ here the schema is the ID ]],
                    show_volume = true
                }
            end
        end

        return metric_list
    elseif rule_type == "interface" then
        local ifname_ts_enabled = ntop.getCache("ntopng.prefs.ifname_ndpi_timeseries_creation")
        local has_top_protocols = ifname_ts_enabled == "both" or ifname_ts_enabled == "per_protocol" or
            ifname_ts_enabled ~= "0"
        local has_top_categories = ifname_ts_enabled == "both" or ifname_ts_enabled == "per_category"

        local metric_list = { {
            title = i18n('graphs.traffic_rxtx'),
            group = i18n('generic_data'),
            label = i18n('graphs.traffic_rxtx'),
            id = 'iface:traffic_rxtx' --[[ here the ID is the schema ]],
            show_volume = true
        }, {
            title = i18n('graphs.traffic_rcvd'),
            group = i18n('generic_data'),
            label = i18n('graphs.traffic_rcvd'),
            id = 'iface:traffic_rxtx-rx' --[[ here the ID is the schema ]],
            show_volume = true
        }, {
            title = i18n('graphs.traffic_sent'),
            group = i18n('generic_data'),
            label = i18n('graphs.traffic_sent'),
            id = 'iface:traffic_rxtx-tx' --[[ here the ID is the schema ]],
            show_volume = true
        }, {
            title = i18n('score'),
            group = i18n('generic_data'),
            label = i18n('score'),
            id = 'iface:score' --[[ here the ID is the schema ]],
            show_volume = false
        } }

        if has_top_protocols then
            local application_list = interface.getnDPIProtocols()
            for application, _ in pairsByKeys(application_list or {}, asc) do
                metric_list[#metric_list + 1] = {
                    label = application,
                    group = i18n('applications_long'),
                    title = application,
                    id = 'top:iface:ndpi',
                    extra_metric = 'protocol:' .. application --[[ here the schema is the ID ]],
                    show_volume = true
                }
            end
        end

        if has_top_categories then
            local category_list = interface.getnDPICategories()
            for category, _ in pairsByKeys(category_list or {}, asc) do
                metric_list[#metric_list + 1] = {
                    label = category,
                    group = i18n('categories'),
                    title = category,
                    id = 'top:iface:ndpi_categories',
                    extra_metric = 'category:' .. category --[[ here the schema is the ID ]],
                    show_volume = true
                }
            end
        end

        return metric_list
    elseif rule_type == "exporter" then
        local metric_list = { {
            title = i18n('traffic'),
            group = i18n('generic_data'),
            label = i18n('traffic'),
            show_volume = true
        }, {
            title = i18n("graphs.usage"),
            group = i18n('generic_data'),
            label = i18n("graphs.usage"),
            id = 'flowdev_port:usage' --[[ here the ID is the schema ]],
            show_volume = false,
            type = 'flowdev_port'
        } }

        return metric_list
    elseif rule_type == "host_pool" then
        local metric_list = {}
        for _, item in ipairs(community_timeseries) do
            if (item.id == timeseries_id.host_pool) then
                metric_list[#metric_list + 1] = item
            end
        end

        metric_list[#metric_list + 1] = {

            title = i18n('graphs.traffic_rcvd'),
            -- group = i18n('generic_data'),
            measure_unit = "bps",
            label = i18n('graphs.traffic_rcvd'),
            id = 'host_pool:traffic-RX' --[[ here the ID is the schema ]],
            schema = 'host_pool:traffic-RX',
            show_volume = true

        }

        metric_list[#metric_list + 1] = {

            title = i18n('graphs.traffic_sent'),
            -- group = i18n('generic_data'),
            label = i18n('graphs.traffic_sent'),
            measure_unit = "bps",
            id = 'host_pool:traffic-TX' --[[ here the ID is the schema ]],
            schema = 'host_pool:traffic-TX',
            show_volume = true

        }

        return metric_list
    elseif rule_type == "CIDR" then
        local metric_list = {}
        for _, item in ipairs(community_timeseries) do
            if (item.schema == "subnet:traffic") then
                item.label = i18n("graphs.network_traffic.total")
            end
            if (item.schema == "subnet:broadcast_traffic") then
                item.label = i18n("graphs.network_broadcast_traffic.total")
            end
            if (item.id == timeseries_id.network) then
                metric_list[#metric_list + 1] = item
            end
        end

        metric_list[#metric_list + 1] = {

            title = i18n('graphs.network_traffic.ingress'),
            -- group = i18n('generic_data'),
            measure_unit = "bps",
            label = i18n('graphs.network_traffic.ingress'),
            id = 'subnet:traffic-ingress' --[[ here the ID is the schema ]],
            schema = 'subnet:traffic-ingress',
            show_volume = true

        }

        metric_list[#metric_list + 1] = {

            title = i18n('graphs.network_traffic.egress'),
            -- group = i18n('generic_data'),
            label = i18n('graphs.network_traffic.egress'),
            measure_unit = "bps",
            id = 'subnet:traffic-egress' --[[ here the ID is the schema ]],
            schema = 'subnet:traffic-egress',
            show_volume = true

        }

        metric_list[#metric_list + 1] = {

            title = i18n('graphs.network_traffic.inner'),
            -- group = i18n('generic_data'),
            label = i18n('graphs.network_traffic.inner'),
            measure_unit = "bps",
            id = 'subnet:traffic-inner' --[[ here the ID is the schema ]],
            schema = 'subnet:traffic-inner',
            show_volume = true
        }

        metric_list[#metric_list + 1] = {

            title = i18n('graphs.network_broadcast_traffic.ingress'),
            -- group = i18n('generic_data'),
            measure_unit = "bps",
            label = i18n('graphs.network_broadcast_traffic.ingress'),
            id = 'subnet:broadcast_traffic-ingress' --[[ here the ID is the schema ]],
            schema = 'subnet:broadcast_traffic-ingress',
            show_volume = true

        }

        metric_list[#metric_list + 1] = {

            title = i18n('graphs.network_broadcast_traffic.egress'),
            -- group = i18n('generic_data'),
            label = i18n('graphs.network_broadcast_traffic.egress'),
            measure_unit = "bps",
            id = 'subnet:broadcast_traffic-egress' --[[ here the ID is the schema ]],
            schema = 'subnet:broadcast_traffic-egress',
            show_volume = true

        }

        metric_list[#metric_list + 1] = {

            title = i18n('graphs.network_broadcast_traffic.inner'),
            -- group = i18n('generic_data'),
            label = i18n('graphs.network_broadcast_traffic.inner'),
            measure_unit = "bps",
            id = 'subnet:broadcast_traffic-inner' --[[ here the ID is the schema ]],
            schema = 'subnet:broadcast_traffic-inner',
            show_volume = true

        }
        return metric_list
    elseif rule_type == 'vlan' then
        local metric_list = {}
        for _, item in ipairs(community_timeseries) do
            if (item.id == timeseries_id.vlan) then
                if (item.schema == "vlan:score") then
                    item.show_volume = false
                else
                    item.show_volume = true
                end
                metric_list[#metric_list + 1] = item
            end
        end
        return metric_list
    elseif rule_type == 'profiles' then
        local metric_list = {}
        for _, item in ipairs(community_timeseries) do
            if (item.id == timeseries_id.profile) then
                metric_list[#metric_list + 1] = item
            end
        end
        return metric_list
    end
end

-- #################################

return timeseries_info
