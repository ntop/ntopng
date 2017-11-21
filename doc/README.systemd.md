ntopng is controlled using utility `systemctl` on operating systems
and distributions that use the `systemd` service manager.

Upon successful package installation, the ntopng service is
automatically started on the loopback interface. The service uses a
configuration file that is located at `/etc/ntopng/ntopng.conf` and
that is populated with some defaults during installation. The
configuration file can be edited and extended with any configuration
option supported by ntopng. A service restart is required after
configuration file modifications.

The ntopng service is always started on boot by default. The service
must be disabled to prevent this behavior.

## The ntopng service configuration file

The configuration file is located at `/etc/ntopng/ntopng.conf`.

## Controlling ntopng

To start, stop and restart the ntopng service type:

```
# systemctl start ntopng
# systemctl stop ntopng
# systemctl restart ntopng
```

To prevent ntopng from starting on boot type:

```
# systemctl disable ntopng
```

To start ntopng on boot, assuming it has previously been disabled,
type:

```
# systemctl enable ntopng
```

To check the status of the service, including its output and PID, type:

```
# systemctl status ntopng
```
