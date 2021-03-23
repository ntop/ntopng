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
#include "flow_callbacks_includes.h"

void TCPZeroWindow::checkTCPWindow(Flow *f) {
  if(f->isTCPZeroWindow()) {
    u_int16_t c_score = 30, s_score = 30;

    f->triggerAlertAsync(TCPZeroWindowAlert::getClassType(), getSeverity(), c_score, s_score);
  }
}

/* ***************************************************** */

void TCPZeroWindow::periodicUpdate(Flow *f) {
  checkTCPWindow(f);
}

/* ***************************************************** */

void TCPZeroWindow::flowEnd(Flow *f) {
  checkTCPWindow(f);
}

/* ***************************************************** */

FlowAlert *TCPZeroWindow::buildAlert(Flow *f) {
  return new TCPZeroWindowAlert(this, f);
}

/* ***************************************************** */
