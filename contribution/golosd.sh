#!/bin/bash

export HOME="/var/lib/golosd"

STEEMD="/usr/local/golosd-default/bin/golosd"

if [[ "$USE_WAY_TOO_MUCH_RAM" ]]; then
    STEEMD="/usr/local/golosd-full/bin/golosd"
fi

chown -R golosd:golosd $HOME

# seed nodes come from documentation/seednodes.txt which is
# installed by docker into /etc/golosd/seednodes.txt
SEED_NODES="$(cat /etc/golosd/seednodes | awk -F' ' '{print $1}')"

ARGS=""

# if user did not pass in any desired
# seed nodes, use the ones above:
if [[ -z "$STEEMD_SEED_NODES" ]]; then
    for NODE in $SEED_NODES ; do
        ARGS+=" --seed-node=$NODE"
    done
fi

# if user did pass in desired seed nodes, use
# the ones the user specified:
if [[ ! -z "$STEEMD_SEED_NODES" ]]; then
    for NODE in $STEEMD_SEED_NODES ; do
        ARGS+=" --seed-node=$NODE"
    done
fi

if [[ ! -z "$STEEMD_WITNESS_NAME" ]]; then
    ARGS+=" --witness=\"$STEEMD_WITNESS_NAME\""
fi

if [[ ! -z "$STEEMD_MINER_NAME" ]]; then
    ARGS+=" --miner=[\"$STEEMD_MINER_NAME\",\"$STEEMD_PRIVATE_KEY\"]"
    ARGS+=" --mining-threads=$(nproc)"
fi

if [[ ! -z "$STEEMD_PRIVATE_KEY" ]]; then
    ARGS+=" --private-key=$STEEMD_PRIVATE_KEY"
fi

# overwrite local config with image one
if [[ "$USE_FULL_WEB_NODE" ]]; then
  cp /etc/golosd/fullnode.config.ini $HOME/config.ini
else
  cp /etc/golosd/config.ini $HOME/config.ini
fi

chown golosd:golosd $HOME/config.ini

if [[ ! -d $HOME/blockchain ]]; then
    if [[ -e /var/cache/golosd/blocks.tbz2 ]]; then
        # init with blockchain cached in image
        ARGS+=" --replay-blockchain"
        mkdir -p $HOME/blockchain/database
        cd $HOME/blockchain/database
        tar xvjpf /var/cache/golosd/blocks.tbz2
        chown -R golosd:golosd $HOME/blockchain
    fi
fi

# without --data-dir it uses cwd as datadir(!)
# who knows what else it dumps into current dir
cd $HOME

# slow down restart loop if flapping
sleep 1

#start multiple read-only instances based on the number of cores
#attach to the local interface since a proxy will be used to loadbalance
if [[ "$USE_MULTICORE_READONLY" ]]; then
    exec chpst -ugolosd \
        $STEEMD \
            --rpc-endpoint=127.0.0.1:8091 \
            --p2p-endpoint=0.0.0.0:2001 \
            --data-dir=$HOME \
            $ARGS \
            $STEEMD_EXTRA_OPTS \
            2>&1 &
    #sleep for a moment to allow the writer node to be ready to accept connections from the readers
    sleep 5
    PORT_NUM=8092
    #don't generate endpoints in haproxy config if it already exists
    #this prevents adding to it if the docker container is stopped/started
    if [[ ! -f /etc/haproxy/haproxy.steem.cfg ]]; then
        cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.steem.cfg
        for (( i=2; i<=$(nproc); i++ ))
          do
            echo server server$PORT_NUM 127.0.0.1:$PORT_NUM maxconn 10000 weight 10 cookie server$PORT_NUM check >> /etc/haproxy/haproxy.steem.cfg
            ((PORT_NUM++))
        done
    fi
    PORT_NUM=8092
    for (( i=2; i<=$(nproc); i++ ))
      do
        exec chpst -ugolosd \
        $STEEMD \
          --rpc-endpoint=127.0.0.1:$PORT_NUM \
          --data-dir=$HOME \
          --read-forward-rpc=127.0.0.1:8091 \
          --read-only \
          2>&1 &
          ((PORT_NUM++))
          sleep 1
    done
    #start haproxy now that the config file is complete with all endpoints
    #all of the read-only processes will connect to the write node onport 8091
    #haproxy will balance all incoming traffic on port 8090
    /usr/sbin/haproxy -f /etc/haproxy/haproxy.steem.cfg 2>&1
else
    exec chpst -ugolosd \
        $STEEMD \
            --rpc-endpoint=0.0.0.0:8090 \
            --p2p-endpoint=0.0.0.0:2001 \
            --data-dir=$HOME \
            $ARGS \
            $STEEMD_EXTRA_OPTS \
            2>&1
fi


#!/bin/bash

export HOME="/var/lib/golosd"

STEEMD="/usr/local/bin/golosd"

#if [[ "$USE_WAY_TOO_MUCH_RAM" ]]; then
#    STEEMD="/usr/local/golosd-full/bin/golosd"
#fi

chown -R golosd:golosd $HOME

# seed nodes come from documentation/seednodes which is
# installed by docker into /etc/golosd/seednodes
SEED_NODES="$(cat /etc/golosd/seednodes | awk -F' ' '{print $1}')"

ARGS=""

# if user did not pass in any desired
# seed nodes, use the ones above:
if [[ -z "$STEEMD_SEED_NODES" ]]; then
    for NODE in $SEED_NODES ; do
        ARGS+=" --seed-node=$NODE"
    done
fi

# if user did pass in desired seed nodes, use
# the ones the user specified:
if [[ ! -z "$STEEMD_SEED_NODES" ]]; then
    for NODE in $STEEMD_SEED_NODES ; do
        ARGS+=" --seed-node=$NODE"
    done
fi

if [[ ! -z "$STEEMD_WITNESS_NAME" ]]; then
    ARGS+=" --witness=\"$STEEMD_WITNESS_NAME\""
fi

if [[ ! -z "$STEEMD_MINER_NAME" ]]; then
    ARGS+=" --miner=[\"$STEEMD_MINER_NAME\",\"$STEEMD_PRIVATE_KEY\"]"
#    ARGS+=" --mining-threads=$(nproc)"
fi

if [[ ! -z "$STEEMD_PRIVATE_KEY" ]]; then
    ARGS+=" --private-key=$STEEMD_PRIVATE_KEY"
fi

# overwrite local config with image one
cp /etc/golosd/config.ini $HOME/config.ini

chown golosd:golosd $HOME/config.ini

if [[ ! -d $HOME/blockchain ]]; then
    if [[ -e /var/cache/golosd/blocks.tbz2 ]]; then
        # init with blockchain cached in image
        ARGS+=" --replay-blockchain"
        mkdir -p $HOME/blockchain/database
        cd $HOME/blockchain/database
        tar xvjpf /var/cache/golosd/blocks.tbz2
        chown -R golosd:golosd $HOME/blockchain
    fi
fi

# without --data-dir it uses cwd as datadir(!)
# who knows what else it dumps into current dir
cd $HOME

# slow down restart loop if flapping
sleep 1

if [[ ! -z "$STEEMD_RPC_ENDPOINT" ]]; then
    RPC_ENDPOINT=$STEEMD_RPC_ENDPOINT
else
    RPC_ENDPOINT="0.0.0.0:8090"
fi

if [[ ! -z "$STEEMD_P2P_ENDPOINT" ]]; then
    P2P_ENDPOINT=$STEEMD_P2P_ENDPOINT
else
    P2P_ENDPOINT="0.0.0.0:2001"
fi

exec chpst -ugolosd \
    $STEEMD \
        --rpc-endpoint=${RPC_ENDPOINT} \
        --p2p-endpoint=${P2P_ENDPOINT} \
        --data-dir=$HOME \
        $ARGS \
        $STEEMD_EXTRA_OPTS \
        2>&1
