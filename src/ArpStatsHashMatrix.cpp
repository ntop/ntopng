
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

/* ************************************ */

ArpStatsHashMatrix::ArpStatsHashMatrix(NetworkInterface *_iface, u_int _num_hashes, u_int _max_hash_size) :
  GenericHash(_iface, _num_hashes, _max_hash_size, "ArpStatsHashMatrix") {
  ;
}

/* ************************************ */

ArpStatsMatrixElement* ArpStatsHashMatrix::get(const u_int8_t _src_mac[6], const u_int8_t _dst_mac[6]) {
  if(_src_mac == NULL ||  _dst_mac == NULL)
    return(NULL);
  else {

    u_int32_t hash = Utils::macHash((u_int8_t*)_src_mac) + Utils::macHash((u_int8_t*) _dst_mac);
    hash %= num_hashes;

    if(table[hash] == NULL) {
      return(NULL);

      //andrebbe qui il controllo per l'"inverso"

    } else {
    
      ArpStatsMatrixElement *head;

      locks[hash]->lock(__FILE__, __LINE__);
      head = (ArpStatsMatrixElement*)table[hash];

      while(head != NULL) {
        if((!head->idle()) && head->equal(_src_mac, _dst_mac) )//TODO: test!!!!!!!!!!
        
          break;
        else
          head = (ArpStatsMatrixElement*)head->next();
      }
    
      locks[hash]->unlock(__FILE__, __LINE__);
    
      return(head);
    }
  }
}

/*

#ifdef ARP_STATS_MATRIX_ELEMENT_DEBUG

static bool printMAtrixElement(GenericHashEntry *_elem, void *user_data) {

  //TODO: controlla Country, Mac e GenericHashEntry
}



void CountriesHash::printHash() { //TODO: finisci e test
  disablePurge();

  walk(printMatrixElement, NULL);
  
  enablePurge();
}

#endif 

*/
