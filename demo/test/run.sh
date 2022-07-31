#!/usr/bin/env bash

K6_SCRIPT=${1:-"load-testing.js"}

if [[ ! -f "${K6_SCRIPT}" ]]; then
  echo "[ERROR] file not exist: ${K6_SCRIPT}"
fi

docker run --rm -i grafana/k6:0.39.0 run - <${K6_SCRIPT}

