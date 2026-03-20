#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail

AWS_LC_VERSION=${AWS_LC_VERSION:?AWS_LC_VERSION is not set}
HAPROXY_VERSION=${HAPROXY_VERSION:?HAPROXY_VERSION is not set}
SOURCES_DIR=${SOURCES_DIR:-.}

curl_download() {
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

archive_top_level_dir() {
  local archive=${1:?missing archive}

  python3 -c 'import sys, tarfile
with tarfile.open(sys.argv[1], "r:gz") as archive:
    for member in archive:
        top = member.name.split("/", 1)[0]
        if top:
            print(top)
            break
    else:
        raise SystemExit("archive is empty")' "${archive}"
}

verify_archive_structure() {
  local archive=${1:?missing archive}
  local expected_top_level=${2:?missing expected top-level directory}
  local actual_top_level

  actual_top_level=$(archive_top_level_dir "${archive}")
  if [[ "${actual_top_level}" != "${expected_top_level}" ]]; then
    printf 'unexpected archive layout in %s: expected %s, got %s\n' \
      "${archive}" \
      "${expected_top_level}" \
      "${actual_top_level:-<empty>}" \
      >&2
    exit 1
  fi
}

haproxy_release_field() {
  local field=${1:?missing field}

  curl --fail --show-error --silent --location --retry 3 \
    "https://www.haproxy.org/download/${HAPROXY_VERSION%.*}/src/releases.json" \
    | python3 -c 'import json, sys; version, field = sys.argv[1:3]; print(json.load(sys.stdin)["releases"][version][field])' \
        "${HAPROXY_VERSION}" \
        "${field}"
}

verify_haproxy_archive() {
  local archive=${1:?missing archive}
  local expected_sha
  local actual_sha

  verify_archive_structure "${archive}" "haproxy-${HAPROXY_VERSION}"

  expected_sha=$(haproxy_release_field sha256)
  actual_sha=$(sha256sum "${archive}" | awk '{print $1}')
  if [[ "${actual_sha}" != "${expected_sha}" ]]; then
    printf 'sha256 mismatch for %s: expected %s, got %s\n' \
      "${archive}" \
      "${expected_sha}" \
      "${actual_sha}" \
      >&2
    exit 1
  fi
}

download_aws_lc() {
  local archive="${SOURCES_DIR}/aws-lc-${AWS_LC_VERSION}.tar.gz"

  mkdir -p "${SOURCES_DIR}"
  if [[ ! -f "${archive}" ]]; then
    curl_download \
      "https://github.com/aws/aws-lc/archive/refs/tags/v${AWS_LC_VERSION}.tar.gz" \
      "${archive}"
  fi

  verify_archive_structure "${archive}" "aws-lc-${AWS_LC_VERSION}"
}

download_haproxy() {
  local archive="${SOURCES_DIR}/haproxy-${HAPROXY_VERSION}.tar.gz"

  mkdir -p "${SOURCES_DIR}"
  if [[ ! -f "${archive}" ]]; then
    curl_download \
      "https://www.haproxy.org/download/${HAPROXY_VERSION%.*}/src/haproxy-${HAPROXY_VERSION}.tar.gz" \
      "${archive}"
  fi

  verify_haproxy_archive "${archive}"
}

download_aws_lc
download_haproxy
