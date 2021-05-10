#!/bin/bash
#
# Purpose: Run `eida-crawl-fdsnws-station`

ODC=www.orfeus-eu.org

BIN=/var/www/eidaws-federator/venv/bin/eida-crawl-fdsnws-station
PATH_VAR_LIB=/var/lib/eidaws
HISTORY_BASE="eida-crawl-fdsnws-station"
HISTORY_SUFFIX=".history"
HISTORY="${HISTORY_BASE}${HISTORY_SUFFIX}"
PATH_HISTORY="${PATH_VAR_LIB}/${HISTORY}"

ERROR_STATUS="500 502 503 504 429 204 404"

create_if_no_history () {
  mkdir -p "$(dirname "${1}")"
  test -f "${1}" || echo "[]" > "${1}"
}

create_if_no_history "${PATH_HISTORY}"

# ODC is slow - crawl it separately
${BIN} --exclude-domain ${ODC} \
  --worker-pool-size 8 --timeout 30 \
  --history-json-load "${PATH_HISTORY}" \
  --history-json-dump "${PATH_HISTORY}.new" \
  --history-include-supplementary-epochs >> /dev/null &
pid=$!
${BIN} --domain ${ODC} \
  --worker-pool-size 6 --timeout 120 \
  --level network station \
  --sorted \
  -P /var/tmp/eida-crawl-fdsnws-station-odc.pid >> /dev/null &

# wait for the ODC crawling process
wait $!

# wait for the general crawling process
if wait ${pid}
then
  sleep 30m
  # recrawl history by error status
  ${BIN} --exclude-domain ${ODC} \
    --worker-pool-size 6 --timeout 120 \
    --history-json-load "${PATH_HISTORY}.new" \
    --history-by-status $(echo ${ERROR_STATUS}) >> /dev/null

  mv "${PATH_HISTORY}.new" "${PATH_HISTORY}"
fi

STL_SCHEMA="http"
STL_NETLOC="eidaws-stationlite:8089"
STL_PATH="/eidaws/routing/1/query"
STL_QUERY="level=network&service=station"

# crawl distributed physical networks
STL_URL="${STL_SCHEMA}://${STL_NETLOC}${STL_PATH}?${STL_QUERY}"
DISTRIBUTED_NETS=$(curl -s "${STL_URL}" | \
  grep -v -e '^http' | \
  sed '/^$/d' | \
  cut -d ' ' -f 1 | \
  sort | uniq -d | tr '\n' ' ' | xargs)

if [ ! -z "${DISTRIBUTED_NETS+x}" ]
then
  HISTORY_DISTRIBUTED_NETS="${HISTORY_BASE}-distributed-nets${HISTORY_SUFFIX}"
  PATH_HISTORY="${PATH_VAR_LIB}/${HISTORY_DISTRIBUTED_NETS}"
  create_if_no_history "${PATH_HISTORY}"

  sleep 15m
  ${BIN} --worker-pool-size 6 --timeout 120 \
    --network $(echo ${DISTRIBUTED_NETS}) \
    --history-json-load "${PATH_HISTORY}" \
    --history-json-dump "${PATH_HISTORY}.new" \
    --history-include-supplementary-epochs >> /dev/null

  if [ $? -eq 0 ]
  then
    sleep 30m
    # recrawl distributed physical network history by error status
    ${BIN} --worker-pool-size 6 --timeout 120 \
      --network $(echo ${DISTRIBUTED_NETS}) \
      --history-json-load "${PATH_HISTORY}.new" \
      --history-by-status $(echo ${ERROR_STATUS}) >> /dev/null

    mv "${PATH_HISTORY}.new" "${PATH_HISTORY}"
  fi
fi

exit 0
