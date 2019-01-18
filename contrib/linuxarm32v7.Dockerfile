# This dockerfile is meant to cross compile with a x64 machine for a arm32v7 host
# It is using multi stage build:
# * downloader: Download Groestlcoin and qemu binaries needed for c-lightning
# * builder: Cross compile c-lightning dependencies, then c-lightning itself with static linking
# * final: Copy the binaries required at runtime
# The resulting image uploaded to dockerhub will only contain what is needed for runtime.
# From the root of the repository, run "docker build -t yourimage:yourtag -f contrib/linuxarm32v7.Dockerfile ."
FROM debian:stretch-slim as downloader

RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates dirmngr wget \
     qemu qemu-user-static qemu-user binfmt-support

WORKDIR /opt

ENV GROESTLCOIN_VERSION 2.16.3
ENV GROESTLCOIN_URL https://github.com/Groestlcoin/groestlcoin/releases/download/v2.16.3/groestlcoin-2.16.3-x86_64-linux-gnu.tar.gz
ENV GROESTLCOIN_SHA256 f15bd5e38b25a103821f1563cd0e1b2cf7146ec9f9835493a30bd57313d3b86f

RUN mkdir /opt/groestlcoin && cd /opt/groestlcoin \
		&& wget -qO groestlcoin.tar.gz "$GROESTLCOIN_URL" \
		&& echo "$GROESTLCOIN_SHA256  groestlcoin.tar.gz" | sha256sum -c - \
		&& tar -xzvf groestlcoin.tar.gz groestlcoin-cli --exclude=*-qt \
		&& rm groestlcoin.tar.gz

FROM debian:stretch-slim as builder

ENV LIGHTNINGD_VERSION=master
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates autoconf automake build-essential git libtool python python3 wget gnupg dirmngr git \
  libc6-armhf-cross gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf

ENV target_host=arm-linux-gnueabihf

ENV AR=${target_host}-ar \
AS=${target_host}-as \
CC=${target_host}-gcc \
CXX=${target_host}-g++ \
LD=${target_host}-ld \
STRIP=${target_host}-strip \
QEMU_LD_PREFIX=/usr/${target_host} \
HOST=${target_host}

RUN wget -q https://zlib.net/zlib-1.2.11.tar.gz \
&& tar xvf zlib-1.2.11.tar.gz \
&& cd zlib-1.2.11 \
&& ./configure --prefix=$QEMU_LD_PREFIX \
&& make \
&& make install && cd .. && rm zlib-1.2.11.tar.gz && rm -rf zlib-1.2.11

RUN apt-get install -y --no-install-recommends unzip tclsh \
&& wget -q https://www.sqlite.org/2018/sqlite-src-3260000.zip \
&& unzip sqlite-src-3260000.zip \
&& cd sqlite-src-3260000 \
&& ./configure --enable-static --disable-readline --disable-threadsafe --disable-load-extension --host=${target_host} --prefix=$QEMU_LD_PREFIX \
&& make \
&& make install && cd .. && rm sqlite-src-3260000.zip && rm -rf sqlite-src-3260000

RUN wget -q https://gmplib.org/download/gmp/gmp-6.1.2.tar.xz \
&& tar xvf gmp-6.1.2.tar.xz \
&& cd gmp-6.1.2 \
&& ./configure --disable-assembly --prefix=$QEMU_LD_PREFIX --host=${target_host} \
&& make \
&& make install && cd .. && rm gmp-6.1.2.tar.xz && rm -rf gmp-6.1.2

COPY --from=downloader /usr/bin/qemu-arm-static /usr/bin/qemu-arm-static
WORKDIR /opt/lightningd
COPY . .
ARG DEVELOPER=0
RUN ./configure --enable-static && make -j3 DEVELOPER=${DEVELOPER} && cp lightningd/lightning* cli/lightning-cli /usr/bin/

FROM arm32v7/debian:stretch-slim as final
COPY --from=downloader /usr/bin/qemu-arm-static /usr/bin/qemu-arm-static
RUN apt-get update && apt-get install -y --no-install-recommends socat inotify-tools \
    && rm -rf /var/lib/apt/lists/*

ENV LIGHTNINGD_DATA=/root/.lightning
ENV LIGHTNINGD_PORT=9835

RUN mkdir $LIGHTNINGD_DATA && \
    touch $LIGHTNINGD_DATA/config
VOLUME [ "/root/.lightning" ]

COPY --from=builder /opt/lightningd/cli/lightning-cli /usr/bin
COPY --from=builder /opt/lightningd/lightningd/lightning* /usr/bin/
COPY --from=downloader /opt/groestlcoin /usr/bin
COPY tools/docker-entrypoint.sh entrypoint.sh

EXPOSE 9735 9835
ENTRYPOINT  [ "./entrypoint.sh" ]
