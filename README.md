# haproxy-quic-rpm
RPM packaging for HAProxy 3.2 (LTS) with HTTP/3 support on RHEL9, built against AWS-LC.

| Package name | Supported distributions | Includes |
| --- | --- | --- |
| haproxy-quic | el9 | [AWS-LC](https://github.com/aws/aws-lc) 1.71.0 |

## Project scope
- This repository builds and publishes the `haproxy-quic` RPM for `el9` `x86_64`.
- The package is intended as a drop-in replacement for distro `haproxy`, not a side-by-side install.
- Public artifacts are currently distributed through GitHub Releases only.
- Build and runtime validation are currently focused on Rocky Linux 9.

## Prerequisites
- `docker`: Ensure Docker is installed and running.
- `make`: You need GNU Make to run the Makefile commands.

## Usage
### Build
First, build the docker image that we'll use for building the RPM:
```bash
make docker-build
```

To build the RPM inside the docker container:
```bash
make rpm-build
```
or, if you wish to specify a different version of `haproxy` or `AWS-LC` (use `make check-latest` to compare the pinned haproxy/AWS-LC versions with upstream latest releases):
```bash
make rpm-build HAPROXY_VERSION=3.2.15 AWS_LC_VERSION=1.71.0
```
If you need to rebuild the same `haproxy` version for a new `AWS-LC` bundle or a packaging-only change, increment `PACKAGE_RELEASE`:
```bash
make rpm-build HAPROXY_VERSION=3.2.15 AWS_LC_VERSION=1.71.0 PACKAGE_RELEASE=2
```

Clean up and remove all artifacts from the build:
```bash
make clean-all
```

### Post-build
After building, you should have the RPM and SRPM files saved locally in your repo:
```
$ tree {,S}RPMS
RPMS
└── x86_64
    └── haproxy-quic-3.2.15-1.aws_lc.1.71.0.el9.x86_64.rpm
SRPMS
└── haproxy-quic-3.2.15-1.aws_lc.1.71.0.el9.src.rpm
```

### Help
Run `make help` for more information:
```bash
$ make help

Usage: make <command>

Commands:
  docker-build     Build the docker container (required for building the RPM)
  docker-build-nc  Build the container without caching
  docker-run       Run the docker container (useful for manual testing)
  fetch-sources    Fetch sources required for the RPM build
  check-latest     Compare pinned haproxy/AWS-LC versions with upstream latest releases
  rpm-build        Build the RPM inside docker container
  rpm-build-local  Build the RPM locally
  release-bundle   Build RPM/SRPM assets and assemble a GitHub Release bundle
  clean-rpm        Clean all previously built RPMs and SRPMs
  clean-sources    Clean all previously downloaded RPM source files
  clean-release    Clean generated GitHub Release bundle assets
  clean-all        Clean all the things
  print-release-env Print release metadata as shell assignments
  help             Display this help
```

### Manual build
The RPM build above relies on system packages for `lua` and `pcre2`. If you need to source these manually or want specific versions for a local build, you can use `scripts/manual_build.sh`. By default it picks up the repo's current haproxy and AWS-LC versions from `Makefile`. Be sure to check the build flags and edit as needed. 

### GitHub Releases
For now, public artifacts are distributed through GitHub Releases rather than a hosted DNF repository.

Each release will include:
- an `el9` `x86_64` binary RPM
- the matching SRPM
- a `SHA256SUMS` file for the attached assets

Tags should use the form `v<HAPROXY_VERSION>-aws-lc-<AWS_LC_VERSION>`, for example `v3.2.15-aws-lc-1.71.0`.

To build the exact bundle used by the release workflow locally:
```bash
make docker-build
make release-bundle
```

The resulting artifacts will be written to `release-artifacts/`.


## Installation
Install on an `el9` host from a local build or a downloaded GitHub Release asset:
```
dnf install /path/to/haproxy-quic-3.2.15-1.aws_lc.1.71.0.el9.x86_64.rpm
```

The package `Conflicts` with and `Obsoletes` the distro `haproxy` package, so `dnf` will replace an existing `haproxy` install rather than attempt a side-by-side install.

Verify `haproxy` installation (use `-vv` to display build information):
```
$ haproxy -v
HAProxy version 3.2.15-04ef5bd69 2026/03/19 - https://haproxy.org/
Status: long-term supported branch - will stop receiving fixes around Q2 2030.
Known bugs: http://www.haproxy.org/bugs/bugs-3.2.15.html
Running on: Linux 5.14.0-611.16.1.el9_7.x86_64 #1 SMP PREEMPT_DYNAMIC Mon Dec 22 12:21:56 UTC 2025 x86_64
```
To enable and start the systemd service:
```
systemctl enable --now haproxy
```
To check the service status:
```
systemctl status haproxy
```
To inspect HAProxy logs from the packaged systemd service:
```
journalctl -u haproxy -e
```

The packaged service validates `/etc/haproxy/haproxy.cfg` plus any `*.cfg` snippets in `/etc/haproxy/conf.d/` on start and reload, and logs to journald by default.
The installed default configuration exposes only a local stats page plus an admin socket; add your real frontends and backends in `/etc/haproxy/haproxy.cfg` or `/etc/haproxy/conf.d/*.cfg`.

To confirm you can access haproxy stats locally:
```
curl localhost:9000/stats
```

To inspect the packaged admin socket:
```
echo "show info" | socat - UNIX-CONNECT:/run/haproxy/admin.sock
```

### Configuring haproxy
To enable HTTP/3, update `/etc/haproxy/haproxy.cfg`:
```
frontend default-https
    bind :443 ssl crt /path/to/certs/mycerts.pem alpn h2,http/1.1 allow-0rtt
    bind quic4@:443 ssl crt /path/to/certs/mycerts.pem alpn h3 allow-0rtt

    # HTTP/3 (QUIC)
    http-after-response add-header alt-svc 'h3=":443"; ma=86400'

    # HSTS(HTTP Strict Transport Security)
    #http-response set-header Strict-Transport-Security max-age=63072000

    # Backend
    default_backend default-http

backend default-http
    # Balancer type
    balance     roundrobin

    # Backend servers
    server  app1 127.0.0.1:5001
    server  app2 127.0.0.1:5002
```
For explicit TLS cipher and protocol policy, set it in your own frontend/backend configuration rather than relying on the packaged baseline. The [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/) is a good starting point for haproxy-specific TLS settings, but you should validate the result against client-compatibility.

**NOTE**: Remember to update your firewall to allow UDP traffic on port 443!!

To reload haproxy configuration:
```
systemctl reload haproxy
```

Release workflow details are documented in `RELEASING.md`.

## Versioning
`Version` follows HAProxy. `Release` carries the packaging iteration plus the bundled AWS-LC version:

```text
<package_release>.aws_lc.<aws_lc_version>%{?dist}
```

Examples:
- `haproxy-quic-3.2.15-1.aws_lc.1.71.0.el9`
- `haproxy-quic-3.2.15-2.aws_lc.1.72.0.el9`
- `haproxy-quic-3.2.15-3.aws_lc.1.72.0.el9`

While `HAPROXY_VERSION` stays the same, the leading `PACKAGE_RELEASE` value must keep increasing.
