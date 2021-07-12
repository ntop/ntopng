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

/* **************************************************** */

Check::Check(NtopngEdition _edition) {
  check_edition = _edition;
};

/* **************************************************** */

Check::~Check() {
};

/* **************************************************** */

bool Check::isCheckCompatibleWithEdition() const {
  /* Check first if the license allows plugin to be enabled */
  switch(check_edition) {
  case ntopng_edition_community:
    /* Ok */
    break;
     
  case ntopng_edition_pro:
    if(!ntop->getPrefs()->is_pro_edition() /* includes Pro, Enterprise M/L */)
      return(false);
    break;
     
  case ntopng_edition_enterprise_m:
    if(!ntop->getPrefs()->is_enterprise_m_edition() /* includes Enterprise M/L */)
      return(false);
    break;
     
  case ntopng_edition_enterprise_l:
    if(!ntop->getPrefs()->is_enterprise_l_edition() /* includes L */)
      return(false);
    break;     
  }

  return(true);
}
