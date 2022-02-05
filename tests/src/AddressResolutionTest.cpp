/*
 *
 * (C) 2013-22 - ntop.org
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
#include "../include/AddressResolutionTest.h"
namespace ntoptesting {
TEST_F(AddressResolutionTest, ShouldNotCrashWhenNull) {
    resolver_.resolveHostName(NULL,0, true);
}
TEST_F(AddressResolutionTest, ShouldNotCrashWhenNullDestination) {
    resolver_.resolveHost(address_, NULL, 0, true);
}
TEST_F(AddressResolutionTest, ShouldResolveCorrectly) {
    // A: arrange
    char maxIpSize[1024];
    // A: act
    resolver_.resolveHost(address_, maxIpSize, sizeof(maxIpSize), true);
    // A: assert
    EXPECT_EQ("74.6.231.20", maxIpSize);
}
}


