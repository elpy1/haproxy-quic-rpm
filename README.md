# haproxy-quic-rpm
Build RPM for haproxy 3.2 (LTS) with HTTP/3 support. Built, tested and actively running on Rocky Linux 9.

| Package name | Supported distributions | Includes |
| --- | --- | --- |
| haproxy-quic | el9 | [AWS-LC](https://github.com/aws/aws-lc) 1.71.0 |


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
or, if you wish to specify a different version of `haproxy` or `AWS-LC`:
```bash
make rpm-build HAPROXY_VERSION=3.2.15 AWS_LC_VERSION=1.71.0
```
If you need to rebuild the same `haproxy` version for a new AWS-LC bundle or a packaging-only change, increment `PACKAGE_RELEASE`:
```bash
make rpm-build HAPROXY_VERSION=3.2.15 AWS_LC_VERSION=1.71.0 PACKAGE_RELEASE=2
```

Clean up and remove all artifacts from the build:
```bash
make clean-all
```

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

### Help
Run `make help` for more information:
```bash
$ make

Usage: make <command>

Commands:
  docker-build     Build the docker container (required for building the RPM)
  docker-build-nc  Build the container without caching
  docker-run       Run the docker container (useful for manual testing)
  fetch-sources    Fetch sources required for the RPM build
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
The RPM build above relies on system packages for `lua` and `pcre2`. If you need to source these manually or want a specific version for your build, you can use the `manual_build.sh` script in the `scripts` directory.

## Post-build
After building, you should have the RPM and SRPM files saved locally in you repo:
```
$ tree {,S}RPMS
RPMS
└── x86_64
    └── haproxy-quic-3.2.15-1.aws_lc.1.71.0.el9.x86_64.rpm
SRPMS
└── haproxy-quic-3.2.15-1.aws_lc.1.71.0.el9.src.rpm
```
### Installation
To install on a RHEL9 machine, use `dnf` to install the package from a local build or downloaded GitHub Release asset:
```
dnf install /path/to/haproxy-quic-3.2.15-1.aws_lc.1.71.0.el9.x86_64.rpm
```
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
To confirm you can access haproxy stats locally:
```
curl localhost:9000/stats
```

### Configuring haproxy
The packaged service validates `/etc/haproxy/haproxy.cfg` plus any `*.cfg` snippets in `/etc/haproxy/conf.d/` on start and reload.

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
    server  app1 127.0.0.1:5001 check
    server  app2 127.0.0.1:5002 check
```
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
