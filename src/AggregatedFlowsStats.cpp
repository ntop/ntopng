/*
 *
 * (C) 2019-26 - ntop.org
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#include "ntop_includes.h"

/* *************************************** */

AggregatedFlowsStats::AggregatedFlowsStats(
    const IpAddress* c, const IpAddress* s, u_int8_t _l4_proto,
    u_int64_t bytes_sent, u_int64_t bytes_rcvd, u_int32_t score,
    Bitmap128 flow_alerts) {
  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);
  num_flows = tot_sent = tot_rcvd = tot_score = key = vlan_id = proto_key = 0;
  memset(&flow_device_ip, 0, sizeof(struct ndpi_in6_addr));
  l4_proto = _l4_proto;
  proto_name = info_key = NULL;
  server = client = host = NULL;
  alerts_status.reset();

  incFlowStats(c, s, bytes_sent, bytes_rcvd, score, flow_alerts);
}

/* *************************************** */

AggregatedFlowsStats::~AggregatedFlowsStats() {
  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[delete] %s", __FILE__);
  
  if (proto_name) free(proto_name);
  if (info_key) free(info_key);
  if (client) delete client;
  if (server) delete server;
  if (host)   delete host;
}

/* *************************************** */

/* Same identity of IpAddress::get_ip_hex(): IPv4 and IPv6 never collide, an
 * address without version is a single entry */
static AggregatedIpKey ipKey(const IpAddress* ip) {
  const struct ipAddress* a = ip->getIP();
  AggregatedIpKey k = {a->ipVersion, 0, 0};

  if (a->ipVersion == 4)
    k.lo = a->ipType.ipv4; /* The other bytes of the union are not set */
  else if (a->ipVersion == 6)
    k.hi = a->ipType.ipv6.u6_addr.u6_addr64[0],
    k.lo = a->ipType.ipv6.u6_addr.u6_addr64[1];
  else
    k.ip_version = 0;

  return (k);
}

/* *************************************** */

void AggregatedFlowsStats::incFlowStats(const IpAddress* _client,
                                        const IpAddress* _server,
                                        u_int64_t bytes_sent,
                                        u_int64_t bytes_rcvd, u_int32_t score,
                                        Bitmap128 flow_alerts) {
  if (_client) clients.insert(ipKey(_client));

  if (_server) servers.insert(ipKey(_server));

  num_flows++, tot_sent += bytes_sent, tot_rcvd += bytes_rcvd,
      tot_score += score;

  alerts_status.bitmapOr(flow_alerts);
}

/* *************************************** */

void AggregatedFlowsStats::setFlowIPVLANDeviceIP(Flow* f) {
  struct ndpi_in6_addr addr = f->getExporterIP();
  
  setClient(f->get_cli_ip_addr(), f->get_cli_host());
  setServer(f->get_srv_ip_addr(), f->get_srv_host());
  setVlanId(f->get_vlan_id());
  setFlowDeviceIP(&addr);
}
