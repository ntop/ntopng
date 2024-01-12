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

void ZMQUtils::setKeepalive(void *zmq_socket) {
  int val = DEFAULT_ZMQ_TCP_KEEPALIVE;

  if (zmq_setsockopt(zmq_socket, ZMQ_TCP_KEEPALIVE, &val,
                     sizeof(val)) != 0)
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Unable to set tcp keepalive");
  else
    ntop->getTrace()->traceEvent(TRACE_INFO, "TCP keepalive set");

  val = DEFAULT_ZMQ_TCP_KEEPALIVE_IDLE;
  if (zmq_setsockopt(zmq_socket, ZMQ_TCP_KEEPALIVE_IDLE, &val,
                     sizeof(val)) != 0)
    ntop->getTrace()->traceEvent(
        TRACE_ERROR, "Unable to set tcp keepalive idle to %u seconds", val);
  else
    ntop->getTrace()->traceEvent(
        TRACE_INFO, "TCP keepalive idle set to %u seconds", val);

  val = DEFAULT_ZMQ_TCP_KEEPALIVE_CNT;
  if (zmq_setsockopt(zmq_socket, ZMQ_TCP_KEEPALIVE_CNT, &val,
                     sizeof(val)) != 0)
    ntop->getTrace()->traceEvent(
        TRACE_ERROR, "Unable to set tcp keepalive count to %u", val);
  else
    ntop->getTrace()->traceEvent(TRACE_INFO,
                                 "TCP keepalive count set to %u", val);

  val = DEFAULT_ZMQ_TCP_KEEPALIVE_INTVL;
  if (zmq_setsockopt(zmq_socket, ZMQ_TCP_KEEPALIVE_INTVL, &val,
                     sizeof(val)) != 0)
    ntop->getTrace()->traceEvent(
        TRACE_ERROR, "Unable to set tcp keepalive interval to %u seconds",
        val);
  else
    ntop->getTrace()->traceEvent(
        TRACE_INFO, "TCP keepalive interval set to %u seconds", val);
}

/* *********************************************************** */

#if ZMQ_VERSION >= ZMQ_MAKE_VERSION(4, 1, 0)

bool ZMQUtils::readEncryptionKeysFromFile(char *public_key_path, char *secret_key_path,
    char *public_key,     char *secret_key,
    int   public_key_len, int   secret_key_len) {
  char *tmp_public_key = NULL, *tmp_secret_key = NULL;
  bool rc = false;

  ntop->fixPath(public_key_path);
  ntop->fixPath(secret_key_path);

  if (Utils::file_read(public_key_path, &tmp_public_key) > 0 &&
      Utils::file_read(secret_key_path, &tmp_secret_key) > 0) {
    memcpy(public_key, tmp_public_key, public_key_len - 1);
    memcpy(secret_key, tmp_secret_key, secret_key_len - 1);
    public_key[public_key_len - 1] = '\0';
    secret_key[secret_key_len - 1] = '\0';
    rc = true;
  }

  if (tmp_public_key != NULL) free(tmp_public_key);
  if (tmp_secret_key != NULL) free(tmp_secret_key);

  return rc;
}

/* **************************************************** */

void ZMQUtils::generateEncryptionKeys() {
  char public_key[41], secret_key[41];
  char public_key_path[PATH_MAX], secret_key_path[PATH_MAX];
  bool rc = -1;

  snprintf(public_key_path, sizeof(public_key_path), "%s/zmq-key.pub",
           ntop->get_working_dir());
  snprintf(secret_key_path, sizeof(secret_key_path), "%s/zmq-key.priv",
           ntop->get_working_dir());

  if (readEncryptionKeysFromFile(public_key_path, secret_key_path, public_key, secret_key, sizeof(public_key), sizeof(secret_key))) {
    /* Keys already on file */
    rc = 0;
  }

  if (rc != 0) {
    /* Keys not found, generate keys */
    rc = zmq_curve_keypair(public_key, secret_key);
    if (rc == 0) {
      Utils::file_write(public_key_path, public_key,
                        strlen(public_key));
      Utils::file_write(secret_key_path, secret_key,
                        strlen(secret_key));
    }
  }

  if (rc != 0) 
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Unable to generate ZMQ encryption keys");
}

/* **************************************************** */

char *ZMQUtils::findEncryptionKeys(char *public_key, char *secret_key, int public_key_len, int secret_key_len) {
  char public_key_path[PATH_MAX], secret_key_path[PATH_MAX];
  bool rc = false;

  /* Private key from option */
  if (ntop->getPrefs()->get_zmq_encryption_priv_key()) {
    strncpy(secret_key, ntop->getPrefs()->get_zmq_encryption_priv_key(), secret_key_len - 1);
    secret_key[secret_key_len - 1] = '\0';
    rc = true;
  }

  if (!rc) {
    /* Keys from datadir */
    snprintf(public_key_path, sizeof(public_key_path), "%s/zmq-key.pub",
             ntop->get_working_dir());
    snprintf(secret_key_path, sizeof(secret_key_path), "%s/zmq-key.priv",
             ntop->get_working_dir());
    rc = readEncryptionKeysFromFile(public_key_path, secret_key_path, public_key, secret_key, public_key_len, secret_key_len);
  }

  if (!rc) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Unable to find ZMQ encryption keys");
    return NULL;
  }

  return secret_key;
}

/* *********************************************************** */

int ZMQUtils::setServerEncryptionKeys(void *zmq_socket, const char *secret_key) {
  int val = 1;

  if (strlen(secret_key) != 40) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Bad ZMQ secret key len (%lu != 40)",
                                 strlen(secret_key));
    return -1;
  }

  if (zmq_setsockopt(zmq_socket,
                     ZMQ_CURVE_SERVER, &val, sizeof(val)) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Unable to set ZMQ_CURVE_SERVER");
    return -1;
  }

  if (zmq_setsockopt(zmq_socket,
                     ZMQ_CURVE_SECRETKEY, secret_key, 41) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Unable to set ZMQ_CURVE_SECRETKEY");
    return -1;
  }

  ntop->getTrace()->traceEvent(TRACE_INFO,
                               "ZMQ CURVE encryption enabled");

  return 0;
}

/* *********************************************************** */

int ZMQUtils::setClientEncryptionKeys(void *zmq_socket, const char *server_public_key) {
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

  rc = zmq_setsockopt(zmq_socket, ZMQ_CURVE_SERVERKEY, server_public_key,
                      strlen(server_public_key) + 1);

  if (rc != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Error setting ZMQ_CURVE_SERVERKEY = %s (%d)",
                                 server_public_key, errno);
    return (-3);
  }

  rc = zmq_setsockopt(zmq_socket, ZMQ_CURVE_PUBLICKEY, client_public_key,
                      strlen(client_public_key) + 1);

  if (rc != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Error setting ZMQ_CURVE_PUBLICKEY = %s",
                                 client_public_key);
    return (-3);
  }

  rc = zmq_setsockopt(zmq_socket, ZMQ_CURVE_SECRETKEY, client_secret_key,
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

#endif /* HAVE_NEDGE */
#endif
