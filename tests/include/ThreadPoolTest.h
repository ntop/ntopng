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

#ifndef _TEST_THREAD_POOL_H_
#define _TEST_THREAD_POOL_H_
#include "NtopTestingBase.h"
#include "ScopedThreadPool.h"
#include "gtest/gtest.h"

namespace ntoptesting {

class ThreadPoolTest : public ::testing::Test {
  public:
  static constexpr int MaxScripts = 30;
  void PopulateScripts(std::vector<std::string> &scripts, int max) const;

protected:
  NtopTestingBase ntop_;
  ScopedThreadPool scoped_pool_;

private:
  void CreateScript(const std::string &path, const std::string &base, int i) const;
  
};
} // namespace ntoptesting

#endif