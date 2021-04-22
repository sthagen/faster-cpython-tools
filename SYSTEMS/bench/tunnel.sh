#!/usr/bin/env bash

BENCH_ROOT=$HOME/BENCH
PIDFILE=$BENCH_ROOT/tunnel.pid
CONFIG="$BENCH_ROOT/bench.json"

HOST="$(jq -r '.portal_host' $CONFIG)"
PORT="$(jq -r '.portal_port' $CONFIG)"
TUNNEL="$(jq -r '.portal_tunnel' $CONFIG)"


function check-pid-file() {
    local verbosity=$1

    if [ ! -e "$PIDFILE" ]; then
        echo "0"
        return
    fi

    local pid=$(cat $PIDFILE)
    if [ -z "$pid" ]; then
        if [ -z "$verbosity" -o "$verbosity" -ge 3 ]; then
            >&2 echo "WARNING: no PID in $PIDFILE"
            >&2 echo "  (removing it...)"
        fi
        rm $PIDFILE
        echo "-1"
        return
    fi

    if ! &>/dev/null ps -q "$pid"; then
        if [ -z "$verbosity" -o "$verbosity" -ge 3 ]; then
            >&2 echo "WARNING: the SSH tunnel is unexpectedly not running (PID $pid)"
            >&2 echo "  (it will be restarted now)"
        fi
        rm $PIDFILE
        echo "-1"
        return
    fi

    echo "$pid"
}


function start-tunnel() {
    local mode=$1
    local verbosity=$2

    if [ -z "$mode" ]; then
        mode="orphan"
    fi

    echo "starting tunnel in $mode mode..."
    case "$mode" in
        daemon)
            if [ -z "$verbosity" -o "$verbosity" -ge 3 ]; then
               echo "> ssh -i ~/.ssh/id_rsa -R $TUNNEL:localhost:$PORT -N -n $HOST &"
            fi
            ssh -i ~/.ssh/id_rsa -R $TUNNEL:localhost:$PORT -N -n $HOST &
            local pid=$!
            if [ -z "$verbosity" -o "$verbosity" -ge 3 ]; then
                echo "PID: $pid"
            else
                echo $pid
            fi
            echo "$pid" > $PIDFILE
            # Unlike with "orphan", we don't wait here.
	    # XXX Clear the PID file somehow?
	    ;;
        orphan)
            if [ -z "$verbosity" -o "$verbosity" -ge 3 ]; then
               echo "> \$(ssh -i ~/.ssh/id_rsa -R $TUNNEL:localhost:$PORT -N -n $HOST &)"
            fi
            ssh -i ~/.ssh/id_rsa -R $TUNNEL:localhost:$PORT -N -n $HOST &
            local pid=$!
            if [ -z "$verbosity" -o "$verbosity" -ge 3 ]; then
                echo "PID: $pid"
            else
                echo $pid
            fi
            echo "$pid" > $PIDFILE
            wait $pid
	    rm $PIDFILE
	    ;;
        dead)
            local pid=$$
            if [ -z "$verbosity" -o "$verbosity" -ge 3 ]; then
                echo "> ssh -i ~/.ssh/id_rsa -R $TUNNEL:localhost:$PORT -N -n $HOST"
                echo "PID: $pid"
            else
                echo $pid
            fi
            echo "$pid" > $PIDFILE
            exec ssh -i ~/.ssh/id_rsa -R $TUNNEL:localhost:$PORT -N -n $HOST
	    # XXX Clear the PID file somehow?
	    ;;
        foreground)
            local pid=$$
            if [ -z "$verbosity" -o "$verbosity" -ge 3 ]; then
                echo "> ssh -i ~/.ssh/id_rsa -R $TUNNEL:localhost:$PORT -N $HOST"
                echo "PID: $pid"
            else
                echo $pid
            fi
            echo "$pid" > $PIDFILE
            exec ssh -i ~/.ssh/id_rsa -R $TUNNEL:localhost:$PORT -N $HOST
	    # XXX Clear the PID file somehow?
	    ;;
        *)
            >&2 echo "ERROR: unsupported mode '$mode'"
            exit 1
	    ;;
    esac
}


##################################
# the script

verbosity=3
mode="orphan"
while [ "$#" -gt 0 ]; do
    arg=$1
    shift
    case "$arg" in
	-v|--verbose)
            verbosity=$((verbosity + 1))
	    ;;
	-q|--quiet)
            verbosity=$((verbosity - 1))
	    ;;
        --daemon)
            mode='daemon'
	    ;;
        --orphan)
            mode='orphan'
	    ;;
        --dead)
            mode='dead'
	    ;;
        --foreground)
            mode='foreground'
	    ;;
        *)
            >&2 echo "unknown arg '$arg'"
            exit 1
	    ;;
    esac
done

echo "creating an SSH tunnel to $HOST:$PORT (exposed as port $TUNNEL)..."
pid=$(check-pid-file $verbosity)
if [ "$pid" -gt 0 ]; then
    if [ "$verbosity" -ge 3 ]; then
        >&2 echo "ERROR: the SSH tunnel is already running"
        echo "PID: $pid"
    else
        echo $pid
    fi
    exit 1
fi

start-tunnel $mode $verbosity
