/*
 *
 * (C) 2013-19 - ntop.org
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

#ifndef HAVE_NEDGE

/* **************************************************** */

ParserInterface::ParserInterface(const char *endpoint, const char *custom_interface_type) : NetworkInterface(endpoint, custom_interface_type) {

}

/* **************************************************** */

ParserInterface::~ParserInterface() {

}

/* **************************************************** */

void ParserInterface::resetParsedFlow(Parsed_Flow *parsed_flow) {
  parsed_flow->src_ip.reset(), parsed_flow->dst_ip.reset();
  memset(&parsed_flow->core, 0, sizeof(parsed_flow->core));
  memset(&parsed_flow->ebpf, 0, sizeof(parsed_flow->ebpf));
  parsed_flow->additional_fields = NULL;
  parsed_flow->http_url = parsed_flow->http_site = NULL;
  parsed_flow->dns_query = parsed_flow->ssl_server_name = NULL;
  parsed_flow->bittorrent_hash = NULL;
  memset(&parsed_flow->custom_app, 0, sizeof(parsed_flow->custom_app));

  parsed_flow->core.l7_proto = Flow::get_ndpi_unknown_protocol();
  parsed_flow->additional_fields = json_object_new_object();
  parsed_flow->core.pkt_sampling_rate = 1; /* 1:1 (no sampling) */
  parsed_flow->core.source_id = parsed_flow->core.vlan_id = 0;
}

#endif
