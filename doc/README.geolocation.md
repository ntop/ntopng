## Introduction

New privacy regulations, such as GDPR and CCPA, place restrictions that impact our ability to continue distributing MaxMind GeoLite2 databases in the public `ntopng-data` package. Reasons are explained in detail at the following page https://blog.maxmind.com/2019/12/18/significant-changes-to-accessing-and-using-geolite2-databases/.

Starting December 30, 2019, to continue using geolocation in ntop software, you are required to register for a MaxMind account and obtain a license key in order to download GeoLite2 geolocation databases.

## Using geolocation in ntopng

The following section lists all the steps which are necessary to use geolocation in ntopng.

0. Install package `ntopng-data` which pulls in MaxMind downloader `geoipupdate` as dependency.
1. Register for a MaxMind account at https://www.maxmind.com/en/geolite2/signup.
2. Create a license key at https://www.maxmind.com/en/accounts/current/license-key.
    1. Select "Generate New License Key".
    2. Add a license key description and answer "Yes" to the question "Will this key be used for GeoIP Update?".
    3. Then choose one of the two available options "Generate a license key and config file". Choice depends on the installed `geoipupdate` version. Most likely, installed version is older than 3.1.1 so the correct option to select is "Generate a license key and config file for use with `geoipupdate` versions older than 3.1.1". If you don't know the version type `geoipupdate -V`.
3. Once the license is created, you will be promted to download file `GeoIP.conf` which contains account id and license key necessary to download the databases. Download and place this file in `/etc/GeoIP.conf`.
4. Make sure that the `EditionIDs` section (or `ProductIds` according to the `geoipupdate` version) in `/etc/GeoIP.conf` contains `GeoLite2-Country GeoLite2-City GeoLite2-ASN` (`GeoLite2-ASN` could be missing by default).
5. Run `sudo geoipupdate` to download the database files.
6. Restart any running ntop software. Upon restart, software will automatically locate and load the downloaded databases.

Subsequent updates of the `ntopng-data` package will check for the availability of newer geolocation databases and will possibly update them automatically.

If you prefer to handle updates manually, you may skip `ntopng-data` installation and direcly use `geoipupdate`. Instructions to use `geoipupdate` are available at https://dev.maxmind.com/geoip/geoipupdate/

### Using geolocation when `ntopng-data` is not available

In case package `ntopng-data` or `geoipupdate` is not available on your platform:

0. Manually download database files `GeoLite2-ASN.mmdb` and `GeoLite2-City.mmdb` from the download section of your MaxMind account page
1. Place downloaded files under `/var/lib/GeoIP/` or `/usr/share/GeoIP/`. If on Windows, downloaded files must be placed under `Program Files/ntopng/httpdocs/geoip/`.

### Upgrading from a previous version of `ntopng-data`

In case an old `ntopng-data` package was already installed in the system, you may receive the message _The following packages have been kept back_ with reference to it. 

```
# sudo apt-get update
[...]
Calculating upgrade... Done
The following packages have been kept back:
  ntopng-data
```

This occurs usually on debian because the dependencies have changed on the `ntopng-data` you have installed so that a the package `geoipupdate` must be installed to perform the upgrade. If this case, to resolve it suffices to run

```
sudo apt-get --with-new-pkgs upgrade
```
