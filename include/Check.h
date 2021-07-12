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

#ifndef _CHECK_H_
#define _CHECK_H_

#include "ntop_includes.h"

class Check {
 private:
  NtopngEdition check_edition;
  u_int8_t has_protocol_detected:1, has_periodic_update:1, has_flow_end:1, packet_interface_only:1, nedge_exclude:1, nedge_only:1, enabled:1/* , _unused:1 */;

  bool isCheckCompatibleWithInterface(NetworkInterface *iface);

 public:
  Check(NtopngEdition _edition);
  virtual ~Check();

  /* Compatibility */
  bool isCheckCompatibleWithEdition() const;
  inline NtopngEdition getEdition()   const { return check_edition; };

  virtual std::string getName()       const = 0;
};

#endif /* _CHECK_H_ */
