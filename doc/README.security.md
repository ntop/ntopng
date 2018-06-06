After a fresh install, ntopng will run using a default, basic
configuration. Such configuration is meant to provide an
up-and-running ntopng but does not try to secure it. Therefore, the
default configuration should only be used for testing purposes in
non-production environments.

Several things are required to secure ntopng and make it
enterprise-proof. Those things include, but are not limited to,
enabling an encrypted web access, restricting the web server access,
and protecting the Redis server used by ntopng as a cache.

Here is the list of things required to secure ntopng.

# Encrypted Web Access

By default, ntopng runs an HTTP server on port 3000. In production, it
is recommended to disable HTTP and only leave HTTPS. To disable HTTP
and enable HTTPS on port 443 the following options suffice:

```
--http-port=0
--https-port=443
```

Enabling HTTPS ntopng requires ntopng to be able to use a certificate
and a private key for the encryption. Generation instruction are
available in [README.SSL](./README.SSL).


# Restrict Web Server Listening Address

ntopng embedded web server listens on any address by default. This
means that anyone who has IP-reachability of the ntopng host can be
served with web contents by the server. That does not imply anyone can
access the ntopng web GUI -- login credentials are required for the
GUI -- but it is never a good idea to leave a remote web server
exposed also to those that should not be entitled to have access to ntopng.

The listening address can be changed from `any` to another custom address
that can be an IP address of an host interface, or just the loopback
address `127.0.0.1`.

Listening address changes are indicated using a couple of ntopng
configuration options, namely `--http-port` for HTTP and
`--https-port` for HTTPS. For example to change the HTTP server
listening address to only `127.0.0.1` and the listening address of the
HTTPS server to `192.168.2.222`, the following options can be used:

```
--http-port=:3000
--https-port=192.168.2.222:3001
```

The listening addresses can easily be verified with `netstat` on unix.
The any address is indicated with `0.0.0.0`.

This is the `netstat` output when the HTTP and the HTTPS servers are
listening on the `any` addresses.

```
simone@devel:~$ sudo netstat -polenta | grep 300
tcp        0      0 0.0.0.0:3000            0.0.0.0:*
LISTEN      65534      67324991    5480/ntopng      off (0.00/0/0)
tcp        0      0 0.0.0.0:3001            0.0.0.0:*
LISTEN      65534      67324992    5480/ntopng      off (0.00/0/0)
```

This is the `netstat` output after the changes highlighted in the
example above. The `any` address is no longer listed.

```
simone@devel:~$ sudo netstat -polenta | grep 300
tcp        0      0 127.0.0.1:3000          0.0.0.0:*
LISTEN      65534      67323743    5808/ntopng      off (0.00/0/0)
tcp        0      0 192.168.2.222:3001      0.0.0.0:*
LISTEN      65534      67323744    5808/ntopng      off (0.00/0/0)
```


# Protected Redis Server Access

## Password-Protected Redis Server

ntopng uses Redis as a cache for DNS names and other values. The Redis
server by default listens only on the loopback address `127.0.0.1` but
it is accessible without passwords.

To secure the Redis server with a password, uncommend the
`requirepass` line of the Redis configuration file and specify a
secure (very long) password here.

```
simone@devel:~/ntopng$ sudo cat /etc/redis/redis.conf | grep requirepass
requirepass verylongredispassword
```

Once the password is set and the Redis server service has been
restarted, the ntopng `--redis` option can be used to specify the
password. To use the `verylongredispassword` in ntopng it suffices to
use the following option:

```
--redis=127.0.0.1:6379:verylongredispassword
```

## Redis Server Access via Local Unix Socket Files

Another way to secure the Redis server is to configure it to only
accept connections via a local unix socket file, rather than on any
TCP socket.

The relevant part of the Redis configuration to use just a local unix
socket file is the following:

```
# 0 = Redis will not listen on a TCP socket
port 0

# Create a unix domain socket to listen on
unixsocket /var/run/redis/redis.sock
```

To tell ntopng to use the Redis unix socket file the same `--redis`
option can be used as:

```
--redis=/var/run/redis/redis.sock
```


# ntopng User with Limited Privileges

ntopng runs with user `nobody` by default. That user is meant to
represent the user with the least permissions on the system.
It is recommended to create another user `ntopng` to run ntopng with
so that even if there are other daemons running as `nobody`, none of
them will ever be able to access files and data created by ntopng.

To run ntopng with another user just use option `--user`. For example
to run ntopng with user `ntopng` specify:

```
--user=ntopng
```
