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

<<<<<<< HEAD
ArpStatsMatrixElement::ArpStatsMatrixElement(NetworkInterface *_iface, const u_int8_t _src_mac[6], 
                          const u_int8_t _dst_mac[6], u_int32_t _src_ip, u_int32_t _dst_ip, bool * const src2dst): GenericHashEntry(_iface) {
  src_ip = _src_ip;
  dst_ip = _dst_ip;
  memcpy(src_mac, _src_mac, 6);
  memcpy(dst_mac, _dst_mac, 6);
=======
// #define TRACE_ARP_LIFECYCLE   1

ArpStatsMatrixElement::ArpStatsMatrixElement(NetworkInterface *_iface,
					     const u_int8_t _src_mac[6], const u_int8_t _dst_mac[6],
					     const u_int32_t _src_ip, const u_int32_t _dst_ip): GenericHashEntry(_iface) {
  memcpy(src_mac, _src_mac, 6), memcpy(dst_mac, _dst_mac, 6);
  src_ip = _src_ip, dst_ip = _dst_ip;
>>>>>>> 96954bdabb5fa29cbc8d600b339c07591da12cd2
  memset(&stats, 0, sizeof(stats));

<<<<<<< HEAD

#ifdef ARP_STATS_MATRIX_ELEMENT_DEBUG
  char buf1[32], buf2[32], buf3[32], buf4[32];
  Utils::formatMac(src_mac, buf3, sizeof(buf3));
  Utils::formatMac(dst_mac, buf4, sizeof(buf4));
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "ADDED ArpMatrixElement: SourceIP %s - DestinationIP %s - SourceMac %s - DestinationMac %s [num_elements: %u]",
             Utils::intoaV4(src_ip, buf1, 32),
             Utils::intoaV4(dst_ip, buf2, 32),
			       buf3,
			       buf4,
			       iface->getNumArpStatsMatrixElements());
=======
#ifdef TRACE_ARP_LIFECYCLE
  print((char*)"Create ");
>>>>>>> 96954bdabb5fa29cbc8d600b339c07591da12cd2
#endif
}


<<<<<<< HEAD
ArpStatsMatrixElement::~ArpStatsMatrixElement(){
#ifdef ARP_STATS_MATRIX_ELEMENT_DEBUG
  char buf1[32], buf2[32], buf3[32], buf4[32];
  Utils::formatMac(src_mac, buf3, sizeof(buf3));
  Utils::formatMac(dst_mac, buf4, sizeof(buf4));
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "DELETED ArpMatrixElement: SourceIP %s - DestinationIP %s - SourceMac %s - DestinationMac %s [num_elements: %u]",
             Utils::intoaV4(src_ip, buf1, 32),
             Utils::intoaV4(dst_ip, buf2, 32),
			       buf3,
			       buf4,
			       iface->getNumArpStatsMatrixElements());
=======
ArpStatsMatrixElement::~ArpStatsMatrixElement() {
#ifdef TRACE_ARP_LIFECYCLE
  print((char*)"Delete ");
>>>>>>> 96954bdabb5fa29cbc8d600b339c07591da12cd2
#endif
}

/* *************************************** */

bool ArpStatsMatrixElement::idle() {
  bool rc;

  if((num_uses > 0) || (!iface->is_purge_idle_interface()))
    return(false);

  rc = isIdle(MAX_LOCAL_HOST_IDLE);

  return(rc);
}

/* *************************************** */

<<<<<<< HEAD
bool ArpStatsMatrixElement::equal( u_int32_t _src_ip, u_int32_t _dst_ip, bool * const src2dst){
  if(!_src_ip || !_dst_ip)
    return false;

  if( src_ip == _src_ip && dst_ip == _dst_ip) {
    *src2dst = true;
    return true;
  } else if(src_ip == _dst_ip && dst_ip == _src_ip) {
    *src2dst = false;
    return true;
  }

  return false;
}

/* *************************************** */
/*
bool ArpStatsMatrixElement::equal(const u_int8_t _src_mac[6], const u_int8_t _dst_mac[6], bool * const src2dst) const { //TODO change arguments of the fun, add the IPs
  if(!_src_mac || !_dst_mac)
    return false;

  if(memcmp(src_mac, _src_mac, 6) == 0 && memcmp(dst_mac, _dst_mac, 6) == 0) {
=======
bool ArpStatsMatrixElement::equal(const u_int8_t _src_mac[6],
				  const u_int32_t _src_ip, const u_int32_t _dst_ip,
				  bool * const src2dst) const {

  if((src_ip == _src_ip) && (dst_ip == _dst_ip)) {
    if(memcmp(src_mac, _src_mac, 6) != 0) {
      /* This is a new Mac */
      memcpy((void*)src_mac, _src_mac, 6); /* Overwrite Mac (e.g. DHCP reassignment) */
      memset((void*)&stats, 0, sizeof(stats)); /* Reset all stats */      
    }
    
>>>>>>> 96954bdabb5fa29cbc8d600b339c07591da12cd2
    *src2dst = true;

    //WIPupdate destination IP if necessary
    if (src_ip != _src_ip) src_ip = _src_ip;
    if (dst_ip != _dst_ip) dst_ip = _dst_ip;
    //TODO: log the updates!?!?

    return true;
  } else {
    u_int8_t empty_mac[6] = { 0 };
      
    if((src_ip == _dst_ip) && (dst_ip == _src_ip)) {
      if(memcmp(dst_mac, _src_mac, 6) == 0)
	; /* Same mac: nothing to do */
      else if (memcmp(dst_mac, empty_mac, 6) == 0)
	memcpy((void*)dst_mac, _src_mac, 6); /* Mac was never set */
      else {
	/* This is a new Mac */
	memcpy((void*)dst_mac, _src_mac, 6); /* Overwrite Mac (e.g. DHCP reassignment) */
	memset((void*)&stats, 0, sizeof(stats)); /* Reset all stats */
      }
      
      *src2dst = false;
      return true;
    }
  }

  return false;
}

*/
/* *************************************** */

u_int32_t ArpStatsMatrixElement::key() {
<<<<<<< HEAD
  return src_ip + dst_ip;
=======
  return(src_ip + dst_ip);
>>>>>>> 96954bdabb5fa29cbc8d600b339c07591da12cd2
}


/* *************************************** */

<<<<<<< HEAD
void ArpStatsMatrixElement::print() const {
  char buf1[32], buf2[32], buf3[32], buf4[32];
  Utils::formatMac(src_mac, buf3, sizeof(buf3));
  Utils::formatMac(dst_mac, buf4, sizeof(buf4));
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[SourceIP: %s][DestinationIP: %s][SourceMac: %s][DestinationMac: %s]",
             Utils::intoaV4(src_ip, buf1, 32),
             Utils::intoaV4(dst_ip, buf2, 32),
			       buf3,
			       buf4
  );
=======
void ArpStatsMatrixElement::print(char *msg) const {
  char buf1[32], buf1ip[32], buf2[32], buf2ip[32];
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s[Source: %s/%s][Dest: %s/%s]",
			       msg ? msg : "",
			       Utils::formatMac(src_mac, buf1, sizeof(buf1)),
			       Utils::intoaV4(src_ip, buf1ip, sizeof(buf1ip)),
			       Utils::formatMac(dst_mac, buf2, sizeof(buf2)),
			       Utils::intoaV4(dst_ip, buf2ip, sizeof(buf2ip))
			       );
>>>>>>> 96954bdabb5fa29cbc8d600b339c07591da12cd2
}

/* *************************************** */

void ArpStatsMatrixElement::lua(lua_State* vm) {
  char buf[32], buf1[32], key[64];

<<<<<<< HEAD
  lua_newtable(vm); /* Outer table key, source IP */
  lua_newtable(vm); /* Innter table key, destination IP */

  lua_push_str_table_entry(vm,"dstMac", Utils::formatMac(dst_mac, buf, sizeof(buf)) );
  lua_push_str_table_entry(vm, "srcMac", Utils::formatMac(src_mac, buf, sizeof(buf)));
=======
  lua_newtable(vm);

  lua_push_str_table_entry(vm, "src_mac", Utils::formatMac(src_mac, buf, sizeof(buf)));
  lua_push_str_table_entry(vm, "dst_mac", Utils::formatMac(dst_mac, buf, sizeof(buf)));
			
>>>>>>> 96954bdabb5fa29cbc8d600b339c07591da12cd2
  lua_push_uint64_table_entry(vm, "src2dst.requests", stats.src2dst.requests);
  lua_push_uint64_table_entry(vm, "src2dst.replies", stats.src2dst.replies);
  lua_push_uint64_table_entry(vm, "dst2src.requests", stats.dst2src.requests);
  lua_push_uint64_table_entry(vm, "dst2src.replies", stats.dst2src.replies);

<<<<<<< HEAD
  /* Destination IP as the key of the inner table */
  lua_pushstring(vm, Utils::intoaV4(dst_ip, buf, 32));
  
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  /* Source IP as the key of the outer table */
  lua_pushstring(vm, Utils::intoaV4(src_ip, buf, 32));
  
=======
  snprintf(key, sizeof(key), "%s-%s",
	   Utils::intoaV4(src_ip, buf, sizeof(buf)),
	   Utils::intoaV4(dst_ip, buf1, sizeof(buf1)));

  lua_pushstring(vm, key);
>>>>>>> 96954bdabb5fa29cbc8d600b339c07591da12cd2
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}
