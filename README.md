# haproxy-quic-rpm
Build RPM for haproxy with HTTP/3 support. Built and tested on Rocky Linux 9.

## Usage

### Build
First, build the docker image that we'll use for building the RPM:
```
make docker-build
```

Build the RPM inside the docker container:
```
make rpm-build
```

Clean up and remove all artifacts from the build:
```
make clean-all
```

### Help
Run `make help` for more information:
```
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

