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

#ifndef _CHECKS_LOADER_H_
#define _CHECKS_LOADER_H_

#include "ntop_includes.h"

class ChecksLoader {
 private:
  NtopngEdition checks_edition;

  virtual void registerChecks() = 0; /* Method called at runtime to register checks */
  virtual void loadConfiguration() = 0;

 public:
  ChecksLoader();
  virtual ~ChecksLoader();

  virtual bool luaCheckInfo(lua_State* vm, std::string check_name) const = 0;
  inline void initialize() { registerChecks(); loadConfiguration();   };
  inline NtopngEdition getChecksEdition() { return checks_edition; };
};

#endif /* _CHECKS_LOADER_H_ */
