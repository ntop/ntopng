#ifndef NET_H
#define NET_H

/**
 * Split a host[:port] string into the host name and port number, using a
 * default port if one is not specified.  Outputs host name, and port number.
 *
 * @param input String to be split.
 * @param default_port Port number to use if none is specified in input.
 * @param host Output pointer to char pointer to use for host name.
 * @param port Output pointer to integer to use for port number.
 * @return 1 on successful parsing.
 */
int split_host_port(char *input, int default_port, char **host, int *port);

/**
 * Open a socket for UDP use, binding on the given port.
 *
 * @param port Port to bind to.
 * @return The socket if successfully opened, 0 otherwise.
 */
int open_udp_socket(int port);

/**
 * Send a UDP datagram over a socket.
 *
 * @param buf Conents of datagram
 * @param len Length of datagram
 * @param socket UDP socket to send on
 * @param target_host Host to send to (host name)
 * @param target_port Port to send to
 */
void send_udp_datagram(void *buf, int len, int socket, char *target_host, int target_port);

/**
 * Receive a UDP datagram from a socket.
 *
 * @param buf Output pointer to contents.
 * @param max Maximum size of data to receive (allocated size of buf)
 * @param socket Socket to receive on.
 * @param sender_host Host that datagram came from
 * @param sender_port Port that datagram was sent from
 * @return Size of datagram, or 0 if no datagram was available yet.
 */
int receive_udp_datagram(void *buf, int max, int socket, char **sender_host, int *sender_port);

int input_timeout(int filedes, unsigned int seconds);

#endif
