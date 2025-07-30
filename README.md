# haproxy-quic-rpm
Build RPM for haproxy 3.2 with HTTP/3 support. Built, tested and actively running on Rocky Linux 9.

| Package name | Supported distributions | Includes |
| --- | --- | --- |
| haproxy-quic | el9 | [AWS-LC](https://github.com/aws/aws-lc) 1.56.0 |


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
make rpm-build HAPROXY_VERSION=3.2.3 AWS_LC_VERSION=1.56.0
```

Clean up and remove all artifacts from the build:
```bash
make clean-all
```

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
  clean-rpm        Clean all previously built RPMs and SRPMs
  clean-sources    Clean all previously downloaded RPM source files
  clean-all        Clean all the things
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
    └── haproxy-quic-3.2.3-1.el9.x86_64.rpm
SRPMS
└── haproxy-quic-3.2.3-1.el9.src.rpm
```
### Installation
To install on a RHEL9 machine, use `dnf` to install the package:
```
dnf install /path/to/haproxy-quic-3.2.3-1.el9.x86_64.rpm
```
Verify `haproxy` installation (use `-vv` to display build information):
```
$ haproxy -v
HAProxy version 3.2.3-1844da7 2025/07/09 - https://haproxy.org/
Status: long-term supported branch - will stop receiving fixes around Q2 2030.
Known bugs: http://www.haproxy.org/bugs/bugs-3.2.3.html
Running on: Linux 5.14.0-427.37.1.el9_4.x86_64 #1 SMP PREEMPT_DYNAMIC Wed Sep 25 11:51:41 UTC 2024 x86_64
```
To enable and start the systemd service:
```
systemctl start --now haproxy
```
To check the service status:
```
systemctl status haproxy
```
To confirm you can access haproxy stats locally:
```
curl localhost:9000/stats
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
    server  app1 127.0.0.1:5001 check
    server  app2 127.0.0.1:5002 check
```
**NOTE**: Remember to update your firewall to allow UDP traffic on port 443!!

To reload haproxy configuration:
```
systemctl reload haproxy
```
