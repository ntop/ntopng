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

#ifndef _DUMMY_INTERFACE_H_
#define _DUMMY_INTERFACE_H_

#include "ntop_includes.h"

#ifndef HAVE_NEDGE

class DummyInterface : public ZMQParserInterface {
 private:
  inline u_int32_t getNumDroppedPackets()   { return(0); };

 public:
  DummyInterface();

  virtual const char* get_type()    const { return(CONST_INTERFACE_TYPE_DUMMY);      };
  virtual InterfaceType getIfType() const { return(interface_type_DUMMY);            };
  virtual bool is_ndpi_enabled() const    { return(false);  };
  virtual bool isPacketInterface() const  { return(false);  };

  void forgeFlow(u_int iteration);
  void startPacketPolling();
  void shutdown();
};

#endif

#endif /* _DUMMY_INTERFACE_H_ */

