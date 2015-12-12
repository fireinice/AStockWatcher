#! /usr/bin/env bash
# Absolute path to this script, e.g. /home/user/bin/foo.sh
SCRIPT=$(readlink -f "$0")
# Absolute path this script is in, thus /home/user/bin
SCRIPT_PATH=$(dirname "$SCRIPT")
DATA_PATH="${SCRIPT_PATH}/data"

BASE_PATH=$(dirname "${SCRIPT_PATH}")
SPEC_PATH="${BASE_PATH}/spec"

echo -n "running spec ..."
rspec ${SPEC_PATH}/trending_calculator_spec.rb 1>${DATA_PATH}/out 2>&1
pid=$!
wait ${pid}
echo "done"

grep -v "Finished" ${DATA_PATH}/out > ${DATA_PATH}/out1
grep -v $(date +%F) ${DATA_PATH}/out1 > ${DATA_PATH}/out2

diff ${DATA_PATH}/out2 ${DATA_PATH}/000635

if [ "$?" != 0 ]; then
    echo "fail!"
else
    echo "success!"
fi

mv ${DATA_PATH}/out2 ${DATA_PATH}/out
rm ${DATA_PATH}/out1
