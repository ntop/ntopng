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
  u_int64_t bitmap; /* Sync with BITMAP_NUM_BITS */

public:
  Bitmap() { reset(); }

  inline void reset()                       { bitmap = 0; }
  inline void setBit(u_int8_t id)           { bitmap = Utils::bitmapSet(bitmap, id);  }
  inline void clearBit(u_int8_t id)         { bitmap = Utils::bitmapClear(bitmap, id);}
  inline bool issetBit(u_int8_t id) const   { return(Utils::bitmapIsSet(bitmap, id)); }
  inline void bitmapOr(Bitmap b)            { bitmap |= b.bitmap;                     }
  inline u_int64_t get() const              { return(bitmap);                         }
  inline void set(Bitmap *b)                { bitmap = b->bitmap;                     }
  inline bool equal(Bitmap *b) const        { return((bitmap == b->bitmap) ? true : false); }
};

#endif /* _BITMAP_H_ */
