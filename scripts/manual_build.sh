#!/usr/bin/env bash 
set -o errexit -o nounset
set -x

# We rely on system packages for lua and pcre2 but you can use this
# script if you want to manually source each (or use specfic versions)
# before building haproxy

AWS_LC_VERSION=1.36.1
HAPROXY_VERSION=3.0.5
LUA_VERSION=5.4.7
PCRE2_VERSION=10.44

BUILD_TMPDIR="${TMPDIR:-/tmp}"
SOURCES_DIR="."

download_aws_lc () {
  if [ ! -f "${SOURCES_DIR}/aws-lc-${AWS_LC_VERSION}.tar.gz" ]; then
      mkdir -p "${SOURCES_DIR}"
      curl -s -L -o "${SOURCES_DIR}/aws-lc-${AWS_LC_VERSION}.tar.gz" \
        "https://github.com/aws/aws-lc/archive/refs/tags/v${AWS_LC_VERSION}.tar.gz"
  fi
}

download_lua () {
  if [ ! -f "${SOURCES_DIR}/lua-${LUA_VERSION}.tar.gz" ]; then
      mkdir -p "${SOURCES_DIR}"
      curl -s -L -o "${SOURCES_DIR}/lua-${LUA_VERSION}.tar.gz" \
        "https://www.lua.org/ftp/lua-${LUA_VERSION}.tar.gz"
  fi
}

download_pcre2 () {
  if [ ! -f "${SOURCES_DIR}/pcre2-${PCRE2_VERSION}.tar.gz" ]; then
      mkdir -p "${SOURCES_DIR}"
      curl -s -L -o "${SOURCES_DIR}/pcre2-${PCRE2_VERSION}.tar.gz" \
        "https://github.com/PCRE2Project/pcre2/archive/refs/tags/pcre2-${PCRE2_VERSION}.tar.gz"
  fi
}

download_haproxy () {
  if [ ! -f "${SOURCES_DIR}/haproxy-${HAPROXY_VERSION}.tar.gz" ]; then
      mkdir -p "${SOURCES_DIR}"
      curl -s -L -o "${SOURCES_DIR}/haproxy-${HAPROXY_VERSION}.tar.gz" \
        "https://www.haproxy.org/download/${HAPROXY_VERSION%.*}/src/haproxy-${HAPROXY_VERSION}.tar.gz"
  fi
}

build_aws_lc () {
  if [ "$(cat ${BUILD_TMPDIR}/.aws_lc-version)" != "${AWS_LC_VERSION}" ]; then
      mkdir -p "${BUILD_TMPDIR}/aws-lc-${AWS_LC_VERSION}/"
      tar zxf "${SOURCES_DIR}/aws-lc-${AWS_LC_VERSION}.tar.gz" -C "${BUILD_TMPDIR}/aws-lc-${AWS_LC_VERSION}/" --strip-components=1
      (
         cd "${BUILD_TMPDIR}/aws-lc-${AWS_LC_VERSION}/"
         cmake -GNinja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=${BUILD_TMPDIR} .
         ninja run_tests
         ninja install
      )
      echo "${AWS_LC_VERSION}" > "${BUILD_TMPDIR}/.aws_lc-version"
  fi
}

build_lua () {
  if [ "$(cat ${BUILD_TMPDIR}/.lua-version)" != "${LUA_VERSION}" ]; then
      mkdir -p "${BUILD_TMPDIR}/lua-${LUA_VERSION}/"
      tar zxf "${SOURCES_DIR}/lua-${LUA_VERSION}.tar.gz" -C "${BUILD_TMPDIR}/lua-${LUA_VERSION}/" --strip-components=1
      (
         cd "${BUILD_TMPDIR}/lua-${LUA_VERSION}/"
         make
         make install INSTALL_TOP=${BUILD_TMPDIR}
      )
      echo "${LUA_VERSION}" > "${BUILD_TMPDIR}/.lua-version"
  fi
}

build_pcre2 () {
  if [ "$(cat ${BUILD_TMPDIR}/.pcre2-version)" != "${PCRE2_VERSION}" ]; then
      mkdir -p "${BUILD_TMPDIR}/pcre2-${PCRE2_VERSION}/"
      tar zxf "${SOURCES_DIR}/pcre2-${PCRE2_VERSION}.tar.gz" -C "${BUILD_TMPDIR}/pcre2-${PCRE2_VERSION}/" --strip-components=1
      (
         cd "${BUILD_TMPDIR}/pcre2-${PCRE2_VERSION}/"
         ./autogen.sh
         ./configure --prefix=${BUILD_TMPDIR} --disable-shared --enable-jit # --enable-pcre2-16 --enable-pcre2-32
         make install
      )
      echo "${PCRE2_VERSION}" > "${BUILD_TMPDIR}/.pcre2-version"
  fi
}

build_haproxy () {
  if [ "$(cat ${BUILD_TMPDIR}/.haproxy-version)" != "${HAPROXY_VERSION}" ]; then
      mkdir -p "${BUILD_TMPDIR}/haproxy-${HAPROXY_VERSION}/"
      tar zxf "${SOURCES_DIR}/haproxy-${HAPROXY_VERSION}.tar.gz" -C "${BUILD_TMPDIR}/haproxy-${HAPROXY_VERSION}/" --strip-components=1
      (
         cd "${BUILD_TMPDIR}/haproxy-${HAPROXY_VERSION}/"
         make clean
         make -j $(nproc) TARGET=linux-glibc \
          USE_TFO=1 USE_LINUX_TPROXY=1 USE_SYSTEMD=1 \
          USE_GETADDRINFO=1 USE_PROMEX=1 \
          USE_LUA=1 USE_STATIC_PCRE2=1 USE_PCRE2_JIT=1 \
          USE_OPENSSL_AWSLC=1 USE_QUIC=1 USE_ZLIB=1 \
          LUA_INC=${BUILD_TMPDIR}/include LUA_LIB=${BUILD_TMPDIR}/lib \
          PCRE2_INC=${BUILD_TMPDIR}/include PCRE2_LIB=${BUILD_TMPDIR}/lib \
          SSL_INC=${BUILD_TMPDIR}/include SSL_LIB=${BUILD_TMPDIR}/lib64 \
          all
      )
      echo "${HAPROXY_VERSION}" > "${BUILD_TMPDIR}/.haproxy-version"
  fi
}

download_aws_lc
download_haproxy
download_lua
download_pcre2

build_aws_lc
build_lua
build_pcre2
build_haproxy

