/*
 *
 * (C) 2019-23 - ntop.org
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


/* ************************************************ */

char* FlowsHostInfo::getIP(char* buf, u_int len) {
  return(ip->print(buf, len));
}

/* ************************************************ */

char* FlowsHostInfo::getHostName(char* buf, u_int len) {
  char symIP[64];
  char *ip_addr = ip->print(buf, len);
  
  if(host) {
    char* name = host->get_name(buf, len, false);
    
    if(name && strcmp(name,"") != 0 && strcmp(name," ") != 0)
      return(name);
  }

  if(ip_addr) {
    ntop->resolveHostName(ip_addr, symIP, sizeof(symIP));

    if(strcmp(symIP, ip_addr) != 0) {
      snprintf(buf, len, "%s", symIP);      
      return(buf ? buf : (char*)"");
    } else 
      return((char*) "");
  }
  
  return((char*) "");
}

/* ************************************************ */

char* FlowsHostInfo::getIPHex(char* buf, u_int len) {
  return(ip->get_ip_hex(buf, len));
}

/* ************************************************ */

bool FlowsHostInfo::isHostInMem() {
  return(host != NULL);
}

/* ************************************************ */

u_int16_t FlowsHostInfo::getVLANId() {
  u_int16_t v_id = 0;

  if(host) {
    u_int16_t vlan = host->get_vlan_id();

    if(vlan)
      v_id = vlan;
    else {
      vlan = host->get_raw_vlan_id();
      v_id = vlan ? vlan : 0;
    }
  }

  return v_id;
}
