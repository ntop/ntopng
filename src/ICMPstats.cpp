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

/* *************************************** */

ICMPstats::ICMPstats() {
  stats = NULL;
}

/* *************************************** */

ICMPstats::~ICMPstats() {
  ICMPstats_t *curr, *tmp;
  
  HASH_ITER(hh, stats, curr, tmp) {
    HASH_DEL(stats, curr);  /* delete it */
    if(curr->last_host_sent_peer) free(curr->last_host_sent_peer);
    if(curr->last_host_rcvd_peer) free(curr->last_host_rcvd_peer);
    free(curr);         /* free it */
  }
}

/* *************************************** */

void ICMPstats::incStats(u_int8_t icmp_type, u_int8_t icmp_code, bool sent, Host *peer) {
  ICMPstats_t *s = NULL;
  int key = get_typecode(icmp_type, icmp_code);
  char buf[64];
  
  m.lock(__FILE__, __LINE__);
  HASH_FIND_INT(stats, &key, s);
  
  if(!s) {
    if((s = (ICMPstats_t*)malloc(sizeof(ICMPstats_t))) != NULL) {
      s->type_code = key, s->pkt_sent = s->pkt_rcvd = 0,
	s->last_host_sent_peer = s->last_host_rcvd_peer = NULL;

      HASH_ADD_INT(stats, type_code, s);
    } else {
      m.unlock(__FILE__, __LINE__);
      return;
    }
  }

  if(sent) {
    s->pkt_sent++;

    if(peer) {
      if(s->last_host_sent_peer) free(s->last_host_sent_peer);
      s->last_host_sent_peer = strdup(peer->get_string_key(buf, sizeof(buf)));
    }
  } else {
    s->pkt_rcvd++;

    if(peer) {
      if(s->last_host_rcvd_peer) free(s->last_host_rcvd_peer);
      s->last_host_rcvd_peer = strdup(peer->get_string_key(buf, sizeof(buf)));
    }
  }
  
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
  lua_push_str_table_entry(vm, "last_host_sent_peer", curr->last_host_sent_peer);
  lua_push_int_table_entry(vm, "rcvd", curr->pkt_rcvd);
  lua_push_str_table_entry(vm, "last_host_rcvd_peer", curr->last_host_rcvd_peer);
  lua_pushstring(vm, label);
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void ICMPstats::lua(bool isV4, lua_State *vm) {
  ICMPstats_t *curr, *tmp;
  
  m.lock(__FILE__, __LINE__);
  
  HASH_SORT(stats, key_sort);

  lua_newtable(vm);
  HASH_ITER(hh, stats, curr, tmp) {
    u_int8_t icmp_type, icmp_code;
    char label[32];
    
    to_typecode(curr->type_code, &icmp_type, &icmp_code);
    snprintf(label, sizeof(label), "%u,%u", icmp_type, icmp_code);
    addToTable(label, vm, curr);   
  }
  
  m.unlock(__FILE__, __LINE__);
  
  lua_pushstring(vm, isV4 ? "ICMPv4" : "ICMPv6");
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
	s->type_code = key, s->pkt_sent = s->pkt_rcvd = 0,
	  s->last_host_sent_peer = s->last_host_rcvd_peer = NULL;
	HASH_ADD_INT(stats, type_code, s);
      }
    }

    if(s) {
      s->pkt_sent = curr->pkt_sent, s->pkt_rcvd = curr->pkt_rcvd;
      
      if(curr->last_host_sent_peer && (! s->last_host_sent_peer))
	s->last_host_sent_peer = strdup(curr->last_host_sent_peer);      
      
      if(curr->last_host_rcvd_peer && (! s->last_host_rcvd_peer))
	s->last_host_rcvd_peer = strdup(curr->last_host_rcvd_peer);      
    }
  }
}
