#
# Change it according to your setup
#
NTOPNG_HOME=$(PWD)/../..
NTOPNG_BUILD=${NTOPNG_HOME}/packages/macos/install

all: clean ntopng

ntopng:
	if test -e "./install"; then /bin/rm -f install; fi
	\mkdir -p ${NTOPNG_BUILD}/usr/local/bin ${NTOPNG_BUILD}/usr/local/etc ${NTOPNG_BUILD}/usr/local/share/man/man8 ${NTOPNG_BUILD}/usr/local/share/ntopng ./install/
	cd $(NTOPNG_HOME); make ; cp ntopng ${NTOPNG_BUILD}/usr/local/bin/
	cp $(NTOPNG_HOME)/packages/etc/ntopng/ntopng.conf ${NTOPNG_BUILD}/usr/local/etc/
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
	rm -rf ${NTOPNG_BUILD}/usr/local/share/ntopng/httpdocs/geoip/
	find ${NTOPNG_BUILD}/usr/local/share/ntopng -name "*~"   | xargs /bin/rm -f
	find ${NTOPNG_BUILD}/usr/local/share/ntopng -name ".svn" | xargs /bin/rm -rf
	find ${NTOPNG_BUILD}/usr/local/share/ntopng -name ".git" | xargs /bin/rm -rf
	@find . -name "*#" -exec /bin/rm {} ';'
	@find . -name "*~" -exec /bin/rm {} ';'

clean:
	rm -rf *~ install
