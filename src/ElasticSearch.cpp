/*
 *
 * (C) 2013-18 - ntop.org
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

#ifndef HAVE_NEDGE

/* **************************************************** */

static void* esLoop(void* ptr) {
  ntop->getElasticSearch()->pushEStemplate();  // sends ES ntopng template
  ntop->getElasticSearch()->indexESdata();
  return(NULL);
}

/* **************************************** */

ElasticSearch::ElasticSearch() {
  char *es_url, *es_host;

  es_version = NULL;
  num_queued_elems = 0;
  head = NULL;
  tail = NULL;
  reportDrops = false;
  elkDroppedFlowsQueueTooLong = 0;
  elkExportedFlows = 0, elkLastExportedFlows = 0;
  elkExportRate = 0;
  checkpointDroppedFlows = checkpointExportedFlows = 0;
  lastUpdateTime.tv_sec = 0, lastUpdateTime.tv_usec = 0;

  if (!(es_template_push_url = (char*)malloc(MAX_PATH))
      || !(es_version_query_url = (char*)malloc(MAX_PATH))
      || !(es_url = strdup(ntop->getPrefs()->get_es_url())))
    throw "Not enough memory";

  es_template_push_url[0] = '\0', es_version_query_url[0] = '\0';

  // Prepare ES urls (keep only host and port by retaining only characters left of the first slash)
  if(!strncmp(es_url, "http://", 7)){  // url starts either with http or https
    Utils::tokenizer(es_url + 7, '/', &es_host);
    snprintf(es_template_push_url, MAX_PATH, "http://%s/_template/ntopng_template", es_host);
    snprintf(es_version_query_url, MAX_PATH, "http://%s/", es_host);
  } else if(!strncmp(es_url, "https://", 8)){
    Utils::tokenizer(es_url + 8, '/', &es_host);
    snprintf(es_template_push_url, MAX_PATH, "https://%s/_template/ntopng_template", es_host);
    snprintf(es_version_query_url, MAX_PATH, "https://%s/", es_host);
  } else {
    Utils::tokenizer(es_url, '/', &es_host);
    snprintf(es_template_push_url, MAX_PATH, "%s/_template/ntopng_template", es_host);
    snprintf(es_version_query_url, MAX_PATH, "%s/", es_host);
  }

  free(es_url);
}

/* **************************************** */

ElasticSearch::~ElasticSearch() {
  if(es_version) free(es_version);
  if(es_template_push_url) free(es_template_push_url);
  if(es_version_query_url) free(es_version_query_url);
}

/* ******************************************* */

void ElasticSearch::updateStats(const struct timeval *tv) {
  if(tv == NULL) return;

  if(lastUpdateTime.tv_sec > 0) {
    float tdiffMsec = Utils::msTimevalDiff(tv, &lastUpdateTime);
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

  listMutex.lock(__FILE__, __LINE__);

  e = (struct string_list*)calloc(1, sizeof(struct string_list));
  if(e != NULL) {
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

  listMutex.unlock(__FILE__, __LINE__);

  return rc;
}

/* **************************************** */

void ElasticSearch::startFlowDump() {
  if(ntop->getPrefs()->do_dump_flows_on_es())
    pthread_create(&esThreadLoop, NULL, esLoop, (void*)this);
}


/* **************************************** */

void ElasticSearch::indexESdata() {
  const u_int min_buffered_flows = 8;
  time_t last_dump = time(0);
  char *postbuf = (char*) malloc(ES_BULK_BUFFER_SIZE);

  if(!postbuf) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Cannot allocate ES bulk buffer");
    return;
  }

  while(!ntop->getGlobals()->isShutdown()) {
    time_t now = time(0);

    if((num_queued_elems >= min_buffered_flows)
       || ((num_queued_elems > 0) && (now >= last_dump + ES_BULK_MAX_DELAY))) {
      u_int len, num_flows;
      char index_name[64], header[256];
      struct tm* tm_info;
      struct timeval tv;
      time_t t;
      HTTPTranferStats stats;

      gettimeofday(&tv, NULL);
      t = tv.tv_sec;
      tm_info = gmtime(&t);

      strftime(index_name, sizeof(index_name), ntop->getPrefs()->get_es_index(), tm_info);

      snprintf(header, sizeof(header),
	       "{\"index\": {\"_type\": \"%s\", \"_index\": \"%s\"}}",
	       atleast_version_6() ? (char*)"_doc" /* types no longer supported in 6 */ : ntop->getPrefs()->get_es_type(),
	       index_name);
      len = 0, num_flows = 0;

      listMutex.lock(__FILE__, __LINE__);
      for(u_int i=0; (i < num_queued_elems) && (len <= ES_BULK_BUFFER_SIZE); i++) {
        struct string_list *prev;
        prev = tail->prev;
        len += snprintf(&postbuf[len], ES_BULK_BUFFER_SIZE-len, "%s\n%s\n", header, tail->str), num_flows++;
        free(tail->str);
        free(tail);
        tail = prev, num_queued_elems--;

        if(num_queued_elems == 0)
	  head = NULL;
      } /* for */

      listMutex.unlock(__FILE__, __LINE__);
      postbuf[len] = '\0';

      ntop->getTrace()->traceEvent(TRACE_INFO, "ES: Buffered request with %d flows (%d bytes)", num_flows, len);

      if(!Utils::postHTTPJsonData(ntop->getPrefs()->get_es_user(),
				  ntop->getPrefs()->get_es_pwd(),
				  ntop->getPrefs()->get_es_url(),
				  postbuf, &stats)) {
	/* Post failure */
	ntop->getTrace()->traceEvent(TRACE_ERROR, "ES: POST request for %d flows (%d bytes) failed", num_flows, len);
	sleep(1);
      } else {
	ntop->getTrace()->traceEvent(TRACE_INFO, "Sent %u flow(s) to ES", num_flows);
	elkExportedFlows += num_flows;
      }

      last_dump = now;
    } else
      sleep(1);
  } /* while */

  free(postbuf);
}

/* **************************************** */

/* Send ntopng index template to Elastic Search */
const char * const ElasticSearch::get_es_version() {
  static bool version_inited = false;

  if(!version_inited) { /* lazy... */
    u_int buf_len =
#ifdef HAVE_CURL
      CURL_MAX_WRITE_SIZE;
#else
    1<<14; /* 16kB */
#endif
    char *buf = (char*)malloc(buf_len);

    if(buf) {
      long http_ret_code = Utils::httpGet(es_version_query_url,
					  ntop->getPrefs()->get_es_user(), ntop->getPrefs()->get_es_pwd(),
					  5,
					  buf, buf_len);
      if(http_ret_code == 200) {
	json_object *o, *obj, *obj2;
	enum json_tokener_error jerr = json_tokener_success;

	ntop->getTrace()->traceEvent(TRACE_INFO, "%s [http return code: %d]", buf, http_ret_code);

	if((o = json_tokener_parse_verbose(buf, &jerr)) == NULL) {
	  ntop->getTrace()->traceEvent(TRACE_WARNING, "JSON Parse error [%s][%s]",
				       json_tokener_error_desc(jerr),
				       buf);
	}

	/* An example json response is:
	  {
	  "name" : "node-1",
	  "cluster_name" : "ntop",
	  "cluster_uuid" : "GnWshRUvTuePXKMO15gZBg",
	  "version" : {
	  "number" : "5.6.5",
	  "build_hash" : "6a37571",
	  "build_date" : "2017-12-04T07:50:10.466Z",
	  "build_snapshot" : false,
	  "lucene_version" : "6.6.1"
	  },
	  "tagline" : "You Know, for Search"
	  }
	 */

	if(json_object_object_get_ex(o, "version", &obj)
	   && json_object_object_get_ex(obj, "number", &obj2)) {
	  const char *ver = json_object_get_string(obj2);

	  if(es_version) free(es_version);
	  if((es_version = (char*)malloc(strlen(ver) + 1))) {
	    strcpy(es_version, ver);
	    version_inited = true;
	  }
	}
      } else {
	ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to query ES to get its version");
      }

      free(buf);
    }
  }

  return es_version;
}

/* **************************************** */

/* Send ntopng index template to Elastic Search */
void ElasticSearch::pushEStemplate() {
  char *postbuf = NULL;
  char template_path[MAX_PATH];
  ifstream template_file;
  u_int8_t max_attempts = 3;
  u_int16_t length = 0;
  HTTPTranferStats stats;

  snprintf(template_path, sizeof(template_path), "%s/misc/%s",
	   ntop->get_docs_dir(),
	   atleast_version_6() ? NTOP_ES6_TEMPLATE : NTOP_ES_TEMPLATE);
  ntop->fixPath(template_path);

  template_file.open(template_path);   // open input file
  template_file.seekg(0, ios::end);    // go to the end
  length = template_file.tellg();      // report location (this is the length)
  template_file.seekg(0, ios::beg);    // go back to the beginning
  postbuf = new char[length+1];        // allocate memory for a buffer of appropriate dimension
  template_file.read(postbuf, length); // read the whole file into the buffer
  postbuf[length] = '\0';
  if(template_file.is_open())
    template_file.close();            // close file handle

  while(max_attempts > 0) {
    if(!Utils::postHTTPJsonData(ntop->getPrefs()->get_es_user(),
				ntop->getPrefs()->get_es_pwd(),
				es_template_push_url, postbuf, &stats)) {
      /* Post failure */
      sleep(1);
    } else {
      ntop->getTrace()->traceEvent(TRACE_INFO, "ntopng template successfully sent to ES");
      break;
    }

    max_attempts--;
  } /* while */

  if(postbuf) delete[] postbuf;

  if(max_attempts == 0)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to send ntopng template (%s) to ES",
				 template_path);
}

#endif
