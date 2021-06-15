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

/* *************************************** */

ICMPinfo::ICMPinfo() {
  unreach = NULL;
  reset();
}
/* *************************************** */

ICMPinfo::ICMPinfo(const ICMPinfo& _icmp_info) {
  unreach = NULL;
  reset();

  icmp_type = _icmp_info.icmp_type,
    icmp_code = _icmp_info.icmp_code,
    icmp_identifier = _icmp_info.icmp_identifier;

  if(_icmp_info.unreach
     && (unreach = (unreachable_t*)calloc(1, sizeof(*unreach)))) {
    unreach->src_ip.set(&_icmp_info.unreach->src_ip),
      unreach->dst_ip.set(&_icmp_info.unreach->dst_ip);
    unreach->src_port = _icmp_info.unreach->src_port,
      unreach->dst_port = _icmp_info.unreach->dst_port;
    unreach->protocol = _icmp_info.unreach->protocol;
  }
}

/* *************************************** */

void ICMPinfo::reset() {
  if(unreach) free(unreach);
  unreach = NULL;
  icmp_type = icmp_code = icmp_identifier = 0;
}

/* *************************************** */

ICMPinfo::~ICMPinfo() {
  if(unreach) free(unreach);
}

/* *************************************** */

u_int32_t ICMPinfo::key() const {
  u_int32_t k = 0;

  if(unreach) {
    k += unreach->src_ip.key() + unreach->dst_ip.key() + unreach->src_port + unreach->dst_port + unreach->protocol;
  }

  if(icmp_identifier)
    k += icmp_identifier;

  return k;
}

/* *************************************** */

void ICMPinfo::dissectICMP(u_int16_t const payload_len, const u_int8_t * const payload_data) {
  reset();

  if(payload_len > 2) {
    icmp_type = payload_data[0], icmp_code = payload_data[1];

    if(icmp_type == ICMP_DEST_UNREACH && icmp_code == ICMP_PORT_UNREACH
       && payload_len >= sizeof(struct ndpi_iphdr)) {
      struct ndpi_iphdr *icmp_port_unreach_ip = (struct ndpi_iphdr *)&payload_data[8];
      u_short icmp_port_unreach_iph_len = (u_short)(icmp_port_unreach_ip->ihl * 4);
	
      if(payload_len >= icmp_port_unreach_iph_len + sizeof(struct ndpi_udphdr)
	 && icmp_port_unreach_ip->protocol == IPPROTO_UDP
	 && (unreach
	     || (unreach = (unreachable_t*)calloc(1, sizeof(*unreach))))) {
	struct ndpi_udphdr *icmp_port_unreach_udp = (struct ndpi_udphdr *)&payload_data[8 + icmp_port_unreach_iph_len];

	unreach->src_ip.set(icmp_port_unreach_ip->saddr),
	  unreach->dst_ip.set(icmp_port_unreach_ip->daddr),
	  unreach->src_port = icmp_port_unreach_udp->source,
	  unreach->dst_port = icmp_port_unreach_udp->dest,
	  unreach->protocol = icmp_port_unreach_ip->protocol;
      }
    } else if((icmp_type == ICMP_ECHO || icmp_type == ICMP_ECHOREPLY
	       || icmp_type == ICMP_TIMESTAMP || icmp_type == ICMP_TIMESTAMPREPLY
	       || icmp_type == ICMP_INFO_REQUEST || icmp_type == ICMP_INFO_REPLY)
	      && icmp_code == 0
	      && payload_len > 5) {
      /* https://tools.ietf.org/html/rfc792

	 Echo or Echo Reply Message
	 Timestamp or Timestamp Reply Message
	 Information Request or Information Reply Message

	 Identifier

	 If code = 0, an identifier to aid in matching echos and replies,
	 may be zero.
      */

      icmp_identifier = ntohs(*(u_int16_t*)&payload_data[4]);
      // ntop->getTrace()->traceEvent(TRACE_NORMAL, "identifier: 0x%X [0x%x%x]", icmp_identifier, payload_data[4], payload_data[5]);
    }
  }
}

/* *************************************** */

void ICMPinfo::print() const {
  char buf1[64], buf2[64];
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[icmp type: %u][icmp code: %u]", icmp_type, icmp_code);
  if(unreach) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Port unreachable: [src: %s:%u][dst: %s:%u]",
				 unreach->src_ip.print(buf1, sizeof(buf1)), unreach->src_port,
				 unreach->dst_ip.print(buf2, sizeof(buf2)), unreach->dst_port);
  }
  if(icmp_identifier)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[identifier: 0x%x]", icmp_identifier);
}

/* *************************************** */

bool ICMPinfo::equal(const ICMPinfo * const _icmp_info) const {
  if(!_icmp_info)
    return false;

  unreachable_t *ur = _icmp_info->getUnreach();

  if(unreach && ur) {
    bool equal =  unreach->src_ip.equal(&ur->src_ip)
      && unreach->dst_ip.equal(&ur->dst_ip)
      && unreach->src_port == ur->src_port
      && unreach->dst_port == ur->dst_port
      && unreach->protocol == ur->protocol;

    return equal;
  }

  if(icmp_identifier)
    return icmp_identifier == _icmp_info->icmp_identifier;

  /* TODO: possibly add checks on icmp type and code */
  return true;
}

/* *************************************** */

void ICMPinfo::lua(lua_State* vm, AddressTree * ptree,
		   NetworkInterface *iface, VLANid vlan_id) const {
  char buf[64];

  if(vm && unreach) {
    lua_newtable(vm);

    lua_push_str_table_entry(vm, "src_ip", unreach->src_ip.print(buf, sizeof(buf)));
    lua_push_str_table_entry(vm, "dst_ip", unreach->dst_ip.print(buf, sizeof(buf)));
    lua_push_uint64_table_entry(vm, "src_port", ntohs(unreach->src_port));
    lua_push_uint64_table_entry(vm, "dst_port", ntohs(unreach->dst_port));
    lua_push_uint64_table_entry(vm, "protocol", unreach->protocol);

    lua_pushstring(vm, "unreach");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* *************************************** */

bool ICMPinfo::isPortUnreachable() const{
  
  if((icmp_type == ICMP_DEST_UNREACH && icmp_code == ICMP_PORT_UNREACH) || 
    (icmp_type == ICMP6_DEST_UNREACH && icmp_code == ICMP6_PORT_UNREACH ))
  {
    return true;
  }
  return false;
}

/* *************************************** */

bool ICMPinfo::isHostUnreachable(u_int8_t proto) const{

  if(proto == IPPROTO_ICMP && icmp_type == ICMP_DEST_UNREACH && icmp_code == ICMP_HOST_UNREACH){
    return true;
  }
  return false;
}

