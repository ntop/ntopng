/*
 *
 * (C) 2013-22 - ntop.org
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

#include "flow_alerts_includes.h"

ndpi_serializer* TCPPacketsIssuesAlert::getAlertJSON(ndpi_serializer* serializer) {
  Flow *f = getFlow();
  FlowTrafficStats* stats = f->getTrafficStats();
  u_int64_t retransmission = stats ? (stats->get_cli2srv_tcp_retr() + stats->get_srv2cli_tcp_retr()) : 0, 
            out_of_order = stats ? (stats->get_cli2srv_tcp_ooo() + stats->get_srv2cli_tcp_ooo()) : 0, 
            lost = stats ? (stats->get_cli2srv_tcp_lost() + stats->get_srv2cli_tcp_lost()) : 0;
  
  u_int8_t retransmission_pctg = (u_int8_t) retransmission * 100 / f->get_packets();
  u_int8_t out_of_order_pctg = (u_int8_t) out_of_order * 100 / f->get_packets();
  u_int8_t lost_pctg = (u_int8_t) lost * 100 / f->get_packets();

  if(serializer == NULL)
    return NULL;

  ndpi_serialize_string_uint64(serializer, "retransmission", retransmission_pctg);
  ndpi_serialize_string_uint64(serializer, "out_of_order", out_of_order_pctg);
  ndpi_serialize_string_uint64(serializer, "lost", lost_pctg);
  ndpi_serialize_string_uint64(serializer, "retransmission_threshold", this->retransmission);
  ndpi_serialize_string_uint64(serializer, "out_of_order_threshold", this->out_of_order);
  ndpi_serialize_string_uint64(serializer, "lost_threshold", this->lost);
  
  return serializer;
}

