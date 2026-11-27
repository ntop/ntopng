---
title: "Connect to ClickHouse"
description: "In order to connect ntopng to ClickHouse use option -F. The format of this option is the following"
outline: [2, 3]
lastUpdated: 2026-07-10T11:41:53+02:00
---
# Connect to ClickHouse {#connect-to-clickhouse}

In order to connect ntopng to ClickHouse use option `-F`. The format of this option is the following

```bash
clickhouse;<host[@<tcp-port>,<mysql-port>]|unix-socket>;<dbname>;<user>;<pw>
```

or

```bash
clickhouse-cluster;<host[@<tcp-port>,<mysql-port>]|socket>;<dbname>;<user>;<pw>;<cluster name>
```

Where

- `<host[@mysqlport]|socket>` Specifies the database `host` or a `socket` file. By default, port `9000` is used for the connection via native API and `9004` for connection over MySQL API. To use a different port, specify it with `@TCP_PORT,MYSQL_PORT`. The host can be a symbolic name or an IP address. By default ntopng connects in clear text, this unless you want to do it over TLS and in this case you need to append a 's' after the port. Example `192.168.2.1@9000,9004s`. Please see later in this pare more information about TLS connections.
- `<dbname>` Specifies the name of the database to be used and defaults to `ntopng`
- `<user>` Specifies an user with read and write permissions on `<dbname>`
- `<pw>` Specifies the password that authenticates `<user>`
- `<cluster name>` Specifies the name of the ClickHouse cluster `<user>`

If you use a stand-alone ClickHouse database you need to use `-F clickhouse;....` whereas with a cluster you need to use `-F clickhouse-cluster;....`

## Example {#example}

To connect ntopng and ClickHouse, both running on the same machine, the following line can be used

```bash
ntopng -F "clickhouse;127.0.0.1;ntopng;default;default"
```

In the example above, `127.0.0.1` is used to connect using IPv4 (using the symbolic string `localhost` could resolve to an IPv6 address). A user `default`, identified with password `default`, with read and write permissions on database `ntopng` is indicated as well. As shortcut you can use `-F clickhouse` for `F="clickhouse;127.0.0.1;ntopng;default;default"`

The above example with a ClickHouse cluster would be:

```bash
ntopng -F "clickhouse-cluster;127.0.0.1;ntopng;default;default;ntop_cluster"
```

## What's Stored in ClickHouse {#what-s-stored-in-clickhouse}

ntopng stores both historical flows and alerts in ClickHouse.

IPv4 and IPv6 flows are stored in table `flows`. A column `INTERFACE_ID` is used to identify the interface on which the flow was seen, this is useful ntopng is monitoring multiple interfaces (see `-i`).

Alerts are stored in several tables, all ending with suffix `_alerts`. The table prefix indicates the alert family, e.g. `host_alerts` table contains alerts for hosts, `flow_alerts` table contains alerts for flows, and so on.

For more information, check the [ntopng database schema](https://github.com/ntop/ntopng/blob/dev/httpdocs/misc/db_schema_clickhouse.sql).

## TLS Connection {#tls-connection}

In order to connect ntopng with ClickHouse using a secure TCP connection, first, create the server certificate with the following command:

```bash
openssl req -subj "/CN=localhost" -new -newkey rsa:2048 -days 365 -nodes -x509 -keyout /etc/clickhouse-server/server.key -out /etc/clickhouse-server/server.crt
```

This command generates a server certificate for secure communication between ntopng and ClickHouse, establishing a secure TCP connection.

::: info
To enable the ClickHouse user to use the `server.crt` and `server.key` files, it is necessary to change their owner.
Run the following command as a superuser to grant the required permissions:
:::

```bash
chown clickhouse:clickhouse /etc/clickhouse-server/server.key /etc/clickhouse-server/server.crt
```

Open the ClickHouse config.xml file and uncomment the following lines:

- `<!--<tcp_port_secure>9440</tcp_port_secure>-->`
- `<!--<certificateFile>/etc/clickhouse-server/server.crt</certificateFile>-->`
- `<!--<privateKeyFile>/etc/clickhouse-server/server.key</privateKeyFile>-->`

Restart ClickHouse.

Start ntopng using the `-F` option, but in this case, it is mandatory to indicate the database port with an `s` at the end of it.

```bash
clickhouse;<host[@<port>s]>;<dbname>;<user>;<pw>
```

For example:

```bash
ntopng -F "clickhouse;127.0.0.1@9000,9440s;ntopng;default;default`
```

## Securing the Connection in ClickHouse Cloud {#securing-the-connection-in-clickhouse-cloud}

To secure the connection in ClickHouse Cloud, instead, the only thing to configure is adding the `s` character in the `-F` option after the ports list, when starting ntopng (or in the configuration file),
without needing to configure anything else.
For example:

```bash
ntopng -F "clickhouse-cloud;127.0.0.1@9440,3306s;ntopng;default,default;default`
```

::: info
Securing the connection when using ClickHouse Cloud is highly recommended,
moreover ClickHouse Cloud by default only accepts secured connections
:::

## Server Certificate Verification {#server-certificate-verification}

When the host used to connect (see `-F`) does not match the Common Name (CN) of the ClickHouse server certificate, TLS verification fails. Use `--clickhouse-server-cn` to explicitly indicate the name to expect in the certificate:

```bash
ntopng -F "clickhouse;clickhouse.host@9000,9440s;ntopng;default;default" --clickhouse-server-cn clickhouse.example.org
```

## Mutual TLS (mTLS) {#mutual-tls-mtls}

ntopng can also authenticate itself to the ClickHouse server using a client certificate, in addition to the usual username/password authentication. This requires setting both `--clickhouse-client-cert` and `--clickhouse-client-key` to PEM-encoded files:

```bash
ntopng -F "clickhouse;127.0.0.1@9000,9440s;ntopng;default;default" --clickhouse-client-cert /etc/ntopng/clickhouse-client.crt --clickhouse-client-key /etc/ntopng/clickhouse-client.key
```

Both options must be set together.

::: info
The private key file must be unencrypted (no passphrase).
:::

Note that the ClickHouse server should also be configured (in `config.xml`, under the `<openSSL><server>` section) to request or require a client certificate, and optionally to map the certificate to a user via `<ssl_certificates>`. Otherwise, mTLS is only used for transport security while user/password authentication is still performed as usual.

## Strict Startup {#strict-startup}

By default, if ntopng fails to connect to ClickHouse at startup, it logs an error and continues running without ClickHouse support. To change this behaviour and force ntopng to exit when the ClickHouse connection cannot be established, use the `--strict-startup` option.
Example:

```bash
ntopng -F "clickhouse" --strict-startup
```

When `--strict-startup` is set and ClickHouse fails to initialize (e.g. the service is down), ntopng prints an error and terminates immediately.
This is particularly useful in production deployments where running without ClickHouse is not acceptable and a hard failure is preferable to silent data loss.

In any case, in case of runtime failures with the ClickHouse connection, ntopng keeps running and the connection is automatically restored when connectivity comes back.
