# SPDX-FileCopyrightText: © 2025 VEXXHOST, Inc.
# SPDX-License-Identifier: GPL-3.0-or-later
# Atmosphere-Rebuild-Time: 2024-06-25T22:49:25Z

FROM ubuntu@sha256:9559ceb7c21e528e233e8dff26a0fb2682f4094cce06176eeb075d87a22b31de AS helm
ARG TARGETOS
ARG TARGETARCH
ARG HELM_VERSION=3.14.0
ADD https://get.helm.sh/helm-v${HELM_VERSION}-${TARGETOS}-${TARGETARCH}.tar.gz /helm.tar.gz
RUN tar -xzf /helm.tar.gz
RUN mv /${TARGETOS}-${TARGETARCH}/helm /usr/bin/helm

FROM ghcr.io/vexxhost/openstack-venv-builder:2023.1@sha256:8c4bd10eb3a5e99a8ce4cdf2e85f976f52ac84ffa20ed4faeda5817b7e7747cb AS build
ENV UV_INDEX=https://packages.vexxhost.com/pypi/openstack/simple/
ARG MAGNUM_VERSION=16.0.3+a8e.1.1
RUN <<EOF bash -xe
uv pip install \
    --constraint /upper-constraints.txt \
        "magnum==${MAGNUM_VERSION}" \
        magnum-cluster-api==0.38.2
EOF

FROM ghcr.io/vexxhost/python-base:2023.1@sha256:f2683457bc8cc97ead3bd3dba9f428fdca7449c4ce7ba7f776459afbe5b634bc
RUN \
    groupadd -g 42424 magnum && \
    useradd -u 42424 -g 42424 -M -d /var/lib/magnum -s /usr/sbin/nologin -c "Magnum User" magnum && \
    mkdir -p /etc/magnum /var/log/magnum /var/lib/magnum /var/cache/magnum && \
    chown -Rv magnum:magnum /etc/magnum /var/log/magnum /var/lib/magnum /var/cache/magnum
RUN <<EOF bash -xe
apt-get update -qq
apt-get install -qq -y --no-install-recommends \
    haproxy
apt-get clean
rm -rf /var/lib/apt/lists/*
EOF
COPY --from=helm --link /usr/bin/helm /usr/local/bin/helm
COPY --from=build --link /var/lib/openstack /var/lib/openstack
