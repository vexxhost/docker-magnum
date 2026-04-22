# SPDX-FileCopyrightText: © 2025 VEXXHOST, Inc.
# SPDX-License-Identifier: GPL-3.0-or-later

FROM ubuntu@sha256:c4a8d5503dfb2a3eb8ab5f807da5bc69a85730fb49b5cfca2330194ebcc41c7b AS helm
ARG TARGETOS
ARG TARGETARCH
ARG HELM_VERSION=3.14.0
ADD https://get.helm.sh/helm-v${HELM_VERSION}-${TARGETOS}-${TARGETARCH}.tar.gz /helm.tar.gz
RUN tar -xzf /helm.tar.gz
RUN mv /${TARGETOS}-${TARGETARCH}/helm /usr/bin/helm

FROM ghcr.io/vexxhost/openstack-venv-builder:2025.1@sha256:1a2c5fa0101e6129dbf53f6187bdf263e99cbdce1cbda21cc0a01bf35c42e880 AS build
RUN --mount=type=bind,from=magnum,source=/,target=/src/magnum,readwrite <<EOF bash -xe
uv pip install \
    --constraint /upper-constraints.txt \
        /src/magnum \
        magnum-cluster-api==0.36.6
EOF

FROM ghcr.io/vexxhost/python-base:2025.1@sha256:f12f388f1dacaccfb67eed6188fa2f2087081fe795ed11de3862d0fc9e9062c3
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
