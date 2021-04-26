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

#ifndef _ALERT_STORE_H_
#define _ALERT_STORE_H_

#include "ntop_includes.h"

class Flow;

class AlertStore : public StoreManager {
 private:
  bool store_opened, store_initialized;
  int openStore();

 public:
  AlertStore(int interface_id, const char *db_filename);
  ~AlertStore();

  bool alert_store_query(lua_State *vm, const char * const query);

};

#endif /* _ALERT_STORE_H_ */
