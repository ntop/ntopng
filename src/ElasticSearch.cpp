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

#include "ntop_includes.h"

/* **************************************************** */

static void* esLoop(void* ptr) {
    ntop->getElasticSearch()->pushEStemplate();  // sends ES ntopng template
    ntop->getElasticSearch()->indexESdata();
  return(NULL);
}

/* **************************************** */

ElasticSearch::ElasticSearch() {
  pthread_rwlock_init(&listMutex, NULL);
  num_queued_elems = 0;
  head = NULL;
  tail = NULL;
  reportDrops = false;
  elkDroppedFlowsQueueTooLong = 0;
  elkExportedFlows = 0, elkLastExportedFlows = 0;
  elkExportRate = 0;
  checkpointDroppedFlows = checkpointExportedFlows = 0;
  lastUpdateTime.tv_sec = 0, lastUpdateTime.tv_usec = 0;
}

/* **************************************** */

ElasticSearch::~ElasticSearch() {
  
}

/* ******************************************* */

void ElasticSearch::updateStats(const struct timeval *tv) {
  if(tv == NULL) return;

  if(lastUpdateTime.tv_sec > 0) {
    float tdiffMsec = ((float)(tv->tv_sec-lastUpdateTime.tv_sec)*1000)+((tv->tv_usec-lastUpdateTime.tv_usec)/(float)1000);
    if(tdiffMsec >= 1000) { /* al least one second */
      u_int64_t diffFlows = elkExportedFlows - elkLastExportedFlows;
      elkLastExportedFlows = elkExportedFlows;

      elkExportRate = ((float)(diffFlows * 1000)) / tdiffMsec;
      if (elkExportRate < 0) elkExportRate = 0;
    }
  }

  memcpy(&lastUpdateTime, tv, sizeof(struct timeval));
}

/* ******************************************* */

void ElasticSearch::lua(lua_State *vm, bool since_last_checkpoint) const {
  lua_push_int_table_entry(vm,   "flow_export_count",
			   elkExportedFlows - (since_last_checkpoint ? checkpointExportedFlows : 0));
  lua_push_int32_table_entry(vm, "flow_export_drops",
			     elkDroppedFlowsQueueTooLong - (since_last_checkpoint ? checkpointDroppedFlows : 0));
  lua_push_float_table_entry(vm, "flow_export_rate",
			     elkExportRate >= 0 ? elkExportRate : 0);
}

/* **************************************** */

int ElasticSearch::sendToES(char* msg) {
  struct string_list *e;
  int rc = 0;
  
  if(num_queued_elems >= ES_MAX_QUEUE_LEN) {
    if(!reportDrops) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "[ES] Export queue too long [%d]: expect drops",
		 num_queued_elems);
      reportDrops = true;
    }

    elkDroppedFlowsQueueTooLong++;
    ntop->getTrace()->traceEvent(TRACE_INFO, "[ES] Message dropped. Total messages dropped: %lu\n",
		 elkDroppedFlowsQueueTooLong);

    return(-1);
  }

  pthread_rwlock_wrlock(&listMutex);
  e = (struct string_list*)calloc(1, sizeof(struct string_list));
  if( e != NULL) {
    e->str = strdup(msg), e->next = head;

    if(e->str) {
      if(head) 
        head->prev = e;
      head = e;
      if(tail == NULL)
	tail = e;
      num_queued_elems++;

      rc = 0;
    } else {
      /* Out of memory */
      free(e);
      rc = -1;
    }
  }

  pthread_rwlock_unlock(&listMutex);

  return rc;
}

/* **************************************** */

void ElasticSearch::startFlowDump() {
  if(ntop->getPrefs()->do_dump_flows_on_es())
    pthread_create(&esThreadLoop, NULL, esLoop, (void*)this);
}


/* **************************************** */

void ElasticSearch::indexESdata() {
  const u_int watermark = 8, min_buf_size = 512;
  char postbuf[16384];

  while(!ntop->getGlobals()->isShutdown()) {

    if(num_queued_elems >= watermark) {
      u_int len, num_flows;
      char index_name[64], header[256];
      struct tm* tm_info;
      struct timeval tv;
      time_t t;

      gettimeofday(&tv, NULL);
      t = tv.tv_sec;
      tm_info = gmtime(&t);

      strftime(index_name, sizeof(index_name), ntop->getPrefs()->get_es_index(), tm_info);

      snprintf(header, sizeof(header),
	       "{\"index\": {\"_type\": \"%s\", \"_index\": \"%s\"}}",
	       ntop->getPrefs()->get_es_type(), index_name);
      len = 0, num_flows = 0;

      pthread_rwlock_wrlock(&listMutex);
      for(u_int i=0; (i<watermark) && ((sizeof(postbuf)-len) > min_buf_size); i++) {
        struct string_list *prev;
        prev = tail->prev;
	len += snprintf(&postbuf[len], sizeof(postbuf)-len, "%s\n%s\n", header, tail->str), num_flows++;
        free(tail->str);
        free(tail);
        tail = prev,
	num_queued_elems--;
        if(num_queued_elems == 0)
	  head = NULL;

      } /* for */

      pthread_rwlock_unlock(&listMutex);
      postbuf[len] = '\0';
     

      if(!Utils::postHTTPJsonData(ntop->getPrefs()->get_es_user(),
				  ntop->getPrefs()->get_es_pwd(),
				  ntop->getPrefs()->get_es_url(),
				  postbuf)) {
	/* Post failure */
	sleep(1);
      } else {
	ntop->getTrace()->traceEvent(TRACE_INFO, "Sent %u flow(s) to ES", num_flows);
	elkExportedFlows += num_flows;
      }
    } else
      sleep(1);
  } /* while */
}

/* **************************************** */

/* Send ntopng index template to Elastic Search */
void ElasticSearch::pushEStemplate() {
  char *postbuf = NULL, *es_host = NULL;
  char template_path[MAX_PATH], es_template_url[MAX_PATH], es_url[MAX_PATH];
  ifstream template_file;
  u_int8_t max_attempts = 3;
  u_int16_t length = 0;

  // store the original es update url
  strncpy(es_url, ntop->getPrefs()->get_es_url(), MAX_PATH);
  // prepare the template file path...
  snprintf(template_path, sizeof(template_path), "%s/misc/%s",
	   ntop->get_docs_dir(), NTOP_ES_TEMPLATE);
  ntop->fixPath(template_path);

  // and the ES url (keep only host and port by retaining only characters left of the first slash)
  if(!strncmp(es_url, "http://", 7)){  // url starts either with http or https
    Utils::tokenizer(es_url + 7, '/', &es_host);
    snprintf(es_template_url, MAX_PATH, "http://%s/_template/ntopng_template", es_host);
  } else if(!strncmp(es_url, "https://", 8)){
    Utils::tokenizer(es_url + 8, '/', &es_host);
    snprintf(es_template_url, MAX_PATH, "https://%s/_template/ntopng_template", es_host);
  } else {
    Utils::tokenizer(es_url, '/', &es_host);
    snprintf(es_template_url, MAX_PATH, "%s/_template/ntopng_template", es_host);
  }

  template_file.open(template_path);   // open input file
  template_file.seekg(0, ios::end);    // go to the end
  length = template_file.tellg();      // report location (this is the length)
  template_file.seekg(0, ios::beg);    // go back to the beginning
  postbuf = new char[length+1];        // allocate memory for a buffer of appropriate dimension
  template_file.read(postbuf, length); // read the whole file into the buffer
  postbuf[length] = '\0';
  if(template_file.is_open())
    template_file.close();           // close file handle

  while(max_attempts > 0) {
    if(!Utils::postHTTPJsonData(ntop->getPrefs()->get_es_user(),
				ntop->getPrefs()->get_es_pwd(),
				es_template_url,
				postbuf)) {
      /* Post failure */
      sleep(1);
    } else {
      ntop->getTrace()->traceEvent(TRACE_INFO, "ntopng template successfully sent to ES");
      if(postbuf) free(postbuf);
      break;
    }
    max_attempts--;
  } /* while */

  if(max_attempts == 0)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to send ntopng template (%s) to ES", template_path);

}
