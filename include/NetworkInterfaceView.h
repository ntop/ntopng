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
#include <list>

class NetworkInterface;

class NetworkInterfaceView {
 protected:
  char *ifvname; /**< Network interface name.*/
  char *descr;
  int id;
  list<NetworkInterface *> physIntf;
  list<string> physNames;
  int num_intfs;

  NetworkInterface *iface;

 public:
  NetworkInterfaceView(NetworkInterface *intf);
  NetworkInterfaceView(const char *name, int id);
  virtual ~NetworkInterfaceView();

  list<NetworkInterface *>::iterator intfBegin() { return physIntf.begin(); }
  list<NetworkInterface *>::iterator intfEnd() {return physIntf.end(); }

  inline char *get_name(void) { return ifvname; }
  inline int get_num_intfs(void) { return num_intfs; }
  inline NetworkInterface *get_iface(void) { return iface; }
  inline void set_id(unsigned int id) { this->id = id; }
  inline int get_id() { return id; }
  inline char *get_descr(void);

  bool hasNamesAs(const char *names);
  bool hasIdsAs(const char *names);

  void flushHostContacts();
  void getnDPIStats(NdpiStats *stats);
  void getActiveHostsList(lua_State* vm, patricia_tree_t *allowed_hosts, bool host_details, bool local_only);
  void getFlowsStats(lua_State* vm);
  void getActiveAggregatedHostsList(lua_State* vm, patricia_tree_t *allowed_hosts, u_int16_t proto_family, char *host);
  u_int getNumAggregatedHosts(void);
  bool hasSeenVlanTaggedPackets(void);
  int  retrieve(lua_State* vm, patricia_tree_t *allowed_hosts, char *SQL);
  bool getHostInfo(lua_State* vm, patricia_tree_t *allowed_hosts, char *host_ip, u_int16_t vlan_id);
  bool loadHostAlertPrefs(lua_State* vm, patricia_tree_t *allowed_hosts, char *host_ip, u_int16_t vlan_id);
  bool correlateHostActivity(lua_State* vm, patricia_tree_t *allowed_hosts, char *host_ip, u_int16_t vlan_id);
  bool similarHostActivity(lua_State* vm, patricia_tree_t *allowed_hosts, char *host_ip, u_int16_t vlan_id);
  Host *getHost(char *host_ip, u_int16_t vlan_id);
  StringHost *getAggregatedHost(char *host_name);
  bool restoreHost(char *host_ip);
  bool getAggregatedHostInfo(lua_State* vm, patricia_tree_t *ptree, char *host_name);
  bool getAggregatedFamilies(lua_State* vm);
  bool getAggregationsForHost(lua_State* vm, patricia_tree_t *allowed_hosts, char *host_ip);
  void getFlowPeersList(lua_State* vm, patricia_tree_t *allowed_hosts, char *numIP, u_int16_t vlanId);
  Flow *findFlowByKey(u_int32_t key, patricia_tree_t *allowed_hosts);
  void findUserFlows(lua_State *vm, char *username);
  void findPidFlows(lua_State *vm, u_int32_t pid);
  void findFatherPidFlows(lua_State *vm, u_int32_t father_pid);
  void findProcNameFlows(lua_State *vm, char *proc_name);
  void listHTTPHosts(lua_State *vm, char *key);
  void findHostsByName(lua_State* vm, patricia_tree_t *allowed_hosts, char *key);
  int isRunning(void);
  bool idle(void);
  void setIdleState(bool new_state);
  void getnDPIProtocols(lua_State *vm);

  PacketDumper *getPacketDumper(void);
  PacketDumperTuntap *getPacketDumperTap(void);
  bool getDumpTrafficDiskPolicy(void);
  bool getDumpTrafficTapPolicy(void);
  string getDumpTrafficTapName(void);
  int getDumpTrafficMaxPktsPerFile(void);
  int getDumpTrafficMaxSecPerFile(void);
  int getDumpTrafficMaxFiles(void);

  void getnDPIFlowsCount(lua_State *vm);
  void lua(lua_State *vm);
#ifdef NTOPNG_PRO
  void refreshL7Rules();
  void refreshShapers();
#endif
  void loadDumpPrefs();
  Host* findHostsByIP(patricia_tree_t *allowed_hosts, char *host_ip, u_int16_t vlan_id);
};

#endif /* _NETWORK_INTERFACE_VIEW_H_ */
