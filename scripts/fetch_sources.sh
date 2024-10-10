#!/usr/bin/env bash
set -o errexit -o nounset

AWS_LC_VERSION=${AWS_LC_VERSION:?AWS_LC_VERSION is not set}
HAPROXY_VERSION=${HAPROXY_VERSION:?HAPROXY_VERSION is not set}
SOURCES_DIR=${SOURCES_DIR:-.}

download_aws_lc () {
  if [ ! -f "${SOURCES_DIR}/aws-lc-${AWS_LC_VERSION}.tar.gz" ]; then
      mkdir -p "${SOURCES_DIR}"
      curl -s -L -o "${SOURCES_DIR}/aws-lc-${AWS_LC_VERSION}.tar.gz" \
        "https://github.com/aws/aws-lc/archive/refs/tags/v${AWS_LC_VERSION}.tar.gz"
  fi
}

download_haproxy () {
  if [ ! -f "${SOURCES_DIR}/haproxy-${HAPROXY_VERSION}.tar.gz" ]; then
      mkdir -p "${SOURCES_DIR}"
      curl -s -L -o "${SOURCES_DIR}/haproxy-${HAPROXY_VERSION}.tar.gz" \
        "https://www.haproxy.org/download/${HAPROXY_VERSION%.*}/src/haproxy-${HAPROXY_VERSION}.tar.gz"
  fi
}

download_aws_lc
download_haproxy
