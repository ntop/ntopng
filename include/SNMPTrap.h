/*
 *
 * (C) 2013-24 - ntop.org
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

#ifndef _SNMP_TRAP_H_
#define _SNMP_TRAP_H_

#include "ntop_includes.h"

#ifdef HAVE_LIBSNMP

/* ******************************* */

class SNMPTrap {
 private:
  netsnmp_transport *trap_transport;
  SNMPSession *trap_session; 
  netsnmp_session *trap_session_internal;
  pthread_t trap_loop;
  bool trap_collection_running;

 public:
  SNMPTrap();
  ~SNMPTrap();
  
  // Call to commence trap collection
  void startTrapCollection();

  // Call to cease trap collection
  void stopTrapCollection();

  // Call to check if trap collection is active
  bool isTrapCollectionRunning();

  // Trap collection loop
  void trapCollection();

  // Handle traps
  void handleTrap(struct snmp_pdu *pdu);

  // Release trap session data structures
  void releaseTrapSession();
};

#endif

#endif /* _SNMP_TRAP_H_ */
