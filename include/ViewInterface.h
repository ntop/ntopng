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

#ifndef _VIEW_INTERFACE_H_
#define _VIEW_INTERFACE_H_

#include "ntop_includes.h"

class ViewInterface : public NetworkInterface {
 private:
  bool is_packet_interface;
  u_int8_t num_viewed_interfaces;
  NetworkInterface *viewed_interfaces[MAX_NUM_VIEW_INTERFACES];
  SPSCQueue<Flow *> *viewed_interfaces_queues[MAX_NUM_VIEW_INTERFACES];

  virtual void sumStats(TcpFlowStats *_tcpFlowStats, EthStats *_ethStats,
			LocalTrafficStats *_localStats, nDPIStats *_ndpiStats,
			PacketStats *_pktStats, TcpPacketStats *_tcpPacketStats,
			ProtoStats *_discardedProbingStats, DSCPStats *_dscpStats,
			SyslogStats *_syslogStats) const;

  bool addSubinterface(NetworkInterface *iface);

 public:
  ViewInterface(const char *_endpoint);
  bool walker(u_int32_t *begin_slot,
	      bool walk_all,
	      WalkerType wtype,
	      bool (*walker)(GenericHashEntry *h, void *user_data, bool *matched),
	      void *user_data);
  void viewed_flows_walker(Flow *f, const struct timeval *tv);
  /* Enqueues a flow to a queue reserved for viewed interface identified by viewed_interface_id */
  bool viewEnqueue(time_t t, Flow *f, u_int8_t viewed_interface_id);
  /* Dequeues enqueued flows sequentially for each of the viewed interfaces belonging to this view.
     The total number of elements dequeued is returned. */
  u_int64_t viewDequeue(u_int budget);
  virtual bool areTrafficDirectionsSupported() { return(true); };
  virtual InterfaceType getIfType() const { return interface_type_VIEW;           };
  virtual const char* get_type()    const { return CONST_INTERFACE_TYPE_VIEW;     };
  virtual bool is_ndpi_enabled()    const { return false;                         };
  virtual bool isPacketInterface()  const { return is_packet_interface;           };
  virtual bool isSampledTraffic()   const;
  void flowPollLoop();
  void startPacketPolling();
  bool set_packet_filter(char *filter)    { return false ;                        };

  AlertsQueue* getAlertsQueue()     const { return alertsQueue;   };

  virtual u_int64_t getNumPackets();
  virtual u_int64_t getNumDroppedAlerts();
  virtual u_int64_t getNumBytes();
  virtual u_int     getNumPacketDrops();
  virtual u_int64_t getNumDiscardedProbingPackets() const;
  virtual u_int64_t getNumDiscardedProbingBytes()   const;
  virtual u_int64_t getNumNewFlows();
  virtual u_int     getNumFlows();
  virtual u_int64_t getNumActiveAlertedFlows() const;
  virtual u_int64_t getNumActiveAlertedFlows(AlertLevelGroup alert_level_group) const;

  virtual u_int64_t getCheckPointNumPackets();
  virtual u_int64_t getCheckPointDroppedAlerts();
  virtual u_int64_t getCheckPointNumBytes();
  virtual u_int32_t getCheckPointNumPacketDrops();
  virtual u_int64_t getCheckPointNumDiscardedProbingPackets() const;
  virtual u_int64_t getCheckPointNumDiscardedProbingBytes() const;
  virtual void checkPointCounters(bool drops_only);

  virtual bool hasSeenVLANTaggedPackets() const;

  virtual u_int32_t getFlowsHashSize();
  virtual Flow* findFlowByKeyAndHashId(u_int32_t key, u_int hash_id, AddressTree *allowed_hosts);
  virtual Flow* findFlowByTuple(VLANid vlan_id,
				u_int16_t observation_domain_id,
  				IpAddress *src_ip,  IpAddress *dst_ip,
  				u_int16_t src_port, u_int16_t dst_port,
				u_int8_t l4_proto,
				AddressTree *allowed_hosts) const;
  void dumpFlowLoop();
  virtual void lua_queues_stats(lua_State* vm);
};

#endif /* _VIEW_INTERFACE_H_ */

