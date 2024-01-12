/*
 *
 * (C) 2019-24 - ntop.org
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

const char* FlowsHostInfo::getIP(char* buf, u_int16_t buf_len) {
  return (ip ? ip->print(buf, buf_len) : (char *)"");
}

/* ************************************************ */

char* FlowsHostInfo::getHostName(char* buf, u_int16_t buf_len) {
  return(host ? host->get_visual_name(buf, buf_len) : (char *)"");
}

/* ************************************************ */

const char* FlowsHostInfo::getIPHex(char* buf, u_int16_t buf_len) {
  return (ip ? ip->get_ip_hex(buf, buf_len) : (char *)"");
}

/* ************************************************ */

bool FlowsHostInfo::isHostInMem() { 
  return (host != NULL); 
}

/* ************************************************ */

u_int16_t FlowsHostInfo::getVLANId() {
  return (host ? host->get_vlan_id() : 0);
}
