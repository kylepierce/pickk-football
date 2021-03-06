#!/bin/bash

set -eux

DIRNAME=$(cd `dirname $0` && pwd)

ENV=${1:-}
if [ -z $ENV ]; then
  echo "Usage: $0 ENV"
  echo "ENV = [prod, stag]"
  exit 1
else
  shift
fi

HOST=root@do.pickk-$ENV

ssh $HOST 'pm2 status'
