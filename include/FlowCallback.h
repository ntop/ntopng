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

#ifndef _FLOW_CALLBACK_H_
#define _FLOW_CALLBACK_H_

#include "ntop_includes.h"

class FlowCallback {
 private:
  NtopngEdition callback_edition;
  u_int8_t has_protocol_detected:1, has_periodic_update:1, has_flow_end:1, packet_interface_only:1, nedge_exclude:1, nedge_only:1, enabled:1/* , _unused:1 */;

  bool isCallbackCompatibleWithInterface(NetworkInterface *iface);

 protected:
  AlertLevel severity_id;

 public:
  FlowCallback(NtopngEdition _edition, bool _packet_interface_only, bool _nedge_exclude, bool _nedge_only,
	       bool _has_protocok_detected, bool _has_periodic_update, bool _has_flow_end);
  virtual ~FlowCallback();

  /* Compatibility */
  bool isCallbackCompatibleWithEdition() const;

  /* Enable/Disable hooks */
  virtual void scriptEnable()            {};
  virtual void scriptDisable()           {};
  
  /* Callback hooks */
  virtual void protocolDetected(Flow *f) {};
  virtual void periodicUpdate(Flow *f)   {};
  virtual void flowEnd(Flow *f)          {};

  /* Used to build an alert when triggerAlertAsync is used */
  virtual FlowAlert *buildAlert(Flow *f) { return NULL; };

  inline void enable()    { enabled = 1; }
  inline bool isEnabled() { return(enabled ? true : false); }
  virtual AlertLevel getSeverity() { return severity_id; }

  void addCallback(std::list<FlowCallback*> *l, NetworkInterface *iface, FlowCallbacks callback);
  virtual bool loadConfiguration(json_object *config);
  
  virtual std::string getName()        const = 0;
};

#endif /* _FLOW_CALLBACK_H_ */
