/*
 *
 * (C) 2015-16 - ntop.org
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

/* *************************************** */
Grouper::Grouper(sortField sf){
  sorter = sf;
  group_id_set = false;
  group_id_s = NULL;
  group_label = NULL;
  memset(&stats, 0, sizeof(stats));
}

Grouper::~Grouper(){
  if(group_id_s)
    free(group_id_s);
  if(group_label)
    free(group_label);
}

bool Grouper::inGroup(Host *h) {
  if (h == NULL || group_id_set == false)
    return false;

  switch(sorter){
  case column_asn:
    return h->get_asn() == group_id_i;
  case column_vlan:
    return h->get_vlan_id() == group_id_i;
  case column_local_network_id:
    return h->get_local_network_id() == group_id_i;
  case column_mac:
    return Utils::macaddr_int(h->get_mac()) == group_id_i;
  case column_country:
    return h->get_country() ?
      !strcmp(group_id_s, h->get_country()) :
      !strcmp(group_id_s, (char*)UNKNOWN_COUNTRY);
  case column_os:
    return h->get_os() ?
      !strcmp(group_id_s, h->get_os()) :
      !strcmp(group_id_s, (char*)UNKNOWN_OS);
  default:
    return false;
  };
}

int8_t Grouper::newGroup(Host *h) {
  if (h == NULL)
    return -1;

  if (group_id_s){
    free(group_id_s);
    group_id_s = NULL;
  }
  if (group_label){
    free(group_label);
    group_label = NULL;
  }
  memset(&stats, 0, sizeof(stats));

  char buf[32];
  switch(sorter){
  case column_asn:
    group_id_i = h->get_asn();
    group_label = strdup(h->get_asname() != NULL ? h->get_asname() : (char*)UNKNOWN_ASN);
    break;
  case column_vlan:
    group_id_i = h->get_vlan_id();
    sprintf(buf, "%i", h->get_vlan_id());
    group_label = strdup(buf);
    break;
  case column_local_network_id:
    group_id_i = h->get_local_network_id();
    if(group_id_i >= 0)
      group_label = strdup(ntop->getLocalNetworkName(h->get_local_network_id()));
    else
      group_label = strdup((char*)UNKNOWN_LOCAL_NETWORK);
    break;
  case column_mac:
    group_id_i = Utils::macaddr_int(h->get_mac());
    group_label = strdup(Utils::macaddr_str((char*)h->get_mac(), buf));
    break;
  case column_country:
    group_id_s  = strdup(h->get_country() ? h->get_country() : (char*)UNKNOWN_COUNTRY);
    group_label = strdup(group_id_s);
    break;
  case column_os:
    group_id_s  = strdup(h->get_os() ? h->get_os() : (char*)UNKNOWN_OS);
    group_label = strdup(group_id_s);
    break;
  default:
    return -1;
  };

  group_id_set = true;
  return 0;
}

int8_t Grouper::incStats(Host *h) {
  if (h == NULL || !inGroup(h))
    return -1;

  stats.num_hosts++;
  stats.bytes_sent += h->getNumBytesSent();
  stats.bytes_rcvd += h->getNumBytesRcvd();
  if(stats.first_seen == 0 || h->get_first_seen() < stats.first_seen)
    stats.first_seen = h->get_first_seen();
  if(h->get_last_seen() > stats.last_seen)
    stats.last_seen = h->get_last_seen();
  stats.num_alerts += h->getNumAlerts();
  stats.throughput_bps += h->getBytesThpt();
  stats.throughput_pps += h->getPacketsThpt();
  stats.throughput_trend_bps_diff += h->getThptTrendDiff();
  if(h->get_country())
    strncpy(stats.country, h->get_country(), sizeof(stats.country));
  return 0;
}

void Grouper::lua(lua_State* vm) {
  lua_newtable(vm);

  lua_push_str_table_entry(vm,   "name", group_label);
  lua_push_int_table_entry(vm,   "bytes.sent", stats.bytes_sent);
  lua_push_int_table_entry(vm,   "bytes.rcvd", stats.bytes_rcvd);
  lua_push_int_table_entry(vm,   "seen.first", stats.first_seen);
  lua_push_int_table_entry(vm,   "seen.last", stats.last_seen);
  lua_push_int_table_entry(vm,   "num_hosts", stats.num_hosts);
  lua_push_int_table_entry(vm,   "num_alerts", stats.num_alerts);
  lua_push_float_table_entry(vm, "throughput_bps", max_val(stats.throughput_bps, 0));
  lua_push_float_table_entry(vm, "throughput_pps", max_val(stats.throughput_pps, 0));
  lua_push_float_table_entry(vm, "throughput_trend_bps_diff", max_val(stats.throughput_trend_bps_diff, 0));
  lua_push_str_table_entry(vm,   "country", strlen(stats.country) ? stats.country : (char*)"");

  if(sorter == column_mac){ // special case for mac
    lua_push_str_table_entry(vm, "id", group_label);
    lua_pushstring(vm, group_label);
  }else if(!group_id_s){ // integer group id
    lua_push_int32_table_entry(vm, "id", group_id_i);
    lua_pushinteger(vm, group_id_i);
  }else{ // string group id
    lua_push_str_table_entry(vm, "id", group_id_s);
    lua_pushstring(vm, group_id_s);
  }
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

#if 0
/* *************************************** */
GrouperEntry* Grouper::getGrouperEntryAt(const char *group_key, const char *label){
  if (!group_key)
    return NULL;

  string k(group_key);
  map<string, GrouperEntry*>::const_iterator it;

  if((it = string_grouper.find(k)) == string_grouper.end()){
    GrouperEntry *ge;
    if((ge = new(std::nothrow) GrouperEntry(label)) == NULL){
      ntop->getTrace()->traceEvent(TRACE_ERROR,
				   "Unable to allocate memory for a GrouperEntry.");
      return NULL;
    }
    string_grouper.insert(make_pair(k, ge));

  }
  return string_grouper[k];
}

/* *************************************** */
GrouperEntry* Grouper::getGrouperEntryAt(int group_key, const char *label){
  map<int, GrouperEntry*>::const_iterator it;
  if((it = number_grouper.find(group_key)) == number_grouper.end()){
    GrouperEntry *ge;
    if((ge = new(std::nothrow) GrouperEntry(label)) == NULL){
      ntop->getTrace()->traceEvent(TRACE_ERROR,
				   "Unable to allocate memory for a GrouperEntry.");
      return NULL;
    }
    number_grouper.insert(make_pair(group_key, ge));
  }
  return number_grouper[group_key];
}

/* *************************************** */
void Grouper::print(){
  map<int,    GrouperEntry*>::const_iterator iti;
  map<string, GrouperEntry*>::const_iterator its;
  for(iti = number_grouper.begin(); iti != number_grouper.end(); iti++){
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "key: %i", iti->first);
    iti->second->print();
  }
  for(its = string_grouper.begin(); its != string_grouper.end(); its++){
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "key: %s", its->first.c_str());
    its->second->print();
  }
}

/* *************************************** */
Grouper::~Grouper(){
  map<int,    GrouperEntry*>::iterator iti;
  map<string, GrouperEntry*>::iterator its;

  for(iti = number_grouper.begin(); iti != number_grouper.end(); iti++)
    if (iti->second) delete iti->second, iti->second = NULL;

  for(its = string_grouper.begin(); its != string_grouper.end(); its++)
    if(its->second) delete its->second, its->second = NULL;

  number_grouper.clear();
  string_grouper.clear();
}


/* *************************************** */
void Grouper::group(Host *h){
  if(!h)
    return;
  GrouperEntry *ge = NULL;
  if (dimension == ASN)
    ge = getGrouperEntryAt(h->get_asn(), h->get_asname());
  else if(dimension == COUNTRY)
    ge = getGrouperEntryAt(h->get_country(), h->get_country());

  if(!ge)
    return;
  ge->incStats();

}

/* *************************************** */
void Grouper::group(Host *h){
  if(!h)
    return;
  GrouperEntry *ge = NULL;
  if (dimension == ASN)
    ge = getGrouperEntryAt(h->get_asn(), h->get_asname());
  else if(dimension == COUNTRY)
    ge = getGrouperEntryAt(h->get_country(), h->get_country());

  if(!ge)
    return;
  ge->incStats();

}

/* *************************************** */

void Grouper::lua(lua_State* vm) {
  map<int,    GrouperEntry*>::iterator iti;
  map<string, GrouperEntry*>::iterator its;

  lua_newtable(vm);
  lua_push_int_table_entry(vm, "numGroups", numEntries());

  lua_newtable(vm);
  for(iti = number_grouper.begin(); iti != number_grouper.end(); iti++)
    iti->second->lua(vm);

  for(its = string_grouper.begin(); its != string_grouper.end(); its++)
    its->second->lua(vm);

  lua_pushstring(vm, "groups"); // Key
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}
#endif
