SHELL := /bin/bash
CWD := $(realpath $(shell dirname $(firstword $(MAKEFILE_LIST))))

AWS_LC_VERSION ?= 1.64.0
HAPROXY_VERSION ?= 3.2.8

SOURCES_DIR = $(CWD)/SOURCES
APP_NAME = el9builder
WORK_DIR = /home/builder/rpmbuild

export AWS_LC_VERSION HAPROXY_VERSION SOURCES_DIR

docker-build: ## Build the docker container (required for building the RPM)
	docker build -t $(APP_NAME) .

docker-build-nc: ## Build the container without caching
	docker build --no-cache -t $(APP_NAME) .

docker-run: ## Run the docker container (useful for manual testing)
	docker run --rm -i -t \
		--tmpfs /tmp:rw,exec \
		--mount type=bind,src="$(CWD)",dst="$(WORK_DIR)" \
		$(APP_NAME) /bin/bash

fetch-sources: ## Fetch sources required for the RPM build
	scripts/fetch_sources.sh

rpm-build: ## Build the RPM inside docker container
	docker run --rm -i \
        --tmpfs /tmp:rw,exec \
        --mount type=bind,src="$(CWD)",dst="$(WORK_DIR)" \
        $(APP_NAME) make rpm-build-local

rpm-build-local: fetch-sources ## Build the RPM locally
	rpmbuild -ba \
		--define "_tmppath /tmp" \
		--define "_builddir /tmp/BUILD" \
		--define "_buildrootdir /tmp/BUILDROOT " \
		--define "haproxy_version $(HAPROXY_VERSION)" \
		--define "aws_lc_version $(AWS_LC_VERSION)" \
		SPECS/haproxy.spec

clean-rpm: ## Clean all previously built RPMs and SRPMs
	rm -rf RPMS SRPMS

clean-sources: ## Clean all previously downloaded RPM source files
	rm -f SOURCES/{aws-lc,haproxy,lua,pcre2}-*.tar.gz
	rm -f SOURCES/{aws-lc,haproxy,lua,pcre2}-*.tgz

clean-all: clean-rpm clean-sources ## Clean all the things

help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage: make <command>\n\nCommands:\033[36m\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help
.PHONY: docker-build docker-build-nc docker-run fetch-sources rpm-build rpm-build-local clean-rpm clean-sources clean-all help

