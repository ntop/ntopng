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
  bool packet_interface_only, nedge_exclude, nedge_only;
  bool enabled;

 public:
  Check(NtopngEdition _edition, bool _packet_interface_only, bool _nedge_exclude, bool _nedge_only);
  virtual ~Check();

  /* Compatibility */
  bool isCheckCompatibleWithInterface(NetworkInterface *iface);
  bool isCheckCompatibleWithEdition() const;
  inline NtopngEdition getEdition()   const { return check_edition; };
 
  /* Enable/Disable hooks */
  virtual void scriptEnable()            {};
  virtual void scriptDisable()           {};

  inline void enable()          { enabled = true; }
  inline bool isEnabled() const { return(enabled ? true : false); }

  virtual std::string getName()       const = 0;
};

#endif /* _CHECK_H_ */
