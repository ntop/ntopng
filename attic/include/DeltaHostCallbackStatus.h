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

#ifndef _DELTA_HOST_CALLBACK_STATUS_H_
#define _DELTA_HOST_CALLBACK_STATUS_H_

#include "ntop_includes.h"

class DeltaHostCallbackStatus : public HostCallbackStatus {
 private:
  u_int64_t cur_value; /* Keeps the current value that is periodically snapshotted */

 public:
 DeltaHostCallbackStatus(HostCallback *cb) : HostCallbackStatus(cb) { cur_value = (u_int64_t)-1; };
  inline u_int64_t delta(u_int64_t new_value) {
    u_int64_t res = new_value > cur_value ? new_value - cur_value : 0; cur_value = new_value; return res;
  };
};

#endif /* _DELTA_HOST_CALLBACK_STATUS_H_ */
