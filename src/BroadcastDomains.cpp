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

#include "ntop_includes.h"

/* *************************************** */

BroadcastDomains::BroadcastDomains(NetworkInterface *_iface) {
  iface = _iface;
  inline_broadcast_domains = new (std::nothrow) AddressTree(false);
  broadcast_domains = broadcast_domains_shadow = NULL;
  next_update = last_update = 0;
}

/* *************************************** */

BroadcastDomains::~BroadcastDomains() {
  if(inline_broadcast_domains) { delete(inline_broadcast_domains); inline_broadcast_domains = NULL; }
  if(broadcast_domains)        { delete(broadcast_domains); broadcast_domains = NULL; }
  if(broadcast_domains_shadow) { delete(broadcast_domains_shadow); broadcast_domains_shadow = NULL; }
}

/* *************************************** */

void BroadcastDomains::inlineAddAddress(const IpAddress * const ipa, int network_bits) {
  patricia_node_t *addr_node;
  if(!inline_broadcast_domains
     || inline_broadcast_domains->match(ipa, network_bits))
    return;

  addr_node = inline_broadcast_domains->addAddress(ipa, network_bits, true /* Compact after add */);

  if(addr_node)
    /* user data has information whether this broadcast domain is contained in network interface addresses */
    addr_node->user_data = iface->isInterfaceNetwork(ipa, network_bits) ? 1 : 0;

  if(!next_update)
    next_update = time(NULL) + 1;
}

/* *************************************** */

void BroadcastDomains::inlineReloadBroadcastDomains(bool force_immediate_reload) {
  time_t now = time(NULL);

  if(force_immediate_reload)
    goto reload;

  if(next_update) {
    if(now > next_update) {
      /* do the swap */
    reload:
      if(broadcast_domains_shadow)
	delete broadcast_domains_shadow;

      broadcast_domains_shadow = broadcast_domains;
      broadcast_domains = new (std::nothrow) AddressTree(*inline_broadcast_domains);

      last_update = now;
      next_update = 0;
    }
  }

  if(broadcast_domains_shadow && now > last_update + 1) {
    delete broadcast_domains_shadow;
    broadcast_domains_shadow = NULL;
  }
}

/* *************************************** */

bool BroadcastDomains::isLocalBroadcastDomain(const IpAddress * const ipa, int network_bits, bool isInlineCall) const {
  AddressTree *cur_tree = isInlineCall ? inline_broadcast_domains : broadcast_domains;

  return cur_tree && cur_tree->match(ipa, network_bits);
}

/* *************************************** */

bool BroadcastDomains::isLocalBroadcastDomainHost(const Host * const h, bool isInlineCall) const {
  AddressTree *cur_tree = isInlineCall ? inline_broadcast_domains : broadcast_domains;

  if(cur_tree && h)
    return h->match(cur_tree);

  return false;
}

/* *************************************** */

void BroadcastDomains::lua(lua_State *vm) const {
  AddressTree *cur_tree = broadcast_domains;

  lua_newtable(vm);

  if(cur_tree)
    cur_tree->getAddresses(vm);

  lua_pushstring(vm, "bcast_domains");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}
