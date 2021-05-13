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

#ifndef _BITMAP_H_
#define _BITMAP_H_

#include "ntop_includes.h"

class Bitmap128 {
private:
  u_int64_t bitmap[2];

public:
  Bitmap128() { reset(); }

  static inline u_int numBits() { return sizeof(bitmap) * 8; };
  void reset();
  void setBit(u_int8_t id);
  void clearBit(u_int8_t id);
  bool isSetBit(u_int8_t id) const;
  void bitmapOr(const Bitmap128 b);
  void set(const Bitmap128 *b);
  bool equal(const Bitmap128 *b) const;
  
  void lua(lua_State* vm, const char *label) const;
  const char * const toHexString(char *buf, ssize_t buf_len) const;
};

#endif /* _BITMAP_H_ */
