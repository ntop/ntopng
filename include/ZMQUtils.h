/*
 *
 * (C) 2019-23 - ntop.org
 *
 *  http://www.ntop.org/
 *
 * This code is proprietary code subject to the terms and conditions
 * defined in LICENSE file which is part of this source code package.
 *
 */

#include "ntop_includes.h"

#ifndef _ZMQ_UTILS_H_
#define _ZMQ_UTILS_H_

#ifndef HAVE_NEDGE

#ifdef HAVE_ZMQ

class ZMQUtils {
 private:

 public:
  static void setKeepalive(void *zmq_socket);
#if ZMQ_VERSION >= ZMQ_MAKE_VERSION(4, 1, 0)
  static int setServerEncryptionKeys(void *zmq_socket, const char *secret_key);
  static int setClientEncryptionKeys(void *zmq_socket, const char *server_public_key);
  static bool readEncryptionKeysFromFile(char *public_key_path, char *secret_key_path,
    char *public_key, char *secret_key, int public_key_len, int secret_key_len);
  static void generateEncryptionKeys();
  static char *findEncryptionKeys(char *public_key, char *secret_key, int public_key_len, int secret_key_len);
#endif
};

#endif /* HAVE_ZMQ */
#endif /* HAVE_NEDGE */
#endif /* _ZMQ_UTILS_H_ */
