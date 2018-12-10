#!/usr/bin/env bash

: "${EXPOSE_TCP:=false}"

if [[ -z "${LIGHTNINGD_OPT}" ]]; then
  echo "${LIGHTNINGD_OPT}" > $LIGHTNINGD_DATA/config
fi
NETWORK=$(sed -n 's/^network=\(.*\)$/\1/p' < "$LIGHTNINGD_DATA/config")
REPLACEDNETWORK="";
if [ "$NETWORK" == "mainnet" ]; then
	REPLACEDNETWORK="groestlcoin"
fi
if [[ $REPLACEDNETWORK ]]; then
    sed -i '/^network=/d' "$LIGHTNINGD_DATA/config"
    echo "network=$REPLACEDNETWORK" >> "$LIGHTNINGD_DATA/config"
    echo "Replaced network $NETWORK by $REPLACEDNETWORK in $LIGHTNINGD_DATA/config"
fi

if [ "$EXPOSE_TCP" == "true" ]; then
    set -m
    lightningd "$@" &

    echo "C-Lightning starting"
    while read -r i; do if [ "$i" = "lightning-rpc" ]; then break; fi; done \
    < <(inotifywait  -e create,open --format '%f' --quiet "$LIGHTNINGD_DATA" --monitor)
    echo "C-Lightning started"
    echo "C-Lightning started, RPC available on port $LIGHTNINGD_RPC_PORT"

    socat "TCP4-listen:$LIGHTNINGD_RPC_PORT,fork,reuseaddr" "UNIX-CONNECT:$LIGHTNINGD_DATA/lightning-rpc" &
    fg %-
else
    lightningd "$@"
fi
