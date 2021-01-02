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

#ifndef _MAC_MANUFACTURERS_H_
#define _MAC_MANUFACTURERS_H_

#include "ntop_includes.h"

typedef struct {
  char *manufacturer_name;
  char *short_name;
} mac_manufacturers_t;

class MacManufacturers {
 private:
  char manufacturers_file[MAX_PATH];
  std::map<u_int32_t, mac_manufacturers_t> mac_manufacturers;

  inline u_int32_t mac2key(u_int8_t mac[]) {
    u_int32_t v = 0;
    memcpy(&v, mac, 3);
    return(v);
  }

  void init();
 public:
  MacManufacturers(const char * const mac_file_home);
  ~MacManufacturers();

  const char *getManufacturer(u_int8_t mac[]);
  void getMacManufacturer(u_int8_t mac[], lua_State *vm);
};

#endif /* _MAC_MANUFACTURERS_H_ */
