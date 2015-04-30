#
# Spec file: ntopng
%define debug_package %{nil}

#
# Tags: Data Definitions...
Summary: A next generation network packet traffic probe used for high-speed web-based traffic analysis and flow collection.
Name: ntopng
Version: 1.1.99
Release: 8082.44.nst20
License: GPLv3
Group: Applications/Internet
URL: http://www.ntop.org/
Packager: http://www.networksecuritytoolkit.org/
Vendor: NST Project

Source0: ntopng-1.1.99.tar.gz
Source1: nDPI-1.1.99.tar.gz
Source2: nst_export_ip_data.lua
Source3: nst_network_load.lua
Source4: ntopng
Source5: ntopng.conf
Source6: ntopng.service

BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

Requires: GeoIP, glib2, hiredis, libgcc, libpcap, libxml2, nst-systemd-presets, redis, sqlite, zlib
%{systemd_requires}

BuildRequires: gcc, gcc-c++, GeoIP-devel, glib2-devel, hiredis-devel, libpcap-devel, libtool, libxml2-devel, redis, sqlite-devel, wget, zlib-devel
BuildArch: x86_64

%description
ntopng is the next generation version of the original ntop.
It is a network packet traffic probe and collector that renders
network usage graphically, similar to what the popular top Unix
command does. It is based on libpcap and it has been written in a
portable way in order to virtually run on every Unix platform and on
Windows as well.

ntopng is easy to use and suitable for monitoring enterprise network
environments. A web browser is used to navigate through ntopng's
rendered web pages for viewing current traffic information and/or to
get a data dump of the collected network network status and statistics.
In the latter case, ntopng can be seen as a simple RMON-like agent with
an embedded web interface.

ntopng feature highlights:

    * An intuitive web interface sporting numerous visuals and monitoring graphs.
    * Show network traffic and IPv4/IPv6 active hosts.
    * Analyse IP traffic and sort it according to the source/destination.
    * Limited configuration and administration via the web interface.
    * Reduced CPU and memory usage (this varies according to network
      size and traffic).
    * Collection of a large number of hosts and network statistic values.
    * Discover application protocols by leveraging nDPI (i.e., ntop’s Deep
      Packet Inspection Library).
    * Report IP protocol usage sorted by protocol type.

%prep
%setup -q -n %{name}-%{version}

%build

#
# Extract the nDPI source prior to build...
%{__tar} -xzf "%{SOURCE1}";

#
# Set the correct nDPI SVN revision in configure for a non-SVN repo...
#
# ${RELEASE} = "SVNREV.NST_RELEASE", Ex "6728.15.nst18"
pushd nDPI
#
# Generate a 'configure' file...
./autogen.sh;
#
svnver="$(echo %{release} | cut -d . -f 1;)";
#
%{__sed} -i -e 's/^SVN_RELEASE=.*$/SVN_RELEASE='"${svnver}"'/' "configure";
#
# Also set a fake SVN_DATE to the build date of today...
svndate="$(date;)";
%{__sed} -i -e 's/^SVN_DATE=.*$/SVN_DATE='"${svndate}"'/' "configure";
popd

#
# Generate a 'configure' file...
./autogen.sh;

#
# Set the correct ntopng SVN revision in configure for a non-SVN repo...
#
# ${RELEASE} = "SVNREV.NST_RELEASE", Ex "6728.15.nst18"
svnver="$(echo %{release} | cut -d . -f 1;)";
#
%{__sed} -i -e 's/^SVN_RELEASE=.*$/SVN_RELEASE='"${svnver}"'/' "configure";

%{configure}

%install
%{__make};

#
# Make the nDPI ndpiReader network utility with plain output patch...
pushd nDPI/example
%{__make};
popd

#
# Install ntopng...
%{__install} -D --mode 755 "%{name}" "%{buildroot}%{_bindir}/%{name}";

#
# Install ndpiReader...
%{__install} -D --mode 755 "nDPI/example/ndpiReader" "%{buildroot}%{_bindir}/ndpiReader";

#
# Install supporting files...
%{__mkdir_p} "%{buildroot}%{_datadir}/%{name}";
for f in "httpdocs" "scripts"; do
  %{__cp} -a "${f}" "%{buildroot}%{_datadir}/%{name}";
done

#
# Create a 'nDPI' doc directory for inclusion with the ntopng docs...
%{__mkdir_p} "nDPI/nDPI";
for d in nDPI/COPYING nDPI/doc nDPI/INSTALL \
         nDPI/ChangeLog nDPI/README*; do
  %{__cp} -rpf "${d}" "nDPI/nDPI";
done
#
# Remove the large "nDPI_QuickStartGuide.pages" doc - A PDF version is available...
%{__rm} -f "nDPI/nDPI/doc/nDPI_QuickStartGuide.pages";

#
# Create a 'third-party' doc directory for inclusion with the ntopng docs...
%{__mkdir_p} "third-party/third-party";
for d in third-party/README* third-party/LuaJIT-2.0.3/doc; do
  %{__cp} -rpf "${d}" "third-party/third-party";
done

#
# Add the NST 'lua' supporting files...
for l in "%{SOURCE2}" "%{SOURCE3}"; do
  %{__cp} "${l}" "%{buildroot}%{_datadir}/%{name}/scripts/lua";
done

#
# Assume running ntopng for directory: "/usr/share/ntopng" then
# setup GeoIP database paths...
%{__mkdir_p} "%{buildroot}%{_datadir}/%{name}/httpdocs/geoip";
%{__ln_s} "%{_datadir}/GeoIP/GeoIPASNum.dat" "%{buildroot}%{_datadir}/%{name}/httpdocs/geoip";
%{__ln_s} "%{_datadir}/GeoIP/GeoIPASNumv6.dat" "%{buildroot}%{_datadir}/%{name}/httpdocs/geoip";
%{__ln_s} "%{_datadir}/GeoIP/GeoLiteCity.dat" "%{buildroot}%{_datadir}/%{name}/httpdocs/geoip";
%{__ln_s} "%{_datadir}/GeoIP/GeoLiteCityv6.dat" "%{buildroot}%{_datadir}/%{name}/httpdocs/geoip";

#
# Install the ntopng man page...
%{__install} -D --mode 644 "%{name}.8" "%{buildroot}%{_mandir}/man8/%{name}.8";

#
# Install an ntopng systemd environmental configuration file...
%{__install} -D --mode 644 %{SOURCE4} \
  "%{buildroot}%{_sysconfdir}/sysconfig/%{name}";

#
# Install a default ntopng configuration file...
%{__install} -D --mode 644 %{SOURCE5} \
  "%{buildroot}%{_sysconfdir}/%{name}/%{name}.conf";

#
# Install the ntop systemd service control file...
%{__install} -D --mode 644 %{SOURCE6} \
  "%{buildroot}%{_unitdir}/%{name}.service";

#
# Install a default ntopng working directory...
%{__mkdir_p} "%{buildroot}%{_localstatedir}/nst/%{name}";

%clean
%{__rm} -rf "%{buildroot}";

%pre

%post
#
# Add an 'ntopng' service and set its boot state disabled...
%systemd_post %{name}.service

%preun
#
# Stop a running the 'ntopng' service and remove start/stop links...
#
# ***Note: Also stop the 'redis' service.
if [ $1 -eq 0 ]; then
  #
  # Package removal, not upgrade 
  /usr/bin/systemctl --no-reload disable %{name}.service > /dev/null 2>&1 || : 
  /usr/bin/systemctl stop redis.service > /dev/null 2>&1 || : 
  /usr/bin/systemctl stop %{name}.service > /dev/null 2>&1 || : 
fi 

%postun
#
# ntopng package upgrade:
#
# If 'ntopng' was running, stop it and restart it with the upgraded version.
#
# *** Note: The 'redis' service is also restarted.
#
# Reload systemd configurations...
/usr/bin/systemctl daemon-reload >/dev/null 2>&1 || :
if [ $1 -ge 1 ]; then
  #
  # Package upgrade, not uninstall 
  #
  # If 'ntopng' was running restart services...
  if /usr/bin/systemctl status %{name}.service >/dev/null 2>&1; then
    #
    # Stop services:
    #/usr/bin/systemctl stop redis.service >/dev/null 2>&1 || :
    /usr/bin/systemctl stop %{name}.service >/dev/null 2>&1 || :
    #
    # Start services:
    #/usr/bin/systemctl start redis.service >/dev/null 2>&1 || :
    #
    # Flush the current 'redis' Database...
    #/bin/redis-cli -n 0 FLUSHDB >/dev/null 2>&1 || :
    #
    # Restart the 'ntopng' service...
    /usr/bin/systemctl start %{name}.service >/dev/null 2>&1 || :
  fi
fi

%files
%defattr(-,root,root,-)
%doc COPYING README* doc/UserGuide.pdf nDPI/nDPI third-party/third-party
%{_bindir}/%{name}
%{_bindir}/ndpiReader
%{_datadir}/%{name}
%{_unitdir}/%{name}.service
%{_mandir}/man8/%{name}.8.gz

%config(noreplace) %{_sysconfdir}/%{name}/%{name}.conf
%config(noreplace) %{_sysconfdir}/sysconfig/%{name}

%defattr(-,nobody,nobody,-)
%dir %{_localstatedir}/nst/%{name}


%changelog
* Sat Aug 09 2014-15 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.99, SVN: 8082

* Wed Aug 06 2014-15 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.99, SVN: 8064

* Tue Aug 05 2014-15 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.99, SVN: 8056

* Fri Jul 25 2014-15 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.4, SVN: 7973

* Thu Jul 17 2014-15 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.4, SVN: 7918
- Binary name change: pcapReader = ndpiReader

* Thu Jul 10 2014-15 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.4, SVN: 7873

* Sun Jul 06 2014-15 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.4, SVN: 7859

* Wed Jun 25 2014-15 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.4, SVN: 7806
- Added Disable RPM debug building.

* Tue Jun 24 2014-15 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.3, SVN: 7800

* Sat Jun 21 2014-15 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.3, SVN: 7791

* Fri Jun 13 2014-15 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.3, SVN: 7759

* Tue Jun 10 2014-15 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.3, SVN: 7745

* Tue Jun 03 2014-15 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.3, SVN: 7719

* Sat May 31 2014-15 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.3, SVN: 7705

* Sat May 24 2014-15 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.3, SVN: 7663

* Tue May 13 2014-15 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.2, SVN: 7618
- Added running 'autogen.sh' to generate a 'configure' in build.

* Sat May 10 2014-15 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.2, SVN: 7605

* Sat May 03 2014-15 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.2, SVN: 7581
- The nDPI pcapReader network utility now uses plain text output only.

* Thu May 01 2014-15 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.2, SVN: 7574
- Dashboard display now has a Rate/Play/Stop Live Update option.

* Thu Apr 24 2014-15 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.2, SVN: 7544
- Updated docs in NST Ntopng specific scripts.

* Tue Apr 15 2014-15 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.2, SVN: 7520

* Tue Apr 01 2014-15 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.2, SVN: 7433

- Add a default '--sticky-hosts none' option to the "ntopng.conf" file.
* Thu Mar 27 2014-15 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.2, SVN: 7397
- Add a default '--sticky-hosts none' option to the "ntopng.conf" file.

* Tue Mar 18 2014-15 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.2, SVN: 7365

* Tue Mar 11 2014-15 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.2, SVN: 7358

* Sat Mar 08 2014-15 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.2, SVN: 7357
- Refactored NST lua scripts to be network interface sensitive.

* Fri Feb 21 2014-15 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.2, SVN: 7323

* Tue Feb 18 2014-15 Ronald W. Henderson <rwhalb@verizon.net>
- NST 20 Integration:
- Next development release: v1.1.2, SVN: 7320

* Fri Dec 20 2013 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.1, SVN: 7132
- Configured the ntopng.service to start after the redis.service.

* Wed Dec 11 2013 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.1, SVN: 7107

* Mon Dec 09 2013 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.1, SVN: 7096
- Added the nDPI pcapReader network utility.

* Sun Nov 17 2013 Ronald W. Henderson <rwhalb@verizon.net>
- Next development release: v1.1.1, SVN: 6977

* Tue Aug 20 2013 Ronald W. Henderson <rwhalb@verizon.net>
- Created initial version of template spec file.
