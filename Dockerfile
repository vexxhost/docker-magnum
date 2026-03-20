# SPDX-FileCopyrightText: © 2025 VEXXHOST, Inc.
# SPDX-License-Identifier: GPL-3.0-or-later
# Atmosphere-Rebuild-Time: 2024-06-25T22:49:25Z

FROM ubuntu@sha256:186072bba1b2f436cbb91ef2567abca677337cfc786c86e107d25b7072feef0c AS helm
ARG TARGETOS
ARG TARGETARCH
ARG HELM_VERSION=3.14.0
ADD https://get.helm.sh/helm-v${HELM_VERSION}-${TARGETOS}-${TARGETARCH}.tar.gz /helm.tar.gz
RUN tar -xzf /helm.tar.gz
RUN mv /${TARGETOS}-${TARGETARCH}/helm /usr/bin/helm

FROM ghcr.io/vexxhost/openstack-venv-builder:2024.2@sha256:50fd643a199b7239abfcbcf8d12433d35ec2523c9724c9c97c5a6ce940a9ca21 AS build
RUN --mount=type=bind,from=magnum,source=/,target=/src/magnum,readwrite <<EOF bash -xe
uv pip install \
    --constraint /upper-constraints.txt \
        /src/magnum \
        magnum-cluster-api==0.36.0
EOF

FROM ghcr.io/vexxhost/python-base:2024.2@sha256:48971cdaff3e6583e2f15810605a3cb42cb16f37c6ddb5d78c325183d00547ca
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
