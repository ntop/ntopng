---
title: "How to Start ntopng"
description: "ntopng can be started from the command line of your favorite Linux, Unix and Windows system. When starting ntopng it is possible to modify its behavior by..."
outline: [2, 3]
lastUpdated: 2018-03-28T15:30:04+02:00
---
# How to Start ntopng {#how-to-start-ntopng}

ntopng can be started from the command line of your favorite Linux, Unix and Windows system. When starting ntopng it is possible to modify its behavior by customizing one or more of the several optional settings available, using either the command line, or grouping them in a configuration file. Configuration files as well as option settings can be given as input to the ntopng executable.

```bash
ntopng <configuration file path>
ntopng <command line options>
```

- [The ntopng Configuration File](/how_to_start/configuration_file.md)
  - [Configuration Changes](/how_to_start/configuration_file.md#configuration-changes)
- [Running ntopng as a Daemon](/how_to_start/running_as_a_daemon.md)
  - [Daemon Configuration File](/how_to_start/running_as_a_daemon.md#daemon-configuration-file)
  - [Automatic Daemon Startup on Boot](/how_to_start/running_as_a_daemon.md#automatic-daemon-startup-on-boot)
  - [Daemon Control](/how_to_start/running_as_a_daemon.md#daemon-control)
  - [Running Multiple Daemons](/how_to_start/running_as_a_daemon.md#running-multiple-daemons)
  - [Accessing ntopng behind a Reverse Proxy](/how_to_start/running_as_a_daemon.md#accessing-ntopng-behind-a-reverse-proxy)
  - [Using ntopng with a HTTP(S) Proxy](/how_to_start/running_as_a_daemon.md#using-ntopng-with-a-http-s-proxy)
- [Running on Windows](/how_to_start/running_on_windows.md)
  - [List Monitored Interfaces](/how_to_start/running_on_windows.md#list-monitored-interfaces)
  - [Manipulating ntopng Windows Service Settings](/how_to_start/running_on_windows.md#manipulating-ntopng-windows-service-settings)
  - [Troubleshooting](/how_to_start/running_on_windows.md#troubleshooting)


Section [Command Line Options](/cli_options/cli_options.md#clioptions) of this guide thoroughly discuss any available options.
