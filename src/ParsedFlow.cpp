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
  additional_fields_json = NULL;
  additional_fields_tlv = NULL;
  http_url = http_site = NULL;
  dns_query = ssl_server_name = NULL;
  ja3c_hash = ja3s_hash = NULL;
  suricata_alert = NULL;
  suricata_alert_severity = 255;

  ssl_cipher = ssl_unsafe_cipher = http_ret_code = 0;
  dns_query_type = dns_ret_code = 0;
 
  bittorrent_hash = NULL;
  memset(&custom_app, 0, sizeof(custom_app));

  has_parsed_ebpf = false;
}

/* *************************************** */

ParsedFlow::ParsedFlow(const ParsedFlow &pf) : ParsedFlowCore(pf), ParsedeBPF(pf) {

  /* Currently we avoid additional fields in the copy constructor */
  additional_fields_json = NULL; 
  additional_fields_tlv = NULL; 

  if(pf.http_url)  http_url = strdup(pf.http_url); else http_url = NULL;
  if(pf.http_site) http_site = strdup(pf.http_site); else http_site = NULL;
  if(pf.dns_query) dns_query = strdup(pf.dns_query); else dns_query = NULL;
  if(pf.ssl_server_name) ssl_server_name = strdup(pf.ssl_server_name); else ssl_server_name = NULL;
  if(pf.bittorrent_hash) bittorrent_hash = strdup(pf.bittorrent_hash); else bittorrent_hash = NULL;
  if(pf.ja3c_hash) ja3c_hash = strdup(pf.ja3c_hash); else ja3c_hash = NULL;
  if(pf.ja3s_hash) ja3s_hash = strdup(pf.ja3s_hash); else ja3s_hash = NULL;
  if(pf.suricata_alert) suricata_alert = strdup(pf.suricata_alert); else suricata_alert = NULL;

  suricata_alert_severity = pf.suricata_alert_severity;

  ssl_cipher = pf.ssl_cipher;
  ssl_unsafe_cipher = pf.ssl_unsafe_cipher;
  http_ret_code = pf.http_ret_code;
  dns_query_type = pf.dns_query_type;
  dns_ret_code = pf.dns_ret_code;

  memcpy(&custom_app, &pf.custom_app, sizeof(custom_app));
  has_parsed_ebpf = pf.has_parsed_ebpf;
}

/* *************************************** */

ParsedFlow::~ParsedFlow() {
  if(additional_fields_json)
    json_object_put(additional_fields_json);

  if(additional_fields_tlv) {
    ndpi_term_serializer(additional_fields_tlv);
    free(additional_fields_tlv);
  }

  if(http_url)  free(http_url);
  if(http_site) free(http_site);
  if(dns_query) free(dns_query);
  if(ssl_server_name) free(ssl_server_name);
  if(bittorrent_hash) free(bittorrent_hash);
  if(ja3c_hash) free(ja3c_hash);
  if(ja3s_hash) free(ja3s_hash);
  if(suricata_alert) free(suricata_alert);
}

/* *************************************** */

void ParsedFlow::swap() {
  ParsedFlowCore::swap();
  ParsedeBPF::swap();
}
