# SPDX-FileCopyrightText: © 2025 VEXXHOST, Inc.
# SPDX-License-Identifier: GPL-3.0-or-later
# Atmosphere-Rebuild-Time: 2024-06-25T22:49:25Z

FROM ubuntu@sha256:513c074113a871b51a8d16ab445c88779d6452d937a164fb5cc479f32668a41d AS helm
ARG TARGETOS
ARG TARGETARCH
ARG HELM_VERSION=3.14.0
ADD https://get.helm.sh/helm-v${HELM_VERSION}-${TARGETOS}-${TARGETARCH}.tar.gz /helm.tar.gz
RUN tar -xzf /helm.tar.gz
RUN mv /${TARGETOS}-${TARGETARCH}/helm /usr/bin/helm

FROM ghcr.io/vexxhost/openstack-venv-builder:2023.2@sha256:68ebc2c43d45ef24dc48a2fc22bc6198797dcde4b961dfea4efa051b6013ed93 AS build
ENV UV_INDEX=https://packages.vexxhost.com/pypi/openstack/simple/
ARG MAGNUM_VERSION=17.0.2+a8e.6.0
RUN <<EOF bash -xe
uv pip install \
    --constraint /upper-constraints.txt \
        "magnum==${MAGNUM_VERSION}" \
        magnum-cluster-api==0.38.2
EOF

FROM ghcr.io/vexxhost/python-base:2023.2@sha256:151488631110c19cf81858bede072b8abe4ba4b8081c64cf28f02f37604be693
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
