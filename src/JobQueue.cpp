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

#include "ntop_includes.h"

#ifdef WIN32
#define popen(a, b) _popen(a, b)
#define pclose(a)   _pclose(a)
#endif

/* ******************************* */

JobQueue::JobQueue() {
  max_num_jobs = MAX_NUM_CONCURRENT_JOBS;
  job_id = 0;
}

/* ******************************* */

JobQueue::~JobQueue() {
  for(std::map<u_int32_t /* id */, std::pair<FILE*, std::string> >::iterator it = running_jobs.begin(); it != running_jobs.end(); ++it) {
    if(it != running_jobs.end())
      fclose(it->second.first);
  }
}

/* ******************************* */

bool JobQueue::queueJob(char *job, u_int32_t *id) {
  if(ntop->getGlobals()->isShutdown()
     || (job_queue.size() > MAX_NUM_QUEUED_JOBS /* Avoid growing too much */))
    return(false);
  
  lock.wrlock(__FILE__, __LINE__);
  *id = job_id;
  
  /* Queue job */
  job_queue.push(std::make_pair(job_id, std::string(job)));

  job_id++;
  lock.unlock(__FILE__, __LINE__);

  return(true);
}

/* ******************************* */

/* Periodic taask called by the Ntop class */
void JobQueue::idleTask() {
  bool do_trace = false, job_completed = false;

  if(ntop->getGlobals()->isShutdown())
    return;
  
  if(do_trace) ntop->getTrace()->traceEvent(TRACE_WARNING, "JobQueue::idleTask()");
  
  lock.wrlock(__FILE__, __LINE__);
  
  /* Schedule a job if possible */
  if(running_jobs.size() < MAX_NUM_CONCURRENT_JOBS) {
    while(!job_queue.empty()) {
      std::pair<u_int32_t /* id */, std::string /* job */> item = job_queue.front();
      FILE *fd = popen(item.second.c_str(), "r");

      if(do_trace) ntop->getTrace()->traceEvent(TRACE_WARNING, "Started %s", item.second.c_str());
      
      job_queue.pop();
      
      if(fd == NULL) {
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to run job [%s]",
				     item.second.c_str());
	completed_jobs[item.first] = std::make_pair(time(NULL), std::string(""));
      } else
	running_jobs[item.first] = std::make_pair(fd, std::string(""));
    }
  }

  /* Manage running jobs */
  for(std::map<u_int32_t /* id */, std::pair<FILE*, std::string> >::iterator it = running_jobs.begin(); it != running_jobs.end(); ) {
    fd_set rset;
    int ret, fd = fileno(it->second.first);
    struct timeval ts;
    u_int32_t id = it->first;
    bool deleted_item = false;
    
    while(true) {
      ts.tv_sec = 0, ts.tv_usec = 0;

      FD_ZERO(&rset);
      FD_SET(fd, &rset);    
      ret = select(fd + 1, &rset, NULL, NULL, &ts);

      if(ret < 0) {
	/* Something went wrong */
      job_completed:
	if(do_trace) ntop->getTrace()->traceEvent(TRACE_WARNING, "[Job %d] Completed", id);
	
	pclose(it->second.first);
	completed_jobs[id] = std::make_pair(time(NULL), it->second.second);
	running_jobs.erase(it++);
	deleted_item = true;
	break;
      } else if(ret > 0) {
	char line[256], *l;
      
	l = fgets(line, sizeof(line), it->second.first);

	if(l != NULL) {
	  if(do_trace) ntop->getTrace()->traceEvent(TRACE_WARNING, "[Job %d] %s", id, l);
	  
	  it->second.second.append(l);
	} else {
	  /* Job completed */
	  goto job_completed;
	}
      } else /* ret == 0 */
	break;
    } /* while */

    if(!deleted_item)
      ++it;
  }

  if(job_completed)
    purgeOldResults();
  
  lock.unlock(__FILE__, __LINE__);
}

/* ******************************* */

bool JobQueue::getJobResult(u_int32_t job_id, std::string *out) {
  if(ntop->getGlobals()->isShutdown()) {
    (*out) = "";
    return(true);
  } else {
    std::map<u_int32_t /* id */, std::pair<time_t, std::string> >::iterator it;
    bool ret;
    
    idleTask(); /* Refresh results first */
    
    lock.wrlock(__FILE__, __LINE__);
    it = completed_jobs.find(job_id);
    
    if(it == completed_jobs.end()) {
      /* Nothing found */
      ret = false;
    } else {
      (*out) = it->second.second;
      completed_jobs.erase(it++);
      ret = true;
    }
    
    lock.unlock(__FILE__, __LINE__);
    return(ret);
  }
}

/* ******************************* */

void JobQueue::purgeOldResults() {
  if(!ntop->getGlobals()->isShutdown()) {
    /* Delete results queued for 5 or more minutes [no need to lock] */
    u_int time_threshold = time(NULL) - 300 /* 5 min */;
    
    for(std::map<u_int32_t /* id */, std::pair<time_t, std::string> >::iterator it = completed_jobs.begin(); it != completed_jobs.end(); ) {
      if(it->second.first < time_threshold)
	completed_jobs.erase(it++);
      else
	++it;
    }
  }
}
