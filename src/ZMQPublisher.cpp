/*
 *
 * (C) 2019-23 - ntop.org
 *
 * This code is proprietary code subject to the terms and conditions
 * defined in LICENSE file which is part of this source code package.
 *
 */

#include "ntop_includes.h"

#ifndef HAVE_NEDGE

/* *********************************************************** */

/**
 * Constructor: initializes ZMQ sockets.
 * @param endpoint The ZMQ endpoint.
 */
ZMQPublisher::ZMQPublisher(char *endpoint, const char *server_public_key) {

  ntop->getTrace()->traceEvent(TRACE_INFO, "Initializing ZMQPublisher with %s",
                               endpoint);

  if (endpoint == NULL)
    throw("NULL endpoint");

  context = zmq_ctx_new();

  if (context == NULL) {
    ntop->getTrace()->traceEvent(
        TRACE_ERROR, "Unable to initialize ZMQ %s (context)", endpoint);
    throw "Unable to initialize ZMQ (context)";
  }

  /* ntopng publish events to remote collectors (probes) */
  flow_publisher = zmq_socket(context, ZMQ_PUB);

  if (flow_publisher == NULL) {
    ntop->getTrace()->traceEvent(
        TRACE_ERROR, "Unable to initialize ZMQ %s (flow_publisher)",
        endpoint);
    throw "Unable to initialize ZMQ (flow_publisher)";
  }

  if (server_public_key != NULL)
#if ZMQ_VERSION >= ZMQ_MAKE_VERSION(4, 1, 0)
    if (setEncryptionKey(server_public_key) < 0)
      throw "Unable to set ZMQ encryption";
#else
    throw "Unable to set ZMQ encryption, it requires ZMQ >= 4.1";
#endif

  if (zmq_bind(flow_publisher, endpoint) != 0) {
    zmq_close(flow_publisher);
    zmq_ctx_destroy(context);
    ntop->getTrace()->traceEvent(
        TRACE_ERROR, "Unable to connect to ZMQ endpoint %s", endpoint);
    throw("Unable to connect to the specified ZMQ endpoint");
  }

  if (strncmp(endpoint, (char *)"tcp://", 6) == 0) {
    int val = DEFAULT_ZMQ_TCP_KEEPALIVE;

    /* TCP socker optimizations */

    if (zmq_setsockopt(flow_publisher, ZMQ_TCP_KEEPALIVE, &val,
                       sizeof(val)) != 0)
      ntop->getTrace()->traceEvent(TRACE_ERROR,
                                   "Unable to set tcp keepalive");
    else
      ntop->getTrace()->traceEvent(TRACE_INFO, "TCP keepalive set");

    val = DEFAULT_ZMQ_TCP_KEEPALIVE_IDLE;
    if (zmq_setsockopt(flow_publisher, ZMQ_TCP_KEEPALIVE_IDLE, &val,
                       sizeof(val)) != 0)
      ntop->getTrace()->traceEvent(
          TRACE_ERROR, "Unable to set tcp keepalive idle to %u seconds", val);
    else
      ntop->getTrace()->traceEvent(
          TRACE_INFO, "TCP keepalive idle set to %u seconds", val);

    val = DEFAULT_ZMQ_TCP_KEEPALIVE_CNT;
    if (zmq_setsockopt(flow_publisher, ZMQ_TCP_KEEPALIVE_CNT, &val,
                       sizeof(val)) != 0)
      ntop->getTrace()->traceEvent(
          TRACE_ERROR, "Unable to set tcp keepalive count to %u", val);
    else
      ntop->getTrace()->traceEvent(TRACE_INFO,
                                   "TCP keepalive count set to %u", val);

    val = DEFAULT_ZMQ_TCP_KEEPALIVE_INTVL;
    if (zmq_setsockopt(flow_publisher, ZMQ_TCP_KEEPALIVE_INTVL, &val,
                       sizeof(val)) != 0)
      ntop->getTrace()->traceEvent(
          TRACE_ERROR, "Unable to set tcp keepalive interval to %u seconds",
          val);
    else
      ntop->getTrace()->traceEvent(
          TRACE_INFO, "TCP keepalive interval set to %u seconds", val);
  }

};

/* *********************************************************** */

/**
 * Destructor.
 */
ZMQPublisher::~ZMQPublisher() {
  zmq_close(flow_publisher);
  zmq_ctx_destroy(context);
}

/* *********************************************************** */

#if ZMQ_VERSION >= ZMQ_MAKE_VERSION(4, 1, 0)
int ZMQPublisher::setEncryptionKey(const char *server_public_key) {
  char client_public_key[41];
  char client_secret_key[41];
  int rc;

  rc = zmq_curve_keypair(client_public_key, client_secret_key);

  if (rc != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Error generating ZMQ client key pair");
    return (-3);
  }

  if (strlen(server_public_key) != 40) {
    ntop->getTrace()->traceEvent(
        TRACE_ERROR, "Bad ZMQ server public key size (%lu != 40) '%s'",
        strlen(server_public_key), server_public_key);
    return (-3);
  }

  rc = zmq_setsockopt(flow_publisher, ZMQ_CURVE_SERVERKEY, server_public_key,
                      strlen(server_public_key) + 1);

  if (rc != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Error setting ZMQ_CURVE_SERVERKEY = %s (%d)",
                                 server_public_key, errno);
    return (-3);
  }

  rc = zmq_setsockopt(flow_publisher, ZMQ_CURVE_PUBLICKEY, client_public_key,
                      strlen(client_public_key) + 1);

  if (rc != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Error setting ZMQ_CURVE_PUBLICKEY = %s",
                                 client_public_key);
    return (-3);
  }

  rc = zmq_setsockopt(flow_publisher, ZMQ_CURVE_SECRETKEY, client_secret_key,
                      strlen(client_secret_key) + 1);

  if (rc != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Error setting ZMQ_CURVE_SECRETKEY = %s",
                                 client_secret_key);
    return (-3);
  }

  return (0);
}
#endif

/* *********************************************************** */

/**
 * Sends a message on ZMQ, encoding and compressing it.
 * @param str The message.
 */
bool ZMQPublisher::sendMessage(const char *topic, char *str) {
  struct zmq_msg_hdr_v1 msg_hdr;
  int len = strlen(str), rc;
#ifdef HAVE_ZLIB
  char *compressed;
#endif

  ntop->getTrace()->traceEvent(TRACE_INFO, "Sending msg on topic '%s' [%s]",
                               topic, str);

  snprintf(msg_hdr.url, sizeof(msg_hdr.url), "%s", topic);

#ifdef HAVE_ZLIB
  if ((compressed = (char *)malloc(len + 16)) != NULL) {
    uLongf complen = len + 14;
    int err;

    if ((err = compress((Byte *)&compressed[1], &complen, (Byte *)str, len)) !=
        Z_OK) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "compress error [%d][%s]", err,
                                   str);
      /* Continue with plain json */
    } else {
      // ntop->getTrace()->traceEvent(TRACE_ERROR, "%u -> %u [%d %%]", len,
      // complen, 100-((100*complen)/len));
      bool ret;

      compressed[0] = 0; /* 1st byte = 0 means compressed */
      msg_hdr.version = 0, msg_hdr.size = complen + 1;
      err = zmq_send(flow_publisher, &msg_hdr, sizeof(msg_hdr), ZMQ_SNDMORE);
      if (err >= 0) err = zmq_send(flow_publisher, compressed, msg_hdr.size, 0);

      if (err >= 0) {
        ntop->getTrace()->traceEvent(TRACE_INFO, "[ZMQ] OK [len: %u]",
                                     msg_hdr.size);
        ret = true;
      } else {
        ntop->getTrace()->traceEvent(TRACE_WARNING, "zmq_send error %d [%d]",
                                     err, errno);
        ret = false;
      }

      free(compressed);
      return (ret);
    }
  }
#endif

  msg_hdr.version = 0, msg_hdr.size = len;
  rc = zmq_send(flow_publisher, &msg_hdr, sizeof(msg_hdr), ZMQ_SNDMORE);
  rc = zmq_send(flow_publisher, str, msg_hdr.size, 0);

  if (rc <= 0)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "[ZMQ] rc=%d - errno=%d/%s", rc,
                                 errno, strerror(errno));
  else
    ntop->getTrace()->traceEvent(TRACE_INFO, "[ZMQ] OK [len: %u]",
                                 msg_hdr.size);

  return ((rc == -1) ? false : true);
}

#endif /* HAVE_NEDGE */
