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

eBPFFlow::eBPFFlow(ParsedFlow * const pf) : ParsedFlowCore(), ParsedeBPF() {
  if((process_info_set = pf->process_info_set)) {
    if(pf->process_info.process_name)        pf->process_info.process_name = strdup(pf->process_info.process_name);
    if(pf->process_info.father_process_name) pf->process_info.father_process_name = strdup(pf->process_info.father_process_name);
  }

  if((container_info_set = pf->container_info_set)) {
    if(pf->container_info.id)   pf->container_info.id = strdup(pf->container_info.id);
    if(pf->container_info.name) pf->container_info.name = strdup(pf->container_info.name);

    if(pf->container_info.data_type == container_info_data_type_k8s) {
      if(pf->container_info.data.k8s.pod) pf->container_info.data.k8s.pod = strdup(pf->container_info.data.k8s.pod);
      if(pf->container_info.data.k8s.ns)  pf->container_info.data.k8s.ns = strdup(pf->container_info.data.k8s.ns);
    } else if(pf->container_info.data_type == container_info_data_type_docker)
      ;
  }

  if((tcp_info_set = pf->tcp_info_set)) {
    memcpy(&tcp_info, &pf->tcp_info, sizeof(tcp_info));
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
