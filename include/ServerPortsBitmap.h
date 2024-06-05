#ifndef _SERVER_PORTS_BITMAP_H_
#define _SERVER_PORTS_BITMAP_H_

#include "ntop_includes.h"

class ServerPortsBitmap {
 private:
  ndpi_bitmap *tcp_bitmap, *udp_bitmap;
  const char* bitmap_serialize(ndpi_bitmap* bitmap);
  void bitmap_deserialize(const char* tcp_str, const char* udp_str);

 public:
  ServerPortsBitmap();
  ~ServerPortsBitmap();

  inline void addPort(bool isTCP, u_int16_t port) { ndpi_bitmap_set((isTCP ? tcp_bitmap : udp_bitmap), port); };
  const char* serializer();
  bool deserializer(const char* json_str);
};

#endif /*_SERVER_PORTS_BITMAP_H_*/
