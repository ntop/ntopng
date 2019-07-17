#include <iostream>
#include <sstream>
#include <fstream>
#include <string.h>
#include <unistd.h>

#include "json.h"
#include "ndpi_main.h"
#include <zmq.h>

using namespace std;

struct zmq_msg_hdr {
  char url[32];
  u_int32_t version;
  u_int32_t size;
};

/* *************************************** */

static pair<char *, size_t> get_corpus(string filename) {
  ifstream is(filename, ios::binary);

  if (is) {
    stringstream buffer;
    char *aligned_buffer;
    size_t length;

    buffer << is.rdbuf();

    length = buffer.str().size();

    if (posix_memalign( (void **)&aligned_buffer, 64, (length + 63) / 64  * 64))
      throw "Allocation failed";

    memset(aligned_buffer, 0x20, (length + 63) / 64  * 64);
    memcpy(aligned_buffer, buffer.str().c_str(), length);

    is.close();

    return make_pair((char *)aligned_buffer, length);
  } 

  cerr << "JSON file " << filename << "not found or empty\n";
  exit(1);
}

/* *************************************** */

int key_is_int(char *key) {
  int i, length = strlen(key);

  for (i = 0; i < length; i++)
    if (!isdigit(key[i]))
      return 0;

  return 1;
}

/* *************************************** */
void json_to_tlv(json_object * jobj, ndpi_serializer *serializer) {
  enum json_type type;
  int rc, ikey, ival = 0;
  char *sval = NULL;

  json_object_object_foreach(jobj, key, val) {
    type = json_object_get_type(val);

    //printf("key: %s type: %u ", key, type);

    switch (type) {
      case json_type_int:
        ival = json_object_get_int(val);
      break;
      case json_type_string:
        sval = (char *) json_object_get_string(val);
      break;
      default:
        printf("JSON type %u not supported\n", type);
      break;
    }

    rc = 0;
    if (key_is_int(key)) {
      ikey = atoi(key);
      switch (type) {
        case json_type_int:
          rc = ndpi_serialize_uint32_uint32(serializer, ikey, ival);
        break;
        case json_type_string:
          rc = ndpi_serialize_uint32_string(serializer, ikey, sval);
        break;
        default:
        break;
      }
    } else {
      switch (type) {
        case json_type_int:
          rc = ndpi_serialize_string_uint32(serializer, key, ival);
        break;
        case json_type_string:
          rc = ndpi_serialize_string_string(serializer, key, sval);
        break;
        default:
        break;
      }
    }

    if (rc == -1)
      printf("Serialization error: %d\n", rc);
  }

  ndpi_serialize_end_of_record(serializer);
}

/* *************************************** */

void print_help(char *bin) {
  cerr << "Usage: " << bin << " -i <JSON file> [-z <ZMQ endpoint>] [-E <num encoding loops] [-D <num decoding loop>] [-v]\n";
  cerr << "Note: the JSON file should contain an array of records\n";
}

/* *************************************** */

int main(int argc, char *argv[]) {
  char *json_path = NULL;
  char* zmq_endpoint = NULL;
  void *zmq_sock = NULL;
  void *zmq_context = NULL;
  int enc_repeat = 1, dec_repeat = 1;
  int batch_size = 20;
  int verbose = 0;
  struct timeval t1, t2;
  uint64_t total_time_usec;
  ndpi_serializer *serializer;
  ndpi_serializer deserializer;
  int rc, i, j, z, num_records, max_tlv_msgs = 0, tlv_msgs = 0, exported_msgs = 0;
  char c;

  while ((c = getopt(argc, argv,"hi:vz:E:D:")) != '?') {
    if (c == (char) 255 || c == -1) break;

    switch(c) {
      case 'h':
        print_help(argv[0]);
        exit(0);
      break;
    
      case 'i':
        json_path = strdup(optarg);
      break;

      case 'v':
        verbose = 1;
      break;

      case 'z':
        zmq_endpoint = strdup(optarg);
      break;

      case 'E':
        enc_repeat = atoi(optarg);
      break;

      case 'D':
        dec_repeat = atoi(optarg);
      break;
    }
  }

  if (json_path == NULL) {
    print_help(argv[0]);
    exit(1);
  }

  if (zmq_endpoint) {
    zmq_context = zmq_ctx_new();
    if (zmq_context == NULL) {
      printf("Unable to initialize ZMQ zmq_context");
      exit(1);
    }

    zmq_sock = zmq_socket(zmq_context, ZMQ_PUB);
    if (zmq_sock == NULL) {
      printf("Unable to create ZMQ socket");
      exit(1);
    }

    if (zmq_endpoint[strlen(zmq_endpoint) - 1] == 'c') {
      /* Collector mode */
      if (zmq_connect(zmq_sock, zmq_endpoint) != 0)
        printf("Unable to connect to ZMQ socket %s: %s\n", zmq_endpoint, strerror(errno));
    } else {
      /* Probe mode */
      if (zmq_bind(zmq_sock, zmq_endpoint) != 0) {
        printf("Unable to bind to ZMQ socket %s: %s\n", zmq_endpoint, strerror(errno));
        exit(1);
      }
    }
  }

  /* JSON Import */

  pair<char *, size_t> p = get_corpus(json_path);

  enum json_tokener_error jerr = json_tokener_success;
  char * buffer = (char *) malloc(p.second);
  json_object *f;

  f = json_tokener_parse_verbose(buffer, &jerr);

  if (json_object_get_type(f) == json_type_array)
    num_records = json_object_array_length(f);
  else
    num_records = 1;

  printf("%u records found\n", num_records);

  free(buffer);

  /* nDPI TLV Serialization */

  max_tlv_msgs = (num_records/batch_size)+1;
  serializer = (ndpi_serializer *) calloc(max_tlv_msgs, sizeof(ndpi_serializer)); 

  for (i = 0; i < max_tlv_msgs; i++) 
    ndpi_init_serializer(&serializer[i], ndpi_serialization_format_tlv);

  printf("Serializing..\n");

  total_time_usec = 0;

  for (int r = 0; r < enc_repeat; r++) {

    gettimeofday(&t1, NULL);

    /* Converting from JSON to TLV records */

    tlv_msgs = 0;
    if (json_object_get_type(f) == json_type_array) {
      i = 0;
      while (i < num_records) {
        ndpi_reset_serializer(&serializer[tlv_msgs]);
        j = 0;
        while (i < num_records && j < batch_size) {
          json_to_tlv(json_object_array_get_idx(f, i), &serializer[tlv_msgs]);
          j++, i++;
        }
        tlv_msgs++;
      }
    } else {
      ndpi_reset_serializer(&serializer[tlv_msgs]);
      json_to_tlv(f, &serializer[tlv_msgs]);
      tlv_msgs++;
    }

    /* Sending TLV records over ZMQ */

    if (zmq_sock) {
      for(i = 0; i < tlv_msgs; i++) {
        struct zmq_msg_hdr msg_hdr;
        strncpy(msg_hdr.url, "flow", sizeof(msg_hdr.url));
        msg_hdr.version = 3;
        msg_hdr.size = serializer[i].size_used;
        zmq_send(zmq_sock, &msg_hdr, sizeof(msg_hdr), ZMQ_SNDMORE);
        rc = zmq_send(zmq_sock, serializer[i].buffer, msg_hdr.size, 0);
        if (rc > 0)
          exported_msgs++;
      }
    }

    gettimeofday(&t2, NULL);

    total_time_usec += (u_int64_t) ((u_int64_t) t2.tv_sec * 1000000 + t2.tv_usec) - ((u_int64_t) t1.tv_sec * 1000000 + t1.tv_usec);
  }  

  printf("Serialization perf (includes json-c overhead): %.3f msec total time for %u iterations\n", (double) total_time_usec/1000, enc_repeat);

  json_object_put(f);

  /* nDPI TLV Deserialization */

  printf("Deserializing..\n");

  total_time_usec = 0;

  for (int r = 0; r < dec_repeat; r++) {

    gettimeofday(&t1, NULL);

    for (i = 0, j = 0, z = 0; i < tlv_msgs; i++, z = 0) {

      if (verbose) printf("\n[Message %u]\n\n", i);

      rc = ndpi_init_deserializer(&deserializer, &serializer[i]);

      if (rc == -1) {
        printf("Deserialization error: %d\n", rc);
        return -1;
      }

      ndpi_serialization_element_type et;
      while ((et = ndpi_deserialize_get_nextitem_type(&deserializer)) != ndpi_serialization_unknown) {
        u_int32_t k32, v32;
        ndpi_string ks, vs;
        u_int8_t bkp, bkpk;

        switch(et) {
          case ndpi_serialization_uint32_uint32:
          ndpi_deserialize_uint32_uint32(&deserializer, &k32, &v32);
          if (verbose) printf("%u=%u ", k32, v32);
          break;

          case ndpi_serialization_uint32_string:
          ndpi_deserialize_uint32_string(&deserializer, &k32, &vs);
          bkp = vs.str[vs.str_len];
          vs.str[vs.str_len] = '\0';
          if (verbose) printf("%u='%s' ", k32, vs.str);
          vs.str[vs.str_len] = bkp;
          break;

          case ndpi_serialization_string_string:
          ndpi_deserialize_string_string(&deserializer, &ks, &vs);
          bkpk = ks.str[ks.str_len], bkp = vs.str[vs.str_len];
          ks.str[ks.str_len] = vs.str[vs.str_len] = '\0';
          if (verbose) printf("%s='%s' ", ks.str, vs.str);
          ks.str[ks.str_len] = bkpk, vs.str[vs.str_len] = bkp;
          break;

          case ndpi_serialization_string_uint32:
          ndpi_deserialize_string_uint32(&deserializer, &ks, &v32);
          bkpk = ks.str[ks.str_len];
          ks.str[ks.str_len] = '\0';
          if (verbose) printf("%s=%u ", ks.str, v32);
          ks.str[ks.str_len] = bkpk;
          break;

          case ndpi_serialization_end_of_record:
          ndpi_deserialize_end_of_record(&deserializer);
          if (verbose) printf("EOR\n");
          j++;
          z = 0;
          break;

          default:
          printf("Unsupported type %u [msg: %u][record: %u][element: %u]\n", et, i, j, z);
          goto close_message;
          break;
        }

        z++;
      }

      close_message:

      if (verbose) printf("\n---\n");  
    }

    gettimeofday(&t2, NULL);

    total_time_usec += (u_int64_t) ((u_int64_t) t2.tv_sec * 1000000 + t2.tv_usec) - ((u_int64_t) t1.tv_sec * 1000000 + t1.tv_usec);
  }

  printf("Deserialization perf: %.3f msec total time for %u iterations\n", (double) total_time_usec/1000, dec_repeat);

  if (zmq_sock)
    printf("%u messages (max %u records each) sent over ZMQ\n", exported_msgs, batch_size);

  for (i = 0; i < tlv_msgs; i++)
    ndpi_term_serializer(&serializer[i]);

  if (zmq_sock != NULL)  zmq_close(zmq_sock);
  if (zmq_context != NULL) zmq_ctx_destroy(zmq_context);
  if (zmq_endpoint)        free(zmq_endpoint);

  return 0;
}

