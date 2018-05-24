--
-- (C) 2018 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

local ts_utils = require "ts_utils"
local ts_schemas = {}

-- TODO: remove rrd_fname after new paths migration
-- NOTE: when rrd_fname is empty, the last tag value is used as file name

-------------------------------------------------------
-- PROFILES SCHEMAS
-------------------------------------------------------

function ts_schemas.profile_traffic()
  local schema = ts_utils.schema:new("profile:traffic", {step=60, rrd_fname="bytes"})

  schema:addTag("ifid")
  schema:addTag("profile")
  schema:addMetric("bytes", ts_utils.metrics.counter)

  return schema
end

-------------------------------------------------------
-- L3 DEVICES SCHEMAS
-------------------------------------------------------

-- NOTE: always disabled?
function ts_schemas.mac_traffic()
  local schema = ts_utils.schema:new("mac:traffic", {step=300, rrd_fname="bytes"})

  schema:addTag("ifid")
  schema:addTag("mac")
  schema:addMetric("bytes_sent", ts_utils.metrics.counter)
  schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)

  return schema
end

-- NOTE: always disabled?
function ts_schemas.mac_ndpi_categories()
  local schema = ts_utils.schema:new("mac:ndpi_categories", {step=300})

  schema:addTag("ifid")
  schema:addTag("mac")
  schema:addTag("category")
  schema:addMetric("bytes", ts_utils.metrics.counter)

  return schema
end

-------------------------------------------------------
-- HOST POOLS SCHEMAS
-------------------------------------------------------

function ts_schemas.host_pool_traffic()
  local schema = ts_utils.schema:new("host_pool:traffic", {step=300, rrd_fname="bytes"})

  schema:addTag("ifid")
  schema:addTag("pool")
  schema:addMetric("bytes_sent", ts_utils.metrics.counter)
  schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)

  return schema
end

function ts_schemas.host_pool_blocked_flows()
  local schema = ts_utils.schema:new("host_pool:blocked_flows", {step=300, rrd_fname="blocked_flows"})

  schema:addTag("ifid")
  schema:addTag("pool")
  schema:addMetric("num_flows", ts_utils.metrics.counter)

  return schema
end

function ts_schemas.host_pool_ndpi()
  local schema = ts_utils.schema:new("host_pool:ndpi", {step=300})

  schema:addTag("ifid")
  schema:addTag("pool")
  schema:addTag("protocol")
  schema:addMetric("bytes_sent", ts_utils.metrics.counter)
  schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)

  return schema
end

-------------------------------------------------------
-- ASN SCHEMAS
-------------------------------------------------------

function ts_schemas.asn_traffic()
  local schema = ts_utils.schema:new("asn:traffic", {step=300, rrd_fname="bytes"})

  schema:addTag("ifid")
  schema:addTag("asn")
  schema:addMetric("bytes_sent", ts_utils.metrics.counter)
  schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)

  return schema
end

function ts_schemas.asn_ndpi()
  local schema = ts_utils.schema:new("asn:ndpi", {step=300})

  schema:addTag("ifid")
  schema:addTag("asn")
  schema:addTag("protocol")
  schema:addMetric("bytes_sent", ts_utils.metrics.counter)
  schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)

  return schema
end

function ts_schemas.asn_rtt()
  local schema = ts_utils.schema:new("asn:rtt", {step=300, rrd_fname="num_ms_rtt"})

  schema:addTag("ifid")
  schema:addTag("asn")
  schema:addMetric("millis_rtt", ts_utils.metrics.gauge)

  return schema
end

-------------------------------------------------------
-- COUNTRIES SCHEMAS
-------------------------------------------------------

function ts_schemas.country_traffic()
  local schema = ts_utils.schema:new("country:traffic", {step=300, rrd_fname="bytes"})

  schema:addTag("ifid")
  schema:addTag("country")
  schema:addMetric("bytes_ingress", ts_utils.metrics.counter)
  schema:addMetric("bytes_egress", ts_utils.metrics.counter)
  schema:addMetric("bytes_inner", ts_utils.metrics.counter)

  return schema
end

-------------------------------------------------------
-- VLAN SCHEMAS
-------------------------------------------------------

function ts_schemas.vlan_traffic()
  local schema = ts_utils.schema:new("vlan:traffic", {step=300, rrd_fname="bytes"})

  schema:addTag("ifid")
  schema:addTag("vlan")
  schema:addMetric("bytes_sent", ts_utils.metrics.counter)
  schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)

  return schema
end

function ts_schemas.vlan_ndpi()
  local schema = ts_utils.schema:new("vlan:ndpi", {step=300})

  schema:addTag("ifid")
  schema:addTag("vlan")
  schema:addTag("protocol")
  schema:addMetric("bytes_sent", ts_utils.metrics.counter)
  schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)

  return schema
end

-------------------------------------------------------
-- FLOW DEVICES SCHEMAS
-------------------------------------------------------

function ts_schemas.sflowdev_port_traffic()
  local schema = ts_utils.schema:new("sflowdev_port:traffic", {step=300, rrd_fname="bytes"})

  schema:addTag("ifid")
  schema:addTag("device")
  schema:addTag("port")
  schema:addMetric("bytes_sent", ts_utils.metrics.counter)
  schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)

  return schema
end

function ts_schemas.flowdev_port_traffic()
  local schema = ts_utils.schema:new("flowdev_port:traffic", {step=300, rrd_fname="bytes"})

  schema:addTag("ifid")
  schema:addTag("device")
  schema:addTag("port")
  schema:addMetric("bytes_sent", ts_utils.metrics.counter)
  schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)

  return schema
end


-------------------------------------------------------
-- SNMP SCHEMAS
-------------------------------------------------------

function ts_schemas.snmp_if_traffic()
  local schema = ts_utils.schema:new("snmp_if:traffic", {step=300, rrd_heartbeat=3000, rrd_fname="bytes"})

  schema:addTag("ifid")
  schema:addTag("device")
  schema:addTag("if_index")
  schema:addMetric("bytes_sent", ts_utils.metrics.counter)
  schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)

  return schema
end

-------------------------------------------------------
-- SUBNETS SCHEMAS
-------------------------------------------------------

function ts_schemas.subnet_traffic()
  local schema = ts_utils.schema:new("subnet:traffic", {step=60, rrd_fname="bytes"})

  schema:addTag("ifid")
  schema:addTag("subnet")
  schema:addMetric("bytes_ingress", ts_utils.metrics.counter)
  schema:addMetric("bytes_egress", ts_utils.metrics.counter)
  schema:addMetric("bytes_inner", ts_utils.metrics.counter)

  return schema
end

function ts_schemas.subnet_broadcast_traffic()
  local schema = ts_utils.schema:new("subnet:broadcast_traffic", {step=60, rrd_fname="broadcast_bytes"})

  schema:addTag("ifid")
  schema:addTag("subnet")
  schema:addMetric("bytes_ingress", ts_utils.metrics.counter)
  schema:addMetric("bytes_egress", ts_utils.metrics.counter)
  schema:addMetric("bytes_inner", ts_utils.metrics.counter)

  return schema
end

-------------------------------------------------------
-- HOSTS SCHEMAS
-------------------------------------------------------

function ts_schemas.host_traffic()
  local schema = ts_utils.schema:new("host:traffic", {step=300, rrd_fname="bytes"})

  schema:addTag("ifid")
  schema:addTag("host")
  schema:addMetric("bytes_sent", ts_utils.metrics.counter)
  schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)

  return schema
end

function ts_schemas.host_flows()
  local schema = ts_utils.schema:new("host:flows", {step=300, rrd_fname="num_flows"})

  schema:addTag("ifid")
  schema:addTag("host")
  schema:addMetric("num_flows", ts_utils.metrics.gauge)

  return schema
end

-- NOTE: not shown
function ts_schemas.host_l4protos()
  local schema = ts_utils.schema:new("host:l4protos", {step=300})

  schema:addTag("ifid")
  schema:addTag("host")
  schema:addTag("l4proto")
  schema:addMetric("bytes_sent", ts_utils.metrics.counter)
  schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)

  return schema
end

function ts_schemas.host_ndpi()
  local schema = ts_utils.schema:new("host:ndpi", {step=300})

  schema:addTag("ifid")
  schema:addTag("host")
  schema:addTag("protocol")
  schema:addMetric("bytes_sent", ts_utils.metrics.counter)
  schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)

  return schema
end

function ts_schemas.host_ndpi_categories()
  local schema = ts_utils.schema:new("host:ndpi_categories", {step=300})

  schema:addTag("ifid")
  schema:addTag("host")
  schema:addTag("category")
  schema:addMetric("bytes", ts_utils.metrics.counter)

  return schema
end

-------------------------------------------------------
-- INTERFACES SCHEMAS
-------------------------------------------------------

function ts_schemas.iface_traffic()
  local schema = ts_utils.schema:new("iface:traffic", {step=1, rrd_fname="bytes"})

  schema:addTag("ifid")
  schema:addMetric("bytes", ts_utils.metrics.counter)

  return schema
end

function ts_schemas.iface_packets()
  local schema = ts_utils.schema:new("iface:packets", {step=1, rrd_fname="packets"})

  schema:addTag("ifid")
  schema:addMetric("packets", ts_utils.metrics.counter)

  return schema
end

function ts_schemas.iface_zmq_recv_flows()
  local schema = ts_utils.schema:new("iface:zmq_recv_flows", {step=1, rrd_fname="num_zmq_rcvd_flows"})

  schema:addTag("ifid")
  schema:addMetric("num_flows", ts_utils.metrics.gauge)

  return schema
end

function ts_schemas.iface_drops()
  local schema = ts_utils.schema:new("iface:drops", {step=1, rrd_fname="drops"})

  schema:addTag("ifid")
  schema:addMetric("packets", ts_utils.metrics.counter)

  return schema
end

function ts_schemas.iface_ndpi()
  local schema = ts_utils.schema:new("iface:ndpi", {step=60})

  schema:addTag("ifid")
  schema:addTag("protocol")
  schema:addMetric("bytes", ts_utils.metrics.counter)

  return schema
end

function ts_schemas.iface_ndpi_categories()
  local schema = ts_utils.schema:new("iface:ndpi_categories", {step=60})

  schema:addTag("ifid")
  schema:addTag("category")
  schema:addMetric("bytes", ts_utils.metrics.counter)

  return schema
end

-- NOTE: not shown
function ts_schemas.iface_local2remote()
  local schema = ts_utils.schema:new("iface:local2remote", {step=60, rrd_fname="local2remote"})

  schema:addTag("ifid")
  schema:addMetric("bytes", ts_utils.metrics.counter)

  return schema
end

-- NOTE: not shown
function ts_schemas.iface_remote2local()
  local schema = ts_utils.schema:new("iface:remote2local", {step=60, rrd_fname="remote2local"})

  schema:addTag("ifid")
  schema:addMetric("bytes", ts_utils.metrics.counter)

  return
  schema
end

function ts_schemas.iface_hosts()
  local schema = ts_utils.schema:new("iface:hosts", {step=60, rrd_fname="num_hosts"})

  schema:addTag("ifid")
  schema:addMetric("num_hosts", ts_utils.metrics.gauge)

  return schema
end

function ts_schemas.iface_devices()
  local schema = ts_utils.schema:new("iface:devices", {step=60, rrd_fname="num_devices"})

  schema:addTag("ifid")
  schema:addMetric("num_devices", ts_utils.metrics.gauge)

  return schema
end

function ts_schemas.iface_flows()
  local schema = ts_utils.schema:new("iface:flows", {step=60, rrd_fname="num_flows"})

  schema:addTag("ifid")
  schema:addMetric("num_flows", ts_utils.metrics.gauge)

  return schema
end

function ts_schemas.iface_http_hosts()
  local schema = ts_utils.schema:new("iface:http_hosts", {step=60, rrd_fname="num_http_hosts"})

  schema:addTag("ifid")
  schema:addMetric("num_hosts", ts_utils.metrics.gauge)

  return schema
end

function ts_schemas.iface_tcp_retransmissions()
  local schema = ts_utils.schema:new("iface:tcp_retransmissions", {step=60, rrd_fname="tcp_retransmissions"})

  schema:addTag("ifid")
  schema:addMetric("packets", ts_utils.metrics.counter)

  return schema
end

function ts_schemas.iface_tcp_out_of_order()
  local schema = ts_utils.schema:new("iface:tcp_out_of_order", {step=60, rrd_fname="tcp_ooo"})

  schema:addTag("ifid")
  schema:addMetric("packets", ts_utils.metrics.counter)

  return schema
end

function ts_schemas.iface_tcp_lost()
  local schema = ts_utils.schema:new("iface:tcp_lost", {step=60, rrd_fname="tcp_lost"})

  schema:addTag("ifid")
  schema:addMetric("packets", ts_utils.metrics.counter)

  return schema
end

function ts_schemas.iface_tcp_syn()
  local schema = ts_utils.schema:new("iface:tcp_syn", {step=60, rrd_fname="tcp_syn"})

  schema:addTag("ifid")
  schema:addMetric("packets", ts_utils.metrics.counter)

  return schema
end

function ts_schemas.iface_tcp_synack()
  local schema = ts_utils.schema:new("iface:tcp_synack", {step=60, rrd_fname="tcp_synack"})

  schema:addTag("ifid")
  schema:addMetric("packets", ts_utils.metrics.counter)

  return schema
end

function ts_schemas.iface_tcp_finack()
  local schema = ts_utils.schema:new("iface:tcp_finack", {step=60, rrd_fname="tcp_finack"})

  schema:addTag("ifid")
  schema:addMetric("packets", ts_utils.metrics.counter)

  return schema
end

function ts_schemas.iface_tcp_rst()
  local schema = ts_utils.schema:new("iface:tcp_rst", {step=60, rrd_fname="tcp_rst"})

  schema:addTag("ifid")
  schema:addMetric("packets", ts_utils.metrics.counter)

  return schema
end

return ts_schemas
