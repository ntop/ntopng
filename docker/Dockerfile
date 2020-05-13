FROM ubuntu:18.04

ENV DEBIAN_FRONTEND noninteractive

# Pass --build-arg TZ=<YOUR_TZ> when running docker build to override this.
ARG TZ=Europe/Rome

RUN apt-get update && apt-get -y install wget lsb-release gnupg tzdata
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN wget -O apt-ntop-stable.deb http://apt-stable.ntop.org/18.04/all/apt-ntop-stable.deb && \
	dpkg -i apt-ntop-stable.deb && rm -f apt-ntop-stable.deb
RUN apt-get update && apt-get -y install ntopng
RUN echo '#!/usr/bin/env bash\n/etc/init.d/redis-server start && ntopng "$@"' > /tmp/run.sh
RUN chmod +x /tmp/run.sh

ENTRYPOINT ["/tmp/run.sh"]
