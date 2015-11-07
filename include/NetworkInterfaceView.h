/*
 *
 * (C) 2013-15 - ntop.org
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

#ifndef _NETWORK_INTERFACE_VIEW_H_
#define _NETWORK_INTERFACE_VIEW_H_

#include "ntop_includes.h"

class NetworkInterface;

class NetworkInterfaceView {
 protected:
  char *name;
  int id;
  NetworkInterface *physIntf[MAX_NUM_INTERFACES];
  int numInterfaces;

 public:
  NetworkInterfaceView(const char *name);
  ~NetworkInterfaceView();

  inline char *get_name()              { return(name);          }
  inline int get_numInterfaces()       { return(numInterfaces); }
  inline NetworkInterface *getFirst()  { return(physIntf[0]);   }
  inline int get_id()                  { return(id);            }

  void getnDPIStats(nDPIStats *stats);
  void getActiveHostsList(lua_State* vm, patricia_tree_t *allowed_hosts, bool host_details, bool local_only);
  void getFlowsStats(lua_State* vm);
  void getNetworksStats(lua_State* vm);
  bool hasSeenVlanTaggedPackets();
  int  retrieve(lua_State* vm, patricia_tree_t *allowed_hosts, char *SQL);
  bool getHostInfo(lua_State* vm, patricia_tree_t *allowed_hosts, char *host_ip, u_int16_t vlan_id);
  bool loadHostAlertPrefs(lua_State* vm, patricia_tree_t *allowed_hosts, char *host_ip, u_int16_t vlan_id);
  bool correlateHostActivity(lua_State* vm, patricia_tree_t *allowed_hosts, char *host_ip, u_int16_t vlan_id);
  bool similarHostActivity(lua_State* vm, patricia_tree_t *allowed_hosts, char *host_ip, u_int16_t vlan_id);
  Host *getHost(char *host_ip, u_int16_t vlan_id);
  bool restoreHost(char *host_ip);
  void getFlowPeersList(lua_State* vm, patricia_tree_t *allowed_hosts, char *numIP, u_int16_t vlanId);
  Flow *findFlowByKey(u_int32_t key, patricia_tree_t *allowed_hosts);
  void findUserFlows(lua_State *vm, char *username);
  void findPidFlows(lua_State *vm, u_int32_t pid);
  void findFatherPidFlows(lua_State *vm, u_int32_t father_pid);
  void findProcNameFlows(lua_State *vm, char *proc_name);
  void listHTTPHosts(lua_State *vm, char *key);
  void findHostsByName(lua_State* vm, patricia_tree_t *allowed_hosts, char *key);
  int isRunning();
  bool idle();
  void setIdleState(bool new_state);
  void getnDPIProtocols(lua_State *vm);

  PacketDumper *getPacketDumper();
  PacketDumperTuntap *getPacketDumperTap();
  bool getDumpTrafficDiskPolicy();
  bool getDumpTrafficTapPolicy();
  string getDumpTrafficTapName();
  int getDumpTrafficMaxPktsPerFile();
  int getDumpTrafficMaxSecPerFile();
  int getDumpTrafficMaxFiles();

  void getnDPIFlowsCount(lua_State *vm);
  void lua(lua_State *vm);
#ifdef NTOPNG_PRO
  void refreshL7Rules();
  void refreshShapers();
#endif
  void loadDumpPrefs();
  Host* findHostsByIP(patricia_tree_t *allowed_hosts, char *host_ip, u_int16_t vlan_id);
  int exec_sql_query(lua_State *vm, char *sql);
#ifdef NTOPNG_PRO
  void updateFlowProfiles();
#endif
};

#endif /* _NETWORK_INTERFACE_VIEW_H_ */
