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

ParsedFlow::ParsedFlow() : ParsedFlowCore(), ParsedeBPF() {
  additional_fields = NULL;
  http_url = http_site = NULL;
  dns_query = ssl_server_name = NULL;
  
  bittorrent_hash = NULL;
  memset(&custom_app, 0, sizeof(custom_app));
  additional_fields = json_object_new_object();

  has_parsed_ebpf = false;
  parsed_flow_free_memory = false;
}

/* *************************************** */

ParsedFlow::ParsedFlow(const ParsedFlow &pf) : ParsedFlowCore(pf), ParsedeBPF(pf) {
  additional_fields = NULL; /* Currently we avoid additional fields in the copy constructor */

  if(pf.http_url)  http_url = strdup(pf.http_url); else http_url = NULL;
  if(pf.http_site) http_site = strdup(pf.http_site); else http_site = NULL;
  if(pf.dns_query) dns_query = strdup(pf.dns_query); else dns_query = NULL;
  if(pf.ssl_server_name) ssl_server_name = strdup(pf.ssl_server_name); else ssl_server_name = NULL;
  if(pf.bittorrent_hash) bittorrent_hash = strdup(pf.bittorrent_hash); else bittorrent_hash = NULL;

  memcpy(&custom_app, &pf.custom_app, sizeof(custom_app));
  has_parsed_ebpf = pf.has_parsed_ebpf;
  
  parsed_flow_free_memory = true;
}

/* *************************************** */

ParsedFlow::~ParsedFlow() {
  if(additional_fields)
    json_object_put(additional_fields);

  if(parsed_flow_free_memory) {
    if(http_url)  free(http_url);
    if(http_site) free(http_site);
    if(dns_query) free(dns_query);
    if(ssl_server_name) free(ssl_server_name);
    if(bittorrent_hash) free(bittorrent_hash);
  }
}

/* *************************************** */

void ParsedFlow::swap() {
  ParsedFlowCore::swap();
  ParsedeBPF::swap();
}
