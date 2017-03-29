/*
 *
 * (C) 2013-17 - ntop.org
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

ICMPstats::ICMPstats() {
  stats = NULL;
}

/* *************************************** */

ICMPstats::~ICMPstats() {
  ICMPstats_t *curr, *tmp;
  
  HASH_ITER(hh, stats, curr, tmp) {
    HASH_DEL(stats, curr);  /* delete it */
    free(curr);         /* free it */
  }
}

/* *************************************** */

void ICMPstats::incStats(u_int8_t icmp_type, u_int8_t icmp_code, bool sent) {
  ICMPstats_t *s = NULL;
  int key = get_typecode(icmp_type, icmp_code);

  m.lock(__FILE__, __LINE__);
  HASH_FIND_INT(stats, &key, s);
  
  if(!s) {
    if((s = (ICMPstats_t*)malloc(sizeof(ICMPstats_t))) != NULL) {
      s->type_code = key, s->pkt_sent = s->pkt_rcvd = 0;
      HASH_ADD_INT(stats, type_code, s);
    } else {
      m.unlock(__FILE__, __LINE__);
      return;
    }
  }

  if(sent) s->pkt_sent++; else s->pkt_rcvd++;

  m.unlock(__FILE__, __LINE__);
};

/* ******************************************************** */

static int key_sort(ICMPstats_t *a, ICMPstats_t *b) {
  return(a->type_code - b->type_code); /* inc sort */
}

/* *************************************** */

void ICMPstats::addToTable(const char *label, lua_State *vm, ICMPstats_t *curr) {
  lua_newtable(vm);
  lua_push_int_table_entry(vm, "sent", curr->pkt_sent);
  lua_push_int_table_entry(vm, "rcvd", curr->pkt_rcvd);
  lua_pushstring(vm, label);
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void ICMPstats::lua(bool isV4, lua_State *vm) {
  ICMPstats_t *curr, *tmp;
  char buf[64];
  
  m.lock(__FILE__, __LINE__);
  
  HASH_SORT(stats, key_sort);

  lua_newtable(vm);
  HASH_ITER(hh, stats, curr, tmp) {
    u_int8_t icmp_type, icmp_code;

    to_typecode(curr->type_code, &icmp_type, &icmp_code);

    if(isV4) {
      switch(icmp_type) {
      case 0: addToTable("Echo Reply", vm, curr); break;
      case 3:
	switch(icmp_code) {
	case 0: addToTable("Destination network unreachable", vm, curr); break;
	case 1: addToTable("Destination host unreachable", vm, curr); break;
	case 2: addToTable("Destination protocol unreachable", vm, curr); break;
	case 3: addToTable("Destination port unreachable", vm, curr); break;
	case 4: addToTable("Fragmentation required", vm, curr); break;
	case 10: addToTable("Host administratively prohibited", vm, curr); break;
	default:
	  snprintf(buf, sizeof(buf), "Destination Unreachable [code: %d]", icmp_code);
	  addToTable(buf, vm, curr);
	  break;
	}
	break;

      case 5:
	snprintf(buf, sizeof(buf), "Redirect Message [code: %d]", icmp_code);
	addToTable(buf, vm, curr);
	break;	

      case 8: addToTable("Echo Request", vm, curr); break;
      case 9: addToTable("Router Advertisement", vm, curr); break;
      case 10: addToTable("Router Solicitation", vm, curr); break;
      case 11: addToTable("Time Exceeded", vm, curr); break;
      default:
	snprintf(buf, sizeof(buf), "[type: %d][code: %d]", icmp_type, icmp_code);
	addToTable(buf, vm, curr);
	break;
      }
    } else {
      switch(icmp_type) {
      case 1:
	switch(icmp_code) {
	case 0: addToTable("No route to destination", vm, curr); break;
	case 1: addToTable("Communication with destination administratively prohibited", vm, curr); break;
	case 3: addToTable("Address unreachable", vm, curr); break;
	case 4: addToTable("Port unreachable", vm, curr); break;
	default:
	  snprintf(buf, sizeof(buf), "Destination Unreachable [code: %d]", icmp_code);
	  addToTable(buf, vm, curr);
	  break;
	}
	break;
      case 2: addToTable("Packet too big", vm, curr); break;
      case 3: addToTable("Time Exceeded", vm, curr); break;
      case 128: addToTable("Echo Request", vm, curr); break;
      case 129: addToTable("Echo Reply", vm, curr); break;
      default:
	snprintf(buf, sizeof(buf), "[type: %d][code: %d]", icmp_type, icmp_code);
	addToTable(buf, vm, curr);
	break;
      }
    }
  }
  
  m.unlock(__FILE__, __LINE__);
  
  lua_pushstring(vm, "ICMP");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

}

/* *************************************** */

void ICMPstats::sum(ICMPstats *e) {
  ICMPstats_t *curr, *tmp, *s;
  
  HASH_ITER(hh, e->stats, curr, tmp) {
    int key = curr->type_code;
    
    HASH_FIND_INT(stats, &key, s);

    if(!s) {
      if((s = (ICMPstats_t*)malloc(sizeof(ICMPstats_t))) != NULL) {
	s->type_code = key, s->pkt_sent = s->pkt_rcvd = 0;
	HASH_ADD_INT(stats, type_code, s);
      }
    }

    if(s)
      s->pkt_sent = curr->pkt_sent, s->pkt_rcvd = curr->pkt_rcvd;    
  }
}
