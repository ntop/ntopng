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

ParserInterface::ParserInterface(const char *endpoint) : NetworkInterface(endpoint) { }

/* **************************************************** */

 u_int8_t ParserInterface::parse_flows(char *payload, int payload_size, u_int8_t source_id, void *data) {
   json_object *o;
   ZMQ_Flow flow;
   NetworkInterface * iface = (NetworkInterface*)data;

  // payload[payload_size] = '\0';

  o = json_tokener_parse(payload);

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
        u_int key_id;
	json_object *additional_o = json_tokener_parse(value);

	/* FIX: the key can either be numeric of a string */
	key_id = atoi(key);

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
          flow.src_ip.set_from_string((char*)value);
          break;
        case IPV4_DST_ADDR:
        case IPV6_DST_ADDR:
          flow.dst_ip.set_from_string((char*)value);
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

        default:
          ntop->getTrace()->traceEvent(TRACE_INFO, "Not handled ZMQ field %u", key_id);
          json_object_object_add(flow.additional_fields, key, json_object_new_string(value));
          break;
        } /* switch */

	if(additional_o) json_object_put(additional_o);
      } /* if */

      /* Move to the next element */
      json_object_iter_next(&it);
    } // while json_object_iter_equal

    /* Process Flow */
    iface->flow_processing(&flow);

    /* Dispose memory */
    json_object_put(o);
    json_object_put(flow.additional_fields);
  } else {
    // if o != NULL
    ntop->getTrace()->traceEvent(TRACE_WARNING,
				 "Invalid message received: your nProbe sender is outdated or invalid JSON?");
    ntop->getTrace()->traceEvent(TRACE_WARNING, "[%u] %s", payload_size, payload);
    return -1;
  }

  return 0;
 }

 /* **************************************************** */
