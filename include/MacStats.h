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

#ifndef _MAC_STATS_H_
#define _MAC_STATS_H_

class MacStats: public GenericTrafficElement {
 protected:
  NetworkInterface *iface;
  ArpStats arp_stats;

 public:
  MacStats(NetworkInterface *_iface);

  void lua(lua_State* vm, bool show_details);
  void deserialize(json_object *obj);
  void getJSONObject(json_object *my_object);

  inline u_int64_t  getNumSentArp()   { return (u_int64_t)arp_stats.sent_requests + arp_stats.sent_replies; }
  inline u_int64_t  getNumRcvdArp()   { return (u_int64_t)arp_stats.rcvd_requests + arp_stats.rcvd_replies; }
  inline void incSentArpRequests()   { arp_stats.sent_requests++;         }
  inline void incSentArpReplies()    { arp_stats.sent_replies++;          }
  inline void incRcvdArpRequests()   { arp_stats.rcvd_requests++;         }
  inline void incRcvdArpReplies()    { arp_stats.rcvd_replies++;          }

  inline void incSentStats(u_int64_t num_pkts, u_int64_t num_bytes)  { sent.incStats(num_pkts, num_bytes); }
  inline void incRcvdStats(u_int64_t num_pkts, u_int64_t num_bytes)  { rcvd.incStats(num_pkts, num_bytes); }
  inline void incnDPIStats(u_int32_t when, u_int16_t protocol,
	    u_int64_t sent_packets, u_int64_t sent_bytes, u_int64_t sent_goodput_bytes,
	    u_int64_t rcvd_packets, u_int64_t rcvd_bytes, u_int64_t rcvd_goodput_bytes) {
    if(ndpiStats || (ndpiStats = new nDPIStats())) {
      //ndpiStats->incStats(when, protocol.master_proto, sent_packets, sent_bytes, rcvd_packets, rcvd_bytes);
      //ndpiStats->incStats(when, protocol.app_proto, sent_packets, sent_bytes, rcvd_packets, rcvd_bytes);
      ndpiStats->incCategoryStats(when,
				  iface->get_ndpi_proto_category(protocol),
				  sent_bytes, rcvd_bytes);
    }
  }
};

#endif
