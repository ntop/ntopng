/*
 *
 * (C) 2013-15 - ntop.org
 *
 *
 * This program is free software; you can addresstribute it and/or modify
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

#ifndef _COMMUNITIES_MANAGER_H_
#define _COMMUNITIES_MANAGER_H_

#include "ntop_includes.h"
#include <vector>

class CommunitiesManager {
private:
  int num_communities;
  std::vector<patricia_tree_t *> communities;
  std::vector<string> community_names;

  patricia_tree_t *findCommunityById(int community_id);
  patricia_tree_t *getCommunity(int community_id, string community_name);
  string getCommunityName(int community_id);
  void addNetwork(int community_id, string community_name, char *_net);

public:
  CommunitiesManager();
  ~CommunitiesManager();

  void parseCommunitiesFile(char *fname);
};

extern patricia_node_t* ptree_add_rule(patricia_tree_t *ptree, char *line);
extern patricia_node_t* ptree_match(patricia_tree_t *tree, int family, void *addr, int bits);
extern void free_ptree_data(void *data);

#endif /* _COMMUNITIES_MANAGER_H_ */
