#!/bin/bash
#
# Purpose: Run `eida-crawl-fdsnws-station`

ODC=www.orfeus-eu.org

BIN=/var/www/eidaws-federator/venv/bin/eida-crawl-fdsnws-station
PATH_VAR_LIB=/var/lib/eidaws
HISTORY=eida-crawl-fdsnws-station.history

# ODC is slow - crawl it separately
${BIN} --exclude-domain ${ODC} \
  --worker-pool-size 8 --timeout 30 \
  --history-json-load ${PATH_VAR_LIB}/${HISTORY} \
  --history-json-dump ${PATH_VAR_LIB}/${HISTORY}.new \
  --history-include-supplementary-epochs >> /dev/null &
pid=$!
${BIN} --domain ${ODC} \
  --worker-pool-size 8 --timeout 120 \
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
    --history-json-load ${PATH_VAR_LIB}/${HISTORY}.new \
    --history-by-status 500 502 503 504 429 204 404 >> /dev/null

  mv ${PATH_VAR_LIB}/${HISTORY}.new ${PATH_VAR_LIB}/${HISTORY}
fi

exit 0
