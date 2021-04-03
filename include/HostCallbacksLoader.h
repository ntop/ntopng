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

#ifndef _HOST_CALLBACKS_LOADER_H_
#define _HOST_CALLBACKS_LOADER_H_

#include "ntop_includes.h"

class HostCallbacksLoader : public CallbacksLoader {
 private:
  /* These are callback instances, that is classes instantiated at runtime each one with a given configuration */
  std::map<std::string, HostCallback*> cb_all; /* All the callbacks instantiated */

  void registerCallbacks();
  void loadConfiguration();

 public:
  HostCallbacksLoader();
  virtual ~HostCallbacksLoader();

  void printCallbacks();

  std::list<HostCallback*>* getCallbacks(NetworkInterface *iface);
};

#endif /* _HOST_CALLBACKS_LOADER_H_ */
