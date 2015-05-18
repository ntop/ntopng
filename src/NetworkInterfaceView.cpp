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
  istringstream ss(name);
  string cmdtok, ifname, desc = "";
  NetworkInterface *intf = NULL;
  int cmdcnt;

  assert(name);

  cmdcnt = 0;
  while(std::getline(ss, cmdtok, ':')) {
    /* NOTE: this is to be called only for merged interfaces view! */
    assert(cmdcnt != 0 || cmdtok == "view");
    cmdcnt++;
  }

  /* cmdtok keeps the interfaces */
  istringstream st(cmdtok);
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

/* FIXME: slow */
bool NetworkInterfaceView::hasNamesAs(const char *names) {
  istringstream ss(names);
  string ifname;
  list<string> _names;
  list<string> thisNames = list<string>(physNames.begin(), physNames.end());
  list<string> res;
  list<string>::iterator i;

  while (std::getline(ss, ifname, ',')) _names.push_back(ifname);
  set_difference(_names.begin(), _names.end(),
                 thisNames.begin(), thisNames.end(),
                 std::inserter(res, res.begin()));
  return res.empty();
}

/* **************************************************** */

/* FIXME: slow */
bool NetworkInterfaceView::hasIdsAs(const char *names) {
  istringstream ss(names);
  stringstream idss;
  string ifid;
  list<string> _ids;
  list<string> thisIds;
  list<string> res;
  list<NetworkInterface *>::iterator p;

  while (std::getline(ss, ifid, ',')) _ids.push_back(ifid);
  for(p = physIntf.begin() ; p != physIntf.end() ; p++) {
    stringstream idss; idss << (*p)->get_id();
    thisIds.push_back(idss.str());
  }
  set_difference(_ids.begin(), _ids.end(),
                 thisIds.begin(), thisIds.end(),
                 std::inserter(res, res.begin()));
  return res.empty();
}

/* **************************************************** */

void NetworkInterfaceView::flushHostContacts() {
  list<NetworkInterface *>::iterator p;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    (*p)->flushHostContacts();
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

void NetworkInterfaceView::getnDPIStats(NdpiStats *stats) {
  list<NetworkInterface *>::iterator p;

  memset(stats, 0, sizeof(NdpiStats));
  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    (*p)->getnDPIStats(stats);
}

/* **************************************************** */

void NetworkInterfaceView::getActiveHostsList(lua_State* vm,
					      patricia_tree_t *allowed_hosts,
					      bool host_details) {
  struct vm_ptree vp;
  list<NetworkInterface *>::iterator p;

  vp.vm = vm, vp.ptree = allowed_hosts;

  lua_newtable(vm);
  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    (*p)->getActiveHostsList(vm, &vp, host_details);
}

/* **************************************************** */

void NetworkInterfaceView::getActiveAggregatedHostsList(lua_State* vm,
						        patricia_tree_t *allowed_hosts,
						        u_int16_t proto_family,
						        char *host) {
  struct aggregation_walk_hosts_info info;
  list<NetworkInterface *>::iterator p;

  info.vm = vm, info.family_id = proto_family,
    info.host = host, info.allowed_hosts = allowed_hosts;

  lua_newtable(vm);

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    (*p)->getActiveAggregatedHostsList(vm, &info);
}

/* **************************************************** */

u_int NetworkInterfaceView::getNumAggregatedHosts() {
  u_int cnt = 0;
  list<NetworkInterface *>::iterator p;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    cnt += (*p)->getNumAggregatedHosts();

  return cnt;
}

/* **************************************************** */

bool NetworkInterfaceView::hasSeenVlanTaggedPackets() {
  list<NetworkInterface *>::iterator p;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    if((*p)->hasSeenVlanTaggedPackets()) return true;

  return false;
}

/* **************************************************** */

void NetworkInterfaceView::getActiveFlowsList(lua_State* vm,
					      patricia_tree_t *allowed_hosts,
					      char *host_ip,
					      u_int vlan_id) {
  list<NetworkInterface *>::iterator p;

  lua_newtable(vm);

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    (*p)->getActiveFlowsList(vm, host_ip, vlan_id, allowed_hosts);
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

StringHost* NetworkInterfaceView::getAggregatedHost(char *host_name) {
  list<NetworkInterface *>::iterator p;
  StringHost *sh = NULL;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    if((sh = (*p)->getAggregatedHost(host_name))) return sh;

  return sh;
}

/* **************************************************** */

bool NetworkInterfaceView::restoreHost(char *host_ip) {
  list<NetworkInterface *>::iterator p;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    if((*p)->restoreHost(host_ip)) return true;

  return false;
}

/* **************************************************** */

bool NetworkInterfaceView::getAggregatedHostInfo(lua_State* vm,
					         patricia_tree_t *ptree,
					         char *host_name) {
  list<NetworkInterface *>::iterator p;
  bool ret;

  lua_newtable(vm);

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    if((*p)->getAggregatedHostInfo(vm, ptree, host_name)) ret = true;

  return ret;
}

/* **************************************************** */

bool NetworkInterfaceView::getAggregatedFamilies(lua_State* vm) {
  list<NetworkInterface *>::iterator p;
  struct ndpi_protocols_aggregation agg;

  lua_newtable(vm);

  lua_newtable(vm);
  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    (*p)->getAggregationFamilies(vm, &agg);

  lua_pushstring(vm, "families");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_newtable(vm);
  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    (*p)->compareAggregationFamilies(vm, &agg);

  lua_pushstring(vm, "aggregations");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  return true;
}

/* **************************************************** */

bool NetworkInterfaceView::getAggregationsForHost(lua_State* vm,
					          patricia_tree_t *allowed_hosts,
					          char *host_ip) {
  list<NetworkInterface *>::iterator p;

  lua_newtable(vm);

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    (*p)->getAggregationsForHost(vm, allowed_hosts, host_ip);

  return(true);
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

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    (*p)->getnDPIProtocols(vm);
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

bool NetworkInterfaceView::getDumpTrafficTapPolicy(void) {
  list<NetworkInterface *>::iterator p;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++) {
    if ((*p)->getDumpTrafficTapPolicy())
      return true;
  }
  return false;
}

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

void NetworkInterfaceView::getnDPIFlowsCount(lua_State *vm) {
  list<NetworkInterface *>::iterator p;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    (*p)->getnDPIFlowsCount(vm);
}

int NetworkInterfaceView::getDumpTrafficMaxPktsPerFile(void) {
  list<NetworkInterface *>::iterator p;
  int max_pkts = 0, temp_num_pkts;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++) {
    temp_num_pkts = (*p)->getDumpTrafficMaxPktsPerFile();
    if (temp_num_pkts > max_pkts)
      max_pkts = temp_num_pkts;
  }

  return max_pkts;
}

int NetworkInterfaceView::getDumpTrafficMaxSecPerFile(void) {
  list<NetworkInterface *>::iterator p;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    return (*p)->getDumpTrafficMaxSecPerFile();

  return 0;
}

int NetworkInterfaceView::getDumpTrafficMaxFiles(void) {
  list<NetworkInterface *>::iterator p;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    return (*p)->getDumpTrafficMaxFiles();

  return 0;
}

PacketDumper *NetworkInterfaceView::getPacketDumper(void) {
  list<NetworkInterface *>::iterator p;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    return (*p)->getPacketDumper();

  return NULL;
}

PacketDumperTuntap *NetworkInterfaceView::getPacketDumperTap(void) {
  list<NetworkInterface *>::iterator p;

  for(p = physIntf.begin() ; p != physIntf.end() ; p++)
    return (*p)->getPacketDumperTap();

  return NULL;
}

/* *************************************** */

char *NetworkInterfaceView::get_descr(void) {
  return descr;
}

void NetworkInterfaceView::lua(lua_State *vm) {
  list<NetworkInterface *>::iterator p;
  bool sprobe_interface = false, inline_interface = false, has_vlan_packets = false;
  u_int64_t stats_packets = 0, stats_bytes = 0;
  u_int stats_flows = 0, stats_hosts = 0, 
    stats_http_hosts = 0, stats_aggregations = 0;
  u_int32_t stats_drops = 0;

  lua_newtable(vm);

  for(p = physIntf.begin() ; p != physIntf.end() ; p++) {
	  sprobe_interface += (*p)->get_sprobe_interface(); /* FIX */
	  inline_interface += (*p)->get_inline_interface(); /* FIX */
	  has_vlan_packets += (*p)->get_has_vlan_packets(); /* FIX */
    stats_packets += (*p)->getNumPackets();
    stats_bytes += (*p)->getNumBytes();
    stats_flows += (*p)->getNumFlows();
    stats_hosts += (*p)->getNumHosts();
    stats_http_hosts += (*p)->getNumHTTPHosts();
    stats_aggregations += (*p)->getNumAggregations();
    stats_drops += (*p)->getNumDroppedPackets();
    (*p)->lua(vm);
  }

  lua_push_str_table_entry(vm, "name", ifvname);
  lua_push_str_table_entry(vm, "description", get_descr());
  lua_push_int_table_entry(vm, "id", id);
  lua_push_bool_table_entry(vm, "iface_sprobe", sprobe_interface);
  lua_push_bool_table_entry(vm, "iface_inline", inline_interface);
  lua_push_bool_table_entry(vm, "iface_view", iface ? false : true);

  lua_push_bool_table_entry(vm, "iface_vlan", has_vlan_packets);
  lua_push_bool_table_entry(vm, "aggregations_enabled",
                            (ntop->getPrefs()->get_aggregation_mode() != aggregations_disabled) ? true : false);

  lua_push_int_table_entry(vm, "stats_packets", stats_packets);
  lua_push_int_table_entry(vm, "stats_bytes",   stats_bytes);
  lua_push_int_table_entry(vm, "stats_flows",   stats_flows);
  lua_push_int_table_entry(vm, "stats_hosts",   stats_hosts);
  lua_push_int_table_entry(vm, "stats_http_hosts",  stats_http_hosts);
  lua_push_int_table_entry(vm, "stats_aggregations", stats_aggregations);
  lua_push_int_table_entry(vm, "stats_drops",   stats_drops);

  lua_pushinteger(vm, 0); //  Index
  lua_insert(vm, -2);
}
