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

//#define SYSLOG_DEBUG

/* **************************************************** */

SyslogParserInterface::SyslogParserInterface(const char *endpoint, const char *custom_interface_type) : ParserInterface(endpoint, custom_interface_type) {

}

/* **************************************************** */

SyslogParserInterface::~SyslogParserInterface() {

}

/* **************************************************** */

u_int8_t SyslogParserInterface::parseLog(char *log_line, void *data) {
  NetworkInterface *iface = (NetworkInterface*)data;
  char *content;
  enum json_tokener_error jerr = json_tokener_success;
  int num_flows = 0;

  content = strstr(log_line, ": ");

  if (content == NULL)
    return 0; /* unexpected format */

  content[1] = '\0';
  content += 2;

  if (strstr(log_line, "suricata") != NULL) {
    json_object *o;
    Parsed_Flow flow;

    /* Suricata Log */

#ifdef SYSLOG_DEBUG
    //ntop->getTrace()->traceEvent(TRACE_NORMAL, "[SYSLOG] Suricata EVE JSON: %s", content);
#endif

    /* Reset data */
    memset(&flow, 0, sizeof(flow));
    flow.core.l7_proto.master_protocol = flow.core.l7_proto.app_protocol = NDPI_PROTOCOL_UNKNOWN;
    flow.core.l7_proto.category = NDPI_PROTOCOL_CATEGORY_UNSPECIFIED;
    flow.additional_fields = json_object_new_object();
    flow.core.pkt_sampling_rate = 1; /* 1:1 (no sampling) */
    flow.core.source_id = 0, flow.core.vlan_id = 0;


    o = json_tokener_parse_verbose(content, &jerr);

    if (o) {
      json_object *w, *f;

#ifdef SYSLOG_DEBUG
      if (json_object_object_get_ex(o, "timestamp", &w)) 
        ntop->getTrace()->traceEvent(TRACE_NORMAL, "Suricata event timestamp: %s", json_object_get_string(w));
#endif

      //if (json_object_object_get_ex(o, "flow_id", &w)) flow_id = json_object_get_string(w);
      if (json_object_object_get_ex(o, "vlan", &w))      flow.core.vlan_id = json_object_get_int(w);
      if (json_object_object_get_ex(o, "src_ip", &w))    flow.core.src_ip.set((char *) json_object_get_string(w));
      if (json_object_object_get_ex(o, "dest_ip", &w))   flow.core.dst_ip.set((char *) json_object_get_string(w));
      if (json_object_object_get_ex(o, "src_port", &w))  flow.core.src_port = htons(json_object_get_int(w));
      if (json_object_object_get_ex(o, "dest_port", &w)) flow.core.dst_port = htons(json_object_get_int(w));
      if (json_object_object_get_ex(o, "proto", &w))     flow.core.l4_proto = Utils::l4name2proto((char *) json_object_get_string(w));

      if (json_object_object_get_ex(o, "flow", &f)) {

#ifdef SYSLOG_DEBUG
        if (json_object_object_get_ex(f, "start", &w)) 
          ntop->getTrace()->traceEvent(TRACE_NORMAL, "Suricata flow start: %s", json_object_get_string(w));
#endif

        if (json_object_object_get_ex(f, "pkts_toserver",  &w)) flow.core.in_pkts   = json_object_get_int(w);
        if (json_object_object_get_ex(f, "pkts_toclient",  &w)) flow.core.out_pkts  = json_object_get_int(w);
        if (json_object_object_get_ex(f, "bytes_toserver", &w)) flow.core.in_bytes  = json_object_get_int(w);
        if (json_object_object_get_ex(f, "bytes_client",   &w)) flow.core.out_bytes = json_object_get_int(w);

        iface->processFlow(&flow);
      }

      json_object_put(o);
    }

    if (flow.additional_fields)
      json_object_put(flow.additional_fields);

  } else {
    /* System Log */
#ifdef SYSLOG_DEBUG
    ntop->getTrace()->traceEvent(TRACE_INFO, "[SYSLOG] System Event (%s): %s", log_line, content);
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
