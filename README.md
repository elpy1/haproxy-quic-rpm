# haproxy-quic-rpm
Build RPM for haproxy 3.0 with HTTP/3 support. Built and tested on Rocky Linux 9.

| Package name | Supported distributions | Includes |
| --- | --- | --- |
| haproxy-quic | el9 | [AWS-LC](https://github.com/aws/aws-lc) 1.36.1 |


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
make rpm-build HAPROXY_VERSION=3.0.3 AWS_LC_VERSION=1.36.1
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
