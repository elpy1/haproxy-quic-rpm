FROM rockylinux:9
RUN set -x && \
    dnf install -y sudo createrepo curl-minimal gcc gcc-c++ make cmake \
    rpm-build systemd-devel perl-core golang libasan \
    libtool pcre2-devel zlib-devel epel-release && \
    crb enable && \
    dnf install -y lua-devel ninja-build libunwind-devel && \
    echo '* - nproc 4096' >> /etc/security/limits.d/90-nproc.conf && \
    dnf clean all

ARG BUILDER_UID=1000
ARG BUILDER_GID=1000

RUN if ! getent group "${BUILDER_GID}" >/dev/null; then \
        groupadd -g "${BUILDER_GID}" builder; \
    fi && \
    useradd builder -u "${BUILDER_UID}" -g "${BUILDER_GID}" -m -G users,wheel && \
    echo "builder ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers

USER builder
RUN mkdir -p /home/builder/rpmbuild && \
    echo '%_topdir %(echo $HOME)/rpmbuild' > /home/builder/.rpmmacros

WORKDIR /home/builder/rpmbuild
