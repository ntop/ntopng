/*
 *
 * (C) 2013-16 - ntop.org
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

/* ****************************************** */

NetworkInterfaceView::NetworkInterfaceView(const char *_name) {
  NetworkInterface *intf;

  numInterfaces = 0;
  if(strncmp(_name, "view:", 5)) {
    intf = ntop->getNetworkInterface(_name);
    if(intf)
      physIntf[numInterfaces++] = intf, id = Utils::ifname2id(_name);
    else
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unknown interface %s: skept", _name);
  } else {
    char buf[128], *iface;

    snprintf(buf, sizeof(buf), "%s", &_name[5]);

    iface = strtok(buf, ","), id = Utils::ifname2id(&_name[5]);

    while(iface) {
      if((intf = ntop->getNetworkInterface(iface)) != NULL) {
	physIntf[numInterfaces++] = intf;
      } else
	ntop->getTrace()->traceEvent(TRACE_ERROR, "Unknown interface %s in view %s: skept", iface, _name);

      if(numInterfaces == MAX_NUM_VIEW_INTERFACES) {
	ntop->getTrace()->traceEvent(TRACE_ERROR, "Too many (%d) interfaces for this view", numInterfaces);
	break;
      } else
	iface = strtok(NULL, ",");
    }
  }

  name = strdup(_name);
}

/* **************************************************** */

NetworkInterfaceView::~NetworkInterfaceView() {
  if(name) free(name);
}

/* **************************************************** */

void NetworkInterfaceView::loadDumpPrefs() {
  for(int i = 0; i<numInterfaces; i++)
    physIntf[i]->loadDumpPrefs();
}

/* **************************************************** */

#ifdef NTOPNG_PRO
void NetworkInterfaceView::updateFlowProfiles() {
  for(int i = 0; i<numInterfaces; i++)
    physIntf[i]->updateFlowProfiles();
}
#endif

/* **************************************************** */

#ifdef NTOPNG_PRO
void NetworkInterfaceView::refreshL7Rules() {
  for(int i = 0; i<numInterfaces; i++)
    physIntf[i]->refreshL7Rules();
}
#endif

/* **************************************************** */

#ifdef NTOPNG_PRO
void NetworkInterfaceView::refreshShapers() {
  for(int i = 0; i<numInterfaces; i++)
    physIntf[i]->refreshShapers();
}
#endif

/* **************************************************** */

void NetworkInterfaceView::getnDPIStats(nDPIStats *stats) {
  memset(stats, 0, sizeof(nDPIStats));

  for(int i = 0; i<numInterfaces; i++)
    physIntf[i]->getnDPIStats(stats);
}

/* **************************************************** */

int NetworkInterfaceView::getActiveHostsList(lua_State* vm,
					     patricia_tree_t *allowed_hosts,
					     bool host_details, bool local_only,
					     char *sortColumn, u_int32_t maxHits,
					     u_int32_t toSkip, bool a2zSortOrder) {
  int ret = 0;

  lua_newtable(vm);
  for(int i = 0; i<numInterfaces; i++) {
    int rc = physIntf[i]->getActiveHostsList(vm, allowed_hosts, host_details, local_only, 
					     sortColumn, maxHits,
					     toSkip, a2zSortOrder);
    if(rc < 0) return(ret); 
    rc += ret;
    
    lua_pushstring(vm, physIntf[i]->get_name()); // Key
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }

  return(ret);
}

/* **************************************************** */

bool NetworkInterfaceView::hasSeenVlanTaggedPackets() {
  for(int i = 0; i<numInterfaces; i++)
    if(physIntf[i]->hasSeenVlanTaggedPackets()) return true;

  return false;
}

/* **************************************************** */

int NetworkInterfaceView::getFlows(lua_State* vm,
				   patricia_tree_t *allowed_hosts,
				   Host *host, int ndpi_proto,
				   bool local_only,
				   char *sortColumn,
				   u_int32_t maxHits,
				   u_int32_t toSkip,
				   bool a2zSortOrder) {
  int ret = 0;

  lua_newtable(vm);

  for(int i = 0; i<numInterfaces; i++) {
    int rc = physIntf[i]->getFlows(vm, allowed_hosts, host, ndpi_proto,
				   local_only, sortColumn, maxHits, 
				   toSkip, a2zSortOrder);
    
    if(rc < 0) return(ret);
    rc += ret;

    lua_pushstring(vm, physIntf[i]->get_name()); // Key
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }

  return(ret);
}

/* **************************************************** */

void NetworkInterfaceView::getFlowsStats(lua_State* vm) {
  lua_newtable(vm);

  for(int i = 0; i<numInterfaces; i++)
    physIntf[i]->getFlowsStats(vm);
}

/* **************************************************** */

void NetworkInterfaceView::getNetworksStats(lua_State* vm) {
  lua_newtable(vm);

  for(int i = 0; i<numInterfaces; i++)
    physIntf[i]->getNetworksStats(vm);
}

/* **************************************************** */

bool NetworkInterfaceView::getHostInfo(lua_State* vm,
				       patricia_tree_t *allowed_hosts,
				       char *host_ip, u_int16_t vlan_id) {
  bool ret = false;

  lua_newtable(vm);

  for(int i = 0; i<numInterfaces; i++)
    if(physIntf[i]->getHostInfo(vm, allowed_hosts, host_ip, vlan_id)) ret = true;

  return ret;
}

/* **************************************************** */

bool NetworkInterfaceView::loadHostAlertPrefs(lua_State* vm,
				              patricia_tree_t *allowed_hosts,
				              char *host_ip, u_int16_t vlan_id) {
  bool ret = false;

  lua_newtable(vm);

  for(int i = 0; i<numInterfaces; i++)
    if(physIntf[i]->loadHostAlertPrefs(vm, allowed_hosts, host_ip, vlan_id)) ret = true;

  return ret;
}

/* **************************************************** */

bool NetworkInterfaceView::correlateHostActivity(lua_State* vm,
			                         patricia_tree_t *allowed_hosts,
					         char *host_ip, u_int16_t vlan_id) {
  bool ret = false;

  lua_newtable(vm);

  for(int i = 0; i<numInterfaces; i++)
    if(physIntf[i]->correlateHostActivity(vm, allowed_hosts, host_ip, vlan_id)) ret = true;

  return ret;
}

/* **************************************************** */

bool NetworkInterfaceView::similarHostActivity(lua_State* vm,
					       patricia_tree_t *allowed_hosts,
					       char *host_ip, u_int16_t vlan_id) {
  bool ret = false;

  lua_newtable(vm);

  for(int i = 0; i<numInterfaces; i++)
    if(physIntf[i]->similarHostActivity(vm, allowed_hosts, host_ip, vlan_id)) ret = true;

  return ret;
}

/* **************************************************** */

Host* NetworkInterfaceView::getHost(char *host_ip, u_int16_t vlan_id) {
  Host *h = NULL;

  for(int i = 0; i<numInterfaces; i++)
    if((h = physIntf[i]->getHost(host_ip, vlan_id))) return h;

  return h;
}

/* **************************************************** */

bool NetworkInterfaceView::restoreHost(char *host_ip) {
  for(int i = 0; i<numInterfaces; i++)
    if(physIntf[i]->restoreHost(host_ip)) return true;

  return false;
}

/* **************************************************** */

void NetworkInterfaceView::getFlowPeersList(lua_State* vm,
					    patricia_tree_t *allowed_hosts,
					    char *numIP, u_int16_t vlanId) {
  lua_newtable(vm);

  for(int i = 0; i<numInterfaces; i++)
    physIntf[i]->getFlowPeersList(vm, allowed_hosts, numIP, vlanId);
}

/* **************************************************** */

Flow* NetworkInterfaceView::findFlowByKey(u_int32_t key,
				          patricia_tree_t *allowed_hosts) {
  Flow *f = NULL;

  for(int i = 0; i<numInterfaces; i++)
    if((f = physIntf[i]->findFlowByKey(key, allowed_hosts))) return f;

  return f;
}

/* **************************************************** */

void NetworkInterfaceView::findUserFlows(lua_State *vm, char *username) {
  lua_newtable(vm);

  for(int i = 0; i<numInterfaces; i++)
    physIntf[i]->findUserFlows(vm, username);
}

/* **************************************** */

void NetworkInterfaceView::findPidFlows(lua_State *vm, u_int32_t pid) {
  lua_newtable(vm);

  for(int i = 0; i<numInterfaces; i++)
    physIntf[i]->findPidFlows(vm, pid);
}

/* **************************************** */

void NetworkInterfaceView::findFatherPidFlows(lua_State *vm, u_int32_t father_pid) {
  lua_newtable(vm);

  for(int i = 0; i<numInterfaces; i++)
    physIntf[i]->findFatherPidFlows(vm, father_pid);
}

/* **************************************** */

void NetworkInterfaceView::findProcNameFlows(lua_State *vm, char *proc_name) {
  lua_newtable(vm);

  for(int i = 0; i<numInterfaces; i++)
    physIntf[i]->findProcNameFlows(vm, proc_name);
}

/* **************************************** */

void NetworkInterfaceView::listHTTPHosts(lua_State *vm, char *key) {
  lua_newtable(vm);

  for(int i = 0; i<numInterfaces; i++)
    physIntf[i]->listHTTPHosts(vm, key);
}

/* **************************************** */

void NetworkInterfaceView::findHostsByName(lua_State* vm,
				           patricia_tree_t *allowed_hosts,
				           char *key) {
  lua_newtable(vm);

  for(int i = 0; i<numInterfaces; i++)
    physIntf[i]->findHostsByName(vm, allowed_hosts, key);
}

/* **************************************** */

Host* NetworkInterfaceView::findHostsByIP(patricia_tree_t *allowed_hosts,
					  char *key, u_int16_t vlan_id) {
  for(int i = 0; i<numInterfaces; i++) {
    Host *h;

    if((h = physIntf[i]->findHostsByIP(allowed_hosts, key, vlan_id)) != NULL)
      return(h);
  }

  return(NULL);
}

/* **************************************** */

int NetworkInterfaceView::isRunning() {
  for(int i = 0; i<numInterfaces; i++)
    if(physIntf[i]->isRunning()) return true;

  return false;
}

/* **************************************** */

bool NetworkInterfaceView::idle() {
  for(int i = 0; i<numInterfaces; i++)
    if(!physIntf[i]->idle()) return false;

  return true;
}

/* **************************************** */

void NetworkInterfaceView::setIdleState(bool new_state) {
  for(int i = 0; i<numInterfaces; i++)
    physIntf[i]->setIdleState(new_state);
}

/* *************************************** */

void NetworkInterfaceView::getnDPIProtocols(lua_State *vm) {
  lua_newtable(vm);
  getFirst()->getnDPIProtocols(vm);
}

/* *************************************** */

bool NetworkInterfaceView::getDumpTrafficDiskPolicy() {
  for(int i = 0; i<numInterfaces; i++) {
    if(physIntf[i]->getDumpTrafficDiskPolicy())
      return true;
  }

  return false;
}

/* *************************************** */

bool NetworkInterfaceView::getDumpTrafficTapPolicy() {
  for(int i = 0; i<numInterfaces; i++) {
    if(physIntf[i]->getDumpTrafficTapPolicy())
      return true;
  }
  return false;
}

/* *************************************** */

string NetworkInterfaceView::getDumpTrafficTapName() {
  string s = "";

  for(int i = 0; i<numInterfaces; i++) {
    if(i > 0) s += ", ";
    s += physIntf[i]->getDumpTrafficTapName();
  }

  return s;
}

/* *************************************** */

void NetworkInterfaceView::getnDPIFlowsCount(lua_State *vm) {
  for(int i = 0; i<numInterfaces; i++)
    physIntf[i]->getnDPIFlowsCount(vm);
}

/* *************************************** */

void NetworkInterfaceView::updateSecondTraffic(time_t when) {
  for(int i = 0; i<numInterfaces; i++)
    physIntf[i]->updateSecondTraffic(when);
}

/* *************************************** */

int NetworkInterfaceView::getDumpTrafficMaxPktsPerFile() {
  int max_pkts = 0;

  for(int i = 0; i<numInterfaces; i++) {
    int temp_num_pkts = physIntf[i]->getDumpTrafficMaxPktsPerFile();
    if(temp_num_pkts > max_pkts)
      max_pkts = temp_num_pkts;
  }

  return max_pkts;
}

/* *************************************** */

int NetworkInterfaceView::getDumpTrafficMaxSecPerFile() { return(getFirst()->getDumpTrafficMaxSecPerFile()); }
int NetworkInterfaceView::getDumpTrafficMaxFiles()      {  return(getFirst()->getDumpTrafficMaxFiles());     }
PacketDumper *NetworkInterfaceView::getPacketDumper()              { return(getFirst()->getPacketDumper());       }
PacketDumperTuntap *NetworkInterfaceView::getPacketDumperTap()     { return(getFirst()->getPacketDumperTap());    }
int NetworkInterfaceView::exec_sql_query(lua_State *vm, char *sql) { return(getFirst()->exec_sql_query(vm, sql)); }

/* *************************************** */

void NetworkInterfaceView::lua(lua_State *vm) {
  int n = 0;

  lua_newtable(vm);

  lua_newtable(vm);
  for(int i = 0; i<numInterfaces; i++) {
    physIntf[i]->lua(vm);

    lua_pushstring(vm, physIntf[i]->get_name());
    lua_insert(vm, -2);
    lua_settable(vm, -3);
    n++;
  }

  lua_pushstring(vm, "interfaces");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_push_str_table_entry(vm, "name", name);
  lua_push_int_table_entry(vm, "id", id);
  lua_push_bool_table_entry(vm, "isView", n > 1 ? true : false);
}
