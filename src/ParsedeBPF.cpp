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
}
/* *************************************** */

ParsedeBPF::ParsedeBPF(const ParsedeBPF &pe) {
}

/* *************************************** */

ParsedeBPF::~ParsedeBPF() {
}

/* *************************************** */

void ParsedeBPF::print() {
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[event_type: %s]", Utils::eBPFEvent2EventStr(event_type));
 }
