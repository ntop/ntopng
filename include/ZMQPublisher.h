/*
 *
 * (C) 2019-21 - ntop.org
 *
 *  http://www.ntop.org/
 *
 * This code is proprietary code subject to the terms and conditions
 * defined in LICENSE file which is part of this source code package.
 *
 */

#include "ntop_includes.h"

/**
 * @file ZMQExporter.h
 *
 * @brief      ZMQPublisher class implementation.
 * @details    ZMQPublisher exports flows in JSON format using a ZMQ socket.
 */

#ifndef _ZMQ_PUBLISHER_H_
#define _ZMQ_PUBLISHER_H_

#define DEFAULT_ZMQ_TCP_KEEPALIVE            1  /* Keepalive ON */
#define DEFAULT_ZMQ_TCP_KEEPALIVE_IDLE       30 /* Keepalive after 30 seconds */
#define DEFAULT_ZMQ_TCP_KEEPALIVE_CNT        3  /* Keepalive send 3 probes */
#define DEFAULT_ZMQ_TCP_KEEPALIVE_INTVL      3  /* Keepalive probes sent every 3 seconds */

class ZMQPublisher {
 private:
  void *context; /**< ZMQ context */
  void *flow_publisher; /**< ZMQ publisher socket */
  char *encryption_key; /**< Encryption key */

#if ZMQ_VERSION >= ZMQ_MAKE_VERSION(4,1,0)
  int setEncryptionKey(const char *server_public_key);
#endif
  void xor_encdec(u_char *data, int data_len, u_char *key);
  bool sendMessage(const char * topic, char * str);

 public:
  ZMQPublisher(char *endpoint, const char *_encryption_key = NULL, const char *server_public_key = NULL);
  ~ZMQPublisher();

  inline bool sendIPSMessage(char *msg) { return(sendMessage("ips", msg)); }
};

#endif /* _ZMQ_PUBLISHER_H_ */


