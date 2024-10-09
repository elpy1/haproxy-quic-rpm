#!/usr/bin/env bash
set -o errexit -o nounset

get_latest_gh_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" \
  | grep '"tag_name":' \
  | sed -E 's/.*"([^"]+)".*/\1/'
}

printf 'aws-lc: %s\n' "$(get_latest_gh_release 'aws/aws-lc')"
printf 'lua:    %s\n' "$(get_latest_gh_release 'lua/lua')"
printf 'pcre2:  %s\n' "$(get_latest_gh_release 'PCRE2Project/pcre2')"
