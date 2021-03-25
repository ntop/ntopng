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

#ifndef _HOST_CALLBACK_H_
#define _HOST_CALLBACK_H_

#include "ntop_includes.h"

class HostCallback {
 private:
  NtopngEdition callback_edition;
  u_int8_t enabled:1 /*,  _unused:7 */;
  u_int32_t periodicity_secs;

 protected:
  AlertLevel severity_id;

 public:
  HostCallback(NtopngEdition _edition);
  virtual ~HostCallback();

  /* Enable/Disable hooks */
  virtual void scriptEnable()            {};
  virtual void scriptDisable()           {};
  
  /* Callback hook (periodic)
   * engaged_alert is the alert already engaged by the callback
   * in a previous iteration, if any. */
  virtual void periodicUpdate(Host *h, HostAlert *engaged_alert) {};

  virtual u_int32_t getPeriod() { return periodicity_secs; }
  inline bool isMinCallback()  const { return periodicity_secs == 60;  };
  inline bool is5MinCallback() const { return periodicity_secs == 300; };

  inline void enable(u_int32_t _periodicity_secs) { enabled = 1; periodicity_secs = _periodicity_secs; }
  inline bool isEnabled() { return(enabled ? true : false); }
  virtual AlertLevel getSeverity() { return severity_id; }

  inline void addCallback(std::list<HostCallback*> *l, NetworkInterface *iface) { l->push_back(this); }
  virtual bool loadConfiguration(json_object *config);

  virtual HostCallbackID getID() const = 0;  
  virtual std::string getName() const = 0;
};

#endif /* _HOST_CALLBACK_H_ */
