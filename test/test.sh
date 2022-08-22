#!/usr/bin/bash

set -e

./lmm.sh help
./lmm.sh version
./lmm.sh list
./lmm.sh search

sudo true

if [ -n "${TEST_ROLE}" ]; then
  ./lmm.sh install ${TEST_ROLE}
  exit 0
fi

for d in ./roles/*; do
  ROLE="${d/'./roles/'/}"

  # shellcheck disable=SC2086
  ./lmm.sh install ${ROLE}
done

echo "DONE"
