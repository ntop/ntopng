/*
 *
 * (C) 2013-21 - ntop.org
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

void Fingerprint::update(const char *_fprint, const char *app_name, bool is_malicious) {
  std::string fprint(_fprint);

  m.lock(__FILE__, __LINE__);

  std::map<std::string, FingerprintStats>::iterator it = fp.find(fprint);

  if(it == fp.end()) {
    FingerprintStats s;

    prune();
    s.app_name = std::string(app_name ? app_name : ""),
      s.num_uses = 1, s.is_malicious = is_malicious;
    fp[fprint] = s;
  } else {
    it->second.num_uses++, it->second.app_name = std::string(app_name ? app_name : "",
							     it->second.is_malicious = is_malicious);
  }

  m.unlock(__FILE__, __LINE__);
}

/* *************************************** */

void Fingerprint::lua(const char *key, lua_State* vm) {
  lua_newtable(vm);

  m.lock(__FILE__, __LINE__);

  for(std::map<std::string, FingerprintStats>::const_iterator it = fp.begin(); it != fp.end(); ++it) {
    lua_newtable(vm);

    lua_push_str_table_entry(vm, "app_name", it->second.app_name.c_str());
    lua_push_int32_table_entry(vm, "num_uses", it->second.num_uses);
    lua_push_bool_table_entry(vm, "is_malicious", it->second.is_malicious);

    lua_pushstring(vm, it->first.c_str());
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }

  m.unlock(__FILE__, __LINE__);

  lua_pushstring(vm, key);
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void Fingerprint::prune() {
  if(fp.size() > MAX_NUM_FINGERPRINT) {
    std::map<std::string, FingerprintStats>::iterator it = fp.begin();
    std::vector<std::string> dropper;

    while(it != fp.end()) {
      if(it->second.num_uses < 3)
	dropper.push_back(it->first);

      ++it;
    } /* while */

    for(std::vector<std::string>::iterator it1 = dropper.begin() ; it1 != dropper.end(); ++it1)
      fp.erase(*it1);
  }
}
