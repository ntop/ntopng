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

#ifndef _FR_TLS_UNSAFE_CHIPERS_ALERT_H_
#define _FR_TLS_UNSAFE_CHIPERS_ALERT_H_

#include "ntop_includes.h"

class FlowRiskTLSUnsafeCiphersAlert : public FlowRiskTLSAlert {
 public:
  static FlowAlertType getClassType() { return { alert_tls_unsafe_ciphers, alert_category_security }; }

 FlowRiskTLSUnsafeCiphersAlert(FlowCallback *c, Flow *f, AlertLevel s) : FlowRiskTLSAlert(c, f, s) { };
  ~FlowRiskTLSUnsafeCiphersAlert() { };

  FlowAlertType getAlertType() const { return getClassType(); }
  std::string getName() const { return std::string("alert_tls_unsafe_ciphers"); }
};

#endif /* _FR_TLS_UNSAFE_CHIPERS_ALERT_H_ */
