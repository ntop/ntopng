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

#include "ntop_includes.h"

/* **************************************************** */

NetworkInterfaceView::NetworkInterfaceView(NetworkInterface *intf) {
  assert(intf);

  physIntf.push_back(intf);
  physNames.push_back(intf->get_name());
  ifvname = strdup(intf->get_name());
  num_intfs = 1;
  iface = intf;
  this->id = intf->get_id();
  descr = strdup(ifvname);
}

NetworkInterfaceView::NetworkInterfaceView(const char *name, int id) {
  string ifname, desc = "";
  NetworkInterface *intf = NULL;

  name = &name[5]; /* Skip view: */

  /* cmdtok keeps the interfaces */
  istringstream st(name);
  num_intfs = 0;
  while(std::getline(st, ifname, ',')) {
    intf = ntop->getNetworkInterface(ifname.c_str());
    if(intf) {
      physIntf.push_back(intf);
      physNames.push_back(intf->get_name());
      if(num_intfs != 0) desc += ",";
      desc += intf->get_name();
      num_intfs++;
    }
  }

  if(num_intfs == 1) iface = intf;
  ifvname = strdup(desc.c_str());
  iface = NULL;
  this->id = id;
  descr = strdup(desc.c_str());
}

NetworkInterfaceView::~NetworkInterfaceView() {
  physIntf.clear();
  physNames.clear();
  free(ifvname);
  free(descr);
}

/* **************************************************** */

void NetworkInterfaceView::loadDumpPrefs() {
  list<NetworkInterface *>::iterator p;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    (*p)->loadDumpPrefs();
}

/* **************************************************** */

#ifdef NTOPNG_PRO
void NetworkInterfaceView::refreshL7Rules() {
  list<NetworkInterface *>::iterator p;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    (*p)->refreshL7Rules();
}
#endif

/* **************************************************** */

#ifdef NTOPNG_PRO
void NetworkInterfaceView::refreshShapers() {
  list<NetworkInterface *>::iterator p;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    (*p)->refreshShapers();
}
#endif

/* **************************************************** */

void NetworkInterfaceView::getnDPIStats(nDPIStats *stats) {
  list<NetworkInterface *>::iterator p;

  memset(stats, 0, sizeof(nDPIStats));
  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    (*p)->getnDPIStats(stats);
}

/* **************************************************** */

void NetworkInterfaceView::getActiveHostsList(lua_State* vm,
					      patricia_tree_t *allowed_hosts,
					      bool host_details,
					      bool local_only) {
  struct vm_ptree vp;
  list<NetworkInterface *>::iterator p;

  vp.vm = vm, vp.ptree = allowed_hosts;

  lua_newtable(vm);
  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    (*p)->getActiveHostsList(vm, &vp, host_details, local_only);
}

/* **************************************************** */

bool NetworkInterfaceView::hasSeenVlanTaggedPackets() {
  list<NetworkInterface *>::iterator p;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    if((*p)->hasSeenVlanTaggedPackets()) return true;

  return false;
}

/* **************************************************** */

int NetworkInterfaceView::retrieve(lua_State* vm, patricia_tree_t *allowed_hosts,
                                   char *SQL) {
  list<NetworkInterface *>::iterator p;
  int ret = 0;

  lua_newtable(vm);

  for(p = physIntf.begin() ; p != physIntf.end() ; p++) {
    if ((ret = (*p)->retrieve(vm, allowed_hosts, SQL)))
      return ret;
  }

  return ret;
}

/* **************************************************** */

void NetworkInterfaceView::getFlowsStats(lua_State* vm) {
  list<NetworkInterface *>::iterator p;

  lua_newtable(vm);

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    (*p)->getFlowsStats(vm);
}

/* **************************************************** */

bool NetworkInterfaceView::getHostInfo(lua_State* vm,
				       patricia_tree_t *allowed_hosts,
				       char *host_ip, u_int16_t vlan_id) {
  list<NetworkInterface *>::iterator p;
  bool ret = false;

  lua_newtable(vm);

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    if((*p)->getHostInfo(vm, allowed_hosts, host_ip, vlan_id)) ret = true;

  return ret;
}

/* **************************************************** */

bool NetworkInterfaceView::loadHostAlertPrefs(lua_State* vm,
				              patricia_tree_t *allowed_hosts,
				              char *host_ip, u_int16_t vlan_id) {
  list<NetworkInterface *>::iterator p;
  bool ret = false;

  lua_newtable(vm);

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    if((*p)->loadHostAlertPrefs(vm, allowed_hosts, host_ip, vlan_id)) ret = true;

  return ret;
}

/* **************************************************** */

bool NetworkInterfaceView::correlateHostActivity(lua_State* vm,
			                         patricia_tree_t *allowed_hosts,
					         char *host_ip, u_int16_t vlan_id) {
  list<NetworkInterface *>::iterator p;
  bool ret = false;

  lua_newtable(vm);

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    if((*p)->correlateHostActivity(vm, allowed_hosts, host_ip, vlan_id)) ret = true;

  return ret;
}

/* **************************************************** */

bool NetworkInterfaceView::similarHostActivity(lua_State* vm,
					       patricia_tree_t *allowed_hosts,
					       char *host_ip, u_int16_t vlan_id) {
  list<NetworkInterface *>::iterator p;
  bool ret = false;

  lua_newtable(vm);

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    if((*p)->similarHostActivity(vm, allowed_hosts, host_ip, vlan_id)) ret = true;

  return ret;
}

/* **************************************************** */

Host* NetworkInterfaceView::getHost(char *host_ip, u_int16_t vlan_id) {
  list<NetworkInterface *>::iterator p;
  Host *h = NULL;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    if((h = (*p)->getHost(host_ip, vlan_id))) return h;

  return h;
}

/* **************************************************** */

bool NetworkInterfaceView::restoreHost(char *host_ip) {
  list<NetworkInterface *>::iterator p;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    if((*p)->restoreHost(host_ip)) return true;

  return false;
}

/* **************************************************** */

void NetworkInterfaceView::getFlowPeersList(lua_State* vm,
					    patricia_tree_t *allowed_hosts,
					    char *numIP, u_int16_t vlanId) {
  list<NetworkInterface *>::iterator p;

  lua_newtable(vm);

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    (*p)->getFlowPeersList(vm, allowed_hosts, numIP, vlanId);
}

/* **************************************************** */

Flow* NetworkInterfaceView::findFlowByKey(u_int32_t key,
				          patricia_tree_t *allowed_hosts) {
  list<NetworkInterface *>::iterator p;
  Flow *f = NULL;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    if((f = (*p)->findFlowByKey(key, allowed_hosts))) return f;

  return f;
}

/* **************************************************** */

void NetworkInterfaceView::findUserFlows(lua_State *vm, char *username) {
  list<NetworkInterface *>::iterator p;

  lua_newtable(vm);

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    (*p)->findUserFlows(vm, username);
}

/* **************************************** */

void NetworkInterfaceView::findPidFlows(lua_State *vm, u_int32_t pid) {
  list<NetworkInterface *>::iterator p;

  lua_newtable(vm);

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    (*p)->findPidFlows(vm, pid);
}

/* **************************************** */

void NetworkInterfaceView::findFatherPidFlows(lua_State *vm, u_int32_t father_pid) {
  list<NetworkInterface *>::iterator p;

  lua_newtable(vm);

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    (*p)->findFatherPidFlows(vm, father_pid);
}

/* **************************************** */

void NetworkInterfaceView::findProcNameFlows(lua_State *vm, char *proc_name) {
  list<NetworkInterface *>::iterator p;

  lua_newtable(vm);

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    (*p)->findProcNameFlows(vm, proc_name);
}

/* **************************************** */

void NetworkInterfaceView::listHTTPHosts(lua_State *vm, char *key) {
  list<NetworkInterface *>::iterator p;

  lua_newtable(vm);

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    (*p)->listHTTPHosts(vm, key);
}

/* **************************************** */

void NetworkInterfaceView::findHostsByName(lua_State* vm,
				           patricia_tree_t *allowed_hosts,
				           char *key) {
  list<NetworkInterface *>::iterator p;

  lua_newtable(vm);

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    (*p)->findHostsByName(vm, allowed_hosts, key);
}

/* **************************************** */

Host* NetworkInterfaceView::findHostsByIP(patricia_tree_t *allowed_hosts, 
					  char *key, u_int16_t vlan_id) {
  list<NetworkInterface *>::iterator p;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++) {
    Host *h;
    if((h = (*p)->findHostsByIP(allowed_hosts, key, vlan_id)) != NULL)
      return(h);   
  }

  return(NULL);
}

/* **************************************** */

int NetworkInterfaceView::isRunning() {
  list<NetworkInterface *>::iterator p;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    if((*p)->isRunning()) return true;

  return false;
}

/* **************************************** */

bool NetworkInterfaceView::idle() {
  list<NetworkInterface *>::iterator p;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    if(!(*p)->idle()) return false;

  return true;
}

/* **************************************** */

void NetworkInterfaceView::setIdleState(bool new_state) {
  list<NetworkInterface *>::iterator p;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    (*p)->setIdleState(new_state);
}

/* *************************************** */

void NetworkInterfaceView::getnDPIProtocols(lua_State *vm) {
  list<NetworkInterface *>::iterator p;

  lua_newtable(vm);

  for(p = physIntf.begin() ; p != physIntf.end() ; p++) {
    (*p)->getnDPIProtocols(vm);
    break;
  }
}

/* *************************************** */

bool NetworkInterfaceView::getDumpTrafficDiskPolicy(void) {
  list<NetworkInterface *>::iterator p;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++) {
    if ((*p)->getDumpTrafficDiskPolicy())
      return true;
  }
  return false;
}

/* *************************************** */

bool NetworkInterfaceView::getDumpTrafficTapPolicy(void) {
  list<NetworkInterface *>::iterator p;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++) {
    if ((*p)->getDumpTrafficTapPolicy())
      return true;
  }
  return false;
}

/* *************************************** */

string NetworkInterfaceView::getDumpTrafficTapName(void) {
  list<NetworkInterface *>::iterator p;
  int i = 0;
  string s = "";

  for(p = physIntf.begin() ; p != physIntf.end() ; p++) {
    s += (*p)->getDumpTrafficTapName();
    if (i < num_intfs-1) s += ", ";
    i++;
  }

  return s;
}

/* *************************************** */

void NetworkInterfaceView::getnDPIFlowsCount(lua_State *vm) {
  list<NetworkInterface *>::iterator p;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    (*p)->getnDPIFlowsCount(vm);
}

/* *************************************** */

int NetworkInterfaceView::getDumpTrafficMaxPktsPerFile(void) {
  list<NetworkInterface *>::iterator p;
  int max_pkts = 0;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++) {
    int temp_num_pkts = (*p)->getDumpTrafficMaxPktsPerFile();
    if (temp_num_pkts > max_pkts)
      max_pkts = temp_num_pkts;
  }

  return max_pkts;
}

/* *************************************** */

int NetworkInterfaceView::getDumpTrafficMaxSecPerFile(void) {
  list<NetworkInterface *>::iterator p;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    return (*p)->getDumpTrafficMaxSecPerFile();

  return 0;
}

/* *************************************** */

int NetworkInterfaceView::getDumpTrafficMaxFiles(void) {
  list<NetworkInterface *>::iterator p;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    return (*p)->getDumpTrafficMaxFiles();

  return 0;
}

/* *************************************** */

PacketDumper *NetworkInterfaceView::getPacketDumper(void) {
  list<NetworkInterface *>::iterator p;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    return (*p)->getPacketDumper();

  return NULL;
}

/* *************************************** */

PacketDumperTuntap *NetworkInterfaceView::getPacketDumperTap(void) {
  list<NetworkInterface *>::iterator p;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    return (*p)->getPacketDumperTap();

  return NULL;
}

/* *************************************** */

int NetworkInterfaceView::exec_sql_query(lua_State *vm, char *sql) {
  list<NetworkInterface *>::iterator p;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    return((*p)->exec_sql_query(vm, sql));

  return(-1);
}

/* *************************************** */

#ifdef NTOPNG_PRO
void NetworkInterfaceView::updateFlowProfiles() {
  list<NetworkInterface *>::iterator p;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    (*p)->updateFlowProfiles();
}
#endif

/* *************************************** */

void NetworkInterfaceView::lua(lua_State *vm) {
  list<NetworkInterface *>::iterator p;
  int n = 0;
  
  lua_newtable(vm);

  lua_newtable(vm);
  for(p = physIntf.begin(); p != physIntf.end(); p++) {
    (*p)->lua(vm);
    
    lua_pushstring(vm, (*p)->get_name());
    lua_insert(vm, -2);
    lua_settable(vm, -3);
    n++;
  }
  
  lua_pushstring(vm, "interfaces");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
  
  lua_push_str_table_entry(vm, "name", get_name());
  lua_push_str_table_entry(vm, "description", descr);
  lua_push_int_table_entry(vm, "id", id);
  lua_push_bool_table_entry(vm, "isView", n > 1 ? true : false);
}
