#!/bin/bash

docker exec -ti groestlcoind groestlcoin-cli -datadir="/data" "$@"