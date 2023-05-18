/*
 *
 * (C) 2013-23 - ntop.org
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

template <typename T>
class Bitmap {
 private:
  T bitmap;

 public:
  Bitmap() { reset(); }

  static inline u_int numBits() { return sizeof(bitmap) * 8; };
  inline void reset() { bitmap = 0; };
  inline void setBit(u_int8_t id) { bitmap |= ((T)1) << id; };
  inline void clearBit(u_int8_t id) { bitmap &= ~(((T)1) << id); };
  inline bool isSetBit(u_int8_t id) const {
    return (((bitmap >> id) & 1) ? true : false);
  };
  inline void bitmapOr(const Bitmap b) { bitmap |= b.bitmap; };
  inline void set(const Bitmap *b) { bitmap = b->bitmap; };
  inline bool equal(const Bitmap *b) const { return bitmap == b->bitmap; };

  void lua(lua_State *vm, const char *label) const {
    lua_newtable(vm);

    for (u_int i = 0; i < numBits(); i++) {
      if (isSetBit(i)) {
        lua_pushboolean(vm, true); /* The boolean indicating this risk is set */
        lua_pushinteger(
            vm, i); /* The integer risk id, used as key of this lua table */
        lua_insert(vm, -2);
        lua_settable(vm, -3);
      }
    }

    lua_pushstring(vm, label);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  };
};

#endif /* _BITMAP_H_ */
