/*
 *
 * (C) 2019 - ntop.org
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

#ifndef _SYSLOG_LUA_ENGINE_H_
#define _SYSLOG_LUA_ENGINE_H_

class SyslogLuaEngine : public LuaEngine {
 private:
  char script_path[MAX_PATH];
  bool initialized;

  bool pcall(int num_args, int num_results);

 public:
  SyslogLuaEngine(NetworkInterface *iface);
  virtual ~SyslogLuaEngine();

  void handleEvent(const char *producer, const char *message,
    const char *host, int priority);
};

#endif
