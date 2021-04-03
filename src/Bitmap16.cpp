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

#include "ntop_includes.h"


/* ****************************************** */

void Bitmap16::reset() {
  bitmap = 0;
}

/* ****************************************** */

void Bitmap16::setBit(u_int8_t id) {
  bitmap = Utils::bitmapSet(bitmap, id);
}

/* ****************************************** */

void Bitmap16::clearBit(u_int8_t id) {
  Utils::bitmapClear(bitmap, id);
}

/* ****************************************** */

bool Bitmap16::isSetBit(u_int8_t id) const {
  return Utils::bitmapIsSet(bitmap, id);
}

/* ****************************************** */

void Bitmap16::bitmapOr(const Bitmap16 b) {
  bitmap |= b.bitmap;
}

/* ****************************************** */

void Bitmap16::set(const Bitmap16 *b) {
  bitmap = b->bitmap;
}

/* ****************************************** */

bool Bitmap16::equal(const Bitmap16 *b) const {
  return bitmap == b->bitmap;
}

/* ****************************************** */

void Bitmap16::lua(lua_State* vm, const char *label) const {
  lua_newtable(vm);

  for(u_int i=0; i < numBits(); i++) {
    if(isSetBit(i)) {
      lua_pushboolean(vm, true); /* The boolean indicating this risk is set            */
      lua_pushinteger(vm, i);    /* The integer risk id, used as key of this lua table */
      lua_insert(vm, -2);
      lua_settable(vm, -3);
    }
  }

  lua_pushstring(vm, label);
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

