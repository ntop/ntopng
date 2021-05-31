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

void Bitmap128::reset() {
  memset(bitmap, 0, sizeof(bitmap));
}

/* ****************************************** */

void Bitmap128::setBit(u_int8_t id) {
  if(id < 64)
    bitmap[0] = Utils::bitmapSet(bitmap[0], id);
  else if(id < numBits())
    bitmap[1] = Utils::bitmapSet(bitmap[1], id-64);
}

/* ****************************************** */

void Bitmap128::clearBit(u_int8_t id) {
  if(id < 64)
    bitmap[0] = Utils::bitmapClear(bitmap[0], id);
  else if(id < numBits())
    bitmap[1] = Utils::bitmapClear(bitmap[1], id-64);
}

/* ****************************************** */

bool Bitmap128::isSetBit(u_int8_t id) const {
  if(id < 64)
    return(Utils::bitmapIsSet(bitmap[0], id));
  else if(id < numBits())
    return(Utils::bitmapIsSet(bitmap[1], id-64));
  else
    return(0);
}

/* ****************************************** */

void Bitmap128::bitmapOr(const Bitmap128 b) {
  bitmap[0] |= b.bitmap[0], bitmap[1] |= b.bitmap[1];
}

/* ****************************************** */

void Bitmap128::set(const Bitmap128 *b) {
  memcpy(bitmap, b->bitmap, sizeof(bitmap));
}

/* ****************************************** */

bool Bitmap128::equal(const Bitmap128 *b) const {
  return((memcmp(bitmap, b->bitmap, sizeof(bitmap)) == 0) ? true : false);
}

/* ****************************************** */

void Bitmap128::lua(lua_State* vm, const char *label) const {
  lua_newtable(vm);

  for(u_int i=0; i<numBits(); i++) {
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

/* ****************************************** */

const char * const Bitmap128::toHexString(char *buf, ssize_t buf_len) const {
  u_int shifts = 0;

  snprintf(buf, buf_len, "%016lX%016lX",
	   (unsigned long)bitmap[1], (unsigned long)bitmap[0]);

  /* Remove heading zeroes but keep HEX byte-aligned (SQLite doesn't like heading zeroes when inserting blob literals) */
  for(u_int pos = 0; pos < strlen(buf) - 2; pos += 2) {
    uint8_t cur_byte = 0;
    
    sscanf(&buf[pos], "%02hhX", &cur_byte);
    if(cur_byte > 0) break;
    shifts += 2;
  }

  if(shifts > 0)
    memmove(buf, &buf[shifts], buf_len - shifts);

  return buf;
}
