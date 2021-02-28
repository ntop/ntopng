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

void Bitmap::reset() {
  memset(bitmap, 0, sizeof(bitmap));
}

/* ****************************************** */

void Bitmap::setBit(u_int8_t id) {
  if(id < 64)
    bitmap[0] = Utils::bitmapSet(bitmap[0], id);
  else if(id < BITMAP_NUM_BITS)
    bitmap[1] = Utils::bitmapSet(bitmap[1], id-64);
}

/* ****************************************** */

void Bitmap::clearBit(u_int8_t id) {
  if(id < 64)
    bitmap[0] = Utils::bitmapClear(bitmap[0], id);
  else if(id < BITMAP_NUM_BITS)
    bitmap[1] = Utils::bitmapClear(bitmap[1], id-64);
}

/* ****************************************** */

bool Bitmap::issetBit(u_int8_t id) const {
  if(id < 64)
    return(Utils::bitmapIsSet(bitmap[0], id));
  else if(id < BITMAP_NUM_BITS)
    return(Utils::bitmapIsSet(bitmap[1], id-64));
  else
    return(0);
}

/* ****************************************** */

void Bitmap::bitmapOr(Bitmap b) {
  bitmap[0] |= b.bitmap[0], bitmap[1] |= b.bitmap[1];
}

/* ****************************************** */

void Bitmap::set(Bitmap *b) {
  memcpy(bitmap, b->bitmap, sizeof(bitmap));
}

/* ****************************************** */

bool Bitmap::equal(Bitmap *b) const {
  return((memcmp(bitmap, b->bitmap, sizeof(bitmap)) == 0) ? true : false);
}

/* ****************************************** */

void Bitmap::lua(lua_State* vm, const char *label) const {
  lua_newtable(vm);

  for(u_int i=0; i<BITMAP_NUM_BITS; i++) {
    if(issetBit(i)) {
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

