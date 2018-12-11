#!/usr/bin/env bash

: "${EXPOSE_TCP:=false}"

cat <<-EOF > "$LIGHTNINGD_DATA/config"
${LIGHTNINGD_OPT}
EOF

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

if [[ $LIGHTNINGD_EXPLORERURL && $NETWORK ]]; then
    # We need to do that because clightning behave weird if it starts at same time as bitcoin core, or if the node is not synched
    echo "Waiting for the node to start and sync"
    dotnet /opt/NBXplorer.NodeWaiter/NBXplorer.NodeWaiter.dll --chains "grs" --network "$NETWORK" --explorerurl "$LIGHTNINGD_EXPLORERURL"
    echo "Node synched"
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
