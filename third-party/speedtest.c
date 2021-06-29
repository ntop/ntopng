/*
   Code taken from
   https://github.com/compex-systems/speedtest-cli
*/

/*
 * To compile as standalone application:
 * gcc -DTEST_SPEEDTEST -DHAVE_EXPAT -I/usr/include/json-c -ljson-c -lexpat -lcurl -lpthread -lm speedtest.c -o speedtest
 * Run:
 * ./speedtest
 */

#ifdef TEST_SPEEDTEST
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>
#include <math.h>
#include <curl/curl.h>
#include "json.h"
#define _usleep usleep
#define DEBUG_SPEEDTEST
#endif

//#ifdef DEBUG_SPEEDTEST
#define INFO_SPEEDTEST
//#endif

#ifdef HAVE_EXPAT

#include <float.h>
#include <math.h>
#include "expat.h"

#define URL_LENGTH_MAX         255
#define THREAD_NUM_MAX           1
#define UPLOAD_EXT_LENGTH_MAX    5
#define SPEEDTEST_TIME_MAX      10
#define CUNTRY_NAME_MAX         64

#define UPLOAD_EXTENSION_TAG "upload_extension"
#define LATENCY_TXT_URL "/speedtest/latency.txt"

#define INIT_DOWNLOAD_FILE_RESOLUTION 750
#define FILE_350_SIZE                 245388

#define MAX_ISP_NAME           255
#define MAX_IPADDRESS_STRLEN    48
#define MAX_CLOSEST_SERVER_NUM  64
#define MIN_SERVERS_TO_CHECK     5

#define RECORED_EVERY_SEC        0.2
#define PRINT_RECORED_NUM        2

#define PI                       3.1415926
#define EARTH_RADIUS          6378.137

#define UPLOAD_CHRUNK_SIZE_MAX  512000 // Max upload chunk size 512K

#define OK  0
#define NOK 1
#define FULL_REPORT

#define ARRAY_SIZE(x) (sizeof(x)/sizeof(x[0]))

struct thread_para
{
  pthread_t    tid;
  char         url[URL_LENGTH_MAX + 32];
  long         result;
  long         upload_size;
  long         chunk_size;
  double       now;
  char         finish;
#if THREAD_NUM_MAX > 1
  pthread_mutex_t lock;
#endif
};


struct web_buffer
{
  char *data;
  int   size;
};

struct client_info
{
  char   ip[MAX_IPADDRESS_STRLEN];
  double lat;
  double lon;
  char   isp[MAX_ISP_NAME];
};

struct server_info
{
  char   url[URL_LENGTH_MAX];
  double lat;
  double lon;
  char   country[CUNTRY_NAME_MAX];
  int    id;
  double distance;
};

int depth;
struct client_info client;
struct server_info servers[MAX_CLOSEST_SERVER_NUM];
int num_servers = 0;

static int calc_past_time(struct timeval* start, struct timeval* end)
{
  return (end->tv_sec - start->tv_sec) * 1000 + (end->tv_usec - start->tv_usec)/1000;
}

static size_t write_data(void* ptr, size_t size, size_t nmemb, void *stream)
{
  struct thread_para *p_thread = (struct thread_para*)stream;
  if (p_thread) {
    //p_thread->data++;
#if THREAD_NUM_MAX > 1
    pthread_mutex_lock(&p_thread->lock);
#endif
    p_thread->now += size * nmemb;
#if THREAD_NUM_MAX > 1
    pthread_mutex_unlock(&p_thread->lock);
#endif
  }
  return size * nmemb;
}


size_t
write_web_buf(void *ptr, size_t size, size_t nmemb, void *data)
{
  size_t realsize = size * nmemb;
  struct web_buffer *mem = (struct web_buffer *)data;

  mem->data = (char *)realloc(mem->data, mem->size + realsize + 1);
  if (mem->data) {
    memcpy(&(mem->data[mem->size]), ptr, realsize);
    mem->size += realsize;
    mem->data[mem->size] = 0;
  }
  return realsize;
}

double radian(double d)
{
  return d * PI / 180.0;
}

double get_distance(double lat1, double lng1, double lat2, double lng2)
{
  double radLat1 = radian(lat1);
  double radLat2 = radian(lat2);
  double a = radLat1 - radLat2;
  double b = radian(lng1) - radian(lng2);

  double dst = 2 * asin((sqrt(pow(sin(a / 2), 2) + cos(radLat1) * cos(radLat2) * pow(sin(b / 2), 2) )));

  dst = dst * EARTH_RADIUS;
  dst= round(dst * 10000) / 10000;
  return dst;
}

static void XMLCALL start_element(void *userData, const char *el, const char **atts)
{
  int i;

  if (depth == 1 && strcmp(el, "client") == 0) {

    struct client_info *p_client = (struct client_info *)userData;

    for (i = 0; atts[i]; i += 2) {
      //printf(" %s \n", atts[i]);
      if (strcmp(atts[i], "ip") == 0)
        strcpy(p_client->ip, atts[i + 1]);
      if (strcmp(atts[i], "isp") == 0)
        strcpy(p_client->isp, atts[i + 1]);
      if (strcmp(atts[i], "lat") == 0)
        p_client->lat = atof(atts[i + 1]);
      if (strcmp(atts[i], "lon") == 0)
        p_client->lon = atof(atts[i + 1]);

      //printf("client %s %s %lf %lf\n", p_client->ip, p_client->isp, p_client->lat, p_client->lon);
    }
  }

  if (depth == 2 && strcmp(el, "server") == 0) {
    struct server_info *p_server = (struct server_info *)userData;

    for (i = 0; atts[i]; i += 2) {
      //printf(" %s \n", atts[i]);
      if (strcmp(atts[i], "url") == 0)
        strcpy(p_server->url, atts[i + 1]);
      if (strcmp(atts[i], "country") == 0)
        strcpy(p_server->country, atts[i + 1]);
      if (strcmp(atts[i], "lat") == 0)
        p_server->lat = atof(atts[i + 1]);
      if (strcmp(atts[i], "lon") == 0)
        p_server->lon = atof(atts[i + 1]);
      if (strcmp(atts[i], "id") == 0)
        p_server->id = atof(atts[i + 1]);
    }
  }
  depth++;
}

static void XMLCALL end_element(void *userData, const char *name)
{
  depth--;

  if (strcmp(name, "server") == 0) {
    int i;
    struct server_info *p_server = (struct server_info *)userData;
    double max_distance = 0;
    int max_distance_i = -1;

    p_server->distance = get_distance(client.lat, client.lon, p_server->lat, p_server->lon);

    for (i = 0; i < MAX_CLOSEST_SERVER_NUM; i++) {
      if (servers[i].url[0] == 0 ) {
        break;
      } else {
        if (servers[i].distance >= max_distance) {
          /* Keep track of the server with max distance */
          max_distance = servers[i].distance;
          max_distance_i = i;
        }
      }
    }

    if (i == MAX_CLOSEST_SERVER_NUM) {
      /* No room */
      if (max_distance > p_server->distance) {
        /* Replacing the server with max distance */
        i = max_distance_i;
      }
    }

    if (i != MAX_CLOSEST_SERVER_NUM) {
      memcpy(&servers[i], p_server, sizeof(struct server_info));
      num_servers++; /* Note: this also includes servers discarded due to distance */
    }

    memset(p_server, 0, sizeof(struct server_info));
  }
}

static int do_latency(char *p_url)
{
  char latency_url[URL_LENGTH_MAX + sizeof(LATENCY_TXT_URL)] = {0};
  CURL *curl;
  CURLcode res;
  long response_code;

  curl = curl_easy_init();

  sprintf(latency_url, "%s%s", p_url, LATENCY_TXT_URL);
  curl_easy_setopt(curl, CURLOPT_URL, latency_url);
  curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_data);
  curl_easy_setopt(curl, CURLOPT_WRITEDATA, NULL);
  curl_easy_setopt(curl, CURLOPT_TIMEOUT, 3L);
  res = curl_easy_perform(curl);
  curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &response_code);
  curl_easy_cleanup(curl);

  if (res != CURLE_OK || response_code != 200) {
#ifdef DEBUG_SPEEDTEST
    printf("curl_easy_perform() failed for %s: %s %ld\n", p_url, curl_easy_strerror(res), response_code);
#endif
    return NOK;
  }
  return OK;
}

static double test_latency(char *p_url)
{
  struct timeval s_time, e_time;
  double latency;

  gettimeofday(&s_time, NULL);
  if (do_latency(p_url) != OK)
    return DBL_MAX;
  gettimeofday(&e_time, NULL);

  latency = calc_past_time(&s_time, &e_time);
  return latency;
}

static void* do_download(void* data)
{
  CURL *curl;
  CURLcode res;
  struct thread_para* p_para = (struct thread_para*)data;
  double length = 0;
  double time = 0, time1 = 0, time2;

  curl = curl_easy_init();

  //printf("image url = %s\n", p_para->url);
  curl_easy_setopt(curl, CURLOPT_URL, p_para->url);
  curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_data);
  curl_easy_setopt(curl, CURLOPT_WRITEDATA, p_para);
  res = curl_easy_perform(curl);
  if (res != CURLE_OK) {
    // printf("curl_easy_perform() failed: %s\n", curl_easy_strerror(res));
    curl_easy_cleanup(curl);
    return NULL;
  }
  curl_easy_getinfo(curl, CURLINFO_SIZE_DOWNLOAD, &length);
  curl_easy_getinfo(curl, CURLINFO_TOTAL_TIME, &time);
  curl_easy_getinfo(curl, CURLINFO_CONNECT_TIME, &time1);
  curl_easy_getinfo(curl, CURLINFO_STARTTRANSFER_TIME, &time2);
  //printf("Length is %lf %lf %lf %lf\n", length, time, time1, time2);
  p_para->result = length;
  p_para->finish = 1;
  curl_easy_cleanup(curl);
  return NULL;
}

static void loop_threads(struct thread_para *p_thread,
			 int num_thread, double *speed, int *p_num_speed)
{
  char alive = 0;
  int  num_speed = 0;


  do {
    int i;
    double sum = 0;
    alive = 0;

    for (i = 0;i < num_thread; i++) {
      if (p_thread[i].finish == 0)
        alive = 1;
#if THREAD_NUM_MAX > 1
      pthread_mutex_lock(&p_thread->lock);
#endif
      sum += p_thread[i].now;
      p_thread[i].now = 0;
#if THREAD_NUM_MAX > 1
      pthread_mutex_unlock(&p_thread->lock);
#endif
      //printf("p_thread[i].now = %lf\n", p_thread[i].now);
    }

    _usleep(RECORED_EVERY_SEC*1000*1000); //0.2s
    if (sum == 0 && num_speed == 0)
      continue;

    if (num_speed < *p_num_speed) {

      speed[num_speed] = sum/RECORED_EVERY_SEC; //Byte
      num_speed++;
    }

#if 0
    if (++num % PRINT_RECORED_NUM == 0) {
      printf(".");
      fflush(stdout);
    }
#endif
  } while(alive);
  // printf("\n");
  *p_num_speed = num_speed;
  return;
}

static double calculate_average_speed(double *p_speed, int num_speed)
{

  int i = 0;
  int start ,end;
  double sum = 0;
  for (i = 0; i < num_speed; i++) {

    int j, min;

    for ( min = i, j =  i + 1; j < num_speed; j++) {

      if (p_speed[min] > p_speed[j])
        min = j;
    }
    if (min != i) {

      double          tmp;
      tmp           = p_speed[i];
      p_speed[i]    = p_speed[min];
      p_speed[min]    = tmp;
    }

  }
#if 0
  for (i = 0; i < num_speed; i++) {
    printf("%0.2lf ", p_speed[i]*8/(1024*1024));
    if (i%10 == 0)
      printf("\n");
  }
#endif
  /*The fastest 10% and slowest 20% of the slices are discarded*/
  start = num_speed*0.2;
  end   = num_speed - (int)(num_speed*0.1);
  //end = num_speed;
  for (i = start; i < end; i++) {

    sum += p_speed[i];
  }
  //printf("speed = %0.2lf\n", (sum*8/(end - start))/(1024*1024));

  return sum/(end - start);
}

static int init_instant_speed(double **p_speed, int *p_speed_num)
{
  *p_speed_num    = SPEEDTEST_TIME_MAX/RECORED_EVERY_SEC + 1;
  *p_speed         = (double*)malloc((*p_speed_num)*sizeof(double));

  if (*p_speed == NULL) {
   // fprintf(stderr, "malloc failed\n");
    return -1;
  }
  memset(*p_speed, 0, (*p_speed_num)*sizeof(double));
  return 0;
}
static int test_download(char *p_url, int num_thread, int dsize, char init)
{
  struct timeval s_time;
  int time, i;
  struct thread_para paras[THREAD_NUM_MAX];
  double sum = 0;
  double speed = 0;
  double *instant_speed = NULL;
  int    speed_num = 0;

  gettimeofday(&s_time, NULL);
  init_instant_speed(&instant_speed, &speed_num);

  for ( i = 0; i < num_thread; i++) {
    //int error;

    memset(&paras[i], 0, sizeof(struct thread_para));
    sprintf(paras[i].url, "%s/speedtest/random%dx%d.jpg", p_url, dsize, dsize);
    paras[i].result = 0;

    //error = 

#if THREAD_NUM_MAX > 1
    pthread_mutex_init(paras[i].lock, NULL);
#endif

    pthread_create(&paras[i].tid, NULL, do_download, (void*)&paras[i]);

    // if ( error != 0) printf("Can't Run thread num %d, error %d\n", i, error);
  }

  if (init != 0)
    {
      loop_threads(paras, num_thread, instant_speed, &speed_num);
    }

  for (i = 0;i < num_thread; i++) {
    pthread_join(paras[i].tid, NULL);
    sum += paras[i].result;
  }

  if (init != 0) {

    speed = calculate_average_speed(instant_speed, speed_num);
  }else {

    struct timeval  e_time;

    gettimeofday(&e_time, NULL);
    time = calc_past_time(&s_time, &e_time);
    speed = (sum*1000)/time;
    //printf("msec = %d speed = %0.2fMbps\n", time, ((sum*8*1000/time))/(1024*1024));
  }
  free(instant_speed);
  return speed;
}

#ifdef FULL_REPORT
static size_t read_data(void* ptr, size_t size, size_t nmemb, void *userp)
{
  struct  thread_para* para = (struct thread_para*)userp;
  int     length;
  char    data[16284] = {0};

  if (size * nmemb < 1 && para->chunk_size)
    return 0;
  int i;
  for (i = 0; i < 16284; i++) {

    data[i] = i%26 + 'a';
  }

  if ((size_t) para->chunk_size > size * nmemb) {

    length = size * nmemb < 16284 ? size*nmemb : 16284;
  }
  else
    length = para->chunk_size < 16284 ? para->chunk_size : 16284;
  memcpy(ptr, data, length);

  para->chunk_size -= length;

#if THREAD_NUM_MAX > 1
  pthread_mutex_lock(&para);
#endif
  para->now += length;
#if THREAD_NUM_MAX > 1
  pthread_mutex_unlock(&para->lock);
#endif
  //printf("length = %d\n", length);
  return  length;
}

static void* do_upload(void *p) {
  struct thread_para* para = (struct thread_para*)p;
  CURL *curl;
  CURLcode res;
  long size = para->upload_size;
  int loop = 1;

  if (size > UPLOAD_CHRUNK_SIZE_MAX)
    loop = (size / UPLOAD_CHRUNK_SIZE_MAX) + 1;

  curl = curl_easy_init();

  curl_easy_setopt(curl, CURLOPT_URL, para->url);
  curl_easy_setopt(curl, CURLOPT_READFUNCTION, read_data);
  curl_easy_setopt(curl, CURLOPT_READDATA, para);
  curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_data);
  curl_easy_setopt(curl, CURLOPT_WRITEDATA, NULL);
  curl_easy_setopt(curl, CURLOPT_POSTFIELDS, NULL);

  while (loop) {

    double size_upload;

    para->chunk_size = size - para->result> UPLOAD_CHRUNK_SIZE_MAX ?
      UPLOAD_CHRUNK_SIZE_MAX : size - para->result;
    curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE , (curl_off_t)para->chunk_size);

    res = curl_easy_perform(curl);
    if (res != CURLE_OK) {
      // fprintf(stderr, "Error: curl_easy_perform() failed: %s\n", curl_easy_strerror(res));
      curl_easy_cleanup(curl);
      para->finish = 1;
      return(NULL);
    }
    curl_easy_getinfo(curl, CURLINFO_SIZE_UPLOAD, &size_upload);
    para->result += size_upload;
    loop--;
  }

  curl_easy_cleanup(curl);
  para->finish = 1;
  //printf("size upload = %lf\n", size_upload);

  return(NULL);
}


static int test_upload(char *p_url, int num_thread, long size,
		       char *p_ext, char init)
{
  struct timeval s_time;
  int i;
  struct thread_para paras[THREAD_NUM_MAX];
  double sum = 0, speed = 0;
  double *instant_speed = NULL;
  int    speed_num = 0;
  gettimeofday(&s_time, NULL);

  init_instant_speed(&instant_speed, &speed_num);

  for ( i = 0; i < num_thread; i++) {
    memset(&paras[i], 0, sizeof(struct thread_para));
    sprintf(paras[i].url, "%s/speedtest/upload.%s", p_url, p_ext);
    paras[i].result = 0;
    paras[i].finish = 0;
    paras[i].upload_size = size/num_thread;
    //printf("szeleft = %ld\n", paras[i].upload_size);
    //int error = 
    pthread_create(&paras[i].tid, NULL, do_upload, (void*)&paras[i]);
    // if ( error != 0) printf("Can't Run thread num %d, error %d\n", i, error);
  }
  if (init != 0)
    {
      loop_threads(paras, num_thread, instant_speed, &speed_num);
    }
  for (i = 0;i < num_thread; i++) {
    pthread_join(paras[i].tid, NULL);
    sum += paras[i].result;
  }
  if (init != 0) {

    speed = calculate_average_speed(instant_speed, speed_num);
  }else {
    struct timeval e_time;
    int time;

    gettimeofday(&e_time, NULL);
    time = calc_past_time(&s_time, &e_time);
    speed = (sum*1000)/time; //bytes per second
  }
  //printf("msec = %d speed = %0.2fMbps\n", time, ((sum*8*1000/time))/(1024*1024));
  free(instant_speed);
  return speed;
}
#endif

static int get_download_filename(double speed, int num_thread)
{
  int i;
  int filelist[] = {350, 500, 750, 1000, 1500, 2000, 3000, 3500, 4000};
  int num_file = ARRAY_SIZE(filelist);

  for (i = 1; i < num_file; i++) {

    int time;
    float times = (float)filelist[i]/350;
    //printf("time %f speed %lf\n", times, speed);
    times = (times*times);
    time = (num_thread*times*FILE_350_SIZE)/speed;
    //printf("%d %d %f\n", filelist[i], time, times);
    if (time > SPEEDTEST_TIME_MAX)
      break;
  }
  if (i < num_file)
    return filelist[i - 1];
  return filelist[num_file - 1];
}

static int get_upload_extension(char *server, char *p_ext)
{
  CURL *curl;
  CURLcode res;
  struct web_buffer web;
  char* p = NULL;
  int rv = NOK;

  memset(&web, 0, sizeof(web));

  curl = curl_easy_init();

  curl_easy_setopt(curl, CURLOPT_URL, server);
  curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_web_buf);
  curl_easy_setopt(curl, CURLOPT_WRITEDATA, &web);
  //curl_easy_setopt(curl, CURLOPT_VERBOSE, 1L);
  res = curl_easy_perform(curl);
  curl_easy_cleanup(curl);
  if (res != CURLE_OK) {
    // printf("curl_easy_perform() failed: %s\n", curl_easy_strerror(res));
    goto cleanup;
  }
  p = strstr(web.data, UPLOAD_EXTENSION_TAG);
  if (p == NULL ||
      sscanf(p + strlen(UPLOAD_EXTENSION_TAG), "%*[^a-zA-Z]%[a-zA-Z]", p_ext) <= 0) {
    // fprintf(stderr, "Upload extension not found\n");
    goto cleanup;
  }

  rv = OK;

cleanup:
  if(web.data) free(web.data);

  // printf("Upload extension: %s\n", p_ext);
  return rv;
}

static int get_client_info(struct client_info *p_client)
{
  CURL *curl;
  CURLcode res;
  XML_Parser xml = XML_ParserCreate(NULL);
  struct web_buffer web;
  int rv = NOK;

  memset(&web, 0, sizeof(web));

  curl = curl_easy_init();
  curl_easy_setopt(curl, CURLOPT_URL, "https://www.speedtest.net/speedtest-config.php");
  curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_web_buf);
  curl_easy_setopt(curl, CURLOPT_WRITEDATA, &web);
  curl_easy_setopt(curl, CURLOPT_USERAGENT, "haibbo speedtest-cli");
  curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
  //curl_easy_setopt(curl, CURLOPT_VERBOSE, 1L);
  res = curl_easy_perform(curl);
  curl_easy_cleanup(curl);
  if (res != CURLE_OK) {
#ifdef DEBUG_SPEEDTEST
    printf("curl_easy_perform() failed: %s\n", curl_easy_strerror(res));
#endif
    goto cleanup;
  }
  XML_SetUserData(xml, p_client);
  XML_SetElementHandler(xml, start_element, end_element);
  if (XML_Parse(xml, web.data, web.size , 1) == XML_STATUS_ERROR) {
#ifdef DEBUG_SPEEDTEST
    fprintf(stderr, "Parse client failed\n");
#endif
    // exit(-1);
    goto cleanup;
  }

  rv = OK;

cleanup:
  if(web.data) free(web.data);
  XML_ParserFree(xml);

  return rv;
}

static int get_closest_server()
{
  CURL *curl;
  CURLcode res;
  XML_Parser xml = XML_ParserCreate(NULL);
  struct web_buffer web;
  struct server_info server;
  int rv = NOK;

  memset(&web, 0, sizeof(web));

  curl = curl_easy_init();

  curl_easy_setopt(curl, CURLOPT_URL, "http://www.speedtest.net/speedtest-servers.php");
  curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1);
  curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_web_buf);
  curl_easy_setopt(curl, CURLOPT_WRITEDATA, &web);
  curl_easy_setopt(curl, CURLOPT_USERAGENT, "ntopng");
  //curl_easy_setopt(curl, CURLOPT_VERBOSE, 1L);
  res = curl_easy_perform(curl);
  curl_easy_cleanup(curl);
  if (res != CURLE_OK) {
#ifdef DEBUG_SPEEDTEST
    printf("curl_easy_perform() failed: %s\n", curl_easy_strerror(res));
#endif
    goto cleanup;
  }
  XML_SetUserData(xml, &server);
  depth = 0;
  XML_SetElementHandler(xml, start_element, end_element);
  if (XML_Parse(xml, web.data, web.size , 1) == XML_STATUS_ERROR) {
#ifdef DEBUG_SPEEDTEST
    fprintf(stderr, "Parse servers list failed\n");
#endif
    // exit(-1);
    goto cleanup;
  }

  rv = OK;

cleanup:
  if(web.data) free(web.data);
  XML_ParserFree(xml);

  return rv;
}

static int get_best_server(int *p_index)
{
  int     i;
  double  minimum = DBL_MAX;
  char    server[URL_LENGTH_MAX] = {0};

  for (i = 0; i < MAX_CLOSEST_SERVER_NUM; i++) {
    double latency;

    if (minimum != DBL_MAX && i >= MIN_SERVERS_TO_CHECK)
      break; /* MIN_SERVERS_TO_CHECK evaluated and at least one found */

    if (strlen(servers[i].url) == 0)
      continue;

    sscanf(servers[i].url, "http://%[^/]speedtest/upload.%*s", server);
    latency = test_latency(server);

#ifdef DEBUG_SPEEDTEST
    //printf("Measured latency for %s is %0.3fms\n", server, latency);
#endif

    if (minimum > latency ) {
      minimum = latency;
      *p_index = i;
#ifdef DEBUG_SPEEDTEST
      //printf("Best server set to %u (%s)\n", i, server);
#endif
    }
  }

  if (minimum == DBL_MAX)
    return NOK;

  return OK;
}

json_object* speedtest() {
  int     num_thread;
  char    server_url[URL_LENGTH_MAX], ext[UPLOAD_EXT_LENGTH_MAX];
#ifdef FULL_REPORT
  double  latency, upload_speed;
#endif
  double  speed, download_speed;
  int     dsize, sindex;
  json_object *rc = json_object_new_object();

  if(rc == NULL) {
#ifdef INFO_SPEEDTEST
    printf("speedtest: failure allocating memory\n");
#endif
    return(rc);
  }

  //Initialization

  sindex      = -1;
  num_thread  = 1;
  dsize       = INIT_DOWNLOAD_FILE_RESOLUTION;
  memset(server_url, 0, sizeof(server_url));
  memset(ext, 0, sizeof(ext));

#ifdef DEBUG_SPEEDTEST
  printf("Retrieving speedtest.net configuration...\n");
#endif
  get_client_info(&client);

#ifdef DEBUG_SPEEDTEST
  printf("Retrieving speedtest.net server list...\n");
#endif
  get_closest_server();

#ifdef DEBUG_SPEEDTEST
  printf("Testing from %s (%s)...\n", client.isp, client.ip);
#endif

  json_object_object_add(rc, "client.isp", json_object_new_string(client.isp));
  json_object_object_add(rc, "client.ip", json_object_new_string(client.ip));

#ifdef DEBUG_SPEEDTEST
  printf("Selecting best server based on ping...\n");
#endif

  if (get_best_server(&sindex) != OK) {
#ifdef INFO_SPEEDTEST
    printf("speedtest: failure selecting the best server out of %u\n", num_servers);
#endif
    return(rc);
  }
  
  sscanf(servers[sindex].url, "http://%[^/]/speedtest/upload.%4s", server_url, ext);
#ifdef DEBUG_SPEEDTEST
  printf("Best server: %s(%0.2fKM)\n", server_url, servers[sindex].distance);
#endif
  json_object_object_add(rc, "server.url", json_object_new_string(server_url));
  json_object_object_add(rc, "server.distance", json_object_new_double(servers[sindex].distance));

  /* Must initialize libcurl before any threads are started */
  curl_global_init(CURL_GLOBAL_ALL);

#ifdef FULL_REPORT
  latency = test_latency(server_url);
  if (latency == DBL_MAX) {
#ifdef INFO_SPEEDTEST
    printf("speedtest: failure testing latency\n");
#endif
    return(rc);
  }

#ifdef DEBUG_SPEEDTEST
  printf("Server latency is %0.0fms\n", latency);
#endif
  json_object_object_add(rc, "server.latency", json_object_new_double(latency));
#endif

  speed = test_download(server_url, num_thread, dsize, 0);

  dsize = get_download_filename(speed, num_thread);
#ifdef DEBUG_SPEEDTEST
  fprintf(stderr, "Testing download speed");
#endif
  download_speed = test_download(server_url, num_thread, dsize, 1);

#ifdef DEBUG_SPEEDTEST
  printf("Download speed: %0.2fMbps\n", ((download_speed*8)/(1024*1024)));
#endif
  json_object_object_add(rc, "download.speed", json_object_new_double((download_speed*8)/(1024*1024)));

  if (ext[0] == 0 && get_upload_extension(server_url, ext) != OK) {
#ifdef INFO_SPEEDTEST
    printf("speedtest: failure in upload extension\n");
#endif
    return(rc);
  }

#ifdef FULL_REPORT
  speed = test_upload(server_url, num_thread, speed, ext, 0);

#ifdef DEBUG_SPEEDTEST
  fprintf(stderr, "Testing upload speed");
#endif
  upload_speed = test_upload(server_url, num_thread, speed*SPEEDTEST_TIME_MAX, ext, 1);

#ifdef DEBUG_SPEEDTEST
  printf("Upload speed: %0.2fMbps\n", ((upload_speed*8)/(1024*1024)));
#endif
  json_object_object_add(rc, "upload.speed", json_object_new_double(((upload_speed*8)/(1024*1024))));
#endif

  return(rc);
}

#else
json_object* speedtest() { return(NULL); }
#endif /* HAVE_EXPAT */

#ifdef TEST_SPEEDTEST
int main(int argc, char *argv[]) {
  json_object *out;
 
  out = speedtest();

  if (out == NULL) {
    printf("failure\n");
    return 1;
  }

  printf("%s\n", json_object_to_json_string(out));

  json_object_put(out);

  return 0;
}
#endif
