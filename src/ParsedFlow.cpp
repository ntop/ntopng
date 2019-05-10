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

/* *************************************** */

ParsedFlow::ParsedFlow() : ParsedFlowCore() {
  memset(&ebpf, 0, sizeof(ebpf));
  additional_fields = NULL;
  http_url = http_site = NULL;
  dns_query = ssl_server_name = NULL;
  bittorrent_hash = NULL;
  memset(&custom_app, 0, sizeof(custom_app));
  additional_fields = json_object_new_object();
}

/* *************************************** */

ParsedFlow::~ParsedFlow() {
}

/* *************************************** */

void ParsedFlow::print() {
  char buf1[32], buf2[32];

  src_ip.print(buf1, sizeof(buf1));
  dst_ip.print(buf2, sizeof(buf2));

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "[src: %s][dst: %s][src_port: %u][dst_port: %u][event: %s]",
  // 			       src_ip.print(buf1, sizeof(buf1)),
  // 			       dst_ip.print(buf2, sizeof(buf2)),
  // 			       ntohs(get_cli_port()), ntohs(get_srv_port()),
  // 			       Utils::eBPFEvent2EventStr(ebpf.event_type));
 }
