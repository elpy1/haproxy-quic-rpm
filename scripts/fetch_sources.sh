#!/usr/bin/env bash
set -o errexit -o nounset

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

# don't need on el9
download_lua () {
  if [ ! -f "${SOURCES_DIR}/lua-${LUA_VERSION}.tar.gz" ]; then
      mkdir -p "${SOURCES_DIR}"
      curl -s -L -o "${SOURCES_DIR}/lua-${LUA_VERSION}.tar.gz" \
        "https://www.lua.org/ftp/lua-${LUA_VERSION}.tar.gz"
  fi
}

# don't need on el9
download_pcre2 () {
  if [ ! -f "${SOURCES_DIR}/pcre2-${PCRE2_VERSION}.tar.gz" ]; then
      mkdir -p "${SOURCES_DIR}"
      curl -s -L -o "${SOURCES_DIR}/pcre2-${PCRE2_VERSION}.tar.gz" \
        "https://github.com/PCRE2Project/pcre2/archive/refs/tags/pcre2-${PCRE2_VERSION}.tar.gz"
  fi
}

download_aws_lc
download_haproxy
