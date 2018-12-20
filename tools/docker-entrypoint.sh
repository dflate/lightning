#!/usr/bin/env bash

: "${EXPOSE_TCP:=false}"

if [[ $LIGHTNINGD_OPT ]]; then
	cat <<-EOF > "$LIGHTNINGD_DATA/config"
${LIGHTNINGD_OPT}
EOF
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


wait_sync () {
    rpcConnect=$(sed -n 's/^bitcoin-rpcconnect=\(.*\)$/\1/p' < "$LIGHTNINGD_DATA/config")
    dataDir=$(sed -n 's/^bitcoin-datadir=\(.*\)$/\1/p' < "$LIGHTNINGD_DATA/config")
    rpcPort=$(sed -n 's/^bitcoin-rpcport=\(.*\)$/\1/p' < "$LIGHTNINGD_DATA/config")
    
    status=$(groestlcoin-cli -datadir="$dataDir" -rpcport="$rpcPort" -rpcconnect="$rpcConnect" echo ok)
    status=$(echo "$status" | jq '.[0]')
    expectedstatus="\"ok\""
    if [[ "$status" != "$expectedstatus" ]]; then
        echo "Could not connect to node: $status"
        sleep 5
        wait_sync;
        return
    fi
    result=$(groestlcoin-cli -datadir="$dataDir" -rpcport="$rpcPort" -rpcconnect="$rpcConnect" getblockchaininfo)
    isDownload=$(echo "$result" | jq '.initialblockdownload')
    progress=$(echo "$result" | jq '.verificationprogress')
    if [[ $isDownload == true ]] || [[ $(echo "$progress < 0.99" |bc -l) -eq 1 ]]; then
        echo "Waiting for the node to sync($progress %)"
        sleep 5
        wait_sync;
        return;
    fi
    echo "Node synched"
}

wait_sync


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
