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


ArpStatsHashMatrix::ArpStatsHashMatrix(NetworkInterface *_iface, u_int _num_hashes, u_int _max_hash_size) :
  GenericHash(_iface, _num_hashes, _max_hash_size, "ArpStatsHashMatrix") {
  ;
}

/* ************************************ */
//this get function DO NOT reverse the snd / rcv counters in case src_mac and dst_mac are reversed
ArpStatsMatrixElement* ArpStatsHashMatrix::get(const u_int8_t _src_mac[6], const u_int8_t _dst_mac[6]) {
  if(_src_mac == NULL ||  _dst_mac == NULL)
    return(NULL);
  else {
    u_int32_t hash = Utils::macHash((u_int8_t*)_src_mac) + Utils::macHash((u_int8_t*) _dst_mac);
    hash %= num_hashes;

    if(table[hash] == NULL) {
      return(NULL);

    } else {
      ArpStatsMatrixElement *head;

      locks[hash]->lock(__FILE__, __LINE__);
      head = (ArpStatsMatrixElement*)table[hash];

      while(head != NULL) {
        if((!head->idle()) && head->equal(_src_mac, _dst_mac))
        
          break;
        else
          head = (ArpStatsMatrixElement*)head->next();
      }
    
      locks[hash]->unlock(__FILE__, __LINE__);
    
      return(head);
    }
  }
}

/* ************************************ */

static bool print_all_arp_stats(GenericHashEntry *e, void *user_data, bool *matched) {
  ArpStatsMatrixElement *elem = (ArpStatsMatrixElement*)e;
  lua_State* vm = (lua_State*) user_data;

  //TODO: errors handling
  if(elem)
    elem->lua(vm);

  return(false); /* false = keep on walking */
}

/* ************************************ */

void ArpStatsHashMatrix::lua(lua_State* vm) {
  u_int32_t begin_slot = 0;

  walk(&begin_slot, true, print_all_arp_stats, vm);
}
