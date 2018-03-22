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

#ifndef _ETH_STATS_H_
#define _ETH_STATS_H_

#include "ntop_includes.h"

class EthStats {
 private:
  ProtoStats rawIngress, rawEgress, eth_IPv4, eth_IPv6, eth_ARP, eth_MPLS, eth_other;

 public:
  EthStats();

  inline ProtoStats* getIPv4Stats()     { return(&eth_IPv4);  };
  inline ProtoStats* getIPv6Stats()     { return(&eth_IPv6);  };
  inline ProtoStats* getARPStats()      { return(&eth_ARP);   };
  inline ProtoStats* getMPLSStats()     { return(&eth_MPLS);  };
  inline ProtoStats* getEthOtherStats() { return(&eth_other); };

  void lua(lua_State *vm);
  void incStats(bool ingressPacket, u_int16_t proto, u_int32_t num_pkts,
		u_int32_t num_bytes, u_int pkt_overhead);

  inline void setNumPackets(bool ingressPacket, u_int64_t v) { 
    if(ingressPacket) rawIngress.setPkts(v); else rawEgress.setPkts(v);   
  };

  inline void setNumBytes(bool ingressPacket, u_int64_t v) {
    if(ingressPacket) rawIngress.setBytes(v); else rawEgress.setBytes(v); 
  };

  inline u_int64_t getNumIngressPackets() { return(rawIngress.getPkts());  };
  inline u_int64_t getNumEgressPackets()  { return(rawEgress.getPkts());   };
  inline u_int64_t getNumIngressBytes()   { return(rawIngress.getBytes()); };
  inline u_int64_t getNumEgressBytes()    { return(rawEgress.getBytes());  };

  inline u_int64_t getNumPackets() { return(rawIngress.getPkts() + rawEgress.getPkts());  };
  inline u_int64_t getNumBytes()   { return(rawIngress.getBytes() + rawEgress.getBytes()); };

  inline void sum(EthStats *e) {
    rawIngress.sum(&e->rawIngress), rawEgress.sum(&e->rawEgress),
      eth_IPv4.sum(&e->eth_IPv4), eth_IPv6.sum(&e->eth_IPv6),
      eth_ARP.sum(&e->eth_ARP), eth_MPLS.sum(&e->eth_MPLS), eth_other.sum(&e->eth_other);
  };

  /**
   * @brief Cleanup the proto stats.
   * @details Reset all proto stats information.
   */
  void cleanup();
  void print();
};

#endif /* _ETH_STATS_H_ */
