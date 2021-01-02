/*
 *
 * (C) 2013-21 - ntop.org
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

bool ParsedeBPF::update(const ParsedeBPF * const pe) {
  /* Update tcp stats */
  if(pe) {
    if(container_info_set && pe->container_info_set
       && container_info.id && pe->container_info.id
       && strcmp(container_info.id, pe->container_info.id)) {
      /* Clash! attempting to update info for a different container */
      static bool warning_shown = false;

      if(!warning_shown) {
	ntop->getTrace()->traceEvent(TRACE_WARNING,
				     "Attempting to update container %s using information from container %s.",
				     container_info.id,
				     pe->container_info.id);
	warning_shown = true;
      }

      return false;
    }

    if(pe->tcp_info_set) {
      if(!tcp_info_set) tcp_info_set = true;
      memcpy(&tcp_info, &pe->tcp_info, sizeof(tcp_info));
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

void ParsedeBPF::getJSONObject(json_object *my_object, bool client) const {
  const ProcessInfo * proc;
  const ContainerInfo * cont;
  const TcpInfo * tcp;
  json_object *proc_object = json_object_new_object(),
    *cont_object = json_object_new_object(),
    *tcp_object = json_object_new_object();

  if(proc_object && process_info_set && (proc = &process_info) && proc->pid > 0) {
    json_object_object_add(proc_object, "PID", json_object_new_int64(proc->pid));
    json_object_object_add(proc_object, "NAME", json_object_new_string(proc->process_name));
    json_object_object_add(proc_object, "UID", json_object_new_int64(proc->uid));
    json_object_object_add(proc_object, "GID", json_object_new_int64(proc->gid));
    json_object_object_add(proc_object, "ACTUAL_MEMORY", json_object_new_int64(proc->actual_memory));
    json_object_object_add(proc_object, "PEAK_MEMORY", json_object_new_int64(proc->peak_memory));
    json_object_object_add(proc_object, "USER_NAME", json_object_new_string(proc->uid_name));

    if(proc->father_pid > 0) {
      json_object_object_add(proc_object, "FATHER_PID", json_object_new_int64(proc->father_pid));
      json_object_object_add(proc_object, "FATHER_NAME", json_object_new_string(proc->father_process_name));
      json_object_object_add(proc_object, "FATHER_UID", json_object_new_int64(proc->father_uid));
      json_object_object_add(proc_object, "FATHER_GID", json_object_new_int64(proc->father_gid));
      json_object_object_add(proc_object, "FATHER_USER_NAME", json_object_new_string(proc->father_uid_name));
    }

    json_object_object_add(my_object, client ? "CLIENT_PROCESS" : "SERVER_PROCESS", proc_object);
  }

  if(cont_object && container_info_set && (cont = &container_info)) {
    if(cont->id) json_object_object_add(cont_object, "ID", json_object_new_string(cont->id));

    if(cont->data_type == container_info_data_type_k8s) {
      if(cont->name)         json_object_object_add(cont_object, "K8S_NAME", json_object_new_string(cont->name));
      if(cont->data.k8s.pod) json_object_object_add(cont_object, "K8S_POD", json_object_new_string(cont->data.k8s.pod));
      if(cont->data.k8s.ns)  json_object_object_add(cont_object, "K8S_NS", json_object_new_string(cont->data.k8s.ns));
    } else if(cont->data_type == container_info_data_type_docker) {
      if(cont->name) json_object_object_add(cont_object, "DOCKER_NAME", json_object_new_string(cont->name));
    }

    json_object_object_add(my_object, client ? "CLIENT_CONTAINER" : "SERVER_CONTAINER", cont_object);
  }

  if(tcp_object && tcp_info_set && (tcp = &tcp_info)) {
    json_object_object_add(tcp_object, "RTT", json_object_new_double(tcp->rtt));
    json_object_object_add(tcp_object, "RTT_VAR", json_object_new_double(tcp->rtt_var));

    json_object_object_add(my_object, client ? "CLIENT_TCP_INFO" : "SERVER_TCP_INFO", tcp_object);
  }
}

/* *************************************** */

void ParsedeBPF::lua(lua_State *vm, bool client) const{
  const ProcessInfo * proc;
  const ContainerInfo * cont;
  const TcpInfo * tcp;

  if(process_info_set && (proc = &process_info) && proc->pid > 0) {
    lua_newtable(vm);

    lua_push_uint64_table_entry(vm, "pid", proc->pid);
    lua_push_str_table_entry(vm, "name", proc->process_name);
    lua_push_uint64_table_entry(vm, "uid", proc->uid);
    lua_push_uint64_table_entry(vm, "gid", proc->gid);
    lua_push_uint64_table_entry(vm, "actual_memory", proc->actual_memory);
    lua_push_uint64_table_entry(vm, "peak_memory", proc->peak_memory);
    lua_push_str_table_entry(vm, "user_name", proc->uid_name);

    if(proc->father_pid > 0) {
      lua_push_uint64_table_entry(vm, "father_pid", proc->father_pid);
      lua_push_uint64_table_entry(vm, "father_uid", proc->father_uid);
      lua_push_uint64_table_entry(vm, "father_gid", proc->father_gid);
      lua_push_str_table_entry(vm, "father_name", proc->father_process_name);
      lua_push_str_table_entry(vm, "father_user_name", proc->father_uid_name);
    }

    lua_pushstring(vm, client ? "client_process" : "server_process");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }

  if(container_info_set && (cont = &container_info)) {
    Utils::containerInfoLua(vm, cont);

    lua_pushstring(vm, client ? "client_container" : "server_container");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }

  if(tcp_info_set && (tcp = &tcp_info)) {
    lua_newtable(vm);

    lua_push_float_table_entry(vm, "rtt", tcp->rtt);
    lua_push_float_table_entry(vm, "rtt_var", tcp->rtt_var);

    lua_pushstring(vm, client ? "client_tcp_info" : "server_tcp_info");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}
