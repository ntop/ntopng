/*
 *
 * (C) 2013-20 - ntop.org
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

#ifndef _SYSLOG_H_
#define _SYSLOG_H_

#include "ntop_includes.h"

class SyslogDump : public DB {
 public:
  SyslogDump(NetworkInterface *_iface);
  virtual ~SyslogDump();

  virtual bool dumpFlow(time_t when, Flow *f, char *json);
  virtual void startLoop() { ; }
};


#endif /* _LOGSTASH_H_ */
