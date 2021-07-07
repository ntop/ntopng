## Introduction

ntopng includes Geolocation support provided by the following companies
- MaxMind https://maxmind.com
- DB-IP https://db-ip.com

ntopng geolocation is based on a database file stored locally with no cloud access whatsoever.

You can choose to install the free (albeith not very accurate) GeoIP databases or the commercial ones.
By default the `ntopng-data` includes the DB-IP databases that are released under the Creative Commons Attribution License.

Please install the `ntopng-data` package to enable geolocation in ntopng, this unless you already have geolocation databases installed.

## Using MaxMind geolocation in ntopng

New privacy regulations, such as GDPR and CCPA, place restrictions that impact our ability to continue distributing MaxMind GeoLite2 databases in the public `ntopng-data` package. Reasons are explained in detail at the following page https://blog.maxmind.com/2019/12/18/significant-changes-to-accessing-and-using-geolite2-databases/.

Starting December 30, 2019, to continue using geolocation in ntop software, you are required to register for a MaxMind account and obtain a license key in order to download GeoLite2 geolocation databases.

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

## Using geolocation on Raspberry Pi OS (Raspbian)

Since the `geoipupdate` package is not available on Raspberry Pi, the MaxMind database should be downloaded and installed manually on this platform. Please check the next section for further instructions.

## Using geolocation when `ntopng-data` is not available

In case package `ntopng-data` or `geoipupdate` is not available on your platform:

0. Manually download database files
   - DB-IP: `dbip-city-lite`, `dbip-asn-lite`, and `dbip-country-lite` (https://db-ip.com/db/) databases
   - MaxMind: `GeoLite2-ASN.mmdb` and `GeoLite2-City.mmdb` from the "GeoIP2 / GeoLite2" > "Download Files" section of your MaxMind account page
   
1. Then place the downloaded files under a specifiy folder which depends on the platform:

    - **Linux** (including Raspberry Pi OS): place downloaded files under `/var/lib/GeoIP/` (`/usr/share/GeoIP/` is also a valid path)
    - **Windows**: place downloaded files under `Program Files/ntopng/httpdocs/geoip/`
    - **OS X package**: place downloaded files under `/usr/local/share/ntopng/httpdocs/geoip` (in case the `geoip` folder is missing, it is necessary to create it with `mkdir -p /usr/local/share/ntopng/httpdocs/geoip` before copying the files)

## Upgrading from a previous version of `ntopng-data`

In case an old `ntopng-data` package was already installed in the system, you may receive the message _The following packages have been kept back_ with reference to it. 

```
# sudo apt-get update
[...]
Calculating upgrade... Done
The following packages have been kept back:
  ntopng-data
```

This occurs usually on debian because the dependencies have changed on the `ntopng-data` you have installed so that a the package `geoipupdate` from MaxMind must be installed to perform the upgrade. If this case, to resolve it suffices to run

```
sudo apt-get --with-new-pkgs upgrade
```
