---
title: "Running ntopng as a Daemon"
description: "Ntopng can be run in daemon mode on Unix systems and optionally be run automatically on system startup. Daemon execution and status are controlled with..."
outline: [2, 3]
lastUpdated: 2025-04-24T12:47:34+02:00
---
# Running ntopng as a Daemon {#running-ntopng-as-a-daemon}

Ntopng can be run in daemon mode on Unix systems and optionally be run automatically on system startup. Daemon execution and status are controlled with systemd using the `systemctl` script.
The systemd script is installed automatically on Unix systems as it is part of any standard ntopng installation procedure.

## Daemon Configuration File {#daemon-configuration-file}

Ntopng configuration file is required when running it as a daemon. The configuration file has to be named `ntopng.conf` and must be placed under `/etc/ntopng/`. The interested reader can find above and example of a configuration file. A default configuration file is created by default when installing ntopng from any binary package.

## Automatic Daemon Startup on Boot {#automatic-daemon-startup-on-boot}

In order to launch ntopng daemon automatically on system startup, an empty file ntopng.start must be created in the same directory of the configuration files. Therefore, the directory will contain both the configuration and the startup files

```bash
root@devel:/etc/ntopng$ ls -lha
total 28K
drwxr-xr-x   2 root root 4.0K Mar 17 15:44 .
drwxr-xr-x 117 root root  12K Mar 11 12:16 ..
-rw-r--r--   1 root root  211 Mar 15 17:54 ntopng.conf
-rw-r--r--   1 root root    0 Mar 17 15:44 ntopng.start
```

The existence of the `ntopng.start` file is no longer required on systems that have systemd. On those systems, automatic ntopng daemon startup is controlled by enabling/disabling the ntopng service as

```bash
systemctl enable ntopng
systemctl disable ntopng
```

## Daemon Control {#daemon-control}

On Unix systems the ntopng daemon can be controlled with systemd using the `systemctl` tool. All the standard options are accepted. The options and the usage of the daemon control script are discussed below.

### start {#start}

This option is used to start the ntopng daemon

```bash
systemctl start ntopng
```

### stop {#stop}

This option is used to stop an ntopng daemon instance. For example

```bash
systemctl stop ntopng
```

### restart {#restart}

This option causes the restart of the ntopng instance.

```bash
systemctl restart ntopng
```

### status {#status}

This options prints the status of the ntopng daemon.

```bash
systemctl status ntopng
```

## Running Multiple Daemons {#running-multiple-daemons}

Multiple ntopng daemons can be run on the same machine when
`systemd` is available. In general, this is not necessary as a
single ntopng is multi-tenant and can handle multiple
interfaces. However, there are circumstances under which it is
desirable to have multiple ntopng instances running.

To run multiple ntopng daemons, `systemctl` can be used. Each
daemon is identified by a `<name>` so that `systemctl` can
be used with this identifier when controlling the daemon. For example:

```bash
systemctl start ntopng@eno1
systemctl stop ntopng@eno1
systemctl start ntopng@lo
systemctl stop ntopng@lo
```

Each daemon must have its own configuration file under
`/etc/ntopng` and the configuration file name must be named as
`ntopng-<name>.conf`. The example above assumes two files
`ntopng-eno1.conf` and `ntopng-lo.conf` exist under
`/etc/ntopng`.

In order to run multiple daemons on the same machine, each daemon
must be guaranteed to have its own Redis database (option `-r`), its
own HTTP/HTTPS ports (options `-w` and `-W`), and its own
data directory (option `-d`). Those options must be specified in
each daemon's configuration file.

In order to start daemons on boot, it is necessary to enable them as

```bash
systemctl enable ntopng@eno1
systemctl enable ntopng@eno1
```

Daemons which have been `enable` d, will be automatically
restarted after each ntopng update. Note that backup and restore of
ntopng configuration is not supported when multiple daemons are in use.

## Accessing ntopng behind a Reverse Proxy {#accessing-ntopng-behind-a-reverse-proxy}

If you have many ntopng instances that you want to mask behind a proxy the
`-Z` option is what you look for. See the man page for more information.

## Using ntopng with a HTTP(S) Proxy {#using-ntopng-with-a-http-s-proxy}

If ntopng is behind a proxy which is used to access the Internet, proxy information
should be configured into standard environment variables to let ntopng detect them
and connect to the internet (e.g. for downloading blacklists). Both HTTP and HTTPS
are supported.

```bash
export HTTP_PROXY=http://127.0.0.1:3128
ntopng -i eth0
```

When ntopng runs as a service from systemd, environment variables should be configured
in /etc/systemd/system.conf as below:

```text
DefaultEnvironment="http_proxy=http://127.0.0.1:3128"
DefaultEnvironment="https_proxy=http://127.0.0.1:3128"
```

Then run systemctl daemon-reexec to apply the change:

```bash
sudo systemctl daemon-reexec
```

Alternatively, proxy information can be added the the ntopng service only
by configuring /etc/systemd/system/ntopng.service as below:

```text
[Service]
Type=simple
Environment="http_proxy=http://127.0.0.1:3128"
Environment="https_proxy=http://127.0.0.1:3128"
```

Then run systemctl daemon-reload to apply the change

```bash
sudo systemctl daemon-reload
```

Then restart ntopng

```bash
sudo systemctl restart ntopng
```
