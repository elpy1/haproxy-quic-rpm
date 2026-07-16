#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "${REPO_ROOT}"

eval "$(make --silent print-release-env)"

OUTPUT_DIR=${1:-"${RELEASE_DIR}"}

rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

rpm_nvr="${HAPROXY_VERSION}-${PACKAGE_RELEASE}.aws_lc.${AWS_LC_VERSION}.${SUPPORTED_DISTRO}"
main_rpm="RPMS/${SUPPORTED_ARCH}/${PACKAGE_NAME}-${rpm_nvr}.${SUPPORTED_ARCH}.rpm"
source_rpm="SRPMS/${PACKAGE_NAME}-${rpm_nvr}.src.rpm"

if [[ ! -f "${main_rpm}" || ! -f "${source_rpm}" ]]; then
    printf 'Missing expected RPM artifacts for %s-%s. Run make rpm-build first.\n' \
        "${PACKAGE_NAME}" "${rpm_nvr}" >&2
    exit 1
fi

shopt -s nullglob
subpackages=(
    RPMS/"${SUPPORTED_ARCH}"/"${PACKAGE_NAME}"-*-"${rpm_nvr}.${SUPPORTED_ARCH}.rpm"
)
rpm_files=("${main_rpm}" "${subpackages[@]}" "${source_rpm}")

cp -p "${rpm_files[@]}" "${OUTPUT_DIR}/"

(
    cd "${OUTPUT_DIR}"
    sha256sum ./*.rpm > SHA256SUMS
)

cat > "${OUTPUT_DIR}/release-notes.md" <<EOF
HAProxy version: ${HAPROXY_VERSION}
AWS-LC version: ${AWS_LC_VERSION}
Supported distro: ${SUPPORTED_DISTRO}
Supported architecture: ${SUPPORTED_ARCH}

This release is built from the tag \`${RELEASE_TAG}\`.

Attached assets:
- Binary RPM
- Source RPM
- SHA256SUMS

Installation:
\`\`\`bash
sudo dnf install ./<binary-rpm-from-this-release>
\`\`\`

No public DNF repository is published yet; install directly from the GitHub Release asset for now.
EOF

printf '%s\n' "${RELEASE_TITLE}" > "${OUTPUT_DIR}/release-title.txt"
