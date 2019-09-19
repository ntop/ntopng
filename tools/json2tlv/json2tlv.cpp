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
  char url[16];
  u_int8_t version, source_id;
  u_int16_t size;
  u_int32_t msg_id;
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

    if (posix_memalign( (void **)&aligned_buffer, 64, (length + 63) / 64  * 64)) {
      printf("Allocation failed\n");
      exit(1);
    }

    memset(aligned_buffer, 0x20, (length + 63) / 64  * 64);
    memcpy(aligned_buffer, buffer.str().c_str(), length);

    is.close();

    return make_pair((char *)aligned_buffer, length);
  } 

  printf("JSON file %s not found or empty\n", filename.c_str());
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
void json_to_tlv(json_object *jobj, ndpi_serializer *serializer) {
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
  cerr << "Usage: " << bin << " -i <JSON file> [-z <ZMQ endpoint>] [-E <num encoding loops] [-D <num decoding loop>] [-j] [-v]\n";
  cerr << "\n";
  cerr << "-i <file>       Input JSON file containing an array of records\n";
  cerr << "-z <endpoint>   ZMQ endpoint for delivering records\n";
  cerr << "-E <loops>      Encode <loops> times to check the performance\n";
  cerr << "-D <loops>      Decode <loops> times to check the performance\n";
  cerr << "-j              Generate JSON records instead of TLV records\n";
  cerr << "-v              Verbose mode\n";
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
  int rc, i, j, z, num_records, max_tlv_msgs = 0, tlv_msgs = 0;
  u_int32_t exported_msgs = 0, exported_records = 0;
  u_int8_t use_json_encoding = 0;
  char c;
  int once = 0;

  while ((c = getopt(argc, argv,"hi:jvz:E:D:")) != '?') {
    if (c == (char) 255 || c == -1) break;

    switch(c) {
      case 'h':
        print_help(argv[0]);
        exit(0);
      break;
    
      case 'i':
        json_path = strdup(optarg);
      break;

      case 'j':
        use_json_encoding = 1;
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
      if (zmq_bind(zmq_sock, zmq_endpoint) != 0) {
        printf("Unable to bind to ZMQ socket %s: %s\n", zmq_endpoint, strerror(errno));
        exit(1);
      }

    } else {
      /* Probe mode */
      if (zmq_connect(zmq_sock, zmq_endpoint) != 0)
        printf("Unable to connect to ZMQ socket %s: %s\n", zmq_endpoint, strerror(errno));
    }
  }

  /* JSON Import */

  pair<char *, size_t> p = get_corpus(json_path);

  enum json_tokener_error jerr = json_tokener_success;
  json_object *f;
  u_int64_t delta_usec, last_delta_usec = 0, last_exported_records = 0;

  f = json_tokener_parse_verbose(p.first, &jerr);

  if (f == NULL) {
    printf("Error parsing buffer\n");
    goto exit;
  }

  if (json_object_get_type(f) == json_type_array)
    num_records = json_object_array_length(f);
  else
    num_records = 1;

  printf("%u records found\n", num_records);

  /* nDPI TLV Serialization */

  max_tlv_msgs = (num_records/batch_size)+1;
  serializer = (ndpi_serializer *) calloc(max_tlv_msgs, sizeof(ndpi_serializer)); 

  for (i = 0; i < max_tlv_msgs; i++) 
    ndpi_init_serializer(&serializer[i], use_json_encoding ? ndpi_serialization_format_json : ndpi_serialization_format_tlv);

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
          json_object *ji = json_object_array_get_idx(f, i);
          if (ji == NULL) {
            printf("Error reading flow #%u\n", i);
            goto exit;
          }
          json_to_tlv(ji, &serializer[tlv_msgs]);
          j++, i++;
        }
        tlv_msgs++;
      }
    } else {
      ndpi_reset_serializer(&serializer[tlv_msgs]);
      json_to_tlv(f, &serializer[tlv_msgs]);
      tlv_msgs++;
    }

    if (!once) {
      printf("Batching %u flows in %u messages (%u per message)\n", num_records, tlv_msgs, batch_size);
      once = 1;
    }

    /* Sending TLV records over ZMQ */

    if (zmq_sock) {
      for(i = 0; i < tlv_msgs; i++) {
        struct zmq_msg_hdr msg_hdr;
        u_int32_t buffer_len;
        u_int8_t *buffer = (u_int8_t *) ndpi_serializer_get_buffer(&serializer[i], &buffer_len);
        strncpy(msg_hdr.url, "flow", sizeof(msg_hdr.url));
        msg_hdr.version = (use_json_encoding ? 2 : 3);
        msg_hdr.size = htonl(buffer_len);
        msg_hdr.msg_id = htonl(exported_msgs);
        rc = zmq_send(zmq_sock, &msg_hdr, sizeof(msg_hdr), ZMQ_SNDMORE);

        if (use_json_encoding && verbose) {
          enum json_tokener_error jerr = json_tokener_success;
          json_object *f = json_tokener_parse_verbose((char *) buffer, &jerr);
          printf("Sending JSON #%u '%s' [len=%u][%s]\n", i, (char *) buffer, buffer_len, f == NULL ? "INVALID" : "VALID");
        }

        if (rc > 0)
          rc = zmq_send(zmq_sock, buffer, buffer_len, 0);

        if (rc > 0) {
          exported_msgs++;
        } else {
          printf("zmq_send failure: %d\n", rc);
          goto exit;
        }
      }
      exported_records += num_records;
    }

    gettimeofday(&t2, NULL);

    delta_usec = (u_int64_t) ((u_int64_t) t2.tv_sec * 1000000 + t2.tv_usec) - ((u_int64_t) t1.tv_sec * 1000000 + t1.tv_usec);
    total_time_usec += delta_usec;

    if (total_time_usec - last_delta_usec > 1000000 /* every 1 sec */) {
      printf("%u flows / %.2f flows/sec / %u messages exported\n", exported_records, 
        ((double) (exported_records - last_exported_records) / ((total_time_usec - last_delta_usec)/1000000)),
        exported_msgs);
      last_exported_records = exported_records;
      last_delta_usec = total_time_usec;
    }

  }  

  printf("Serialization perf (includes json-c overhead): %.3f msec total time for %u iterations\n", (double) total_time_usec/1000, enc_repeat);

  json_object_put(f);

  if (use_json_encoding)
    goto exit;

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

      ndpi_serialization_type kt, et;
      while((et = ndpi_deserialize_get_item_type(&deserializer, &kt)) != ndpi_serialization_unknown) {
        u_int32_t k32, v32;
        ndpi_string ks, vs;
        u_int8_t bkp, bkpk;

        if (et == ndpi_serialization_end_of_record) {
          if (verbose) printf("EOR\n");
          j++;
          z = 0;
          goto next;
        }

        switch(kt) {
          case ndpi_serialization_uint32:
          ndpi_deserialize_key_uint32(&deserializer, &k32);
          if (verbose) printf("%u=", k32);
          break;

          case ndpi_serialization_string:
          ndpi_deserialize_key_string(&deserializer, &ks);
          bkpk = ks.str[ks.str_len];
          ks.str[ks.str_len] = '\0';
          if (verbose) printf("%s=", ks.str);
          ks.str[ks.str_len] = bkpk;
          break;

          default:
          printf("Unsupported key type %u [msg: %u][record: %u][element: %u]\n", kt, i, j, z);
          goto close_message;
        }

        switch(et) {
          case ndpi_serialization_uint32:
          ndpi_deserialize_value_uint32(&deserializer, &v32);
          if (verbose) printf("%u ", v32);
          break;

          case ndpi_serialization_string:
          ndpi_deserialize_value_string(&deserializer, &vs);
          bkp = vs.str[vs.str_len];
          vs.str[vs.str_len] = '\0';
          if (verbose) printf("'%s' ", vs.str);
          vs.str[vs.str_len] = bkp;
          break;

          default:
          printf("Unsupported type %u [msg: %u][record: %u][element: %u]\n", et, i, j, z);
          goto close_message;
          break;
        }

        next:
        ndpi_deserialize_next(&deserializer);

        z++;
      }

      close_message:

      if (verbose) printf("\n---\n");  
    }

    gettimeofday(&t2, NULL);

    total_time_usec += (u_int64_t) ((u_int64_t) t2.tv_sec * 1000000 + t2.tv_usec) - ((u_int64_t) t1.tv_sec * 1000000 + t1.tv_usec);
  }

  printf("Deserialization perf: %.3f msec total time for %u iterations\n", (double) total_time_usec/1000, dec_repeat);

 exit:

  if (zmq_sock)
    printf("%u messages %u records sent over ZMQ\n", exported_msgs, exported_records);

  for (i = 0; i < tlv_msgs; i++)
    ndpi_term_serializer(&serializer[i]);

  if (zmq_sock != NULL)  zmq_close(zmq_sock);
  if (zmq_context != NULL) zmq_ctx_destroy(zmq_context);
  if (zmq_endpoint)        free(zmq_endpoint);

  return 0;
}

