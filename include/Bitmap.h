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

class Bitmap {
private:
  u_int64_t bitmap[BITMAP_NUM_BITS/64];

public:
  Bitmap() { reset(); }

  inline u_int32_t size() { return sizeof(bitmap)*64; }

  void reset();
  void setBit(u_int8_t id);
  void clearBit(u_int8_t id);
  bool isSetBit(u_int8_t id) const;
  void bitmapOr(const Bitmap b);
  void set(const Bitmap *b);
  bool equal(const Bitmap *b) const;
  
  void lua(lua_State* vm, const char *label) const;
};

#endif /* _BITMAP_H_ */
