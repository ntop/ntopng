/*
 *
 * (C) 2013-22 - ntop.org
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

 public:
  ProcessInfo src_process_info, dst_process_info;
  ContainerInfo src_container_info, dst_container_info;
  TcpInfo src_tcp_info, dst_tcp_info;
  eBPFEventType event_type;
  char *ifname;
  bool process_info_set, container_info_set, tcp_info_set;

  ParsedeBPF();
  ParsedeBPF(const ParsedeBPF &pe, bool swap_directions);
  virtual ~ParsedeBPF();

  inline void swap() { server_info = !server_info; };	

  bool update(const ParsedeBPF * const pe);
  bool isServerInfo() const;
  void print();

  void getJSONObject(json_object *my_object) const;
  void getProcessInfoJSONObject(const ProcessInfo *proc, json_object *proc_object) const;
  void getContainerInfoJSONObject(const ContainerInfo *cont, json_object *proc_object) const;
  void getTCPInfoJSONObject(const TcpInfo *tcp, json_object *proc_object) const;

  void lua(lua_State *vm) const;
  void processInfoLua(lua_State *vm, const ProcessInfo *proc) const;
};

#endif /* _PARSED_EBPF_H_ */
