#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "${REPO_ROOT}"

eval "$(make --silent print-release-env)"

OUTPUT_DIR=${1:-"${RELEASE_DIR}"}

rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

shopt -s nullglob
rpm_files=(RPMS/x86_64/*.rpm SRPMS/*.rpm)

if [ ${#rpm_files[@]} -eq 0 ]; then
    printf 'No RPM artifacts found. Run make rpm-build first.\n' >&2
    exit 1
fi

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
