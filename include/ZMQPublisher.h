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

/**
 * @file ZMQPublisher.h
 *
 * @brief      ZMQPublisher class implementation.
 * @details    ZMQPublisher exports events using a ZMQ socket.
 */

#ifndef _ZMQ_PUBLISHER_H_
#define _ZMQ_PUBLISHER_H_

#ifdef HAVE_ZMQ

class ZMQPublisher {
 private:
  void *context; /**< ZMQ context */
  void *pub_socket; /**< ZMQ publisher socket */
  char server_public_key[41];
  char server_secret_key[41];

#if ZMQ_VERSION >= ZMQ_MAKE_VERSION(4, 1, 0)
  int setServerEncryptionKeys(const char *secret_key);
  int setClientEncryptionKeys(const char *server_public_key);
#endif
  bool sendMessage(const char *topic, char *str);

 public:
  ZMQPublisher(char *endpoint);
  ~ZMQPublisher();

  inline bool sendIPSMessage(char *msg)     { return (sendMessage("ips", msg)); }
  inline bool sendControlMessage(char *msg) { return (sendMessage("message", msg)); }
};

#endif /* HAVE_ZMQ */

#endif /* _ZMQ_PUBLISHER_H_ */
