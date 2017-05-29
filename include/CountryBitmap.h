/*
 *
 * (C) 2013-17 - ntop.org
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

#ifndef _COUNTRYBITMAP_H_
#define _COUNTRYBITMAP_H_

#include "ntop_includes.h"

class CountryBitmap {
	private :
		uint64_t * bitmap;
		uint8_t activeCountry;

	public :		
		CountryBitmap();
		~CountryBitmap();
		const char ** getActiveCountry();
		uint8_t numActiveCountry();
		void setActiveCountry(uint8_t countryID);
		bool isActiveCountry(uint8_t countryID);
		const char * getCountry(uint8_t countryID);
};

#endif