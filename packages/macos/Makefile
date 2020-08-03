#
# Change it according to your setup
#
NTOPNG_HOME=$(PWD)/../..
NTOPNG_BUILD=${NTOPNG_HOME}/packages/macos/install

all: clean ntopng-build

ntopng-build:
	if test -e "./install"; then /bin/rm -f install; fi
	\mkdir -p ${NTOPNG_BUILD}/usr/local/bin ${NTOPNG_BUILD}/usr/local/etc/ntopng ${NTOPNG_BUILD}/usr/local/share/man/man8
	\mkdir -p ${NTOPNG_BUILD}/usr/local/opt/ntopng ${NTOPNG_BUILD}/usr/local/share/ntopng/httpdocs/geoip ./install/
	cd $(NTOPNG_HOME); make ; cp ntopng ${NTOPNG_BUILD}/usr/local/bin/ntopng-bin
	cp ./ntopng ${NTOPNG_BUILD}/usr/local/bin/
	cp ./uninstall.sh ${NTOPNG_BUILD}/usr/local/bin/ntopng-uninstall.sh
	cp ./ntopng-macos.conf ${NTOPNG_BUILD}/usr/local/etc/ntopng/ntopng.conf

	cp /usr/local/opt/rrdtool/lib/librrd.8.dylib ${NTOPNG_BUILD}/usr/local/opt/ntopng
	cp /usr/local/opt/json-c/lib/libjson-c.4.dylib ${NTOPNG_BUILD}/usr/local/opt/ntopng
	cp /usr/local/opt/libmaxminddb/lib/libmaxminddb.0.dylib ${NTOPNG_BUILD}/usr/local/opt/ntopng
	cp /usr/local/opt/libsodium/lib/libsodium.23.dylib ${NTOPNG_BUILD}/usr/local/opt/ntopng
	cp /usr/local/opt/mysql/lib/libmysqlclient.21.dylib ${NTOPNG_BUILD}/usr/local/opt/ntopng
	cp /usr/local/opt/openssl@1.1/lib/libssl.1.1.dylib ${NTOPNG_BUILD}/usr/local/opt/ntopng
	cp /usr/local/opt/openssl@1.1/lib/libcrypto.1.1.dylib ${NTOPNG_BUILD}/usr/local/opt/ntopng
	cp /usr/local/opt/zstd/lib/libzstd.1.dylib ${NTOPNG_BUILD}/usr/local/opt/ntopng
	cp /usr/local/opt/libpng/lib/libpng16.16.dylib ${NTOPNG_BUILD}/usr/local/opt/ntopng
	cp /usr/local/Cellar/pango/1.44.7/lib/libpangocairo-1.0.0.dylib ${NTOPNG_BUILD}/usr/local/opt/ntopng
	cp /usr/local/opt/pango/lib/libpango-1.0.0.dylib ${NTOPNG_BUILD}/usr/local/opt/ntopng
	cp /usr/local/opt/glib/lib/libgobject-2.0.0.dylib ${NTOPNG_BUILD}/usr/local/opt/ntopng
	cp /usr/local/opt/glib/lib/libglib-2.0.0.dylib ${NTOPNG_BUILD}/usr/local/opt/ntopng
	cp /usr/local/opt/harfbuzz/lib/libharfbuzz.0.dylib ${NTOPNG_BUILD}/usr/local/opt/ntopng
	cp /usr/local/opt/cairo/lib/libcairo.2.dylib ${NTOPNG_BUILD}/usr/local/opt/ntopng
	cp /usr/local/opt/gettext/lib/libintl.8.dylib ${NTOPNG_BUILD}/usr/local/opt/ntopng
	cp /usr/local/Cellar/pango/1.44.7/lib/libpangoft2-1.0.0.dylib ${NTOPNG_BUILD}/usr/local/opt/ntopng
	cp /usr/local/opt/fontconfig/lib/libfontconfig.1.dylib ${NTOPNG_BUILD}/usr/local/opt/ntopng
	cp /usr/local/opt/fribidi/lib/libfribidi.0.dylib ${NTOPNG_BUILD}/usr/local/opt/ntopng
	cp /usr/local/opt/pcre/lib/libpcre.1.dylib ${NTOPNG_BUILD}/usr/local/opt/ntopng
	cp /usr/local/opt/libffi/lib/libffi.7.dylib ${NTOPNG_BUILD}/usr/local/opt/ntopng
	cp /usr/local/opt/freetype/lib/libfreetype.6.dylib ${NTOPNG_BUILD}/usr/local/opt/ntopng
	cp /usr/local/opt/graphite2/lib/libgraphite2.3.dylib ${NTOPNG_BUILD}/usr/local/opt/ntopng
	cp /usr/local/opt/pixman/lib/libpixman-1.0.dylib ${NTOPNG_BUILD}/usr/local/opt/ntopng
	cp /usr/local/opt/net-snmp/lib/libnetsnmp.35.dylib ${NTOPNG_BUILD}/usr/local/opt/ntopng

	cp /usr/local/bin/redis-server ${NTOPNG_BUILD}/usr/local/bin/ntopng-redis-server

	cp ../../httpdocs/geoip/dbip-asn-*.mmdb ../../httpdocs/geoip/dbip-country-*.mmdb ${NTOPNG_BUILD}/usr/local/share/ntopng/httpdocs/geoip

	cp $(NTOPNG_HOME)/ntopng.8 ${NTOPNG_BUILD}/usr/local/share/man/man8
	cp -RL $(NTOPNG_HOME)/httpdocs ${NTOPNG_BUILD}/usr/local/share/ntopng
	cp -RL $(NTOPNG_HOME)/scripts ${NTOPNG_BUILD}/usr/local/share/ntopng
	mv ${NTOPNG_BUILD}/usr/local/share/ntopng/httpdocs/ssl/ntopng-cert.pem.dummy ${NTOPNG_BUILD}/usr/local/share/ntopng/httpdocs/ssl/ntopng-cert.pem
	if test -d "$(NTOPNG_HOME)/pro"; then \
		mkdir ${NTOPNG_BUILD}/usr/local/share/ntopng/pro; \
		cp -r $(NTOPNG_HOME)/pro/httpdocs ${NTOPNG_BUILD}/usr/local/share/ntopng/pro; \
		cp -r $(NTOPNG_HOME)/pro/scripts ${NTOPNG_BUILD}/usr/local/share/ntopng/pro; \
		rm -rf ${NTOPNG_BUILD}/usr/local/share/ntopng/pro/scripts/lua/nedge; \
		cd ${NTOPNG_BUILD}/usr/local/share/ntopng/scripts/lua; rm -rf pro; ln -s ../../pro/scripts/lua pro; \
		find ${NTOPNG_BUILD}/usr/local/share/ntopng/pro -name "*.lua" -type f -exec $(NTOPNG_HOME)/pro/utils/snzip -c -i {} -o {}r \;; \
		find ${NTOPNG_BUILD}/usr/local/share/ntopng/pro -name "*.lua" -type f -exec /bin/rm  {} ';'; \
		find ${NTOPNG_BUILD}/usr/local/share/ntopng/pro/scripts -name "*.luar" | xargs rename 's/\.luar/.lua/'; \
	fi
	if hash systemctl 2>/dev/null; then \
		rm -rf ${NTOPNG_BUILD}/etc/init.d; \
	fi

	find ${NTOPNG_BUILD}/usr/local/share/ntopng -name "*~"   | xargs /bin/rm -f
	find ${NTOPNG_BUILD}/usr/local/share/ntopng -name ".svn" | xargs /bin/rm -rf
	find ${NTOPNG_BUILD}/usr/local/share/ntopng -name ".git" | xargs /bin/rm -rf
	@find . -name "*#" -exec /bin/rm {} ';'
	@find . -name "*~" -exec /bin/rm {} ';'

clean:
	rm -rf *~ install
