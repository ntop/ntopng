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
#include <iostream>
#include <vector>

CommunitiesManager::CommunitiesManager() {
  num_communities = 0;
}

CommunitiesManager::~CommunitiesManager() {
}

patricia_tree_t *CommunitiesManager::findCommunityById(int community_id) {
  return communities.at(community_id);
}

patricia_tree_t *CommunitiesManager::getCommunity(int community_id, string community_name) {
  patricia_tree_t *ptree;
  if ((ptree = findCommunityById(community_id)))
    return ptree;
  ptree = New_Patricia(128);
  communities.at(community_id) = ptree;
  community_names.at(community_id) = community_name;
  return ptree;
}

string CommunitiesManager::getCommunityName(int community_id) {
  return community_names.at(community_id);
}

void CommunitiesManager::addNetwork(int community_id, string community_name, char *_net) {
  patricia_node_t *node;
  patricia_tree_t *community = NULL;

  ntop->getTrace()->traceEvent(TRACE_INFO, "Set network %s to community %s [%d]", _net, community_name.c_str(), community_id);

  if (num_communities >= CONST_MAX_NUM_COMMUNITIES) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Too many communities defined: ignored %d", community_id);
    return;
  }

  if (community_id >= num_communities) {
    communities.resize(community_id+1);
    community_names.resize(community_id+1);
  }

  community = getCommunity(community_id, community_name);
  node = ptree_add_rule(community, _net);
  if (node)
    node->user_data = community_id;

  num_communities++;
}

int CommunitiesManager::findAddress(int community_id, int family, void *addr) {
  patricia_node_t *node = NULL;

  if (community_id < num_communities)
    node = ptree_match(communities.at(community_id), family, addr, (family == AF_INET) ? 32 : 128);

  if (node == NULL)
    return -1;
  else
    return node->user_data;
}

void CommunitiesManager::listAddressCommunitiesLua(lua_State* vm, int family, void *addr) {
  int i = 0;
  int num_communities = 0;

  for (std::vector<patricia_tree_t *>::iterator it = communities.begin() ; it != communities.end(); ++it)
     if (community_names.at(i) != "" && findAddress(i, family, addr) != -1) num_communities++;

  if (num_communities == 0) {
    lua_pushnil(vm);
    return;
  }

  lua_newtable(vm);

  for (std::vector<patricia_tree_t *>::iterator it = communities.begin() ; it != communities.end(); ++it) {
    /* default value for string is "" */
    if (community_names.at(i) != "" && findAddress(i, family, addr) != -1)
      lua_push_int_table_entry(vm, community_names.at(i).c_str(), i);
    i++;
  }

  lua_pushstring(vm, (char *)addr);
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* Format:
   communityX@id1=net1,net2,net3
   communityY@id2=net4,net5,net6
 */
void CommunitiesManager::parseCommunitiesFile(char *fname) {
  char *tok = NULL, community_name[MAX_PATH];
  string st;
  int community_id;
  int line = 0;

  ifstream ifs(fname, std::ifstream::in);
  if(!ifs.is_open()) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Communities file %s does not exist", fname);
    return;
  }

  while(std::getline(ifs, st)) {
    tok = strtok((char *)st.c_str(), "@");
    if (!tok) goto error;
    strncpy(community_name, tok, MAX_PATH);
    tok = strtok(NULL, "=");
    if (!tok) goto error;
    community_id = atoi(tok);
    tok = strtok(NULL, ",");
    if (!tok) goto error;
    while (tok != NULL) {
      addNetwork(community_id, community_name, tok);
      tok = strtok(NULL, ",");
    }
    line++;
  }

  return;

error:
  ntop->getTrace()->traceEvent(TRACE_ERROR, "Parsing error in file %s at line %d", fname, line);
}

