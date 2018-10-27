FROM ubuntu:16.04
MAINTAINER Christian Decker <decker.christian@gmail.com>

ENV DEBIAN_FRONTEND noninteractive
ENV GROESTLCOIN_VERSION 2.16.3

WORKDIR /build

RUN apt-get -qq update && \
    apt-get -qq install --no-install-recommends --allow-unauthenticated -yy \
	asciidoc \
	autoconf \
	automake \
	clang \
	cppcheck \
	docbook-xml \
	shellcheck \
	eatmydata \
	software-properties-common \
	build-essential \
	autoconf \
	locales \
	libtool \
	libprotobuf-c-dev \
	libsqlite3-dev \
	libgmp-dev \
	git \
	python \
	python3 \
	valgrind \
	net-tools \
	python3-pip \
	python3-setuptools \
	python-pkg-resources \
	shellcheck \
	libxml2-utils \
	wget \
	xsltproc \
	zlib1g-dev && \
	rm -rf /var/lib/apt/lists/*

ENV LANGUAGE=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
RUN locale-gen en_US.UTF-8 && dpkg-reconfigure locales

RUN cd /tmp/ && \
    wget https://github.com/Groestlcoin/groestlcoin/releases/download/v2.16.3/groestlcoin-2.16.3-x86_64-linux-gnu.tar.gz -O groestlcoin.tar.gz && \
    tar -xvzf groestlcoin.tar.gz && \
    mv /tmp/groestlcoin-$GROESTLCOIN_VERSION/bin/groestlcoin* /usr/local/bin/ && \
    rm -rf groestlcoin.tar.gz /tmp/groestlcoin-$GROESTLCOIN_VERSION

RUN pip3 install --upgrade pip && \
    python3 -m pip install python-bitcoinlib==0.7.0 pytest==3.0.5 setuptools==36.6.0 pytest-test-groups==1.0.3 flake8==3.5.0 pytest-rerunfailures==3.1 ephemeral-port-reserve==1.1.0 pytest-xdist==1.22.2 flaky==3.4.0 CherryPy==17.3.0 Flask==1.0.2
