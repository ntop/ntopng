Introduction
------------

VyOS (https://www.vyos.io) is a popular open-source router and firewall platform based on Linux.


Prerequisites
-------------
As VyOS is based on Debian Linux, the easiest solution is to install precompiled Debian packages or compile it from source. 

In order to do this you need to configure the Debian repositories that on VyOS are empty. You need (as root) to edit ``/etc/apt/sources.list`` and store on it something like this:


```
deb http://mi.mirror.garr.it/mirrors/debian/ jessie main
deb-src http://mi.mirror.garr.it/mirrors/debian/ jessie main

deb http://archive.debian.org/debian jessie-backports main

deb http://security.debian.org/ jessie/updates main
deb-src http://security.debian.org/ jessie/updates main

# jessie-updates, previously known as 'volatile'
deb http://mi.mirror.garr.it/mirrors/debian/ jessie-updates main
deb-src http://mi.mirror.garr.it/mirrors/debian/ jessie-updates main
```

As of today, we are using VyOS 1.2.x that is based on Debian 8 (jessie). For different VyOS versions you might need to use a different Debian version that you can find out running the following command

```
root@vyos:/home/vyos# lsb_release -a
No LSB modules are available.
Distributor ID:	Debian
Description:	Debian GNU/Linux 8.11 (jessie)
Release:	8.11
Codename:	jessie
```

Furthermore please make sure you use the best mirror for your country (in this example we used the Italian Debian mirror).

You are now ready to do

```
apt-get update
```

and your VyOS installation will now look like a Debian box where you can install your favorite packages.

How to install ntopng
---------------------

As this point you have two options. You can:
- compile ntopng from source as explained in https://github.com/ntop/ntopng/blob/dev/doc/README.compilation
- (we suggest this option) install ntop maintained binary packages available at https://packages.ntop.org
for your Debian distribution on top of which VyOS sits.

Installing Additional Packages
------------------------------
Id you decided to use binary packages, you can also install additional ntop packages such as nProbe that
can turn your VyOS router installation in a full fledged DPI-based NetFlow/IPFIX probe or remote probe for a ntopng installation running on a remote server.
