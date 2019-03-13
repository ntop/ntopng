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

BroadcastDomains::BroadcastDomains() {
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
  if(!inline_broadcast_domains
     || inline_broadcast_domains->match(ipa, network_bits))
    return;

  inline_broadcast_domains->addAddress(ipa, network_bits, true /* Compact after add */);

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

bool BroadcastDomains::inlineIsLocalBroadcastDomainHost(const Host * const h) const {
  if(inline_broadcast_domains && h)
    return h->match(inline_broadcast_domains);

  return false;
}
