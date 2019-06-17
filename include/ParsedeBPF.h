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

#ifndef _PARSED_EBPF_H_
#define _PARSED_EBPF_H_

#include "ntop_includes.h"

class ParsedeBPF {
 private:
  bool server_info;
  bool free_memory;

 public:
  ProcessInfo process_info;
  ContainerInfo container_info;
  TcpInfo tcp_info;
  eBPFEventType event_type;
  char *ifname;
  bool process_info_set, container_info_set, tcp_info_set;

  ParsedeBPF();
  ParsedeBPF(const ParsedeBPF &pe);
  virtual ~ParsedeBPF();

  inline void swap() { server_info = !server_info; };	

  void update(const ParsedeBPF * const pe);
  bool isServerInfo() const;
  void print();

};

#endif /* _PARSED_EBPF_H_ */
