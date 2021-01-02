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

#ifndef _FINGERPRINT_H_
#define _FINGERPRINT_H_

#include "ntop_includes.h"

typedef struct {
  std::string app_name; /* NetLink/eBPF-like only */
  u_int32_t num_uses;
} FingerprintStats;

class Fingerprint {
 private:
  Mutex m;
  std::map<std::string /* fingerprint */, FingerprintStats> fp;

  void prune();
  
 public:
  Fingerprint() { ; }

  void update(const char *fp, const char *app_name);
  void lua(const char *key, lua_State* vm);
};

#endif /* _FINGERPRINT_H_ */
