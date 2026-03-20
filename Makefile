SHELL := /bin/bash
CWD := $(realpath $(shell dirname $(firstword $(MAKEFILE_LIST))))
HOST_UID ?= $(shell id -u)
HOST_GID ?= $(shell id -g)

PACKAGE_RELEASE ?= 1
PACKAGE_NAME ?= haproxy-quic
SUPPORTED_DISTRO ?= el9
SUPPORTED_ARCH ?= x86_64
AWS_LC_VERSION ?= 1.71.0
HAPROXY_VERSION ?= 3.2.15
RELEASE_TAG ?= v$(HAPROXY_VERSION)-aws-lc-$(AWS_LC_VERSION)
RELEASE_TITLE ?= HAProxy QUIC $(SUPPORTED_DISTRO) - $(HAPROXY_VERSION) / AWS-LC $(AWS_LC_VERSION)
RELEASE_DIR ?= $(CWD)/release-artifacts

SOURCES_DIR = $(CWD)/SOURCES
APP_NAME = el9builder
WORK_DIR = /home/builder/rpmbuild

export PACKAGE_RELEASE AWS_LC_VERSION HAPROXY_VERSION SOURCES_DIR

docker-build: ## Build the docker container (required for building the RPM)
	docker build \
		--build-arg BUILDER_UID="$(HOST_UID)" \
		--build-arg BUILDER_GID="$(HOST_GID)" \
		-t $(APP_NAME) .

docker-build-nc: ## Build the container without caching
	docker build --no-cache \
		--build-arg BUILDER_UID="$(HOST_UID)" \
		--build-arg BUILDER_GID="$(HOST_GID)" \
		-t $(APP_NAME) .

docker-run: ## Run the docker container (useful for manual testing)
	docker run --rm -i -t \
		--tmpfs /tmp:rw,exec \
		--mount type=bind,src="$(CWD)",dst="$(WORK_DIR)" \
		$(APP_NAME) /bin/bash

fetch-sources: ## Fetch sources required for the RPM build
	scripts/fetch_sources.sh

check-latest: ## Compare pinned haproxy/AWS-LC versions with upstream latest releases
	scripts/check_latest.sh

rpm-build: ## Build the RPM inside docker container
	docker run --rm -i \
        --tmpfs /tmp:rw,exec \
        --mount type=bind,src="$(CWD)",dst="$(WORK_DIR)" \
        $(APP_NAME) make rpm-build-local \
        PACKAGE_RELEASE="$(PACKAGE_RELEASE)" \
        HAPROXY_VERSION="$(HAPROXY_VERSION)" \
        AWS_LC_VERSION="$(AWS_LC_VERSION)"

rpm-build-local: fetch-sources ## Build the RPM locally
	rpmbuild -ba \
		--define "_tmppath /tmp" \
		--define "_builddir /tmp/BUILD" \
		--define "_buildrootdir /tmp/BUILDROOT " \
		--define "package_release $(PACKAGE_RELEASE)" \
		--define "haproxy_version $(HAPROXY_VERSION)" \
		--define "aws_lc_version $(AWS_LC_VERSION)" \
		SPECS/haproxy.spec

release-bundle: rpm-build ## Build RPM/SRPM assets and assemble a GitHub Release bundle
	scripts/prepare_release_bundle.sh

clean-rpm: ## Clean all previously built RPMs and SRPMs
	rm -rf RPMS SRPMS

clean-sources: ## Clean all previously downloaded RPM source files
	rm -f SOURCES/{aws-lc,haproxy,lua,pcre2}-*.tar.gz
	rm -f SOURCES/{aws-lc,haproxy,lua,pcre2}-*.tgz

clean-release: ## Clean generated GitHub Release bundle assets
	rm -rf $(RELEASE_DIR)

clean-all: clean-rpm clean-sources clean-release ## Clean all the things

print-release-env: ## Print release metadata as shell assignments
	@printf "PACKAGE_NAME='%s'\n" "$(PACKAGE_NAME)"
	@printf "SUPPORTED_DISTRO='%s'\n" "$(SUPPORTED_DISTRO)"
	@printf "SUPPORTED_ARCH='%s'\n" "$(SUPPORTED_ARCH)"
	@printf "HAPROXY_VERSION='%s'\n" "$(HAPROXY_VERSION)"
	@printf "AWS_LC_VERSION='%s'\n" "$(AWS_LC_VERSION)"
	@printf "RELEASE_TAG='%s'\n" "$(RELEASE_TAG)"
	@printf "RELEASE_TITLE='%s'\n" "$(RELEASE_TITLE)"
	@printf "RELEASE_DIR='%s'\n" "$(RELEASE_DIR)"

help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage: make <command>\n\nCommands:\033[36m\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help
.PHONY: docker-build docker-build-nc docker-run fetch-sources check-latest rpm-build rpm-build-local release-bundle clean-rpm clean-sources clean-release clean-all print-release-env help
