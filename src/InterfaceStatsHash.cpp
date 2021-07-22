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

/* ************************************ */

InterfaceStatsHash::InterfaceStatsHash(u_int _max_hash_size) {
  max_hash_size = _max_hash_size;
  buckets = (sFlowInterfaceStats**)calloc(sizeof(sFlowInterfaceStats*), max_hash_size);

  if(buckets == NULL)
    throw "Not enough memory";
}

/* ************************************ */

InterfaceStatsHash::~InterfaceStatsHash() {
  for(u_int i=0; i<max_hash_size; i++) {
    if(buckets[i] != NULL) {
      if(buckets[i]->ifName) free(buckets[i]->ifName);

      if(buckets[i]->container_info_set) {
	if(buckets[i]->container_info.id)   free(buckets[i]->container_info.id);
	if(buckets[i]->container_info.name) free(buckets[i]->container_info.name);

	if(buckets[i]->container_info.data_type == container_info_data_type_k8s) {
	  if(buckets[i]->container_info.data.k8s.pod)     free(buckets[i]->container_info.data.k8s.pod);
	  if(buckets[i]->container_info.data.k8s.ns)      free(buckets[i]->container_info.data.k8s.ns);
	} else if(buckets[i]->container_info.data_type == container_info_data_type_docker)
	  ;
      }

      free(buckets[i]);
    }
  }

  free(buckets);
}
/* ************************************ */

bool InterfaceStatsHash::set(const sFlowInterfaceStats * const stats) {
  u_int32_t ifIndex = stats->ifIndex, deviceIP = stats->deviceIP;
  const char * ifName = stats->ifName;
  u_int32_t hash = (deviceIP + ifIndex + Utils::hashString(ifName)) % max_hash_size, num_runs = 0;
  bool ret = true;

  m.lock(__FILE__, __LINE__);
  
  if(!buckets[hash])
    goto new_bucket;
  else {
    sFlowInterfaceStats *head;

    head = (sFlowInterfaceStats*)buckets[hash];
    
    while(head != NULL) {      
      if(head->deviceIP == deviceIP
	 && head->ifIndex == ifIndex
	 && ((!head->ifName && !ifName)
	     || (head->ifName && ifName && !strcmp(head->ifName, ifName))))
	break;
      else {
	/* Inplace hash */
	hash = (hash + 1) % max_hash_size, num_runs++;

	if(num_runs >= max_hash_size) {
	  ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: too many loops=%u", max_hash_size);
	  m.unlock(__FILE__, __LINE__);
	  return(false);
	}

	head = buckets[hash];
      }
    }

    if(head) {
      /* Update values */
      head->ifType = stats->ifType, head->ifSpeed = stats->ifSpeed,
	head->ifFullDuplex = stats->ifFullDuplex, head->ifAdminStatus = stats->ifAdminStatus,
	head->ifOperStatus = stats->ifOperStatus, head->ifPromiscuousMode = stats->ifPromiscuousMode,
	head->ifInOctets = stats->ifInOctets, head->ifInPackets = stats->ifInPackets,
	head->ifInErrors = stats->ifInErrors, head->ifOutOctets = stats->ifOutOctets,
	head->ifOutPackets = stats->ifOutPackets, head->ifOutErrors = stats->ifOutErrors;
    } else {
    new_bucket:
      buckets[hash] = (sFlowInterfaceStats*)malloc(sizeof(sFlowInterfaceStats));
      if(buckets[hash]) {
	memcpy(buckets[hash], stats, sizeof(sFlowInterfaceStats));

	if(buckets[hash]->ifName) buckets[hash]->ifName = strdup(buckets[hash]->ifName);

	if(buckets[hash]->container_info_set) {
	  if(buckets[hash]->container_info.id)   buckets[hash]->container_info.id = strdup(buckets[hash]->container_info.id);
	  if(buckets[hash]->container_info.name) buckets[hash]->container_info.name = strdup(buckets[hash]->container_info.name);

	  if(buckets[hash]->container_info.data_type == container_info_data_type_k8s) {
	    if(buckets[hash]->container_info.data.k8s.pod)  buckets[hash]->container_info.data.k8s.pod = strdup(buckets[hash]->container_info.data.k8s.pod);
	    if(buckets[hash]->container_info.data.k8s.ns)   buckets[hash]->container_info.data.k8s.ns = strdup(buckets[hash]->container_info.data.k8s.ns);
	  } else if(buckets[hash]->container_info.data_type == container_info_data_type_docker)
	    ;
	}

      } else
	ret = false;
    }
  }

  m.unlock(__FILE__, __LINE__);
  
  return(ret);
}

/* ************************************ */

void InterfaceStatsHash::luaDeviceList(lua_State *vm) {
  std::set<u_int32_t> flowDevices; /* Set size automatically limited by max_hash_size */
  std::set<u_int32_t>::const_iterator it;

  lua_newtable(vm);

  m.lock(__FILE__, __LINE__);

  for(u_int i=0; i<max_hash_size; i++) {
    sFlowInterfaceStats *head = (sFlowInterfaceStats*)buckets[i];
    
    if(head) {
      bool found = false;

      if(flowDevices.find(head->deviceIP) != flowDevices.end())
	found = true;

      if(!found) {
	char a[64];

	flowDevices.insert(head->deviceIP);

	lua_push_uint64_table_entry(vm, 
				    Utils::intoaV4(head->deviceIP, a, sizeof(a)),
				    head->deviceIP);
      }
    }
  }

  m.unlock(__FILE__, __LINE__);
}

/* ************************************ */

void InterfaceStatsHash::luaDeviceInfo(lua_State *vm, u_int32_t deviceIP) {
  lua_newtable(vm);

  m.lock(__FILE__, __LINE__);

  for(u_int i=0; i<max_hash_size; i++) {
    sFlowInterfaceStats *head = (sFlowInterfaceStats*)buckets[i];
    
    if(head && (head->deviceIP == deviceIP)) {
      lua_newtable(vm);      
      
      lua_push_uint64_table_entry(vm, "ifType", head->ifType);
      if(head->ifName)
	lua_push_str_table_entry(vm, "ifName", head->ifName);
      if(head->container_info_set) {
	Utils::containerInfoLua(vm, &head->container_info);

	lua_pushstring(vm, "container");
	lua_insert(vm, -2);
	lua_settable(vm, -3);
      }
      lua_push_uint64_table_entry(vm, "ifSpeed", head->ifSpeed);
      lua_push_bool_table_entry(vm, "ifFullDuplex", head->ifFullDuplex);
      lua_push_bool_table_entry(vm, "ifAdminStatus", head->ifAdminStatus);
      lua_push_bool_table_entry(vm, "ifOperStatus", head->ifOperStatus);
      lua_push_bool_table_entry(vm, "ifPromiscuousMode", head->ifPromiscuousMode);
      lua_push_uint64_table_entry(vm, "ifInOctets", head->ifInOctets);
      lua_push_uint64_table_entry(vm, "ifInPackets", head->ifInPackets);
      lua_push_uint64_table_entry(vm, "ifInErrors", head->ifInErrors);
      lua_push_uint64_table_entry(vm, "ifOutOctets", head->ifOutOctets);
      lua_push_uint64_table_entry(vm, "ifOutPackets", head->ifOutPackets);
      lua_push_uint64_table_entry(vm, "ifOutErrors", head->ifOutErrors);

      lua_pushinteger(vm, head->ifIndex);
      lua_insert(vm, -2);
      lua_settable(vm, -3);
    }
  }

  m.unlock(__FILE__, __LINE__);
}
