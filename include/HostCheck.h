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

#ifndef _HOST_CHECK_H_
#define _HOST_CHECK_H_

#include "ntop_includes.h"

class HostCheck : public Check {
 private:
  u_int8_t enabled:1 /*,  _unused:7 */;
  u_int32_t periodicity_secs;

 public:
  HostCheck(NtopngEdition _edition);
  virtual ~HostCheck();

  /* Enable/Disable hooks */
  virtual void scriptEnable()            {};
  virtual void scriptDisable()           {};
  
  /* Check hook (periodic)
   * engaged_alert is the alert already engaged by the check
   * in a previous iteration, if any. */
  virtual void periodicUpdate(Host *h, HostAlert *engaged_alert) {};

  virtual u_int32_t getPeriod() { return periodicity_secs; }
  inline bool isMinCheck()  const { return periodicity_secs == 60;  };
  inline bool is5MinCheck() const { return periodicity_secs == 300; };

  inline void enable(u_int32_t _periodicity_secs) { enabled = 1; periodicity_secs = _periodicity_secs; }
  inline bool isEnabled() { return(enabled ? true : false); }

  inline void addCheck(std::list<HostCheck*> *l, NetworkInterface *iface) { l->push_back(this); }
  virtual bool loadConfiguration(json_object *config);

  virtual HostCheckID getID() const = 0;  
  virtual std::string getName() const = 0;
};

#endif /* _HOST_CHECK_H_ */
