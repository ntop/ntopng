FROM ubuntu:18.04

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get -y install wget lsb-release gnupg
RUN wget -O apt-ntop-stable.deb http://apt-stable.ntop.org/18.04/all/apt-ntop-stable.deb && \
	dpkg -i apt-ntop-stable.deb && rm -f apt-ntop-stable.deb
RUN apt-get update && apt-get -y install ntopng

RUN echo '#!/usr/bin/env bash\n/etc/init.d/redis-server start && ntopng "$@"' > /tmp/run.sh
RUN chmod +x /tmp/run.sh

ENTRYPOINT ["/tmp/run.sh"]
