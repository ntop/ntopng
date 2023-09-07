/*
 *
 * (C) 2013-23 - ntop.org
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
  char *l7_info;
  char *http_url, *http_site, *http_user_agent;
  ndpi_http_method http_method;
  char *dns_query;
  char *tls_server_name, *bittorrent_hash;
  char *ja3c_hash, *ja3s_hash, *flow_risk_info;
  char *external_alert;
  u_int8_t tls_unsafe_cipher, flow_verdict;
  u_int16_t tls_cipher;
  u_int16_t http_ret_code;
  u_int16_t dns_query_type, dns_ret_code;
  u_int32_t l7_error_code;
  custom_app_t custom_app;
  ndpi_confidence_t confidence;
  ndpi_risk ndpi_flow_risk_bitmap;

 public:
  ParsedFlow();
  
  ParsedFlow(const ParsedFlow &pf);

  inline void addAdditionalField(const char *key, json_object *field) {
    if (!additional_fields_json)
      additional_fields_json = json_object_new_object();
    if (additional_fields_json)
      json_object_object_add(additional_fields_json, key, field);
  }
  
  inline void addAdditionalField(ndpi_deserializer *deserializer) {
    if (!additional_fields_tlv) {
      additional_fields_tlv =
          (ndpi_serializer *)calloc(1, sizeof(ndpi_serializer));
      if (additional_fields_tlv)
        ndpi_init_serializer_ll(additional_fields_tlv,
                                ndpi_serialization_format_tlv, 64);
    }
    
    if (additional_fields_tlv)
      ndpi_deserialize_clone_item(deserializer, additional_fields_tlv);
  }
  
  inline json_object *getAdditionalFieldsJSON()    { return additional_fields_json; };
  inline ndpi_serializer *getAdditionalFieldsTLV() {
    ndpi_serializer *tlv = additional_fields_tlv;
    additional_fields_tlv = NULL;
    return tlv;
  };
  inline bool hasParsedeBPF() const    { return has_parsed_ebpf; };
  inline void setParsedeBPF()          { has_parsed_ebpf = true; };
  inline void setParsedProcessInfo()   { process_info_set = true; setParsedeBPF(); }  
  inline void setParsedContainerInfo() { container_info_set = true; setParsedeBPF(); }

  virtual ~ParsedFlow();

  void freeMemory();
  void swap();
  void fromLua(lua_State *L, int index);

  void setL7Info(const char *str)  { if(l7_info != NULL) free(l7_info); if(str) { l7_info = strdup(str); } else l7_info = NULL; }
  void setHTTPurl(const char *str) { if(http_url != NULL) free(http_url);  if(str) { http_url = strdup(str); } else http_url = NULL; }
  void setHTTPsite(const char *str) { if(http_site != NULL) free(http_site);  if(str) { http_site = strdup(str);} else http_site = NULL; }
  void setHTTPuserAgent(const char *str) { if(http_user_agent != NULL) free(http_user_agent);  if(str) { http_user_agent = strdup(str);} else http_user_agent = NULL; }
  void setHTTPMethod(ndpi_http_method m) { http_method = m; }
  void setDNSQuery(const char *str) { if(dns_query != NULL) free(dns_query);  if(str) { dns_query = strdup(str);} else dns_query = NULL; }
  void setTLSserverName(const char *str) { if(tls_server_name != NULL) free(tls_server_name);  if(str) { tls_server_name = strdup(str);} else tls_server_name = NULL; }
  void setBittorrentHash(const char *str) { if(bittorrent_hash != NULL) free(bittorrent_hash);  if(str) { bittorrent_hash = strdup(str);} else bittorrent_hash = NULL; }
  void setJA3cHash(const char *str) { if(ja3c_hash != NULL) free(ja3c_hash);  if(str) { ja3c_hash = strdup(str); } else ja3c_hash = NULL; }
  void setJA3sHash(const char *str) { if(ja3s_hash != NULL) free(ja3s_hash);  if(str) { ja3s_hash = strdup(str); } else ja3s_hash = NULL; }
  void setRiskInfo(const char *str) { if(flow_risk_info != NULL) free(flow_risk_info);  if(str) { flow_risk_info = strdup(str); } else flow_risk_info = NULL; }
  void setExternalAlert(const char *str) { if(external_alert != NULL) free(external_alert);  if(str) { external_alert = strdup(str);} else external_alert = NULL; }
  void setTLSUnsafeCipher(u_int8_t v) { tls_unsafe_cipher = v; }
  void setTLSCipher(u_int16_t v) { tls_cipher = v; }
  void setFlowVerdict(u_int8_t v) { flow_verdict = v; }
  void setHTTPRetCode(u_int16_t v) { http_ret_code = v; }
  void setDNSQueryType(u_int16_t v) { dns_query_type = v; }
  void setDNSRetCode(u_int16_t v) { dns_ret_code = v; }
  void setL7ErrorCode(u_int32_t v) { l7_error_code = v; }
  void setCustomApp(custom_app_t c) { custom_app = c; }
  void setConfidence(ndpi_confidence_t c) { confidence = c; }
  void setRisk(ndpi_risk r) { ndpi_flow_risk_bitmap = r; }

  /* ****** */
  inline char* getL7Info(bool setToNULL = false)  { char *r = l7_info; if(setToNULL) l7_info = NULL; return(r); }
  inline char* getHTTPurl(bool setToNULL = false) { char *r = http_url; if(setToNULL) http_url = NULL; return(r); }
  inline char* getHTTPsite(bool setToNULL = false) { char *r = http_site; if(setToNULL) http_site = NULL; return(r); }
  inline char* getHTTPuserAgent(bool setToNULL = false) { char *r = http_user_agent; if(setToNULL) http_user_agent = NULL; return(r); }
  inline ndpi_http_method getHTTPMethod() { return(http_method); }
  inline char* getDNSQuery(bool setToNULL = false) { char *r = dns_query; if(setToNULL) dns_query = NULL; return(r); }
  inline char* getTLSserverName(bool setToNULL = false) { char *r = tls_server_name; if(setToNULL) tls_server_name = NULL; return(r); }
  inline char* getBittorrentHash(bool setToNULL = false) { char *r = bittorrent_hash; if(setToNULL) bittorrent_hash = NULL; return(r); }
  inline char* getJA3cHash(bool setToNULL = false) { char *r = ja3c_hash; if(setToNULL) ja3c_hash = NULL; return(r); }
  inline char* getJA3sHash(bool setToNULL = false) { char *r = ja3s_hash; if(setToNULL) ja3s_hash = NULL; return(r); }
  inline char* getRiskInfo(bool setToNULL = false) { char *r = flow_risk_info; if(setToNULL) flow_risk_info  = NULL; return(r); }
  inline char* getExternalAlert(bool setToNULL = false) { char *r = external_alert; if(setToNULL) external_alert = NULL; return(r); }
  inline u_int8_t getTLSUnsafeCipher() { return(tls_unsafe_cipher); }
  inline u_int16_t getTLSCipher() { return(tls_cipher); }
  inline u_int8_t getFlowVerdict() { return(flow_verdict); }
  inline u_int16_t getHTTPRetCode() { return(http_ret_code); }
  inline u_int16_t getDNSQueryType() { return(dns_query_type); }
  inline u_int16_t getDNSRetCode() { return(dns_ret_code); }
  inline u_int32_t getL7ErrorCode() { return(l7_error_code); }
  inline custom_app_t getCustomApp() { return(custom_app ); }
  inline ndpi_confidence_t getConfidence() { return(confidence); }
  inline ndpi_risk getRisk() { return(ndpi_flow_risk_bitmap); }
};

#endif /* _PARSED_FLOW_H_ */
