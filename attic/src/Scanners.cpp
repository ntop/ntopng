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

/* **************************************** */

Scanners::Scanners() {
  offline_scanners_ptree = NULL;
  inline_scanners_ptree  = new (std::nothrow) ScannersAddressTree();
}

/* **************************************** */

Scanners::~Scanners() {
  if(offline_scanners_ptree) delete offline_scanners_ptree;
  if(inline_scanners_ptree)  delete inline_scanners_ptree;
}

/* **************************************** */

void Scanners::inlineIncScanner(const IpAddress *ipa, u_int32_t weight) {
  if(inline_scanners_ptree)
    inline_scanners_ptree->incHits(ipa, weight);
}

/* **************************************** */

void Scanners::inlineRefreshScanners() {
  if(!offline_scanners_ptree) {
    offline_scanners_ptree = inline_scanners_ptree;
    inline_scanners_ptree = new (std::nothrow) ScannersAddressTree();
  }
}

/* **************************************** */

void Scanners::getScanners(lua_State *vm) {
  if(!offline_scanners_ptree)
    return;

  offline_scanners_ptree->getScanners(vm);

  delete offline_scanners_ptree;
  offline_scanners_ptree = NULL;
}
