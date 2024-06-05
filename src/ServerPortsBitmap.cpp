/*
 *
 * (C) 2013-24 - ntop.org
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#include "ntop_includes.h"

/* *************************************** */

ServerPortsBitmap::ServerPortsBitmap() {
  if((tcp_bitmap = ndpi_bitmap_alloc()) == NULL)
    throw("Out of memory");

  if((udp_bitmap = ndpi_bitmap_alloc()) == NULL)
    throw("Out of memory");
}

/* *************************************** */

ServerPortsBitmap::~ServerPortsBitmap() {
  if(tcp_bitmap) ndpi_bitmap_free(tcp_bitmap);
  if(udp_bitmap) ndpi_bitmap_free(udp_bitmap);
}

/* *************************************** */

const char* ServerPortsBitmap::bitmap_serialize(ndpi_bitmap* port_bitmap) {
  char *buf, *ret;
  size_t len = ndpi_bitmap_serialize(port_bitmap, &buf);

  if(buf != NULL) {
    ret = ndpi_base64_encode((const u_char*)buf, len);
    ndpi_free(buf);
    return(ret);
  } else
    return(NULL);
}

/* *************************************** */

void ServerPortsBitmap::bitmap_deserialize(const char* tcp_str, const char* udp_str) {
  size_t tcp_bitmap_len, udp_bitmap_len;
  u_char *tcp_bitmap_str, *udp_bitmap_str;

  if((tcp_bitmap_str = ndpi_base64_decode((const u_char*)tcp_str, strlen(tcp_str), &tcp_bitmap_len)) != NULL) {
    ndpi_bitmap_free(tcp_bitmap); /* Free the old bitmap */
    tcp_bitmap = ndpi_bitmap_deserialize((char*)tcp_bitmap_str, tcp_bitmap_len);
    free(tcp_bitmap_str);
  }

  if((udp_bitmap_str = ndpi_base64_decode((const u_char*)udp_str, strlen(udp_str), &udp_bitmap_len)) != NULL) {
    ndpi_bitmap_free(udp_bitmap); /* Free the old bitmap */
    udp_bitmap = ndpi_bitmap_deserialize((char*)udp_bitmap_str, udp_bitmap_len);
    free(udp_bitmap_str);
  }
}

/* *************************************** */

const char* ServerPortsBitmap::serializer() {
  const char *bitmap_str_tcp, *bitmap_str_udp;
  ndpi_serializer serializer;
  u_int32_t buflen;
  const char *ser;

  if (ndpi_init_serializer(&serializer, ndpi_serialization_format_json) == -1) {
    return NULL;
  }

  bitmap_str_tcp = bitmap_serialize(tcp_bitmap);
  if(bitmap_str_tcp != NULL) {
    ndpi_serialize_string_string(&serializer, "tcp", bitmap_str_tcp);
    ndpi_free((void*)bitmap_str_tcp);
  }

  bitmap_str_udp = bitmap_serialize(udp_bitmap);
  if(bitmap_str_udp != NULL) {
    ndpi_serialize_string_string(&serializer, "udp", bitmap_str_udp);
    ndpi_free((void*)bitmap_str_udp);
  }

  ser = ndpi_strdup(ndpi_serializer_get_buffer(&serializer, &buflen));

  ndpi_term_serializer(&serializer);

  return(ser);
}

/* *************************************** */

bool ServerPortsBitmap::deserializer(const char* json_str) {
  enum json_tokener_error jerr = json_tokener_success;
  json_object *json_obj, *udp_str, *tcp_str;

  if ((json_obj = json_tokener_parse_verbose(json_str, &jerr)) == NULL)
    return false;

  const char* bitmap_str_tcp;
  const char* bitmap_str_udp;

  if(json_object_object_get_ex(json_obj, "tcp", &tcp_str) &&
          json_object_object_get_ex(json_obj, "udp", &udp_str)) {
    bitmap_str_tcp = json_object_get_string(tcp_str);
    bitmap_str_udp = json_object_get_string(udp_str);
  } else
    return false;

  bitmap_deserialize(bitmap_str_tcp, bitmap_str_udp);

  json_object_put(json_obj);

  return true;
}
