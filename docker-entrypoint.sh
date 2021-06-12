#!/bin/sh
set -e

if [ $(echo "$1" | cut -c1) = "-" ]; then
	echo "$0: assuming arguments for bgoldd"
	set -- bgoldd "$@"
fi

# Allow the container to be started with `--user`, if running as root drop privileges
if [ "$1" = 'bgoldd' -a "$(id -u)" = '0' ]; then
	# Set perms on data
	echo "$0: detected bgoldd"
	mkdir -p "$DATADIR"
	chmod 700 "$DATADIR"
	chown -R btcgold "$DATADIR"
	exec gosu btcgold "$0" "$@" -datadir=$DATADIR
fi

if [ "$1" = 'bgoldd-cli' -a "$(id -u)" = '0' ] || [ "$1" = 'bitcoin-tx' -a "$(id -u)" = '0' ]; then
	echo "$0: detected bgoldd-cli or bitcoin-tx"
	exec gosu btcgold "$0" "$@" -datadir=$DATADIR
fi

# If not root (i.e. docker run --user $USER ...), then run as invoked
echo "$0: running exec"
exec "$@"
