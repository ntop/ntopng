/*
 *
 * (C) 2013-23 - ntop.org
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

MacStats::MacStats(NetworkInterface* _iface) {
  iface = _iface;
  arp_stats.sent.requests.reset(), arp_stats.sent.replies.reset(),
      arp_stats.rcvd.requests.reset(), arp_stats.rcvd.replies.reset();

  memset(&dhcp_stats, 0, sizeof(dhcp_stats));

  /* NOTE: ndpiStats: allocated dynamically and deleted by
   * ~GenericTrafficElement */
  ndpiStats = NULL;
}

/* *************************************** */

void MacStats::lua(lua_State* vm, bool show_details) {
  if (show_details) {
    lua_push_uint64_table_entry(vm, "arp_requests.sent",
                                arp_stats.sent.requests.get());
    lua_push_uint64_table_entry(vm, "arp_requests.rcvd",
                                arp_stats.rcvd.requests.get());
    lua_push_uint64_table_entry(vm, "arp_replies.sent",
                                arp_stats.sent.replies.get());
    lua_push_uint64_table_entry(vm, "arp_replies.rcvd",
                                arp_stats.rcvd.replies.get());

    lua_push_uint32_table_entry(vm, "dhcp.sent", dhcp_stats.num_req_sent);
    lua_push_uint32_table_entry(vm, "dhcp.rcvd", dhcp_stats.num_rep_rcvd);

    if (ndpiStats) ndpiStats->lua(iface, vm, true);
  }

  ((GenericTrafficElement*)this)->lua(vm, true);
}
