## Introduction

New privacy regulations, such as GDPR and CCPA, place restrictions that impact our ability to continue distributing MaxMind GeoLite2 databases in the public `ntopng-data` package. Reasons are explained in detail at the following page https://blog.maxmind.com/2019/12/18/significant-changes-to-accessing-and-using-geolite2-databases/

Starting December 30, 2019, to continue using geolocation in `ntopng`, you are required to register for a MaxMind account and obtain a license key in order to download GeoLite2 geolocation databases.

## Using geolocation in ntopng

The following section lists all the steps which are necessary to use geolocation in ntopng.

0. Install package `geoipupdate`
1. Register for a MaxMind account at https://www.maxmind.com/en/geolite2/signup
2. Create a license key at https://www.maxmind.com/en/accounts/current/license-key
    1. Select "Generate New License Key"
    2. Add a license key description and answer "Yes" to the question "Will this key be used for GeoIP Update?"
    3. Then choose one of the two available options "Generate a license key and config file". Choice depends on the installed `geoipupdate` version. Most likely, installed version is older than 3.1.1 so the correct option to select is "Generate a license key and config file for use with `geoipupdate` versions older than 3.1.1".
3. Once the license is created, you will be promted to download file `GeoIP.conf` which contains account id and license key necessary to download the databases. Download and place this file in `/etc/GeoIP.conf`.
4. Run `sudo geoipupdate` to download the database files
5. Restart ntopng. Upon restart, ntopng will automatically locate and load the downloaded databases.

Additional instructions to use `geoipupdate` are available at https://dev.maxmind.com/geoip/geoipupdate/

In case package `geoipupdate` is not available on your platform:

0. Manually download database files `GeoLite2-ASN.mmdb` and `GeoLite2-City.mmdb` from the download section of your MaxMind account page
1. Place downloaded files under `/var/lib/GeoIP/` or `/usr/share/GeoIP/`.
