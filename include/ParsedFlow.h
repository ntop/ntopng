/*
 *
 * (C) 2013-24 - ntop.org
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
  bool has_parsed_ebpf, is_swapped;
  json_object *additional_fields_json;
  ndpi_serializer *additional_fields_tlv;
  char *l7_info;
  char *http_url, *http_site, *http_user_agent, *dhcp_client_name, *sip_call_id;
  ndpi_http_method http_method;
  char *dns_query;
  char *end_reason;
  char *tls_server_name, *bittorrent_hash;
  char *ja4c_hash;
  char *flow_risk_info;
  char *external_alert;
  char *smtp_rcp_to, *smtp_mail_from;
  u_int32_t src_ip_addr_pre_nat, dst_ip_addr_pre_nat,
              src_ip_addr_post_nat, dst_ip_addr_post_nat;
  u_int8_t tls_unsafe_cipher, flow_verdict;
  u_int16_t tls_cipher;
  u_int16_t http_ret_code;
  u_int16_t dns_query_type, dns_ret_code;
  u_int32_t l7_error_code;
  u_int16_t src_port_pre_nat, dst_port_pre_nat,
            src_port_post_nat, dst_port_post_nat;
  custom_app_t custom_app;
  ndpi_confidence_t confidence;
  ndpi_risk ndpi_flow_risk_bitmap;
  char *ndpi_flow_risk_name;
  FlowSource flow_source;
  
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

  inline void setL7Info(const char *str)  { if(l7_info != NULL) free(l7_info); if(str) { l7_info = strdup(str); } else l7_info = NULL; }
  inline void setHTTPurl(const char *str) { if(http_url != NULL) free(http_url);  if(str) { http_url = strdup(str); } else http_url = NULL; }
  inline void setHTTPsite(const char *str) { if(http_site != NULL) free(http_site);  if(str) { http_site = strdup(str);} else http_site = NULL; }
  inline void setHTTPuserAgent(const char *str) { if(http_user_agent != NULL) free(http_user_agent);  if(str) { http_user_agent = strdup(str);} else http_user_agent = NULL; }
  inline void setHTTPMethod(ndpi_http_method m) { http_method = m; }
  inline void setDNSQuery(const char *str) { if(dns_query != NULL) free(dns_query);  if(str) { dns_query = strdup(str);} else dns_query = NULL; }
  inline void setTLSserverName(const char *str) { if(tls_server_name != NULL) free(tls_server_name);  if(str) { tls_server_name = strdup(str);} else tls_server_name = NULL; }
  inline void setBittorrentHash(const char *str) { if(bittorrent_hash != NULL) free(bittorrent_hash);  if(str) { bittorrent_hash = strdup(str);} else bittorrent_hash = NULL; }
  inline void setJA4cHash(const char *str) { if(ja4c_hash != NULL) free(ja4c_hash);  if(str) { ja4c_hash = strdup(str); } else ja4c_hash = NULL; }
  inline void setRiskInfo(const char *str) { if(flow_risk_info != NULL) free(flow_risk_info);  if(str) { flow_risk_info = strdup(str); } else flow_risk_info = NULL; }
  inline void setExternalAlert(const char *str) { if(external_alert != NULL) free(external_alert);  if(str) { external_alert = strdup(str);} else external_alert = NULL; }
  inline void setTLSUnsafeCipher(u_int8_t v) { tls_unsafe_cipher = v; }
  inline void setTLSCipher(u_int16_t v) { tls_cipher = v; }
  inline void setFlowVerdict(u_int8_t v) { flow_verdict = v; }
  inline void setHTTPRetCode(u_int16_t v) { http_ret_code = v; }
  inline void setDNSQueryType(u_int16_t v) { dns_query_type = v; }
  inline void setDNSRetCode(u_int16_t v) { dns_ret_code = v; }
  inline void setL7ErrorCode(u_int32_t v) { l7_error_code = v; }
  inline void setCustomApp(custom_app_t c) { custom_app = c; }
  inline void setConfidence(ndpi_confidence_t c) { confidence = c; }
  inline void setRisk(ndpi_risk r) { ndpi_flow_risk_bitmap = r; }
  inline void setFlowSource(FlowSource n) { flow_source = n; }
  inline void setEndReason(const char *str) { if(end_reason != NULL) free(end_reason);  if(str) { end_reason = strdup(str);} else end_reason = NULL; }
  inline void setSMTPRcptTo(const char *str) { if(smtp_rcp_to != NULL) free(smtp_rcp_to);  if(str) { smtp_rcp_to = strdup(str);} else smtp_rcp_to = NULL; }
  inline void setSMTPMailFrom(const char *str) { if(smtp_mail_from != NULL) free(smtp_mail_from);  if(str) { smtp_mail_from = strdup(str);} else smtp_mail_from = NULL; }
  inline void setRiskName(const char *str) { if(ndpi_flow_risk_name != NULL) free(ndpi_flow_risk_name); if (str) { ndpi_flow_risk_name = strdup(str);} else ndpi_flow_risk_name = NULL; }
  inline void setDHCPClientName(const char *str) { if(dhcp_client_name != NULL) free(dhcp_client_name);  if(str) { dhcp_client_name = strdup(str);} else dhcp_client_name = NULL; }
  inline void setSIPCallId(const char *str) { if(sip_call_id != NULL) free(sip_call_id);  if(str) { sip_call_id = strdup(str);} else sip_call_id = NULL; }
  inline void setPreNATSrcIp(u_int32_t v) { src_ip_addr_pre_nat = v; };
  inline void setPreNATDstIp(u_int32_t v) { dst_ip_addr_pre_nat = v; };
  inline void setPostNATSrcIp(u_int32_t v) { src_ip_addr_post_nat = v; };
  inline void setPostNATDstIp(u_int32_t v) { dst_ip_addr_post_nat = v; };
  inline void setPreNATSrcPort(u_int16_t v) { src_port_pre_nat = v; };
  inline void setPreNATDstPort(u_int16_t v) { dst_port_pre_nat = v; };
  inline void setPostNATSrcPort(u_int16_t v) { src_port_post_nat = v; };
  inline void setPostNATDstPort(u_int16_t v) { dst_port_post_nat = v; };
  /* ****** */
  inline char* getL7Info(bool setToNULL = false)  { char *r = l7_info; if(setToNULL) l7_info = NULL; return(r); }
  inline char* getHTTPurl(bool setToNULL = false) { char *r = http_url; if(setToNULL) http_url = NULL; return(r); }
  inline char* getHTTPsite(bool setToNULL = false) { char *r = http_site; if(setToNULL) http_site = NULL; return(r); }
  inline char* getHTTPuserAgent(bool setToNULL = false) { char *r = http_user_agent; if(setToNULL) http_user_agent = NULL; return(r); }
  inline ndpi_http_method getHTTPMethod() { return(http_method); }
  inline char* getDNSQuery(bool setToNULL = false) { char *r = dns_query; if(setToNULL) dns_query = NULL; return(r); }
  inline char* getTLSserverName(bool setToNULL = false) { char *r = tls_server_name; if(setToNULL) tls_server_name = NULL; return(r); }
  inline char* getBittorrentHash(bool setToNULL = false) { char *r = bittorrent_hash; if(setToNULL) bittorrent_hash = NULL; return(r); }
  inline char* getJA4cHash(bool setToNULL = false) { char *r = ja4c_hash; if(setToNULL) ja4c_hash = NULL; return(r); }
  inline char* getRiskInfo(bool setToNULL = false) { char *r = flow_risk_info; if(setToNULL) flow_risk_info  = NULL; return(r); }
  inline char* getExternalAlert(bool setToNULL = false) { char *r = external_alert; if(setToNULL) external_alert = NULL; return(r); }
  inline char* getEndReason(bool setToNull = false) { char *r = end_reason; if(setToNull) end_reason = NULL; return(r); }
  inline char* getSMTPRcptTo(bool setToNull = false) { char *r = smtp_rcp_to; if(setToNull) smtp_rcp_to = NULL; return(r); }
  inline char* getSMTPMailFrom(bool setToNull = false) { char *r = smtp_mail_from; if(setToNull) smtp_mail_from = NULL; return(r); }
  inline char* getDHCPClientName(bool setToNull = false) { char *r = dhcp_client_name; if(setToNull) dhcp_client_name = NULL; return(r); }
  inline char* getSIPCallId(bool setToNull = false) { char *r = sip_call_id; if(setToNull) sip_call_id = NULL; return(r); }
  inline u_int32_t getPreNATSrcIp() { return src_ip_addr_pre_nat; };
  inline u_int32_t getPreNATDstIp() { return dst_ip_addr_pre_nat; };
  inline u_int32_t getPostNATSrcIp() { return src_ip_addr_post_nat; };
  inline u_int32_t getPostNATDstIp() { return dst_ip_addr_post_nat; };
  inline u_int16_t getPreNATSrcPort() { return src_port_pre_nat; };
  inline u_int16_t getPreNATDstPort() { return dst_port_pre_nat; };
  inline u_int16_t getPostNATSrcPort() { return src_port_post_nat; };
  inline u_int16_t getPostNATDstPort() { return dst_port_post_nat; };
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
  inline char* getRiskName() { return(ndpi_flow_risk_name); }
  inline bool isSwapped() { return(is_swapped); }
  inline FlowSource getFlowSource() { return(flow_source); }

  void print();
};

#endif /* _PARSED_FLOW_H_ */
