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

#ifndef _MAC_STATS_H_
#define _MAC_STATS_H_

class MacStats: public GenericTrafficElement {
 protected:
  NetworkInterface *iface;
  struct {
    struct {
      MonitoredCounter<u_int32_t> requests, replies;
    } sent, rcvd;
  } arp_stats;

 public:
  MacStats(NetworkInterface *_iface);

  void lua(lua_State* vm, bool show_details);
  inline void deserialize(json_object *obj)         { GenericTrafficElement::deserialize(obj, iface); }
  inline void getJSONObject(json_object *my_object) { GenericTrafficElement::getJSONObject(my_object, iface); }

  inline u_int64_t  getNumSentArp()   { return (u_int64_t)arp_stats.sent.requests.get() + arp_stats.sent.replies.get(); }
  inline u_int64_t  getNumRcvdArp()   { return (u_int64_t)arp_stats.rcvd.requests.get() + arp_stats.rcvd.replies.get(); }
  inline void incSentArpRequests()    { arp_stats.sent.requests.inc(1);         }
  inline void incSentArpReplies()     { arp_stats.sent.replies.inc(1);          }
  inline void incRcvdArpRequests()    { arp_stats.rcvd.requests.inc(1);         }
  inline void incRcvdArpReplies()     { arp_stats.rcvd.replies.inc(1);          }

  inline void incSentStats(time_t t, u_int64_t num_pkts, u_int64_t num_bytes)  { sent.incStats(t, num_pkts, num_bytes); }
  inline void incRcvdStats(time_t t, u_int64_t num_pkts, u_int64_t num_bytes)  { rcvd.incStats(t, num_pkts, num_bytes); }
  inline void incnDPIStats(time_t when, ndpi_protocol_category_t ndpi_category,
			   u_int64_t sent_packets, u_int64_t sent_bytes, u_int64_t sent_goodput_bytes,
			   u_int64_t rcvd_packets, u_int64_t rcvd_bytes, u_int64_t rcvd_goodput_bytes) {
    if(ndpiStats || (ndpiStats = new nDPIStats())) {
      //ndpiStats->incStats(when, protocol.master_proto, sent_packets, sent_bytes, rcvd_packets, rcvd_bytes);
      //ndpiStats->incStats(when, protocol.app_proto, sent_packets, sent_bytes, rcvd_packets, rcvd_bytes);
      ndpiStats->incCategoryStats(when,
				  ndpi_category,
				  sent_bytes, rcvd_bytes);
    }
  }
};

#endif
