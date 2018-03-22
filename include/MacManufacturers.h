/*
 *
 * (C) 2013-18 - ntop.org
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

#ifndef _MAC_MANUFACTURERS_H_
#define _MAC_MANUFACTURERS_H_

#include "ntop_includes.h"

typedef struct {
  u_int8_t mac_manufacturer[3];
  char *manufacturer_name;
  char *short_name;
  UT_hash_handle hh;
} mac_manufacturers_t;

class MacManufacturers {
 private:
  char manufacturers_file[MAX_PATH];
  mac_manufacturers_t *mac_manufacturers;

  void init();
 public:
  MacManufacturers(const char * const mac_file_home);
  ~MacManufacturers();

  inline const char * const getManufacturer(u_int8_t mac[]) {
    mac_manufacturers_t *m = NULL;
    HASH_FIND(hh, mac_manufacturers, mac, 3, m);
    return m ? m->manufacturer_name : NULL;
  };

  inline void getMacManufacturer(u_int8_t mac[], lua_State *vm) {
    mac_manufacturers_t *m = NULL;
    HASH_FIND(hh, mac_manufacturers, mac, 3, m);

    if (m) {
      lua_newtable(vm);
      lua_push_str_table_entry(vm, "short", m->short_name);
      lua_push_str_table_entry(vm, "extended", m->manufacturer_name);
    } else {
      lua_pushnil(vm);
    }
  };
};

#endif /* _MAC_MANUFACTURERS_H_ */
