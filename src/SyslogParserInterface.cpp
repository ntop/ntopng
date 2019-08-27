/*
 *
 * (C) 2019 - ntop.org
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

#define USE_SURICATA_NETFLOW
//#define SYSLOG_DEBUG

/* **************************************************** */

SyslogParserInterface::SyslogParserInterface(const char *endpoint, const char *custom_interface_type) : ParserInterface(endpoint, custom_interface_type) {

}

/* **************************************************** */

SyslogParserInterface::~SyslogParserInterface() {

}

/* **************************************************** */

void SyslogParserInterface::parseSuricataNetflow(json_object *f, ParsedFlow *flow) {
  json_object *w;

  if(json_object_object_get_ex(f, "start", &w)) 
    flow->first_switched = Utils::str2epoch(json_object_get_string(w));

  if(json_object_object_get_ex(f, "end", &w))
    flow->last_switched = Utils::str2epoch(json_object_get_string(w));

  if(json_object_object_get_ex(f, "pkts",  &w)) 
    flow->in_pkts   = json_object_get_int(w);

  if(json_object_object_get_ex(f, "bytes", &w)) 
    flow->in_bytes  = json_object_get_int(w);
}

/* **************************************************** */

void SyslogParserInterface::parseSuricataFlow(json_object *f, ParsedFlow *flow) {
  json_object *w;

  if(json_object_object_get_ex(f, "start", &w)) 
    flow->first_switched = Utils::str2epoch(json_object_get_string(w));

  if(json_object_object_get_ex(f, "end", &w))
    flow->last_switched = Utils::str2epoch(json_object_get_string(w));
  if (!flow->last_switched) flow->last_switched = flow->first_switched;

  if(json_object_object_get_ex(f, "pkts_toserver",  &w)) 
    flow->in_pkts   = json_object_get_int(w);

  if(json_object_object_get_ex(f, "pkts_toclient",  &w)) 
    flow->out_pkts  = json_object_get_int(w);

  if(json_object_object_get_ex(f, "bytes_toserver", &w)) 
    flow->in_bytes  = json_object_get_int(w);

  if(json_object_object_get_ex(f, "bytes_client",   &w)) 
    flow->out_bytes = json_object_get_int(w);
}

/* **************************************************** */

void SyslogParserInterface::parseSuricataAlert(json_object *a, ParsedFlow *flow, ICMPinfo *icmp_info, bool flow_alert) {
  if (flow_alert) {
    Flow *f;
    bool src2dst_direction, new_flow;
#ifdef SYSLOG_DEBUG
    char src_ip_buf[64], dst_ip_buf[64];

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[Suricata] Flow Alert for %s:%u <-> %s:%u JSON: %s",
      flow->src_ip.print(src_ip_buf, sizeof(src_ip_buf)), ntohs(flow->src_port), 
      flow->dst_ip.print(dst_ip_buf, sizeof(dst_ip_buf)), ntohs(flow->dst_port),
      json_object_to_json_string(a));
#endif

    f = getFlow(NULL, NULL, flow->vlan_id, 0, 0, 0,
      icmp_info,
      &flow->src_ip, &flow->dst_ip,
      flow->src_port, flow->dst_port,
      flow->l4_proto, &src2dst_direction,
      flow->first_switched, flow->last_switched, 
      0, &new_flow, 
      true /* create it if we didn't receive netflow yet */);

    if (f) {
      f->setSuricataAlert(json_object_get(a));
    } else {
#ifdef SYSLOG_DEBUG 
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "[Suricata] Flow matching the alert not found (ignored)", 
        json_object_to_json_string(a));
#endif
    }

    if (companionsEnabled()) {
      flow->suricata_alert = strdup(json_object_to_json_string(a));
      deliverFlowToCompanions(flow);
    }

  } else {
    /* Other alert types? (e.g. host) */
#ifdef SYSLOG_DEBUG 
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[Suricata] Alert JSON: %s (ignored)", 
      json_object_to_json_string(a));
#endif
  }
}

/* **************************************************** */

u_int8_t SyslogParserInterface::parseLog(char *log_line) {
  char *content;
  enum json_tokener_error jerr = json_tokener_success;
  int num_flows = 0;

  content = strstr(log_line, ": ");

  if(content == NULL)
    return 0; /* unexpected format */

  content[1] = '\0';
  content += 2;

  if(strstr(log_line, "suricata") != NULL) {
    json_object *o;
    ParsedFlow flow;
    ICMPinfo icmp_info;

    /* Suricata Log */

#ifdef SYSLOG_DEBUG
    ntop->getTrace()->traceEvent(TRACE_DEBUG, "[Suricata] JSON: %s", content);
#endif

    o = json_tokener_parse_verbose(content, &jerr);

    if(o) {
      json_object *w, *f, *a;
      const char *event_type = "";
#ifdef SYSLOG_DEBUG
      char src_ip_buf[64], dst_ip_buf[64];
      const char *timestamp = "";

      if(json_object_object_get_ex(o, "timestamp", &w))  timestamp = json_object_get_string(w);
#endif

      if(json_object_object_get_ex(o, "event_type", &w)) event_type = json_object_get_string(w);

      //if(json_object_object_get_ex(o, "flow_id", &w)) flow_id = json_object_get_string(w);
      //if(json_object_object_get_ex(o, "community_id", &w)) community_id = json_object_get_string(w);
      //if(json_object_object_get_ex(o, "app_proto", &w)) app_proto = json_object_get_string(w);
      if(json_object_object_get_ex(o, "vlan", &w))      flow.vlan_id = json_object_get_int(w);
      if(json_object_object_get_ex(o, "src_ip", &w))    flow.src_ip.set((char *) json_object_get_string(w));
      if(json_object_object_get_ex(o, "dest_ip", &w))   flow.dst_ip.set((char *) json_object_get_string(w));
      if(json_object_object_get_ex(o, "src_port", &w))  flow.src_port = htons(json_object_get_int(w));
      if(json_object_object_get_ex(o, "dest_port", &w)) flow.dst_port = htons(json_object_get_int(w));
      if(json_object_object_get_ex(o, "proto", &w))     flow.l4_proto = Utils::l4name2proto((char *) json_object_get_string(w));

      if(flow.l4_proto == 1 /* ICMP */) {
        if(json_object_object_get_ex(o, "icmp_type", &w))
          icmp_info.setType(json_object_get_int(w));
        if(json_object_object_get_ex(o, "icmp_code", &w))
          icmp_info.setCode(json_object_get_int(w));
      }

      if(strcmp(event_type, "alert") == 0 && json_object_object_get_ex(o, "alert", &a)) {
        bool flow_alert = false;

        /* Suricata Alert */

#ifdef SYSLOG_DEBUG
        //ntop->getTrace()->traceEvent(TRACE_NORMAL, "[Suricata] Alert JSON: %s", content);
#endif

        if(json_object_object_get_ex(o, "flow", &f)) {
          parseSuricataFlow(f, &flow);
          flow_alert = true;
        }

        parseSuricataAlert(a, &flow, &icmp_info, flow_alert);

#ifdef USE_SURICATA_NETFLOW
      } else if(strcmp(event_type, "netflow") == 0 && json_object_object_get_ex(o, "netflow", &f)) {

        /* Suricata Flow (Unidirectional "netflow") */

        parseSuricataNetflow(f, &flow);

#ifdef SYSLOG_DEBUG
        ntop->getTrace()->traceEvent(TRACE_NORMAL, "[Suricata] Netflow %s:%u <-> %s:%u [start=%u][end=%u][%u pkts][%u bytes]",
          flow.src_ip.print(src_ip_buf, sizeof(src_ip_buf)), ntohs(flow.src_port), 
          flow.dst_ip.print(dst_ip_buf, sizeof(dst_ip_buf)), ntohs(flow.dst_port),
          flow.first_switched, flow.last_switched,
          flow.in_pkts, flow.in_bytes);
#endif

        processFlow(&flow, false);
        num_flows++;
#else /* USE_SURICATA_NETFLOW */
      } else if(strcmp(event_type, "flow") == 0 && json_object_object_get_ex(o, "flow", &f)) {

        /* Suricata Flow (Bidirectional) */

        parseSuricataFlow(f, &flow);

#ifdef SYSLOG_DEBUG
        ntop->getTrace()->traceEvent(TRACE_NORMAL, "[Suricata] Flow %s:%u <-> %s:%u [start=%u][end=%u][%u/%u pkts][%u/%u bytes]",
          flow.src_ip.print(src_ip_buf, sizeof(src_ip_buf)), ntohs(flow.src_port), 
          flow.dst_ip.print(dst_ip_buf, sizeof(dst_ip_buf)), ntohs(flow.dst_port),
          flow.first_switched, flow.last_switched,
          flow.in_pkts, flow.out_pkts, flow.in_bytes, flow.out_bytes);
#endif

        processFlow(&flow, false);
        num_flows++;
#endif /* USE_SURICATA_NETFLOW */

#ifdef SYSLOG_DEBUG
      } else {
        /* Other Events */
        ntop->getTrace()->traceEvent(TRACE_INFO, "[Suricata] Event '%s' [%s] (ignored)", event_type, timestamp);
#endif
      }

      json_object_put(o);
    }

#ifdef SYSLOG_DEBUG
  } else {
    /* System Log */
    ntop->getTrace()->traceEvent(TRACE_INFO, "[SYSLOG] System Event (%s): %s (ignored)", log_line, content);
#endif
  }

  return num_flows;
}

/* **************************************************** */

void SyslogParserInterface::lua(lua_State* vm) {

  NetworkInterface::lua(vm);

}

/* **************************************************** */

#endif
