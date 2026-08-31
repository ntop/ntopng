/*
 *
 * (C) 2013-26 - ntop.org
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

/**
 * @brief Generic bitmap class template building a bitmap as multiple 64-bit
 * bitmaps
 * @tparam N Number of u_int64_t elements in the bitmap array
 */
template <size_t N>
class Bitmap {
 private:
  u_int64_t bitmap[N];

 public:
  Bitmap() { reset(); }
  Bitmap(char* list) {
    reset();
    setBits(list);
  };

  static inline u_int numBits() { return N * 64; };

  void reset() { memset(bitmap, 0, sizeof(bitmap)); }

  void setBit(u_int16_t id) {
    size_t idx = id >> 6;
    u_int8_t offset = id & 0x3F;
    if (idx < N) bitmap[idx] |= ((u_int64_t)1) << offset;
  }

  void setBits(char* list) {
    char *item, *tmp = NULL;

    item = strtok_r(list, ",", &tmp);

    while (item) {
      int id = atoi(item);
      setBit(id);
      item = strtok_r(NULL, ",", &tmp);
    }
  }

  void clearBit(u_int16_t id) {
    size_t idx = id >> 6;        /* id / 64 */
    u_int8_t offset = id & 0x3F; /* id % 64 */
    if (idx < N) bitmap[idx] &= ~(((u_int64_t)1) << offset);
  }

  bool isSetBit(u_int16_t id) const {
    size_t idx = id >> 6;
    u_int8_t offset = id & 0x3F;
    if (idx < N) return (((bitmap[idx] >> offset) & 1) ? true : false);
    return false;
  }

  /* Return the first bit set, starting from start */
  int getNext(u_int16_t start) {
    size_t start_idx = start >> 6;
    u_int8_t start_offset = start & 0x3F;

    for (size_t i = start_idx; i < N; i++) {
      int bit =
          Utils::bitmapGetNext(bitmap[i], (i == start_idx) ? start_offset : 0);
      if (bit >= 0) {
        return (i << 6) + bit;
      }
    }

    return -1;
  }

  void bitmapOr(const Bitmap<N> b) {
    for (size_t i = 0; i < N; i++) {
      bitmap[i] |= b.bitmap[i];
    }
  }

  void set(const Bitmap<N>* b) { memcpy(bitmap, b->bitmap, sizeof(bitmap)); }

  bool equal(const Bitmap<N>* b) const {
    return (memcmp(bitmap, b->bitmap, sizeof(bitmap)) == 0);
  }

  /* Returns the 64-bit value at position idx */
  u_int64_t getBits64(size_t idx = 0) const {
    return (idx < N) ? bitmap[idx] : 0;
  }

  /* Sets the 64-bit value at position idx */
  void setBits64(u_int64_t val, size_t idx = 0) {
    if (idx < N) bitmap[idx] = val;
  }

  void lua(lua_State* vm, const char* label) const;

  const char* toHexString(char* buf, ssize_t buf_len) const {
    char* ptr = buf;
    ssize_t remaining = buf_len;

    if (buf_len > 0) buf[0] = '\0';

    /* Write hex values in reverse order (most significant first) */
    for (int i = N - 1; i >= 0; i--) {
      int written =
          snprintf(ptr, remaining, "%016lX", (unsigned long)bitmap[i]);
      if (written >= remaining) break;
      ptr += written;
      remaining -= written;
    }

    /* Remove heading zeroes but keep HEX byte-aligned (SQLite doesn't like
     * heading zeroes when inserting blob literals) */
    u_int shifts = 0;
    size_t buf_slen = strlen(buf);
    for (u_int pos = 0; pos + 2 < buf_slen; pos += 2) {
      u_int8_t cur_byte = 0;

      sscanf(&buf[pos], "%02hhX", &cur_byte);
      if (cur_byte > 0) break;
      shifts += 2;
    }

    if (shifts > 0) memmove(buf, &buf[shifts], buf_len - shifts);

    return buf;
  }
};

#endif /* _BITMAP_H_ */
