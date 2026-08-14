/*
 *
 * (C) 2019-26 - ntop.org
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

// #define TRACE_ASN_STATS 0

/* *************************************** */

ASNStats::ASNStats() {
#ifdef TRACE_ASN_STATS
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);
#endif
  resetStats();
}

/* *************************************** */

ASNStats::~ASNStats() {
#ifdef TRACE_ASN_STATS
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[delete] %s", __FILE__);
#endif
}

/* *************************************** */

void ASNStats::incStats(Flow* flow) {
  if (flow) {
    /* Retrieve the ASN */
    u_int32_t srcAS = 0, dstAS = 0;
    /* Also the transit one */
    u_int32_t srcPeerAS = flow->getSrcPeerAS(),
              dstPeerAS = flow->getDstPeerAS();
    char *src_as_name, *dst_as_name;
    std::map<u_int32_t, ASNTrafficStats>::iterator it;

    flow->getSrcAS(&srcAS, &src_as_name);
    flow->getDstAS(&dstAS, &dst_as_name);

    /* First handle the transit ASN */
    if ((srcPeerAS || dstPeerAS) && (srcPeerAS != dstPeerAS)) {
      if (srcAS != srcPeerAS) transit_asn.insert(srcPeerAS);
      if (dstAS != dstPeerAS) transit_asn.insert(dstPeerAS);
    }

    /* Now handle the source ASN */
    it = src_asn.find(srcAS);
    if (it == src_asn.end()) {
      src_asn[srcAS] = {
	flow->get_bytes_cli2srv(), flow->get_bytes_srv2cli(),
	flow->get_transit_bytes(), flow->get_peering_bytes(),
	flow->get_ix_bytes()
      };
    } else {
      it->second.bytes_sent    += flow->get_bytes_cli2srv();
      it->second.bytes_rcvd    += flow->get_bytes_srv2cli();
      it->second.transit_bytes += flow->get_transit_bytes();
      it->second.peering_bytes += flow->get_peering_bytes();
      it->second.ix_bytes      += flow->get_ix_bytes();
    }

    /* Now handle the destination ASN */
    it = dst_asn.find(dstAS);
    if (it == dst_asn.end()) {
      dst_asn[dstAS] = {
	flow->get_bytes_srv2cli(), flow->get_bytes_cli2srv(),
	flow->get_transit_bytes(), flow->get_peering_bytes(),
	flow->get_ix_bytes()
      };
    } else {
      it->second.bytes_sent    += flow->get_bytes_srv2cli();
      it->second.bytes_rcvd    += flow->get_bytes_cli2srv();
      it->second.transit_bytes += flow->get_transit_bytes();
      it->second.peering_bytes += flow->get_peering_bytes();
      it->second.ix_bytes      += flow->get_ix_bytes();
    }
  }
}

/* *************************************** */

void ASNStats::lua(lua_State* vm, bool show_all_stats) {
  std::set<u_int32_t>::iterator it;
  std::map<u_int32_t, ASNTrafficStats>::iterator it2;

  /* Transit ASN */
  lua_newtable(vm);
  for (it = transit_asn.begin(); it != transit_asn.end(); it++) {
    lua_push_uint32_table_entry(vm, std::to_string(*it).c_str(), 1);
  }
  lua_pushstring(vm, "transit_asn");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_newtable(vm);
  for (it2 = src_asn.begin(); it2 != src_asn.end(); it2++) {
    u_int64_t total_bytes = it2->second.bytes_sent + it2->second.bytes_rcvd;

    if (show_all_stats) {
      lua_newtable(vm);
      lua_push_uint64_table_entry(vm, "bytes_sent", it2->second.bytes_sent);
      lua_push_uint64_table_entry(vm, "bytes_rcvd", it2->second.bytes_rcvd);
      lua_push_uint64_table_entry(vm, "total_bytes", total_bytes);
      lua_push_uint64_table_entry(vm, "transit_bytes", it2->second.transit_bytes);
      lua_push_uint64_table_entry(vm, "peering_bytes", it2->second.peering_bytes);
      lua_push_uint64_table_entry(vm, "ix_bytes",      it2->second.ix_bytes);
      lua_pushstring(vm, std::to_string(it2->first).c_str());
      lua_insert(vm, -2);
      lua_settable(vm, -3);
    } else {
      lua_push_uint64_table_entry(vm, std::to_string(it2->first).c_str(), total_bytes);
    }
  }
  lua_pushstring(vm, "src_asn");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_newtable(vm);
  for (it2 = dst_asn.begin(); it2 != dst_asn.end(); it2++) {
    u_int64_t total_bytes = it2->second.bytes_sent + it2->second.bytes_rcvd;

    if (show_all_stats) {
      lua_newtable(vm);
      lua_push_uint64_table_entry(vm, "bytes_sent", it2->second.bytes_sent);
      lua_push_uint64_table_entry(vm, "bytes_rcvd", it2->second.bytes_rcvd);
      lua_push_uint64_table_entry(vm, "total_bytes", total_bytes);
      lua_push_uint64_table_entry(vm, "transit_bytes", it2->second.transit_bytes);
      lua_push_uint64_table_entry(vm, "peering_bytes", it2->second.peering_bytes);
      lua_push_uint64_table_entry(vm, "ix_bytes",      it2->second.ix_bytes);
      lua_pushstring(vm, std::to_string(it2->first).c_str());
      lua_insert(vm, -2);
      lua_settable(vm, -3);
    } else {
      lua_push_uint64_table_entry(vm, std::to_string(it2->first).c_str(),
                                  total_bytes);
    }
  }
  lua_pushstring(vm, "dst_asn");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void ASNStats::resetStats() {
  src_asn.clear();
  dst_asn.clear();
  transit_asn.clear();
}

/* *************************************** */
