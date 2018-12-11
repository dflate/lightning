FROM debian:stretch-slim as builder

RUN apt-get update && apt-get install -y \
  autoconf automake build-essential git libtool libgmp-dev \
  libsqlite3-dev python python3 net-tools zlib1g-dev wget

WORKDIR /opt

ENV GROESTLCOIN_VERSION 2.16.3
ENV GROESTLCOIN_URL https://github.com/Groestlcoin/groestlcoin/releases/download/v2.16.3/groestlcoin-2.16.3-x86_64-linux-gnu.tar.gz
ENV GROESTLCOIN_SHA256 f15bd5e38b25a103821f1563cd0e1b2cf7146ec9f9835493a30bd57313d3b86f

RUN mkdir /opt/groestlcoin && cd /opt/groestlcoin \
    && wget -qO groestlcoin.tar.gz "$GROESTLCOIN_URL" \
    && echo "$GROESTLCOIN_SHA256  groestlcoin.tar.gz" | sha256sum -c - \
    && tar -xzvf groestlcoin.tar.gz groestlcoin-cli --exclude=*-qt \
    && rm groestlcoin.tar.gz

ENV LIGHTNINGD_VERSION=master

WORKDIR /opt/lightningd
COPY . .

ARG DEVELOPER=0
RUN ./configure && make -j3 DEVELOPER=${DEVELOPER} && cp lightningd/lightning* cli/lightning-cli /usr/bin/


FROM microsoft/dotnet:2.1.403-sdk-alpine3.7 AS dotnetbuilder

RUN apk add --no-cache git

WORKDIR /source

RUN git clone https://github.com/dgarage/NBXplorer && cd NBXplorer && git checkout 88a8db8be3911f59b4b6109845b547368c5f02fb

# Cache some dependencies
RUN cd NBXplorer/NBXplorer.NodeWaiter && dotnet restore && cd ..
RUN cd NBXplorer/NBXplorer.NodeWaiter && \
    dotnet publish --output /app/ --configuration Release

FROM microsoft/dotnet:2.2-runtime-deps-stretch-slim

RUN apt-get update && apt-get install -y \
	autoconf automake build-essential git libtool libgmp-dev \
	libsqlite3-dev python python3 net-tools zlib1g-dev

ENV LIGHTNINGD_DATA=/root/.lightning
ENV LIGHTNINGD_RPC_PORT=9835

RUN mkdir $LIGHTNINGD_DATA && \
    touch $LIGHTNINGD_DATA/config

VOLUME [ "/root/.lightning" ]

COPY --from=builder /opt/lightningd/cli/lightning-cli /usr/bin
COPY --from=builder /opt/lightningd/lightningd/lightning* /usr/bin/
COPY --from=builder /opt/groestlcoin /usr/bin
COPY --from=dotnetbuilder /app /opt/NBXplorer.NodeWaiter
COPY tools/docker-entrypoint.sh entrypoint.sh

EXPOSE 9735 9835
ENTRYPOINT  [ "./entrypoint.sh" ]
