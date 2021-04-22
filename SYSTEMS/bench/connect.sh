#!/usr/bin/env bash

BENCH_ROOT=$HOME/BENCH
TUNNEL_SCRIPT=$BENCH_ROOT/tunnel.sh

SESSION="portal"
SESSION_CONFIG=$BENCH_ROOT/tunnel.tmux
CLIENTID=$SESSION-`date +%S`

pidfile="$HOME/tunnel.pid"
if [ ! -e "$pidfile" ]; then
    pid=$(cat $pidfile)
    if [ -n "$pid" ] && &>/dev/null ps -q "$pid"; then
        >&2 echo "a tunnel is already running (PID: $pid)"
        exit 1
    fi
    rm $pidfile
fi

if $(&>/dev/null tmux has-session -t $SESSION); then
    echo "(background terminal already running)"
    INITIALIZE=
else
    echo "starting background terminal..."
    tmux new-session -d -s $SESSION

    INITIALIZE="source $SESSION_CONFIG"
    #INITIALIZE='new-window -k -c $HOME -n portal-tunnel -t 0 \; send-keys "'$TUNNEL_SCRIPT'" C-m'
fi

echo "connecting..."
tmux new-session -d -t $SESSION -s $CLIENTID \; set-option destroy-unattached \; attach-session -t $CLIENTID \; $INITIALIZE
