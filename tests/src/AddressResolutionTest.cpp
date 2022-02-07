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
#include <iostream>

namespace ntoptesting {
void AddressResolutionTest::SetUp() {
        const char* appName = "ntopng";
        ntop_ = std::make_unique<Ntop>(appName);
        pref_ = std::make_unique<Prefs>(ntop_.get()); 
        ntop_->registerPrefs(pref_.get(), false);
    }
TEST_F(AddressResolutionTest, ShouldDNSResolutionEnabled) {
    EXPECT_TRUE(pref_->is_dns_resolution_enabled());
}    
TEST_F(AddressResolutionTest, ShouldNotCrashWhenResolvingNullHostName) {
    EXPECT_THROW(resolver_.resolveHostName(NULL, NULL, true), std::invalid_argument);
}
TEST_F(AddressResolutionTest, ShouldNotCrashWhenResolvingNullHost) {
    EXPECT_THROW(resolver_.resolveHost(NULL, NULL,0 , true), std::invalid_argument);
}
TEST_F(AddressResolutionTest, ShouldNotCrashWhenNullDestination) {
    resolver_.resolveHost(address_, NULL, 0, true);
}
TEST_F(AddressResolutionTest, ShouldResolveHostNameCorrectly) {
    // A: arrange
    char maxIpSize[64];
    // A: act
    resolver_.resolveHostName("74.6.231.20", maxIpSize, sizeof(maxIpSize));
    // A: assert
    printf("%s", maxIpSize);
} 
TEST_F(AddressResolutionTest, ShouldResolveHostCorrectly) {
    // A: arrange
    char resolvedAddress[32];
    // A: act
    resolver_.resolveHost(address_, resolvedAddress, sizeof(resolvedAddress), true);
    // A: assert
    EXPECT_EQ(std::string("74.6.231.20"), std::string(resolvedAddress));
}
}


