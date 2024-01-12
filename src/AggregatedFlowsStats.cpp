/*
 *
 * (C) 2019-24 - ntop.org
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

AggregatedFlowsStats::AggregatedFlowsStats(const IpAddress* c, const IpAddress* s, u_int8_t _l4_proto,
					   u_int64_t bytes_sent, u_int64_t bytes_rcvd, u_int32_t score) {
  num_flows = tot_sent = tot_rcvd = tot_score =
  key = vlan_id = flow_device_ip = proto_key = 0;
  l4_proto = _l4_proto;
  proto_name = info_key = NULL;
  server = client = NULL;
  incFlowStats(c, s, bytes_sent, bytes_rcvd, score);
}

/* *************************************** */

AggregatedFlowsStats::~AggregatedFlowsStats() {
  if (proto_name) free(proto_name);
  if (info_key)   free(info_key);
  if (client)     delete client;
  if (server)     delete server;
}

/* *************************************** */

void AggregatedFlowsStats::incFlowStats(const IpAddress* _client,
					const IpAddress* _server,
					u_int64_t bytes_sent, u_int64_t bytes_rcvd,
					u_int32_t score) {
  char buf[128];

  if(_client)
    clients.insert(std::string(((IpAddress*)_client)->get_ip_hex(buf, sizeof(buf))));
  
  if(_server)
    servers.insert(std::string(((IpAddress*)_server)->get_ip_hex(buf, sizeof(buf))));  

  num_flows++, tot_sent += bytes_sent, tot_rcvd += bytes_rcvd, tot_score += score;
}

/* *************************************** */

void AggregatedFlowsStats::setFlowIPVLANDeviceIP(Flow *f) {
  setClient(f->get_cli_ip_addr(), f->get_cli_host());
  setServer(f->get_srv_ip_addr(), f->get_srv_host());
  setVlanId(f->get_vlan_id());
  setFlowDeviceIP(f->getFlowDeviceIP());
}
