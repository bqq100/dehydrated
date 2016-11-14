#!/usr/bin/env bash

# Get directory script was called from
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-which-directory-it-is-stored-in
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPTDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

cd $SCRIPTDIR

# Err on the side of caution to make sure private keys are only readable to owner
umask 0277

# Only allow 1 execution at a time in case a long running process is waiting for manual dns-01 validation
SCRIPT=$(basename "$0")
RUNNING=$(pgrep -fl "$SCRIPT" | wc -l)
if [ $RUNNING -gt 2 ]; then
    echo "$SCRIPT is already running... Exiting..."
    exit
fi

# If asking for help or env variables, quit afterwards
if [ $# = 1 ]; then
    if [ "$1" = "-h" -o "$1" = "--help" -o "$1" = "-e" -o "$1" = "--env" ]; then
        $SCRIPTDIR/dehydrated $@
        exit
    fi
fi

# If no parameters specify, default to "-c -g", otherwise run with passed in parameters
if [ $# = 0 ]; then
    $SCRIPTDIR/dehydrated -c -g 
else
    $SCRIPTDIR/dehydrated $@
fi

# Ensure proper permissions
find $SCRIPTDIR -type d -exec chmod 755 {} \;
find $SCRIPTDIR -name 'cert-*pem' -exec chmod 444 {} \;
find $SCRIPTDIR -name 'chain-*pem' -exec chmod 444 {} \;
find $SCRIPTDIR -name 'fullchain-*pem' -exec chmod 444 {} \;
find $SCRIPTDIR -name 'cert-*csr' -exec chmod 400 {} \;
find $SCRIPTDIR -name 'privkey-*pem' -exec chmod 400 {} \;

# Archive old certificates
$SCRIPTDIR/dehydrated -gc;

# Delete really old certficates
find $SCRIPTDIR/ -mtime 365 -type f -exec rm -f {} \;