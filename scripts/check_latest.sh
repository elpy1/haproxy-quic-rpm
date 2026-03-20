#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)

curl_fetch() {
  curl --fail --show-error --silent --location --retry 3 "$@"
}

make_release_var() {
  local key=${1:?missing key}
  make -s -C "${REPO_ROOT}" print-release-env | sed -n "s/^${key}='\(.*\)'$/\1/p"
}

latest_aws_lc_version() {
  local final_url
  final_url=$(curl_fetch -o /dev/null -w '%{url_effective}' "https://github.com/aws/aws-lc/releases/latest")
  basename "${final_url}" | sed 's/^v//'
}

latest_haproxy_version() {
  local current_version=${1:?missing haproxy version}
  local series=${current_version%.*}

  curl_fetch "https://www.haproxy.org/download/${series}/src/releases.json" \
    | python3 -c 'import json, sys; print(json.load(sys.stdin)["latest_release"])'
}

CURRENT_AWS_LC_VERSION=$(make_release_var AWS_LC_VERSION)
CURRENT_HAPROXY_VERSION=$(make_release_var HAPROXY_VERSION)

printf 'haproxy (%s): current=%s latest=%s\n' \
  "${CURRENT_HAPROXY_VERSION%.*}" \
  "${CURRENT_HAPROXY_VERSION}" \
  "$(latest_haproxy_version "${CURRENT_HAPROXY_VERSION}")"
printf 'aws-lc:        current=%s latest=%s\n' \
  "${CURRENT_AWS_LC_VERSION}" \
  "$(latest_aws_lc_version)"
