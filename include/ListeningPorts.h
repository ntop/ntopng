/*
 *
 * (C) 2020 - ntop.org
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

#ifndef _NTOP_LISTENING_PORTS_H_
#define _NTOP_LISTENING_PORTS_H_

class ListeningPortInfo {
 private:
  std::string process, package;
 public:
  ListeningPortInfo() {}
  ListeningPortInfo(const ListeningPortInfo &lpi) {
    this->process = lpi.process;
    this->package = lpi.package;
  }
  inline void setProcess(const char *p) { this->process = p; }
  inline void setPackage(const char *p) { this->package = p; }
  inline const char *getProcess() const { return process.c_str(); }
  inline const char *getPackage() const { return package.c_str(); }
};

class ListeningPorts {
 private:
  std::map <u_int16_t /* port */, ListeningPortInfo /* info */> tcp4, tcp6, udp4, udp6;

  void parsePortInfo(json_object *z, std::map <u_int16_t, ListeningPortInfo> *info);
  
 public:
  ListeningPorts() {}

  /* Copy constructor */
  ListeningPorts(const ListeningPorts &lp) {
    this->tcp4 = lp.tcp4;
    this->tcp6 = lp.tcp6;
    this->udp4 = lp.udp4;
    this->udp6 = lp.udp6;
  }

  void parsePorts(json_object *z);

  void luaProtocolInfo(lua_State *vm, std::map <u_int16_t, ListeningPortInfo> &info, const char *label);
  void lua(lua_State *vm);
};

#endif /* _NTOP_LISTENING_PORTS_H_ */
