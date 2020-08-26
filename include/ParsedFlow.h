/*
 *
 * (C) 2013-20 - ntop.org
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
  bool has_parsed_ebpf;
  json_object *additional_fields_json;
  ndpi_serializer *additional_fields_tlv;

 public:
  char *http_url, *http_site, *http_method;
  char *dns_query;
  char *tls_server_name, *bittorrent_hash;
  char *ja3c_hash, *ja3s_hash;
  char *external_alert;
  u_int8_t tls_unsafe_cipher;
  u_int16_t tls_cipher;
  u_int16_t http_ret_code;
  u_int16_t dns_query_type, dns_ret_code;
  custom_app_t custom_app;
  ndpi_risk ndpi_flow_risk_bitmap;
  
  ParsedFlow();
  ParsedFlow(const ParsedFlow &pf);
  inline void addAdditionalField(const char *key, json_object *field) {
    if (!additional_fields_json) additional_fields_json = json_object_new_object();
    if (additional_fields_json)  json_object_object_add(additional_fields_json, key, field);
  }
  inline void addAdditionalField(ndpi_deserializer *deserializer) {
    if (!additional_fields_tlv) {
      additional_fields_tlv = (ndpi_serializer *) calloc(1, sizeof(ndpi_serializer));
      if (additional_fields_tlv)
        ndpi_init_serializer_ll(additional_fields_tlv, 
          ndpi_serialization_format_tlv, 64);
    }
    if (additional_fields_tlv)
      ndpi_deserialize_clone_item(deserializer, additional_fields_tlv);
  }
  inline json_object *getAdditionalFieldsJSON() { return additional_fields_json; };
  inline ndpi_serializer *getAdditionalFieldsTLV() { 
    ndpi_serializer *tlv = additional_fields_tlv;
    additional_fields_tlv = NULL;
    return tlv; 
  };
  inline bool hasParsedeBPF() const { return has_parsed_ebpf; };
  inline void setParsedeBPF()       { has_parsed_ebpf = true; };
  virtual ~ParsedFlow();
  void swap();
  void fromLua(lua_State *L, int index);
};

#endif /* _PARSED_FLOW_H_ */
