/*
 *
 * (C) 2019-24 - ntop.org
 *
 * This code is proprietary code subject to the terms and conditions
 * defined in LICENSE file which is part of this source code package.
 *
 */

#include "ntop_includes.h"


#ifdef HAVE_ZMQ
#ifndef HAVE_NEDGE

/* *********************************************************** */

/**
 * Constructor: initializes ZMQ sockets.
 * @param endpoint The ZMQ endpoint.
 */
ZMQPublisher::ZMQPublisher(char *endpoint) {
  if(trace_new_delete) ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);
  
  server_secret_key[0] = '\0';
  server_public_key[0] = '\0';

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
  pub_socket = zmq_socket(context, ZMQ_PUB);

  if (pub_socket == NULL) {
    ntop->getTrace()->traceEvent(
        TRACE_ERROR, "Unable to initialize ZMQ %s (pub_socket)",
        endpoint);
    throw "Unable to initialize ZMQ (pub_socket)";
  }

  if (ntop->getPrefs()->is_zmq_encryption_enabled()) {
#if ZMQ_VERSION >= ZMQ_MAKE_VERSION(4, 1, 0)
    const char *secret_key;
    if (ntop->getPrefs()->get_zmq_encryption_priv_key() == NULL)
      ZMQUtils::generateEncryptionKeys();

    secret_key = ZMQUtils::findEncryptionKeys(server_public_key, server_secret_key,
      sizeof(server_public_key), sizeof(server_secret_key));

    if (secret_key != NULL) {
      if (ZMQUtils::setServerEncryptionKeys(pub_socket, secret_key) < 0)
        throw "Unable to set ZMQ encryption";
    }
#else
    ntop->getTrace()->traceEvent(TRACE_ERROR,
        "Unable to enable ZMQ CURVE encryption, ZMQ >= 4.1 is required");
#endif
  }

  if (zmq_bind(pub_socket, endpoint) != 0) {
    zmq_close(pub_socket);
    zmq_ctx_destroy(context);
    ntop->getTrace()->traceEvent(
        TRACE_ERROR, "Unable to connect to ZMQ endpoint %s", endpoint);
    throw("Unable to connect to the specified ZMQ endpoint");
  }

  if (strncmp(endpoint, (char *)"tcp://", 6) == 0) {
    /* TCP socket optimizations */
    ZMQUtils::setKeepalive(pub_socket);
  }

};

/* *********************************************************** */

/**
 * Destructor.
 */
ZMQPublisher::~ZMQPublisher() {
  zmq_close(pub_socket);
  zmq_ctx_destroy(context);
}

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
      err = zmq_send(pub_socket, &msg_hdr, sizeof(msg_hdr), ZMQ_SNDMORE);
      if (err >= 0) err = zmq_send(pub_socket, compressed, msg_hdr.size, 0);

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
  rc = zmq_send(pub_socket, &msg_hdr, sizeof(msg_hdr), ZMQ_SNDMORE);
  rc = zmq_send(pub_socket, str, msg_hdr.size, 0);

  if (rc <= 0)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "[ZMQ] rc=%d - errno=%d/%s", rc,
                                 errno, strerror(errno));
  else
    ntop->getTrace()->traceEvent(TRACE_INFO, "[ZMQ] OK [len: %u]",
                                 msg_hdr.size);

  return ((rc == -1) ? false : true);
}

#endif /* HAVE_NEDGE */
#endif
