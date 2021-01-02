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


ArpStatsHashMatrix::ArpStatsHashMatrix(NetworkInterface *_iface,
				       u_int _num_hashes, u_int _max_hash_size) :
  GenericHash(_iface, _num_hashes, _max_hash_size, "ArpStatsHashMatrix") {
  ;
}

/* ************************************ */

ArpStatsMatrixElement* ArpStatsHashMatrix::get(const u_int8_t _src_mac[6],
					       const u_int32_t _src_ip, const u_int32_t _dst_ip,
					       bool * const src2dst) {
  u_int32_t hash = (_src_ip + _dst_ip) % num_hashes;
  
  if(table[hash] == NULL) {
    return(NULL);    
  } else {
    ArpStatsMatrixElement *head;
    
    locks[hash]->wrlock(__FILE__, __LINE__);
    head = (ArpStatsMatrixElement*)table[hash];
    
    while(head != NULL) {
      if((!head->idle()) && head->equal(_src_mac, _src_ip, _dst_ip, src2dst))	
	break;
      else
	head = (ArpStatsMatrixElement*)head->next();
    }
    
    locks[hash]->unlock(__FILE__, __LINE__);
    
    return(head);
  }  
}

/* ************************************ */

typedef struct {
  lua_State* vm;
  u_int64_t entry_id;
} print_all_arp_stats_data_t;

/* ************************************ */

static bool print_all_arp_stats(GenericHashEntry *e, void *user_data, bool *matched) {
  ArpStatsMatrixElement *elem = (ArpStatsMatrixElement*)e;
  print_all_arp_stats_data_t * print_all_arp_stats_data = (print_all_arp_stats_data_t*) user_data;
  lua_State* vm = print_all_arp_stats_data->vm;

  if(elem && vm) {
    lua_newtable(vm);

    elem->lua(vm);

    lua_pushinteger(vm, ++print_all_arp_stats_data->entry_id);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }

  return(false); /* false = keep on walking */
}

/* ************************************ */

void ArpStatsHashMatrix::lua(lua_State* vm) {
  u_int32_t begin_slot = 0;
  print_all_arp_stats_data_t print_all_arp_stats_data;

  print_all_arp_stats_data.vm = vm;
  print_all_arp_stats_data.entry_id = 0;

  walk(&begin_slot, true, print_all_arp_stats, &print_all_arp_stats_data);
}
