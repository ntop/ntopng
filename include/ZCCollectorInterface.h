/*
 *
 * (C) 2016-18 - ntop.org
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

#ifndef _ZC_COLLECTOR_INTERFACE_H_
#define _ZC_COLLECTOR_INTERFACE_H_

#include "ntop_includes.h"

#if defined(HAVE_PF_RING) && (!defined(NTOPNG_EMBEDDED_EDITION))

class ZCCollectorInterface : public ParserInterface {
 private:
  u_int32_t cluster_id, queue_id;
  u_int32_t num_drops;
  pfring_zc_queue *zq;
  pfring_zc_buffer_pool *zp;
  pfring_zc_pkt_buff *buffer;
  pfring_zc_stat last_pfring_zc_stat;
  
  u_int32_t getNumDroppedPackets();

 public:
  ZCCollectorInterface(const char *name);
  ~ZCCollectorInterface();

  inline InterfaceType getIfType()      { return(interface_type_ZC_FLOW);       };
  inline const char* get_type()         { return(CONST_INTERFACE_TYPE_ZC_FLOW); };
  inline bool is_ndpi_enabled()         { return(false);      };
  inline void incrDrops(u_int32_t num)  { num_drops += num;   };
  inline bool isPacketInterface()       { return(false);      };
  void collect_flows();

  void startPacketPolling();
  void shutdown();
  bool set_packet_filter(char *filter);
};

#endif

#endif /* _ZC_COLLECTOR_INTERFACE_H_ */

