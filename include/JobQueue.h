/*
 *
 * (C) 2013-24 - ntop.org
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

#ifndef _JOB_QUEUE_H_
#define _JOB_QUEUE_H_

#include "ntop_includes.h"

/* ******************************* */

class JobQueue {
  private:
  RwLock lock;
  u_int max_num_jobs, job_id;
  std::queue<std::pair<u_int32_t /* id */, std::string /* job */> > job_queue;
  std::map<u_int32_t /* id */, std::pair<FILE*, std::string> > running_jobs;
  std::map<u_int32_t /* id */, std::pair<time_t, std::string> > completed_jobs;

  void purgeOldResults();
  
  public:
  JobQueue();
  ~JobQueue();
  
  bool queueJob(char *job, u_int32_t *id);
  bool getJobResult(u_int32_t job_id, std::string *out);
  void idleTask();
};

#endif /* _JOB_QUEUE_H_ */
