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

eBPFFlow::eBPFFlow(ParsedFlow * const pf) : ParsedFlowCore() {
  if(ebpf.process_info_set) {
    if(ebpf.process_info.process_name)        ebpf.process_info.process_name = strdup(ebpf.process_info.process_name);
    if(ebpf.process_info.father_process_name) ebpf.process_info.father_process_name = strdup(ebpf.process_info.father_process_name);
  }

  if(ebpf.container_info_set) {
    if(ebpf.container_info.id)   ebpf.container_info.id = strdup(ebpf.container_info.id);
    if(ebpf.container_info.name) ebpf.container_info.name = strdup(ebpf.container_info.name);

    if(ebpf.container_info.data_type == container_info_data_type_k8s) {
      if(ebpf.container_info.data.k8s.pod) ebpf.container_info.data.k8s.pod = strdup(ebpf.container_info.data.k8s.pod);
      if(ebpf.container_info.data.k8s.ns)  ebpf.container_info.data.k8s.ns = strdup(ebpf.container_info.data.k8s.ns);
    } else if(ebpf.container_info.data_type == container_info_data_type_docker)
      ;
  }
}

/* *************************************** */

eBPFFlow::~eBPFFlow() {
  if(ebpf.process_info_set) {
    if(ebpf.process_info.process_name)        free(ebpf.process_info.process_name);
    if(ebpf.process_info.father_process_name) free(ebpf.process_info.father_process_name);
  }

  if(ebpf.container_info_set) {
    if(ebpf.container_info.id)   free(ebpf.container_info.id);
    if(ebpf.container_info.name) free(ebpf.container_info.name);

    if(ebpf.container_info.data_type == container_info_data_type_k8s) {
      if(ebpf.container_info.data.k8s.pod) free(ebpf.container_info.data.k8s.pod);
      if(ebpf.container_info.data.k8s.ns)  free(ebpf.container_info.data.k8s.ns);
    } else if(ebpf.container_info.data_type == container_info_data_type_docker)
      ;
  }
}

/* *************************************** */

void eBPFFlow::print() {
  char buf1[32], buf2[32];

  src_ip.print(buf1, sizeof(buf1));
  dst_ip.print(buf2, sizeof(buf2));

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[src: %s][dst: %s][src_port: %u][dst_port: %u][event: %s]",
			       src_ip.print(buf1, sizeof(buf1)),
			       dst_ip.print(buf2, sizeof(buf2)),
			       ntohs(get_cli_port()), ntohs(get_srv_port()),
			       Utils::eBPFEvent2EventStr(ebpf.event_type));
}
