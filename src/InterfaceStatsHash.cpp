/*
 *
 * (C) 2013-18 - ntop.org
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
  for(u_int i=0; i<max_hash_size; i++)
    if(buckets[i] != NULL) free(buckets[i]);

  free(buckets);
}
/* ************************************ */

bool InterfaceStatsHash::set(u_int32_t deviceIP, u_int32_t ifIndex, sFlowInterfaceStats *stats) {
  u_int32_t hash = (deviceIP+ifIndex) % max_hash_size, num_runs = 0;
  bool ret = true;

  m.lock(__FILE__, __LINE__);
  
  if(buckets[hash] == NULL) {
    buckets[hash] = (sFlowInterfaceStats*)malloc(sizeof(sFlowInterfaceStats));
    if(buckets[hash])
      memcpy(buckets[hash], stats, sizeof(sFlowInterfaceStats));
    else
      ret = false;
    m.unlock(__FILE__, __LINE__);
    return(ret);
  } else {
    sFlowInterfaceStats *head;

    head = (sFlowInterfaceStats*)buckets[hash];
    
    while(head != NULL) {      
      if((head->deviceIP == deviceIP) && (head->ifIndex == ifIndex))
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
      /* Overwrite value */
      memcpy(head, stats, sizeof(sFlowInterfaceStats));      
    } else {
      buckets[hash] = (sFlowInterfaceStats*)malloc(sizeof(sFlowInterfaceStats));
      if(buckets[hash])
	memcpy(buckets[hash], stats, sizeof(sFlowInterfaceStats));
      else
	ret = false;
    }

    m.unlock(__FILE__, __LINE__);

    return(ret);
  }
}

/* ************************************ */

bool InterfaceStatsHash::get(u_int32_t deviceIP, u_int32_t ifIndex, sFlowInterfaceStats *stats) {
  u_int32_t hash = (deviceIP+ifIndex) % max_hash_size, num_runs = 0;

  if(buckets[hash] == NULL) {
    return(false);
  } else {
    sFlowInterfaceStats *head;

    m.lock(__FILE__, __LINE__);
    head = (sFlowInterfaceStats*)buckets[hash];
    
    while(head != NULL) {      
      if((head->deviceIP == deviceIP) && (head->ifIndex == ifIndex)) {
	memcpy(stats, head, sizeof(sFlowInterfaceStats));
	break;
      } else {
	/* Inplace hash */
	hash = (hash + 1) % max_hash_size, num_runs++;

	if(num_runs >= max_hash_size) {
	  m.unlock(__FILE__, __LINE__);
	  return(false);
	}

	head = buckets[hash];
      }
    }

    m.unlock(__FILE__, __LINE__);

    return(false);
  }
}

/* ************************************ */

void InterfaceStatsHash::luaDeviceList(lua_State *vm) {
  u_int32_t flowDevices[MAX_NUM_FLOW_DEVICES] = { 0 };
  u_int16_t numDevices = 0;

  lua_newtable(vm);

  m.lock(__FILE__, __LINE__);

  for(u_int i=0; i<max_hash_size; i++) {
    sFlowInterfaceStats *head = (sFlowInterfaceStats*)buckets[i];
    
    if(head) {
      bool found = false;
      
      for(int j=0; j<numDevices; j++) {
	if(flowDevices[j] == head->deviceIP) {
	  found = true;
	  break;
	}
      }
      
      if(!found) {
	char a[64];
	
	flowDevices[numDevices++] = head->deviceIP;
	
	if(numDevices == MAX_NUM_FLOW_DEVICES) {
	  ntop->getTrace()->traceEvent(TRACE_WARNING,
				       "Internal error: too many devices %u",
				       numDevices);
	  break;
	}

	lua_push_int_table_entry(vm, 
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
      
      lua_push_int_table_entry(vm, "ifType", head->ifType);
      lua_push_int_table_entry(vm, "ifSpeed", head->ifSpeed);
      lua_push_bool_table_entry(vm, "ifFullDuplex", head->ifFullDuplex);
      lua_push_bool_table_entry(vm, "ifAdminStatus", head->ifAdminStatus);
      lua_push_bool_table_entry(vm, "ifOperStatus", head->ifOperStatus);
      lua_push_bool_table_entry(vm, "ifPromiscuousMode", head->ifPromiscuousMode);
      lua_push_int_table_entry(vm, "ifInOctets", head->ifInOctets);
      lua_push_int_table_entry(vm, "ifInPackets", head->ifInPackets);
      lua_push_int_table_entry(vm, "ifInErrors", head->ifInErrors);
      lua_push_int_table_entry(vm, "ifOutOctets", head->ifOutOctets);
      lua_push_int_table_entry(vm, "ifOutPackets", head->ifOutPackets);
      lua_push_int_table_entry(vm, "ifOutErrors", head->ifOutErrors);

      lua_pushinteger(vm, head->ifIndex);
      lua_insert(vm, -2);
      lua_settable(vm, -3);
    }
  }

  m.unlock(__FILE__, __LINE__);
}
