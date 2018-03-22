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

#ifndef _VIEW_INTERFACE_H_
#define _VIEW_INTERFACE_H_

#include "ntop_includes.h"

class ViewInterface : public NetworkInterface {
 public:
  ViewInterface(const char *_endpoint);

  inline InterfaceType getIfType()      { return(interface_type_VIEW);           };
  inline const char* get_type()         { return(CONST_INTERFACE_TYPE_VIEW);     };
  inline bool is_ndpi_enabled()         { return(false);                         };
  inline bool isView()                  { return(true);                          };
  inline bool isPacketInterface()       { return(false);                         };
  inline void startPacketPolling()      { ; };
  inline void shutdown()                { ; };
  bool set_packet_filter(char *filter)  { return(false); };

  virtual u_int64_t getNumPackets();
  virtual u_int64_t getNumBytes();
  virtual u_int     getNumPacketDrops();
  virtual u_int     getNumFlows();
  virtual u_int     getNumL2Devices();
  virtual u_int     getNumHosts();
  virtual u_int     getNumLocalHosts();
  virtual u_int     getNumMacs();
  virtual u_int     getNumHTTPHosts();

  virtual u_int64_t getCheckPointNumPackets();
  virtual u_int64_t getCheckPointNumBytes();
  virtual u_int32_t getCheckPointNumPacketDrops();

  virtual u_int32_t getASesHashSize();
  virtual u_int32_t getCountriesHashSize();
  virtual u_int32_t getVLANsHashSize();
  virtual u_int32_t getMacsHashSize();
  virtual u_int32_t getHostsHashSize();
  virtual u_int32_t getFlowsHashSize();
  virtual Mac*  getMac(u_int8_t _mac[6], bool createIfNotPresent);
  virtual Host* getHost(char *host_ip, u_int16_t vlan_id);
  virtual Flow* findFlowByKey(u_int32_t key, AddressTree *allowed_hosts);

  virtual bool walker(u_int32_t *begin_slot, bool walk_all,
		      WalkerType wtype,		      
		      bool (*walker)(GenericHashEntry *h,
				     void *user_data, bool *entryMatched),
		      void *user_data);
  
  virtual void lua(lua_State* vm);
};

#endif /* _VIEW_INTERFACE_H_ */

