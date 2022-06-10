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

#include "ntop_includes.h"

/* *************************************** */

ParsedeBPF::ParsedeBPF() {
  ifname = NULL;

  event_type = ebpf_event_type_unknown;

  process_info_set = container_info_set = tcp_info_set = false;
  memset(&src_process_info, 0, sizeof(src_process_info));
  memset(&dst_process_info, 0, sizeof(dst_process_info));
  memset(&src_container_info, 0, sizeof(src_container_info));
  memset(&dst_container_info, 0, sizeof(dst_container_info));
  memset(&src_tcp_info, 0, sizeof(src_tcp_info));
  memset(&dst_tcp_info, 0, sizeof(dst_tcp_info));

  server_info = false;
}

/* *************************************** */

ParsedeBPF::ParsedeBPF(const ParsedeBPF &pe) {
  ifname = NULL;
  memcpy(&src_process_info, &pe.src_process_info, sizeof(src_process_info));
  memcpy(&dst_process_info, &pe.dst_process_info, sizeof(dst_process_info));
  memcpy(&src_container_info, &pe.src_container_info, sizeof(src_container_info));
  memcpy(&dst_container_info, &pe.dst_container_info, sizeof(dst_container_info));
  memcpy(&src_tcp_info, &pe.src_tcp_info, sizeof(src_tcp_info));
  memcpy(&dst_tcp_info, &pe.dst_tcp_info, sizeof(dst_tcp_info));

  event_type = pe.event_type;

  if(pe.ifname) ifname = strdup(pe.ifname);

  process_info_set = pe.process_info_set;

  if(src_process_info.process_name)        src_process_info.process_name = strdup(src_process_info.process_name);
  if(src_process_info.cmd_line)            src_process_info.cmd_line = strdup(src_process_info.cmd_line);
  if(src_process_info.uid_name)            src_process_info.uid_name = strdup(src_process_info.uid_name);
  if(src_process_info.father_process_name) src_process_info.father_process_name = strdup(src_process_info.father_process_name);
  if(src_process_info.father_uid_name)     src_process_info.father_uid_name = strdup(src_process_info.father_uid_name);
  if(dst_process_info.process_name)        dst_process_info.process_name = strdup(dst_process_info.process_name);
  if(dst_process_info.cmd_line)            dst_process_info.cmd_line = strdup(dst_process_info.cmd_line);
  if(dst_process_info.uid_name)            dst_process_info.uid_name = strdup(dst_process_info.uid_name);
  if(dst_process_info.father_process_name) dst_process_info.father_process_name = strdup(dst_process_info.father_process_name);
  if(dst_process_info.father_uid_name)     dst_process_info.father_uid_name = strdup(dst_process_info.father_uid_name);

  container_info_set = pe.container_info_set;

  if(src_container_info.id)   src_container_info.id = strdup(src_container_info.id);
  if(src_container_info.name) src_container_info.name = strdup(src_container_info.name);

  if(src_container_info.data_type == container_info_data_type_k8s) {
    if(src_container_info.data.k8s.pod) src_container_info.data.k8s.pod = strdup(src_container_info.data.k8s.pod);
    if(src_container_info.data.k8s.ns)  src_container_info.data.k8s.ns = strdup(src_container_info.data.k8s.ns);
  } else if(src_container_info.data_type == container_info_data_type_docker)
    ;

  if(dst_container_info.id)   dst_container_info.id = strdup(dst_container_info.id);
  if(dst_container_info.name) dst_container_info.name = strdup(dst_container_info.name);

  if(dst_container_info.data_type == container_info_data_type_k8s) {
    if(dst_container_info.data.k8s.pod) dst_container_info.data.k8s.pod = strdup(dst_container_info.data.k8s.pod);
    if(dst_container_info.data.k8s.ns)  dst_container_info.data.k8s.ns = strdup(dst_container_info.data.k8s.ns);
  } else if(dst_container_info.data_type == container_info_data_type_docker)
    ;

  tcp_info_set = pe.tcp_info_set;

  server_info = pe.server_info;
}

/* *************************************** */

ParsedeBPF::~ParsedeBPF() {
  if(ifname) free(ifname);

  if(src_process_info.process_name)        free(src_process_info.process_name);
  if(src_process_info.cmd_line)            free(src_process_info.cmd_line);
  if(src_process_info.uid_name)            free(src_process_info.uid_name);
  if(src_process_info.father_process_name) free(src_process_info.father_process_name);
  if(src_process_info.father_uid_name)     free(src_process_info.father_uid_name);

  if(dst_process_info.process_name)        free(dst_process_info.process_name);
  if(dst_process_info.cmd_line)            free(dst_process_info.cmd_line);
  if(dst_process_info.uid_name)            free(dst_process_info.uid_name);
  if(dst_process_info.father_process_name) free(dst_process_info.father_process_name);
  if(dst_process_info.father_uid_name)     free(dst_process_info.father_uid_name);

  if(src_container_info.id)   free(src_container_info.id);
  if(src_container_info.name) free(src_container_info.name);

  if(src_container_info.data_type == container_info_data_type_k8s) {
    if(src_container_info.data.k8s.pod) free(src_container_info.data.k8s.pod);
    if(src_container_info.data.k8s.ns)  free(src_container_info.data.k8s.ns);
  }
  else if(src_container_info.data_type == container_info_data_type_docker)
    ;

  if(dst_container_info.id)   free(dst_container_info.id);
  if(dst_container_info.name) free(dst_container_info.name);

  if(dst_container_info.data_type == container_info_data_type_k8s) {
    if(dst_container_info.data.k8s.pod) free(dst_container_info.data.k8s.pod);
    if(dst_container_info.data.k8s.ns)  free(dst_container_info.data.k8s.ns);
  }
  else if(dst_container_info.data_type == container_info_data_type_docker)
    ;
}

/* *************************************** */

bool ParsedeBPF::update(const ParsedeBPF * const pe) {
  /* Update tcp stats */
  if(pe) {
    if(container_info_set && pe->container_info_set && (
       (src_container_info.id && pe->src_container_info.id && strcmp(src_container_info.id, pe->src_container_info.id) != 0) ||
       (dst_container_info.id && pe->dst_container_info.id && strcmp(dst_container_info.id, pe->dst_container_info.id) != 0)
      )) {
      /* Clash! attempting to update info for a different container */
      static bool warning_shown = false;

      if(!warning_shown) {
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Attempting to update container info for a different container.");
	warning_shown = true;
      }

      return false;
    }

    if(pe->tcp_info_set) {
      if(!tcp_info_set) tcp_info_set = true;
      memcpy(&src_tcp_info, &pe->src_tcp_info, sizeof(src_tcp_info));
      memcpy(&dst_tcp_info, &pe->dst_tcp_info, sizeof(dst_tcp_info));
    }
  }

  return true;
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

/* *************************************** */

void ParsedeBPF::getProcessInfoJSONObject(const ProcessInfo *proc, json_object *proc_object) const {
  json_object_object_add(proc_object, "PID", json_object_new_int64(proc->pid));
  json_object_object_add(proc_object, "NAME", json_object_new_string(proc->process_name ? proc->process_name : ""));
  json_object_object_add(proc_object, "CMDLINE", json_object_new_string(proc->cmd_line ? proc->cmd_line : ""));
  json_object_object_add(proc_object, "UID", json_object_new_int64(proc->uid));
  json_object_object_add(proc_object, "GID", json_object_new_int64(proc->gid));
  json_object_object_add(proc_object, "ACTUAL_MEMORY", json_object_new_int64(proc->actual_memory));
  json_object_object_add(proc_object, "PEAK_MEMORY", json_object_new_int64(proc->peak_memory));
  json_object_object_add(proc_object, "USER_NAME", json_object_new_string(proc->uid_name ? proc->uid_name : ""));

  if(proc->father_pid > 0) {
    json_object_object_add(proc_object, "FATHER_PID", json_object_new_int64(proc->father_pid));
    json_object_object_add(proc_object, "FATHER_NAME", json_object_new_string(proc->father_process_name ? proc->father_process_name : ""));
    json_object_object_add(proc_object, "FATHER_UID", json_object_new_int64(proc->father_uid));
    json_object_object_add(proc_object, "FATHER_GID", json_object_new_int64(proc->father_gid));
    json_object_object_add(proc_object, "FATHER_USER_NAME", json_object_new_string(proc->father_uid_name ? proc->father_uid_name : ""));
  }
}

/* *************************************** */

void ParsedeBPF::getContainerInfoJSONObject(const ContainerInfo *cont, json_object *cont_object) const {
  if(cont->id) json_object_object_add(cont_object, "ID", json_object_new_string(cont->id));

  if(cont->data_type == container_info_data_type_k8s) {
    if(cont->name)         json_object_object_add(cont_object, "K8S_NAME", json_object_new_string(cont->name));
    if(cont->data.k8s.pod) json_object_object_add(cont_object, "K8S_POD", json_object_new_string(cont->data.k8s.pod));
    if(cont->data.k8s.ns)  json_object_object_add(cont_object, "K8S_NS", json_object_new_string(cont->data.k8s.ns));
  } else if(cont->data_type == container_info_data_type_docker) {
    if(cont->name) json_object_object_add(cont_object, "DOCKER_NAME", json_object_new_string(cont->name));
  }
}

/* *************************************** */

void ParsedeBPF::getTCPInfoJSONObject(const TcpInfo *tcp, json_object *tcp_object) const {
  json_object_object_add(tcp_object, "RTT", json_object_new_double(tcp->rtt));
  json_object_object_add(tcp_object, "RTT_VAR", json_object_new_double(tcp->rtt_var));
}

/* *************************************** */

void ParsedeBPF::getJSONObject(json_object *my_object) const {
  const ProcessInfo *proc;
  const ContainerInfo *cont;
  const TcpInfo *tcp;

  if(process_info_set && src_process_info.pid > 0) {
    json_object *proc_object = json_object_new_object();
    if (proc_object) {
      proc = &src_process_info;
      getProcessInfoJSONObject(proc, proc_object);    
      json_object_object_add(my_object, "CLIENT_PROCESS", proc_object);
    }
  }

  if(process_info_set && dst_process_info.pid > 0) {
    json_object *proc_object = json_object_new_object();
    if (proc_object) {
      proc = &dst_process_info;
      getProcessInfoJSONObject(proc, proc_object);    
      json_object_object_add(my_object, "SERVER_PROCESS", proc_object);
    }
  }

  if(container_info_set) {
    json_object *cont_object;

    cont_object = json_object_new_object();
    if (cont_object) {
      cont = &src_container_info;
      getContainerInfoJSONObject(cont, cont_object);
      json_object_object_add(my_object, "CLIENT_CONTAINER", cont_object);
    }

    cont_object = json_object_new_object();
    if (cont_object) {
      cont = &dst_container_info;
      getContainerInfoJSONObject(cont, cont_object);
      json_object_object_add(my_object, "SERVER_CONTAINER", cont_object);
    }
  }

  if(tcp_info_set) {
    json_object *tcp_object;

    tcp_object = json_object_new_object();
    if (tcp_object) {
      tcp = &src_tcp_info;
      getTCPInfoJSONObject(tcp, tcp_object);
      json_object_object_add(my_object, "CLIENT_TCP_INFO", tcp_object);
    }

    tcp_object = json_object_new_object();
    if (tcp_object) {
      tcp = &src_tcp_info;
      getTCPInfoJSONObject(tcp, tcp_object);
      json_object_object_add(my_object, "SERVER_TCP_INFO", tcp_object);
    }
  }
}

/* *************************************** */

void ParsedeBPF::processInfoLua(lua_State *vm, const ProcessInfo *proc) const {
  lua_push_uint64_table_entry(vm, "pid", proc->pid);
  lua_push_str_table_entry(vm, "name", proc->process_name ? proc->process_name : "");
  lua_push_str_table_entry(vm, "cmdline", proc->cmd_line ? proc->cmd_line : "");
  lua_push_uint64_table_entry(vm, "uid", proc->uid);
  lua_push_uint64_table_entry(vm, "gid", proc->gid);
  lua_push_uint64_table_entry(vm, "actual_memory", proc->actual_memory);
  lua_push_uint64_table_entry(vm, "peak_memory", proc->peak_memory);
  lua_push_str_table_entry(vm, "user_name", proc->uid_name ? proc->uid_name : "");

  if(proc->father_pid > 0) {
    lua_push_uint64_table_entry(vm, "father_pid", proc->father_pid);
    lua_push_uint64_table_entry(vm, "father_uid", proc->father_uid);
    lua_push_uint64_table_entry(vm, "father_gid", proc->father_gid);
    lua_push_str_table_entry(vm, "father_name", proc->father_process_name ? proc->father_process_name : "");
    lua_push_str_table_entry(vm, "father_user_name", proc->father_uid_name ? proc->father_uid_name : "");
  }
}

/* *************************************** */

void ParsedeBPF::lua(lua_State *vm) const{
  const ProcessInfo * proc;
  const ContainerInfo * cont;
  const TcpInfo * tcp;

  if(process_info_set && src_process_info.pid > 0) {
    lua_newtable(vm);
    proc = &src_process_info;
    processInfoLua(vm, proc);
    lua_pushstring(vm, "client_process");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }

  if(process_info_set && dst_process_info.pid > 0) {
    lua_newtable(vm);
    proc = &dst_process_info;
    processInfoLua(vm, proc);
    lua_pushstring(vm, "server_process");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }

  if(container_info_set) {
    cont = &src_container_info;
    Utils::containerInfoLua(vm, cont);
    lua_pushstring(vm, "client_container");
    lua_insert(vm, -2);
    lua_settable(vm, -3);

    cont = &dst_container_info;
    Utils::containerInfoLua(vm, cont);
    lua_pushstring(vm, "server_container");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }

  if(tcp_info_set) {
    lua_newtable(vm);
    tcp = &src_tcp_info;
    lua_push_float_table_entry(vm, "rtt", tcp->rtt);
    lua_push_float_table_entry(vm, "rtt_var", tcp->rtt_var);
    lua_pushstring(vm, "client_tcp_info");
    lua_insert(vm, -2);
    lua_settable(vm, -3);

    lua_newtable(vm);
    tcp = &dst_tcp_info;
    lua_push_float_table_entry(vm, "rtt", tcp->rtt);
    lua_push_float_table_entry(vm, "rtt_var", tcp->rtt_var);
    lua_pushstring(vm, "server_tcp_info");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}
