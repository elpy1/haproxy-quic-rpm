#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail

if [[ "${TRACE:-0}" == "1" ]]; then
  set -x
fi

# We rely on system packages for lua and pcre2 but you can use this
# script if you want to manually source each (or use specific versions)
# before building haproxy

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)

make_release_var() {
  local key=${1:?missing key}
  make -s -C "${REPO_ROOT}" print-release-env | sed -n "s/^${key}='\(.*\)'$/\1/p"
}

AWS_LC_VERSION=${AWS_LC_VERSION:-$(make_release_var AWS_LC_VERSION)}
HAPROXY_VERSION=${HAPROXY_VERSION:-$(make_release_var HAPROXY_VERSION)}
LUA_VERSION=${LUA_VERSION:-5.4.7}
PCRE2_VERSION=${PCRE2_VERSION:-10.44}

BUILD_TMPDIR="${TMPDIR:-/tmp}"
SOURCES_DIR=${SOURCES_DIR:-"${REPO_ROOT}/SOURCES"}

download_source_archive() {
  local url=${1:?missing url}
  local destination=${2:?missing destination}
  local temp_file

  temp_file="${destination}.tmp.$$"
  rm -f "${temp_file}"

  curl --fail --show-error --silent --location --retry 3 \
    --output "${temp_file}" \
    "${url}"

  mv "${temp_file}" "${destination}"
}

cached_version() {
  local marker=${1:?missing marker}

  if [[ -f "${marker}" ]]; then
    cat "${marker}"
  fi
}

extract_source_archive() {
  local archive=${1:?missing archive}
  local destination_dir=${2:?missing destination directory}

  rm -rf "${destination_dir}"
  mkdir -p "${destination_dir}"
  tar zxf "${archive}" -C "${destination_dir}" --strip-components=1
}

download_packaged_sources() {
  AWS_LC_VERSION="${AWS_LC_VERSION}" \
  HAPROXY_VERSION="${HAPROXY_VERSION}" \
  SOURCES_DIR="${SOURCES_DIR}" \
    "${SCRIPT_DIR}/fetch_sources.sh"
}

download_aws_lc () {
  download_packaged_sources
}

download_lua () {
  local archive="${SOURCES_DIR}/lua-${LUA_VERSION}.tar.gz"

  mkdir -p "${SOURCES_DIR}"
  if [[ ! -f "${archive}" ]]; then
    download_source_archive \
      "https://www.lua.org/ftp/lua-${LUA_VERSION}.tar.gz" \
      "${archive}"
  fi
}

download_pcre2 () {
  local archive="${SOURCES_DIR}/pcre2-${PCRE2_VERSION}.tar.gz"

  mkdir -p "${SOURCES_DIR}"
  if [[ ! -f "${archive}" ]]; then
    download_source_archive \
      "https://github.com/PCRE2Project/pcre2/archive/refs/tags/pcre2-${PCRE2_VERSION}.tar.gz" \
      "${archive}"
  fi
}

download_haproxy () {
  download_packaged_sources
}

build_aws_lc () {
  if [[ "$(cached_version "${BUILD_TMPDIR}/.aws_lc-version")" != "${AWS_LC_VERSION}" ]]; then
      extract_source_archive \
        "${SOURCES_DIR}/aws-lc-${AWS_LC_VERSION}.tar.gz" \
        "${BUILD_TMPDIR}/aws-lc-${AWS_LC_VERSION}"
      (
         cd "${BUILD_TMPDIR}/aws-lc-${AWS_LC_VERSION}/"
         cmake -GNinja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="${BUILD_TMPDIR}" .
         ninja run_tests
         ninja install
      )
      echo "${AWS_LC_VERSION}" > "${BUILD_TMPDIR}/.aws_lc-version"
  fi
}

build_lua () {
  if [[ "$(cached_version "${BUILD_TMPDIR}/.lua-version")" != "${LUA_VERSION}" ]]; then
      extract_source_archive \
        "${SOURCES_DIR}/lua-${LUA_VERSION}.tar.gz" \
        "${BUILD_TMPDIR}/lua-${LUA_VERSION}"
      (
         cd "${BUILD_TMPDIR}/lua-${LUA_VERSION}/"
         make
         make install INSTALL_TOP="${BUILD_TMPDIR}"
      )
      echo "${LUA_VERSION}" > "${BUILD_TMPDIR}/.lua-version"
  fi
}

build_pcre2 () {
  if [[ "$(cached_version "${BUILD_TMPDIR}/.pcre2-version")" != "${PCRE2_VERSION}" ]]; then
      extract_source_archive \
        "${SOURCES_DIR}/pcre2-${PCRE2_VERSION}.tar.gz" \
        "${BUILD_TMPDIR}/pcre2-${PCRE2_VERSION}"
      (
         cd "${BUILD_TMPDIR}/pcre2-${PCRE2_VERSION}/"
         ./autogen.sh
         ./configure --prefix="${BUILD_TMPDIR}" --disable-shared --enable-jit # --enable-pcre2-16 --enable-pcre2-32
         make install
      )
      echo "${PCRE2_VERSION}" > "${BUILD_TMPDIR}/.pcre2-version"
  fi
}

build_haproxy () {
  if [[ "$(cached_version "${BUILD_TMPDIR}/.haproxy-version")" != "${HAPROXY_VERSION}" ]]; then
      extract_source_archive \
        "${SOURCES_DIR}/haproxy-${HAPROXY_VERSION}.tar.gz" \
        "${BUILD_TMPDIR}/haproxy-${HAPROXY_VERSION}"
      (
         cd "${BUILD_TMPDIR}/haproxy-${HAPROXY_VERSION}/"
         make clean
         make -j "$(nproc)" TARGET=linux-glibc \
          USE_TFO=1 USE_LINUX_TPROXY=1 \
          USE_GETADDRINFO=1 USE_PROMEX=1 \
          USE_LUA=1 USE_STATIC_PCRE2=1 USE_PCRE2_JIT=1 \
          USE_OPENSSL_AWSLC=1 USE_QUIC=1 USE_ZLIB=1 \
          LUA_INC="${BUILD_TMPDIR}/include" LUA_LIB="${BUILD_TMPDIR}/lib" \
          PCRE2_INC="${BUILD_TMPDIR}/include" PCRE2_LIB="${BUILD_TMPDIR}/lib" \
          SSL_INC="${BUILD_TMPDIR}/include" SSL_LIB="${BUILD_TMPDIR}/lib64" \
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
