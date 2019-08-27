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

#ifndef _PARSED_FLOW_H_
#define _PARSED_FLOW_H_

#include "ntop_includes.h"

class ParsedFlow : public ParsedFlowCore, public ParsedeBPF {
 private:
  bool parsed_flow_free_memory;
  bool has_parsed_ebpf;
  json_object *additional_fields;

 public:
  char *http_url, *http_site;
  char *dns_query;
  char *ssl_server_name, *bittorrent_hash;
  char *ja3c_hash, *ja3s_hash;
  char *suricata_alert;
  u_int16_t ssl_cipher;
  u_int8_t ssl_unsafe_cipher;
  u_int16_t http_ret_code;
  u_int16_t dns_query_type, dns_ret_code;
  custom_app_t custom_app;

  ParsedFlow();
  ParsedFlow(const ParsedFlow &pf);
  inline void addAdditionalField(const char *key, json_object *field) {
    if (!additional_fields) additional_fields = json_object_new_object();
    if (additional_fields)  json_object_object_add(additional_fields, key, field);
  }
  inline json_object* getAdditionalFields() { return additional_fields; };
  inline bool hasParsedeBPF() const { return has_parsed_ebpf; };
  inline void setParsedeBPF()       { has_parsed_ebpf = true; };
  virtual ~ParsedFlow();
  void swap();
};

#endif /* _PARSED_FLOW_H_ */
