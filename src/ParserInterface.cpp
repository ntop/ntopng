/*
 *
 * (C) 2013-16 - ntop.org
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

/* **************************************************** */

/* IMPORTANT: keep it in sync with flow_fields_description part of flow_utils.lua */
ParserInterface::ParserInterface(const char *endpoint) : NetworkInterface(endpoint) { 
  map = NULL, once = false;

  addMapping("IN_BYTES", 1);
  addMapping("IN_PKTS", 2);
  addMapping("PROTOCOL", 4);
  addMapping("PROTOCOL_MAP", 58500);
  addMapping("SRC_TOS", 5);
  addMapping("TCP_FLAGS", 6);
  addMapping("L4_SRC_PORT", 7);
  addMapping("L4_SRC_PORT_MAP", 58503);
  addMapping("IPV4_SRC_ADDR", 8);
  addMapping("IPV4_SRC_MASK", 9);
  addMapping("INPUT_SNMP", 10);
  addMapping("L4_DST_PORT", 11);
  addMapping("L4_DST_PORT_MAP", 58507);
  addMapping("L4_SRV_PORT", 58508);
  addMapping("L4_SRV_PORT_MAP", 58509);
  addMapping("IPV4_DST_ADDR", 12);
  addMapping("IPV4_DST_MASK", 13);
  addMapping("OUTPUT_SNMP", 14);
  addMapping("IPV4_NEXT_HOP", 15);
  addMapping("SRC_AS", 16);
  addMapping("DST_AS", 17);
  addMapping("LAST_SWITCHED", 21);
  addMapping("FIRST_SWITCHED", 22);
  addMapping("OUT_BYTES", 23);
  addMapping("OUT_PKTS", 24);
  addMapping("IPV6_SRC_ADDR", 27);
  addMapping("IPV6_DST_ADDR", 28);
  addMapping("IPV6_SRC_MASK", 29);
  addMapping("IPV6_DST_MASK", 30);
  addMapping("ICMP_TYPE", 32);
  addMapping("SAMPLING_INTERVAL", 34);
  addMapping("SAMPLING_ALGORITHM", 35);
  addMapping("FLOW_ACTIVE_TIMEOUT", 36);
  addMapping("FLOW_INACTIVE_TIMEOUT", 37);
  addMapping("ENGINE_TYPE", 38);
  addMapping("ENGINE_ID", 39);
  addMapping("TOTAL_BYTES_EXP", 40);
  addMapping("TOTAL_PKTS_EXP", 41);
  addMapping("TOTAL_FLOWS_EXP", 42);
  addMapping("MIN_TTL", 52);
  addMapping("MAX_TTL", 53);
  addMapping("DST_TOS", 55);
  addMapping("IN_SRC_MAC", 56);
  addMapping("SRC_VLAN", 58);
  addMapping("DST_VLAN", 59);
  addMapping("IP_PROTOCOL_VERSION", 60);
  addMapping("DIRECTION", 61);
  addMapping("IPV6_NEXT_HOP", 62);
  addMapping("MPLS_LABEL_1", 70);
  addMapping("MPLS_LABEL_2", 71);
  addMapping("MPLS_LABEL_3", 72);
  addMapping("MPLS_LABEL_4", 73);
  addMapping("MPLS_LABEL_5", 74);
  addMapping("MPLS_LABEL_6", 75);
  addMapping("MPLS_LABEL_7", 76);
  addMapping("MPLS_LABEL_8", 77);
  addMapping("MPLS_LABEL_9", 78);
  addMapping("MPLS_LABEL_10", 79);
  addMapping("OUT_DST_MAC", 80);
  addMapping("APPLICATION_ID", 95);
  addMapping("PACKET_SECTION_OFFSET", 102);
  addMapping("SAMPLED_PACKET_SIZE", 103);
  addMapping("SAMPLED_PACKET_ID", 104);
  addMapping("EXPORTER_IPV4_ADDRESS", 130);
  addMapping("EXPORTER_IPV6_ADDRESS", 131);
  addMapping("FLOW_ID", 148);
  addMapping("FLOW_START_SEC", 150);
  addMapping("FLOW_END_SEC", 151);
  addMapping("FLOW_START_MILLISECONDS", 152);
  addMapping("FLOW_END_MILLISECONDS", 153);
  addMapping("BIFLOW_DIRECTION", 239);
  addMapping("DOT1Q_SRC_VLAN", 243);
  addMapping("DOT1Q_DST_VLAN", 254);
  addMapping("OBSERVATION_POINT_TYPE", 277);
  addMapping("OBSERVATION_POINT_ID", 300);
  addMapping("SELECTOR_ID", 302);
  addMapping("IPFIX_SAMPLING_ALGORITHM", 304);
  addMapping("SAMPLING_SIZE", 309);
  addMapping("SAMPLING_POPULATION", 310);
  addMapping("FRAME_LENGTH", 312);
  addMapping("PACKETS_OBSERVED", 318);
  addMapping("PACKETS_SELECTED", 319);
  addMapping("SELECTOR_NAME", 335);
  addMapping("APPLICATION_NAME", 57899);
  addMapping("USER_NAME", 57900);
  addMapping("FRAGMENTS", 57552);
  addMapping("CLIENT_NW_LATENCY_MS", 57595);
  addMapping("SERVER_NW_LATENCY_MS", 57596);
  addMapping("APPL_LATENCY_MS", 57597);
  addMapping("CUMULATIVE_ICMP_TYPE", 57570);
  addMapping("SRC_IP_COUNTRY", 57573);
  addMapping("SRC_IP_CITY", 57574);
  addMapping("DST_IP_COUNTRY", 57575);
  addMapping("DST_IP_CITY", 57576);
  addMapping("FLOW_PROTO_PORT", 57577);
  addMapping("UPSTREAM_TUNNEL_ID", 57578);
  addMapping("LONGEST_FLOW_PKT", 57579);
  addMapping("SHORTEST_FLOW_PKT", 57580);
  addMapping("RETRANSMITTED_IN_BYTES", 57599);
  addMapping("RETRANSMITTED_IN_PKTS", 57581);
  addMapping("RETRANSMITTED_OUT_BYTES", 57600);
  addMapping("RETRANSMITTED_OUT_PKTS", 57582);
  addMapping("OOORDER_IN_PKTS", 57583);
  addMapping("OOORDER_OUT_PKTS", 57584);
  addMapping("UNTUNNELED_PROTOCOL", 57585);
  addMapping("UNTUNNELED_IPV4_SRC_ADDR", 57586);
  addMapping("UNTUNNELED_L4_SRC_PORT", 57587);
  addMapping("UNTUNNELED_IPV4_DST_ADDR", 57588);
  addMapping("UNTUNNELED_L4_DST_PORT", 57589);
  addMapping("L7_PROTO", 57590);
  addMapping("L7_PROTO_NAME", 57591);
  addMapping("DOWNSTREAM_TUNNEL_ID", 57592);
  addMapping("FLOW_USER_NAME", 57593);
  addMapping("FLOW_SERVER_NAME", 57594);
  addMapping("PLUGIN_NAME", 57598);
  addMapping("UNTUNNELED_IPV6_SRC_ADDR", 57868);
  addMapping("UNTUNNELED_IPV6_DST_ADDR", 57869);
  addMapping("SRC_IP_LONG", 57920);
  addMapping("SRC_IP_LAT", 57921);
  addMapping("DST_IP_LONG", 57922);
  addMapping("DST_IP_LAT", 57923);
  addMapping("IN_SRC_OSI_SAP", 57821);
  addMapping("OUT_DST_OSI_SAP", 57822);
  addMapping("DURATION_IN", 57863);
  addMapping("DURATION_OUT", 57864);
  addMapping("TCP_WIN_MIN_IN", 57887);
  addMapping("TCP_WIN_MAX_IN", 57888);
  addMapping("TCP_WIN_MSS_IN", 57889);
  addMapping("TCP_WIN_SCALE_IN", 57890);
  addMapping("TCP_WIN_MIN_OUT", 57891);
  addMapping("TCP_WIN_MAX_OUT", 57892);
  addMapping("TCP_WIN_MSS_OUT", 57893);
  addMapping("TCP_WIN_SCALE_OUT", 57894);
  addMapping("PAYLOAD_HASH", 57910);
  addMapping("SRC_AS_MAP", 57915);
  addMapping("DST_AS_MAP", 57916);
  addMapping("SRC_AS_PATH_1", 57762);
  addMapping("SRC_AS_PATH_2", 57763);
  addMapping("SRC_AS_PATH_3", 57764);
  addMapping("SRC_AS_PATH_4", 57765);
  addMapping("SRC_AS_PATH_5", 57766);
  addMapping("SRC_AS_PATH_6", 57767);
  addMapping("SRC_AS_PATH_7", 57768);
  addMapping("SRC_AS_PATH_8", 57769);
  addMapping("SRC_AS_PATH_9", 57770);
  addMapping("SRC_AS_PATH_10", 57771);
  addMapping("DST_AS_PATH_1", 57772);
  addMapping("DST_AS_PATH_2", 57773);
  addMapping("DST_AS_PATH_3", 57774);
  addMapping("DST_AS_PATH_4", 57775);
  addMapping("DST_AS_PATH_5", 57776);
  addMapping("DST_AS_PATH_6", 57777);
  addMapping("DST_AS_PATH_7", 57778);
  addMapping("DST_AS_PATH_8", 57779);
  addMapping("DST_AS_PATH_9", 57780);
  addMapping("DST_AS_PATH_10", 57781);
  addMapping("DHCP_CLIENT_MAC", 57825);
  addMapping("DHCP_CLIENT_IP", 57826);
  addMapping("DHCP_CLIENT_NAME", 57827);
  addMapping("DHCP_REMOTE_ID", 57895);
  addMapping("DHCP_SUBSCRIBER_ID", 57896);
  addMapping("DHCP_MESSAGE_TYPE", 57901);
  addMapping("DIAMETER_REQ_MSG_TYPE", 57871);
  addMapping("DIAMETER_RSP_MSG_TYPE", 57872);
  addMapping("DIAMETER_REQ_ORIGIN_HOST", 57873);
  addMapping("DIAMETER_RSP_ORIGIN_HOST", 57874);
  addMapping("DIAMETER_REQ_USER_NAME", 57875);
  addMapping("DIAMETER_RSP_RESULT_CODE", 57876);
  addMapping("DIAMETER_EXP_RES_VENDOR_ID", 57877);
  addMapping("DIAMETER_EXP_RES_RESULT_CODE", 57878);
  addMapping("DIAMETER_HOP_BY_HOP_ID", 57917);
  addMapping("DNS_QUERY", 57677);
  addMapping("DNS_QUERY_ID", 57678);
  addMapping("DNS_QUERY_TYPE", 57679);
  addMapping("DNS_RET_CODE", 57680);
  addMapping("DNS_TTL_ANSWER", 57824);
  addMapping("DNS_RESPONSE", 57870);
  addMapping("FTP_LOGIN", 57828);
  addMapping("FTP_PASSWORD", 57829);
  addMapping("FTP_COMMAND", 57830);
  addMapping("FTP_COMMAND_RET_CODE", 57831);
  addMapping("GTPV0_REQ_MSG_TYPE", 57793);
  addMapping("GTPV0_RSP_MSG_TYPE", 57794);
  addMapping("GTPV0_TID", 57795);
  addMapping("GTPV0_APN_NAME", 57798);
  addMapping("GTPV0_END_USER_IP", 57796);
  addMapping("GTPV0_END_USER_MSISDN", 57797);
  addMapping("GTPV0_RAI_MCC", 57799);
  addMapping("GTPV0_RAI_MNC", 57800);
  addMapping("GTPV0_RAI_CELL_LAC", 57801);
  addMapping("GTPV0_RAI_CELL_RAC", 57802);
  addMapping("GTPV0_RESPONSE_CAUSE", 57803);
  addMapping("GTPV1_REQ_MSG_TYPE", 57692);
  addMapping("GTPV1_RSP_MSG_TYPE", 57693);
  addMapping("GTPV1_C2S_TEID_DATA", 57694);
  addMapping("GTPV1_C2S_TEID_CTRL", 57695);
  addMapping("GTPV1_S2C_TEID_DATA", 57696);
  addMapping("GTPV1_S2C_TEID_CTRL", 57697);
  addMapping("GTPV1_END_USER_IP", 57698);
  addMapping("GTPV1_END_USER_IMSI", 57699);
  addMapping("GTPV1_END_USER_MSISDN", 57700);
  addMapping("GTPV1_END_USER_IMEI", 57701);
  addMapping("GTPV1_APN_NAME", 57702);
  addMapping("GTPV1_RAI_MCC", 57703);
  addMapping("GTPV1_RAI_MNC", 57704);
  addMapping("GTPV1_RAI_LAC", 57814);
  addMapping("GTPV1_RAI_RAC", 57815);
  addMapping("GTPV1_ULI_MCC", 57816);
  addMapping("GTPV1_ULI_MNC", 57817);
  addMapping("GTPV1_ULI_CELL_LAC", 57705);
  addMapping("GTPV1_ULI_CELL_CI", 57706);
  addMapping("GTPV1_ULI_SAC", 57707);
  addMapping("GTPV1_RESPONSE_CAUSE", 57804);
  addMapping("GTPV2_REQ_MSG_TYPE", 57742);
  addMapping("GTPV2_RSP_MSG_TYPE", 57743);
  addMapping("GTPV2_C2S_S1U_GTPU_TEID", 57744);
  addMapping("GTPV2_C2S_S1U_GTPU_IP", 57745);
  addMapping("GTPV2_S2C_S1U_GTPU_TEID", 57746);
  addMapping("GTPV2_S5_S8_GTPC_TEID", 57907);
  addMapping("GTPV2_S2C_S1U_GTPU_IP", 57747);
  addMapping("GTPV2_C2S_S5_S8_GTPU_TEID", 57911);
  addMapping("GTPV2_S2C_S5_S8_GTPU_TEID", 57912);
  addMapping("GTPV2_C2S_S5_S8_GTPU_IP", 57913);
  addMapping("GTPV2_S2C_S5_S8_GTPU_IP", 57914);
  addMapping("GTPV2_END_USER_IMSI", 57748);
  addMapping("GTPV2_END_USER_MSISDN", 57749);
  addMapping("GTPV2_APN_NAME", 57750);
  addMapping("GTPV2_ULI_MCC", 57751);
  addMapping("GTPV2_ULI_MNC", 57752);
  addMapping("GTPV2_ULI_CELL_TAC", 57753);
  addMapping("GTPV2_ULI_CELL_ID", 57754);
  addMapping("GTPV2_RESPONSE_CAUSE", 57805);
  addMapping("GTPV2_RAT_TYPE", 57755);
  addMapping("GTPV2_PDN_IP", 57756);
  addMapping("GTPV2_END_USER_IMEI", 57757);
  addMapping("HTTP_URL", 57652);
  addMapping("HTTP_METHOD", 57832);
  addMapping("HTTP_RET_CODE", 57653);
  addMapping("HTTP_REFERER", 57654);
  addMapping("HTTP_UA", 57655);
  addMapping("HTTP_MIME", 57656);
  addMapping("HTTP_HOST", 57659);
  addMapping("HTTP_FBOOK_CHAT", 57660);
  addMapping("HTTP_SITE", 57833);
  addMapping("IMAP_LOGIN", 57732);
  addMapping("MYSQL_SERVER_VERSION", 57667);
  addMapping("MYSQL_USERNAME", 57668);
  addMapping("MYSQL_DB", 57669);
  addMapping("MYSQL_QUERY", 57670);
  addMapping("MYSQL_RESPONSE", 57671);
  addMapping("MYSQL_APPL_LATENCY_USEC", 57792);
  addMapping("NETBIOS_QUERY_NAME", 57982);
  addMapping("NETBIOS_QUERY_TYPE", 57983);
  addMapping("NETBIOS_QUERY_RSP", 57983);
  addMapping("ORACLE_USERNAME", 57672);
  addMapping("ORACLE_QUERY", 57673);
  addMapping("ORACLE_RSP_CODE", 57674);
  addMapping("ORACLE_RSP_STRING", 57675);
  addMapping("ORACLE_QUERY_DURATION", 57676);
  addMapping("POP_USER", 57682);
  addMapping("SRC_PROC_PID", 57640);
  addMapping("SRC_PROC_NAME", 57641);
  addMapping("SRC_PROC_UID", 57897);
  addMapping("SRC_PROC_USER_NAME", 57844);
  addMapping("SRC_FATHER_PROC_PID", 57845);
  addMapping("SRC_FATHER_PROC_NAME", 57846);
  addMapping("SRC_PROC_ACTUAL_MEMORY", 57855);
  addMapping("SRC_PROC_PEAK_MEMORY", 57856);
  addMapping("SRC_PROC_AVERAGE_CPU_LOAD", 57857);
  addMapping("SRC_PROC_NUM_PAGE_FAULTS", 57858);
  addMapping("SRC_PROC_PCTG_IOWAIT", 57865);
  addMapping("DST_PROC_PID", 57847);
  addMapping("DST_PROC_NAME", 57848);
  addMapping("DST_PROC_UID", 57898);
  addMapping("DST_PROC_USER_NAME", 57849);
  addMapping("DST_FATHER_PROC_PID", 57850);
  addMapping("DST_FATHER_PROC_NAME", 57851);
  addMapping("DST_PROC_ACTUAL_MEMORY", 57859);
  addMapping("DST_PROC_PEAK_MEMORY", 57860);
  addMapping("DST_PROC_AVERAGE_CPU_LOAD", 57861);
  addMapping("DST_PROC_NUM_PAGE_FAULTS", 57862);
  addMapping("DST_PROC_PCTG_IOWAIT", 57866);
  addMapping("RADIUS_REQ_MSG_TYPE", 57712);
  addMapping("RADIUS_RSP_MSG_TYPE", 57713);
  addMapping("RADIUS_USER_NAME", 57714);
  addMapping("RADIUS_CALLING_STATION_ID", 57715);
  addMapping("RADIUS_CALLED_STATION_ID", 57716);
  addMapping("RADIUS_NAS_IP_ADDR", 57717);
  addMapping("RADIUS_NAS_IDENTIFIER", 57718);
  addMapping("RADIUS_USER_IMSI", 57719);
  addMapping("RADIUS_USER_IMEI", 57720);
  addMapping("RADIUS_FRAMED_IP_ADDR", 57721);
  addMapping("RADIUS_ACCT_SESSION_ID", 57722);
  addMapping("RADIUS_ACCT_STATUS_TYPE", 57723);
  addMapping("RADIUS_ACCT_IN_OCTETS", 57724);
  addMapping("RADIUS_ACCT_OUT_OCTETS", 57725);
  addMapping("RADIUS_ACCT_IN_PKTS", 57726);
  addMapping("RADIUS_ACCT_OUT_PKTS", 57727);
  addMapping("RTP_SSRC", 57909);
  addMapping("RTP_FIRST_SEQ", 57622);
  addMapping("RTP_FIRST_TS", 57623);
  addMapping("RTP_LAST_SEQ", 57624);
  addMapping("RTP_LAST_TS", 57625);
  addMapping("RTP_IN_JITTER", 57626);
  addMapping("RTP_OUT_JITTER", 57627);
  addMapping("RTP_IN_PKT_LOST", 57628);
  addMapping("RTP_OUT_PKT_LOST", 57629);
  addMapping("RTP_IN_PKT_DROP", 57902);
  addMapping("RTP_OUT_PKT_DROP", 57903);
  addMapping("RTP_IN_PAYLOAD_TYPE", 57633);
  addMapping("RTP_OUT_PAYLOAD_TYPE", 57630);
  addMapping("RTP_IN_MAX_DELTA", 57631);
  addMapping("RTP_OUT_MAX_DELTA", 57632);
  addMapping("RTP_SIP_CALL_ID", 57820);
  addMapping("RTP_MOS", 57906);
  addMapping("RTP_IN_MOS", 57842);
  addMapping("RTP_OUT_MOS", 57904);
  addMapping("RTP_R_FACTOR", 57908);
  addMapping("RTP_IN_R_FACTOR", 57843);
  addMapping("RTP_OUT_R_FACTOR", 57905);
  addMapping("RTP_IN_TRANSIT", 57853);
  addMapping("RTP_OUT_TRANSIT", 57854);
  addMapping("RTP_RTT", 57852);
  addMapping("RTP_DTMF_TONES", 57867);
  addMapping("S1AP_ENB_UE_S1AP_ID", 57879);
  addMapping("S1AP_MME_UE_S1AP_ID", 57880);
  addMapping("S1AP_MSG_EMM_TYPE_MME_TO_ENB", 57881);
  addMapping("S1AP_MSG_ESM_TYPE_MME_TO_ENB", 57882);
  addMapping("S1AP_MSG_EMM_TYPE_ENB_TO_MME", 57883);
  addMapping("S1AP_MSG_ESM_TYPE_ENB_TO_MME", 57884);
  addMapping("S1AP_CAUSE_ENB_TO_MME", 57885);
  addMapping("S1AP_DETAILED_CAUSE_ENB_TO_MME", 57886);
  addMapping("SIP_CALL_ID", 57602);
  addMapping("SIP_CALLING_PARTY", 57603);
  addMapping("SIP_CALLED_PARTY", 57604);
  addMapping("SIP_RTP_CODECS", 57605);
  addMapping("SIP_INVITE_TIME", 57606);
  addMapping("SIP_TRYING_TIME", 57607);
  addMapping("SIP_RINGING_TIME", 57608);
  addMapping("SIP_INVITE_OK_TIME", 57609);
  addMapping("SIP_INVITE_FAILURE_TIME", 57610);
  addMapping("SIP_BYE_TIME", 57611);
  addMapping("SIP_BYE_OK_TIME", 57612);
  addMapping("SIP_CANCEL_TIME", 57613);
  addMapping("SIP_CANCEL_OK_TIME", 57614);
  addMapping("SIP_RTP_IPV4_SRC_ADDR", 57615);
  addMapping("SIP_RTP_L4_SRC_PORT", 57616);
  addMapping("SIP_RTP_IPV4_DST_ADDR", 57617);
  addMapping("SIP_RTP_L4_DST_PORT", 57618);
  addMapping("SIP_RESPONSE_CODE", 57619);
  addMapping("SIP_REASON_CAUSE", 57620);
  addMapping("SIP_C_IP", 57834);
  addMapping("SIP_CALL_STATE", 57835);
  addMapping("SMTP_MAIL_FROM", 57657);
  addMapping("SMTP_RCPT_TO", 57658);
  addMapping("SSDP_HOST", 57972);
  addMapping("SSDP_USN", 57973);

  addMapping("SSL_SERVER_NAME", 57660);
  addMapping("BITTORRENT_HASH", 57661);
}

/* **************************************************** */

ParserInterface::~ParserInterface() {
  for(struct FlowFieldMap *s=map; s != NULL; s=(struct FlowFieldMap*)s->hh.next) free(s->key);
  HASH_CLEAR(hh, map);
}

/* **************************************************** */

void ParserInterface::addMapping(const char *sym, int num) {
  struct FlowFieldMap *m = (struct FlowFieldMap*)malloc(sizeof(struct FlowFieldMap));

  if(m) {
    m->key = strdup(sym), m->value = num;
    if(m->key) HASH_ADD_STR(map, key, m); else free(m);
  }
}

/* **************************************************** */

int ParserInterface::getKeyId(char *sym) {
  struct FlowFieldMap *s;

  if(isdigit(sym[0])) return(atoi(sym));
  
  HASH_FIND_STR(map, sym, s);  /* s: output pointer */
  
  return(s ? s->value : -1);
}

/* **************************************************** */

u_int8_t ParserInterface::parseEvent(char *payload, int payload_size, u_int8_t source_id, void *data) {
  json_object *o;
  enum json_tokener_error jerr = json_tokener_success;
  NetworkInterface * iface = (NetworkInterface*)data;
   
  // payload[payload_size] = '\0';
   
  //ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", payload);
  o = json_tokener_parse_verbose(payload, &jerr);
   
  if(o != NULL) {
    struct json_object_iterator it = json_object_iter_begin(o);
    struct json_object_iterator itEnd = json_object_iter_end(o);
    char remote_ifname[32] = { 0 }, remote_ifaddress[64] = { 0 };
    char remote_probe_address[64] = { 0 }, remote_probe_public_address[64] = { 0 };
    u_int64_t remote_bytes = 0, remote_pkts = 0;
    u_int32_t remote_ifspeed = 0, remote_time = 0, avg_bps = 0, avg_pps = 0;

    while(!json_object_iter_equal(&it, &itEnd)) {
      const char *key   = json_object_iter_peek_name(&it);
      json_object *v    = json_object_iter_peek_value(&it);
      const char *value = json_object_get_string(v);

      if((key != NULL) && (value != NULL)) {
	/* 
	   Example
	   { "if.name": "en0", "if.speed": 1000, "if.ip": "fe80::c62c:3ff:fe06:49fe%en0", "probe.ip": "192.168.1.5", "time" : 1456595814, "bytes": 18505, "packets": 85 }
	*/	
	if(!strcmp(key, "if.name"))      snprintf(remote_ifname, sizeof(remote_ifname), "%s", value);
	else if(!strcmp(key, "if.ip"))   snprintf(remote_ifaddress, sizeof(remote_ifaddress), "%s", value);
	else if(!strcmp(key, "if.speed")) remote_ifspeed = atol(value);
	else if(!strcmp(key, "probe.ip")) snprintf(remote_probe_address, sizeof(remote_probe_address), "%s", value);
	else if(!strcmp(key, "probe.public_ip")) snprintf(remote_probe_public_address, sizeof(remote_probe_public_address), "%s", value);
	else if(!strcmp(key, "bytes"))    remote_bytes = atol(value);
	else if(!strcmp(key, "packets"))  remote_pkts = atol(value);
	else if(!strcmp(key, "time"))     remote_time = atol(value); /* Format 1461424017.299 <sec>.<msec> */
	else if(!strcmp(key, "avg.bps"))  avg_bps = atol(value);
	else if(!strcmp(key, "avg.pps"))  avg_pps = atol(value);
	
	/* Move to the next element */
	json_object_iter_next(&it);
      }
    } // while json_object_iter_equal
    
    /* ntop->getTrace()->traceEvent(TRACE_WARNING, "%u/%u", avg_bps, avg_pps); */

    /* Process Flow */
    iface->setRemoteStats(remote_ifname, remote_ifaddress, remote_ifspeed, 
			  remote_probe_address, remote_probe_public_address,
			  remote_bytes, remote_pkts, remote_time, avg_pps, avg_bps);
    
    /* Dispose memory */
    json_object_put(o);
  } else {
    // if o != NULL
    if(!once){
      ntop->getTrace()->traceEvent(TRACE_WARNING,
				   "Invalid message received: your nProbe sender is outdated, data encrypted or invalid JSON?");
      ntop->getTrace()->traceEvent(TRACE_WARNING, "JSON Parse error [%s] payload size: %u payload: %s",
				   json_tokener_error_desc(jerr),
				   payload_size,
				   payload);
    }
    once = true;
    return -1;
  }

  return 0;
}

/* **************************************************** */

u_int8_t ParserInterface::parseFlow(char *payload, int payload_size, u_int8_t source_id, void *data) {
  json_object *o;
  enum json_tokener_error jerr = json_tokener_success;
  ZMQ_Flow flow;
  NetworkInterface * iface = (NetworkInterface*)data;

  // payload[payload_size] = '\0';

  o = json_tokener_parse_verbose(payload, &jerr);

  if(o != NULL) {
    struct json_object_iterator it = json_object_iter_begin(o);
    struct json_object_iterator itEnd = json_object_iter_end(o);

    /* Reset data */
    memset(&flow, 0, sizeof(flow));
    flow.additional_fields = json_object_new_object();
    flow.pkt_sampling_rate = 1; /* 1:1 (no sampling) */
    flow.source_id = source_id, flow.vlan_id = 0;

    while(!json_object_iter_equal(&it, &itEnd)) {
      const char *key   = json_object_iter_peek_name(&it);
      json_object *v    = json_object_iter_peek_value(&it);
      const char *value = json_object_get_string(v);

      if((key != NULL) && (value != NULL)) {
        int key_id;
	json_object *additional_o = json_tokener_parse(value);

	/* FIX: the key can either be numeric of a string */
	key_id = getKeyId((char*)key);

        switch(key_id) {
        case 0: //json additional object added by Flow::serialize()
          if((additional_o != NULL) && (strcmp(key,"json") == 0)) {
            struct json_object_iterator additional_it = json_object_iter_begin(additional_o);
            struct json_object_iterator additional_itEnd = json_object_iter_end(additional_o);

            while(!json_object_iter_equal(&additional_it, &additional_itEnd)) {

              const char *additional_key   = json_object_iter_peek_name(&additional_it);
              json_object *additional_v    = json_object_iter_peek_value(&additional_it);
              const char *additional_value = json_object_get_string(additional_v);

              if((additional_key != NULL) && (additional_value != NULL)) {
		json_object_object_add(flow.additional_fields, additional_key, json_object_new_string(additional_value));
	      }
	      json_object_iter_next(&additional_it);
            }
          }
          break;
        case IN_SRC_MAC:
          /* Format 00:00:00:00:00:00 */
          sscanf(value, "%hhx:%hhx:%hhx:%hhx:%hhx:%hhx",
		 &flow.src_mac[0], &flow.src_mac[1], &flow.src_mac[2],
		 &flow.src_mac[3], &flow.src_mac[4], &flow.src_mac[5]);
          break;
        case OUT_DST_MAC:
          sscanf(value, "%hhx:%hhx:%hhx:%hhx:%hhx:%hhx",
		 &flow.dst_mac[0], &flow.dst_mac[1], &flow.dst_mac[2],
		 &flow.dst_mac[3], &flow.dst_mac[4], &flow.dst_mac[5]);
          break;
        case IPV4_SRC_ADDR:
        case IPV6_SRC_ADDR:
	  /*
	     The following check prevents an empty ip address (e.g., ::) to
	     to overwrite another valid ip address already set.
	     This can happen for example when nProbe is configured (-T) to export
	     both %IPV4_SRC_ADDR and the %IPV6_SRC_ADDR. In that cases nProbe can
	     export a valid ipv4 and an empty ipv6. Without the check, the empty
	     v6 address may overwrite the non empty v4.
	   */
	  if(flow.src_ip.isEmpty())
	    flow.src_ip.set_from_string((char*)value);
	  else
	    /*
	      ipv4 and ipv4 are both non empty or any one of them as been found
	      more than one time.
	     */
	    ntop->getTrace()->traceEvent(TRACE_WARNING,
					 "Attempt to set source ip multiple times. "
					 "Check exported fields in %s", payload);
          break;
        case IPV4_DST_ADDR:
        case IPV6_DST_ADDR:
	  if(flow.dst_ip.isEmpty())
	    flow.dst_ip.set_from_string((char*)value);
	  else
	    ntop->getTrace()->traceEvent(TRACE_WARNING,
					 "Attempt to set destination ip multiple times. "
					 "Check exported fields in %s", payload);
          break;
        case L4_SRC_PORT:
          flow.src_port = htons(atoi(value));
          break;
        case L4_DST_PORT:
          flow.dst_port = htons(atoi(value));
          break;
        case SRC_VLAN:
        case DST_VLAN:
          flow.vlan_id = atoi(value);
          break;
	case DOT1Q_SRC_VLAN:
        case DOT1Q_DST_VLAN:
	  if (flow.vlan_id == 0)
	    /* as those fields are the outer vlans in q-in-q
	       we set the vlan_id only if there is no inner vlan
	       value set
	    */
	    flow.vlan_id = atoi(value);
          break;
        case L7_PROTO:
          flow.l7_proto = atoi(value);
          break;
        case PROTOCOL:
          flow.l4_proto = atoi(value);
          break;
        case TCP_FLAGS:
          flow.tcp_flags = atoi(value);
          break;
        case IN_PKTS:
          flow.in_pkts = atol(value);
          break;
        case IN_BYTES:
          flow.in_bytes = atol(value);
          break;
        case OUT_PKTS:
          flow.out_pkts = atol(value);
          break;
        case OUT_BYTES:
          flow.out_bytes = atol(value);
          break;
        case FIRST_SWITCHED:
          flow.first_switched = atol(value);
          break;
        case LAST_SWITCHED:
          flow.last_switched = atol(value);
          break;
        case SAMPLING_INTERVAL:
          flow.pkt_sampling_rate = atoi(value);
          break;
        case DIRECTION:
          flow.direction = atoi(value);
          break;
	case EXPORTER_IPV4_ADDRESS:
	  /* a.b.c.d */
	  flow.deviceIP = ntohl(inet_addr(value));
	  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%u [%s]", flow.deviceIP, value);
	  break;
	case INPUT_SNMP:
	  flow.inIndex = atoi(value);
	  break;
	case OUTPUT_SNMP:
	  flow.outIndex = atoi(value);
	  break;
        case SRC_PROC_PID:
          iface->enable_sprobe(); /* We're collecting system flows */
          flow.src_process.pid = atoi(value);
          break;
        case SRC_PROC_NAME:
          iface->enable_sprobe(); /* We're collecting system flows */
          snprintf(flow.src_process.name, sizeof(flow.src_process.name), "%s", value);
          break;
        case SRC_PROC_USER_NAME:
          snprintf(flow.src_process.user_name, sizeof(flow.src_process.user_name), "%s", value);
          break;
        case SRC_FATHER_PROC_PID:
          flow.src_process.father_pid = atoi(value);
          break;
        case SRC_FATHER_PROC_NAME:
          snprintf(flow.src_process.father_name, sizeof(flow.src_process.father_name), "%s", value);
          break;
        case SRC_PROC_ACTUAL_MEMORY:
          flow.src_process.actual_memory = atoi(value);
          break;
        case SRC_PROC_PEAK_MEMORY:
          flow.src_process.peak_memory = atoi(value);
          break;
        case SRC_PROC_AVERAGE_CPU_LOAD:
          flow.src_process.average_cpu_load = ((float)atol(value))/((float)100);
          break;
        case SRC_PROC_NUM_PAGE_FAULTS:
          flow.src_process.num_vm_page_faults = atoi(value);
          break;
        case SRC_PROC_PCTG_IOWAIT:
          flow.src_process.percentage_iowait_time = ((float)atol(value))/((float)100);
          break;

        case DST_PROC_PID:
          iface->enable_sprobe(); /* We're collecting system flows */
          flow.dst_process.pid = atoi(value);
          break;
        case DST_PROC_NAME:
          iface->enable_sprobe(); /* We're collecting system flows */
          snprintf(flow.dst_process.name, sizeof(flow.dst_process.name), "%s", value);
          break;
        case DST_PROC_USER_NAME:
          snprintf(flow.dst_process.user_name, sizeof(flow.dst_process.user_name), "%s", value);
          break;
        case DST_FATHER_PROC_PID:
          flow.dst_process.father_pid = atoi(value);
          break;
        case DST_FATHER_PROC_NAME:
          snprintf(flow.dst_process.father_name, sizeof(flow.dst_process.father_name), "%s", value);
          break;
        case DST_PROC_ACTUAL_MEMORY:
          flow.dst_process.actual_memory = atoi(value);
          break;
        case DST_PROC_PEAK_MEMORY:
          flow.dst_process.peak_memory = atoi(value);
          break;
        case DST_PROC_AVERAGE_CPU_LOAD:
          flow.dst_process.average_cpu_load = ((float)atol(value))/((float)100);
          break;
        case DST_PROC_NUM_PAGE_FAULTS:
          flow.dst_process.num_vm_page_faults = atoi(value);
          break;
        case DST_PROC_PCTG_IOWAIT:
          flow.dst_process.percentage_iowait_time = ((float)atol(value))/((float)100);
          break;
	case DNS_QUERY:
	  flow.dns_query = strdup(value);
	  break;
	case HTTP_URL:
	  flow.http_url = strdup(value);
	  break;
	case HTTP_SITE:
	  flow.http_site = strdup(value);
	  break;
	case SSL_SERVER_NAME:
	  flow.ssl_server_name = strdup(value);
	  break;
	case BITTORRENT_HASH:
	  flow.bittorrent_hash = strdup(value);
	  break;

        default:
          ntop->getTrace()->traceEvent(TRACE_DEBUG, "Not handled ZMQ field %u/%s", key_id, key);
          json_object_object_add(flow.additional_fields, key, json_object_new_string(value));
          break;
        } /* switch */

	if(additional_o) json_object_put(additional_o);
      } /* if */

      /* Move to the next element */
      json_object_iter_next(&it);
    } // while json_object_iter_equal

    /* Process Flow */
    iface->processFlow(&flow);

    /* Dispose memory */
    if(flow.dns_query) free(flow.dns_query);
    if(flow.http_url)  free(flow.http_url);
    if(flow.http_site) free(flow.http_site);
    if(flow.ssl_server_name) free(flow.ssl_server_name);
    if(flow.bittorrent_hash) free(flow.bittorrent_hash);

    json_object_put(o);
    json_object_put(flow.additional_fields);
  } else {
    // if o != NULL
    if(!once){
      ntop->getTrace()->traceEvent(TRACE_WARNING,
				   "Invalid message received: your nProbe sender is outdated, data encrypted or invalid JSON?");
      ntop->getTrace()->traceEvent(TRACE_WARNING, "JSON Parse error [%s] payload size: %u payload: %s",
				   json_tokener_error_desc(jerr),
				   payload_size,
				   payload);
    }
    once = true;
    return -1;
  }

  return 0;
}

/* **************************************************** */

u_int8_t ParserInterface::parseCounter(char *payload, int payload_size, u_int8_t source_id, void *data) {
  json_object *o;
  enum json_tokener_error jerr = json_tokener_success;
  NetworkInterface * iface = (NetworkInterface*)data;
  sFlowInterfaceStats stats;

  // payload[payload_size] = '\0';

  memset(&stats, 0, sizeof(stats));
  o = json_tokener_parse_verbose(payload, &jerr);

  if(o != NULL) {
    struct json_object_iterator it = json_object_iter_begin(o);
    struct json_object_iterator itEnd = json_object_iter_end(o);

    /* Reset data */
    memset(&stats, 0, sizeof(stats));

    while(!json_object_iter_equal(&it, &itEnd)) {
      const char *key   = json_object_iter_peek_name(&it);
      json_object *v    = json_object_iter_peek_value(&it);
      const char *value = json_object_get_string(v);

      if((key != NULL) && (value != NULL)) {
	if(!strcmp(key, "deviceIP")) stats.deviceIP = atol(value);
	else if(!strcmp(key, "ifIndex")) stats.ifIndex = atol(value);
	else if(!strcmp(key, "ifType")) stats.ifType = atol(value);
	else if(!strcmp(key, "ifSpeed")) stats.ifSpeed = atol(value);
	else if(!strcmp(key, "ifDirection")) stats.ifFullDuplex = (!strcmp(value, "Full")) ? true : false;
	else if(!strcmp(key, "ifAdminStatus")) stats.ifAdminStatus = (!strcmp(value, "Up")) ? true : false;
	else if(!strcmp(key, "ifOperStatus")) stats.ifOperStatus = (!strcmp(value, "Up")) ? true : false;
	else if(!strcmp(key, "ifInOctets")) stats.ifInOctets = atoll(value);
	else if(!strcmp(key, "ifInPackets")) stats.ifInPackets = atoll(value);
	else if(!strcmp(key, "ifInErrors")) stats.ifInErrors = atoll(value);
	else if(!strcmp(key, "ifOutOctets")) stats.ifOutOctets = atoll(value);
	else if(!strcmp(key, "ifOutPackets")) stats.ifOutPackets = atoll(value);
	else if(!strcmp(key, "ifOutErrors")) stats.ifOutErrors = atoll(value);
	else if(!strcmp(key, "ifPromiscuousMode")) stats.ifPromiscuousMode = (!strcmp(value, "1")) ? true : false;
      } /* if */
      
      /* Move to the next element */
      json_object_iter_next(&it);
    } // while json_object_iter_equal

    /* Process Flow */
    iface->processInterfaceStats(&stats);

    json_object_put(o);
  } else {
    // if o != NULL
    if(!once){
      ntop->getTrace()->traceEvent(TRACE_WARNING,
				   "Invalid message received: your nProbe sender is outdated, data encrypted or invalid JSON?");
      ntop->getTrace()->traceEvent(TRACE_WARNING, "JSON Parse error [%s] payload size: %u payload: %s",
				   json_tokener_error_desc(jerr),
				   payload_size,
				   payload);
    }
    once = true;
    return -1;
  }

  return 0;
}

/* **************************************************** */
