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

#ifndef _VIEW_INTERFACE_H_
#define _VIEW_INTERFACE_H_

#include "ntop_includes.h"

class ViewInterface : public NetworkInterface {
 private:
  u_int8_t num_viewed_interfaces;
  NetworkInterface *viewed_interfaces[MAX_NUM_VIEW_INTERFACES];

 public:
  ViewInterface(const char *_endpoint);

  virtual InterfaceType getIfType() const { return interface_type_VIEW;           };
  inline const char* get_type()           { return CONST_INTERFACE_TYPE_VIEW;     };
  virtual bool is_ndpi_enabled()    const { return false;                         };

  virtual bool isView()             const { return true;                          };
  virtual bool isViewed()           const { return false;                         };

  virtual bool isPacketInterface()  const { return false;                         };
  void flowPollLoop();
  void startPacketPolling();
  void shutdown();
  bool set_packet_filter(char *filter)    { return false ;                        };

  virtual u_int64_t getNumPackets();
  virtual u_int64_t getNumBytes();
  virtual u_int     getNumPacketDrops();
  virtual u_int     getNumFlows();

  virtual u_int64_t getCheckPointNumPackets();
  virtual u_int64_t getCheckPointNumBytes();
  virtual u_int32_t getCheckPointNumPacketDrops();

  virtual u_int32_t getFlowsHashSize();
  virtual Flow* findFlowByKey(u_int32_t key, AddressTree *allowed_hosts);
  virtual Flow* findFlowByTuple(u_int16_t vlan_id,
  				IpAddress *src_ip,  IpAddress *dst_ip,
  				u_int16_t src_port, u_int16_t dst_port,
				u_int8_t l4_proto,
				AddressTree *allowed_hosts) const;
  virtual bool walker(u_int32_t *begin_slot, bool walk_all,
		      WalkerType wtype,		      
		      bool (*walker)(GenericHashEntry *h,
				     void *user_data, bool *entryMatched),
		      void *user_data,
		      bool walk_idle = false /* Should never walk idle unless in ViewInterface::flowPollLoop */);
};

#endif /* _VIEW_INTERFACE_H_ */

