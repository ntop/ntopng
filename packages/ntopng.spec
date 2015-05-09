Summary: Web-based network traffic monitoring
Name: ntopng
Version: 1.99.150507
Release:       69
License: GPL
Group: Networking/Utilities
URL: http://www.ntop.org/
Source: ntopng-%{version}.tgz
Packager: Luca Deri <deri@ntop.org>
# Temporary location where the RPM will be built
BuildRoot:  %{_tmppath}/%{name}-%{version}-root
Requires: redis >= 2.4.0, GeoIP >= 1.4.8, rrdtool >= 1.3.8, numactl, libcurl, ntopng-data, logrotate

%description
Web-based traffic monitoring

%prep

%setup -q

%build
PATH=/usr/bin:/bin:/usr/sbin:/sbin
CFLAGS="$RPM_OPT_FLAGS" ./configure
make
if test -d "pro"; then cd pro; make build; fi
#

# Installation may be a matter of running an install make target or you
# may need to manually install files with the install command.
%install
PATH=/usr/bin:/bin:/usr/sbin:/sbin
if [ -d $RPM_BUILD_ROOT ]; then
	\rm -rf $RPM_BUILD_ROOT
fi
#
# "T.J. Yang" <tjyang2001@gmail.com>
#
#mkdir -p $RPM_BUILD_ROOT/etc/ntopng
#cat >$RPM_BUILD_ROOT/etc/ntopng/ntopng.conf.sample <<_EOT_
#-G=/var/tmp/ntopng.pid
#_EOT_
#cat >$RPM_BUILD_ROOT/etc/ntopng/ntopng.start <<_EOT_
#_EOT_

mkdir -p $RPM_BUILD_ROOT/usr/bin $RPM_BUILD_ROOT/usr/share/ntopng $RPM_BUILD_ROOT/usr/share/man/man8 
mkdir -p $RPM_BUILD_ROOT/etc/init.d $RPM_BUILD_ROOT/etc/logrotate.d
cp $RPM_BUILD_DIR/ntopng-%{version}/ntopng $RPM_BUILD_ROOT/usr/bin
cp $RPM_BUILD_DIR/ntopng-%{version}/ntopng.8 $RPM_BUILD_ROOT/usr/share/man/man8/ 
cp -r $RPM_BUILD_DIR/ntopng-%{version}/httpdocs $RPM_BUILD_DIR/ntopng-%{version}/scripts $RPM_BUILD_ROOT/usr/share/ntopng

if test -d "$RPM_BUILD_DIR/ntopng-%{version}/pro"; then
   cd $RPM_BUILD_DIR/ntopng-%{version}/pro; make; cd -
   mkdir $RPM_BUILD_ROOT/usr/share/ntopng/pro
   cp -r $RPM_BUILD_DIR/ntopng-%{version}/pro/httpdocs $RPM_BUILD_ROOT/usr/share/ntopng/pro
   cp -r $RPM_BUILD_DIR/ntopng-%{version}/pro/scripts $RPM_BUILD_ROOT/usr/share/ntopng/pro
   cd $RPM_BUILD_ROOT/usr/share/ntopng/scripts/lua; ln -s ../../pro/scripts/lua pro
   find $RPM_BUILD_ROOT/usr/share/ntopng/pro -name "*.lua" -type f -exec $RPM_BUILD_DIR/ntopng-%{version}/pro/utils/snzip -c -i {} -o {}r \;
   find $RPM_BUILD_ROOT/usr/share/ntopng/pro -name "*.lua" -type f -exec /bin/rm  {} ';'
   find $RPM_BUILD_ROOT/usr/share/ntopng/pro -name "*.luar" | xargs rename .luar .lua
fi


#cp $RPM_BUILD_DIR/ntopng-%{version}/packages/etc/init/ntopng.conf $RPM_BUILD_ROOT/etc/init
if test -d "/etc/systemd"; then
   mkdir -p $RPM_BUILD_ROOT/etc/systemd/scripts/
   mkdir -p $RPM_BUILD_ROOT/etc/systemd/system/
   cp $RPM_BUILD_DIR/ntopng-%{version}/packages/etc/init.d/ntopng    $RPM_BUILD_ROOT/etc/systemd/scripts/
   cp $RPM_BUILD_DIR/ntopng-%{version}/packages/etc/systemd/system/ntopng.service    $RPM_BUILD_ROOT/etc/systemd/system/
else
   cp $RPM_BUILD_DIR/ntopng-%{version}/packages/etc/init.d/ntopng    $RPM_BUILD_ROOT/etc/init.d
fi
cp $RPM_BUILD_DIR/ntopng-%{version}/packages/etc/logrotate.d/ntopng    $RPM_BUILD_ROOT/etc/logrotate.d/
find $RPM_BUILD_ROOT -name ".git" | xargs /bin/rm -rf
find $RPM_BUILD_ROOT -name "*~"   | xargs /bin/rm -f
#
DST=$RPM_BUILD_ROOT/usr/ntopng
SRC=$RPM_BUILD_DIR/%{name}-%{version}
#mkdir -p $DST/conf
# Clean out our build directory
%clean
rm -fr $RPM_BUILD_ROOT

%files
/usr/bin/ntopng
/usr/share/man/man8/ntopng.8.gz
#/etc/init/ntopng.conf
%if 0%{?centos_ver} == 7
/etc/systemd/scripts/ntopng
/etc/systemd/system/ntopng.service
%else
/etc/init.d/ntopng
%endif
/etc/logrotate.d/ntopng
/usr/share/ntopng
#/etc/ntopng/ntopng.conf.sample
#/etc/ntopng/ntopng.start

# Set the default attributes of all of the files specified to have an
# owner and group of root and to inherit the permissions of the file
# itself.
%defattr(-, root, root)

%changelog
* Sun Jun 30 2013 Luca Deri <deri@ntop.org> 1.0
- Current package version

%post
echo 'Setting up redis auto startup'
/sbin/chkconfig redis on
echo 'Creating link under /usr/local/bin'
if test ! -e /usr/local/bin/ntopng ; then ln -s /usr/bin/ntopng /usr/local/bin/ntopng ; fi
%if 0%{?centos_ver} == 7
/bin/systemctl daemon-reload
/bin/systemctl enable ntopng.service
%else
/sbin/chkconfig --add ntopng
%endif

%postun
echo 'Removing /usr/local/bin/ntopng link'
rm -f /usr/local/bin/ntopng > /dev/null 2>&1

