Summary: GeoIP databases for ntopng
Name: ntopng-data
Version: 1.99.150507
Release: 150507
License: GPL
Group: Networking/Utilities
URL: http://www.ntop.org/
Source: ntopng-data-%{version}.tgz
Packager: Luca Deri <deri@ntop.org>
BuildArch: noarch
# Temporary location where the RPM will be built
BuildRoot:  %{_tmppath}/%{name}-%{version}-root
#Requires: ntopng

%description
GeoIP databases for ntopng

%prep
%setup -q

%build

mkdir -p $RPM_BUILD_ROOT/usr/share/ntopng/httpdocs/geoip
cp $RPM_BUILD_DIR/%{name}-%{version}/usr/share/ntopng/httpdocs/geoip/*.dat* $RPM_BUILD_ROOT/usr/share/ntopng/httpdocs/geoip
find $RPM_BUILD_ROOT/usr/share/ntopng/httpdocs/geoip -name "*.gz" |xargs gunzip -f
find $RPM_BUILD_ROOT -name ".svn" | xargs /bin/rm -rf
find $RPM_BUILD_ROOT -name "*~"   | xargs /bin/rm -f
#
DST=$RPM_BUILD_ROOT/usr/ntopng
SRC=$RPM_BUILD_DIR/%{name}-%{version}
# Clean out our build directory
%clean
rm -fr $RPM_BUILD_ROOT

%files
/usr/share/ntopng/httpdocs/geoip/GeoIPASNum.dat
/usr/share/ntopng/httpdocs/geoip/GeoIPASNumv6.dat
/usr/share/ntopng/httpdocs/geoip/GeoLiteCity.dat
/usr/share/ntopng/httpdocs/geoip/GeoLiteCityv6.dat


# Set the default attributes of all of the files specified to have an
# owner and group of root and to inherit the permissions of the file
# itself.
%defattr(-, root, root)

%changelog
* Fri Aug 23 2013 Yuri Francalacci <yuri@ntop.org> 1.0
- Current package version

