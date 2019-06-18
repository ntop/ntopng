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

ParsedeBPF::ParsedeBPF() {
  ifname = NULL;

  event_type = ebpf_event_type_unknown;

  process_info_set = container_info_set = tcp_info_set = false;
  memset(&process_info, 0, sizeof(process_info)),
    memset(&container_info, 0, sizeof(container_info)),
    memset(&tcp_info, 0, sizeof(tcp_info));

  server_info = false,
    free_memory = false;
}
/* *************************************** */

ParsedeBPF::ParsedeBPF(const ParsedeBPF &pe) {
  ifname = NULL;
  memcpy(&process_info, &pe.process_info, sizeof(process_info)),
    memcpy(&container_info, &pe.container_info, sizeof(container_info)),
    memcpy(&tcp_info, &pe.tcp_info, sizeof(tcp_info));

  event_type = pe.event_type;

  if(pe.ifname) ifname = strdup(pe.ifname);

  if((process_info_set = pe.process_info_set)) {
    if(process_info.process_name)        process_info.process_name = strdup(process_info.process_name);
    if(process_info.uid_name)            process_info.uid_name = strdup(process_info.uid_name);
    if(process_info.father_process_name) process_info.father_process_name = strdup(process_info.father_process_name);
    if(process_info.father_uid_name)     process_info.father_uid_name = strdup(process_info.father_uid_name);
  }

  if((container_info_set = pe.container_info_set)) {
    if(container_info.id)   container_info.id = strdup(container_info.id);
    if(container_info.name) container_info.name = strdup(container_info.name);

    if(container_info.data_type == container_info_data_type_k8s) {
      if(container_info.data.k8s.pod) container_info.data.k8s.pod = strdup(container_info.data.k8s.pod);
      if(container_info.data.k8s.ns)  container_info.data.k8s.ns = strdup(container_info.data.k8s.ns);
    } else if(container_info.data_type == container_info_data_type_docker)
      ;
  }

  if((tcp_info_set = pe.tcp_info_set))
    ;

  server_info = pe.server_info;

  /* Free memory if allocation is from a 'copy' constructor */
  free_memory = true;
}

/* *************************************** */

ParsedeBPF::~ParsedeBPF() {
  if(free_memory) {
    if(ifname) free(ifname);

    if(process_info_set) {
      if(process_info.process_name)        free(process_info.process_name);
      if(process_info.uid_name)            free(process_info.uid_name);
      if(process_info.father_process_name) free(process_info.father_process_name);
      if(process_info.father_uid_name)     free(process_info.father_uid_name);
    }

    if(container_info_set) {
      if(container_info.id)   free(container_info.id);
      if(container_info.name) free(container_info.name);

      if(container_info.data_type == container_info_data_type_k8s) {
	if(container_info.data.k8s.pod) free(container_info.data.k8s.pod);
	if(container_info.data.k8s.ns)  free(container_info.data.k8s.ns);
      } else if(container_info.data_type == container_info_data_type_docker)
	;
    }

    if(tcp_info_set)
    ;
  }
}

/* *************************************** */

void ParsedeBPF::update(const ParsedeBPF * const pe) {
  /* Update tcp stats */
  if(pe) {
    if(pe->tcp_info_set) {
      if(!tcp_info_set) tcp_info_set = true;
      memcpy(&tcp_info, &pe->tcp_info, sizeof(tcp_info));
    }

    if(container_info_set && pe->container_info_set
       && container_info.id && pe->container_info.id
       && strcmp(container_info.id, pe->container_info.id)) {
      static bool warning_shown = false;

      if(!warning_shown) {
	ntop->getTrace()->traceEvent(TRACE_WARNING,
				     "The same flow has been observed across multiple containers. "
				     "[current_container: %s][additional_container: %s]",
				     container_info.id,
				     pe->container_info.id);
	warning_shown = true;
      }
    }
  }
}

/* *************************************** */

bool ParsedeBPF::isServerInfo() const {
  return (event_type == ebpf_event_type_tcp_accept && !server_info)
    || server_info;
}

/* *************************************** */

void ParsedeBPF::print() {
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[event_type: %s]", Utils::eBPFEvent2EventStr(event_type));
 }
