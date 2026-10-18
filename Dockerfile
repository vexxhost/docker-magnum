# SPDX-FileCopyrightText: © 2025 VEXXHOST, Inc.
# SPDX-License-Identifier: GPL-3.0-or-later
# Atmosphere-Rebuild-Time: 2024-06-25T22:49:25Z

FROM ubuntu@sha256:c098726dd9b9733f3e885f8de0ef375206a311b0a317eadc40d347b1115fb944 AS helm
ARG TARGETOS
ARG TARGETARCH
ARG HELM_VERSION=3.14.0
ADD https://get.helm.sh/helm-v${HELM_VERSION}-${TARGETOS}-${TARGETARCH}.tar.gz /helm.tar.gz
RUN tar -xzf /helm.tar.gz
RUN mv /${TARGETOS}-${TARGETARCH}/helm /usr/bin/helm

FROM ghcr.io/vexxhost/openstack-venv-builder:2023.2@sha256:a42bd3b5b2df82ba4aa63b3b938fd36d955a60683cc06c244120d9d764c001b1 AS build
ENV UV_INDEX=https://packages.vexxhost.com/pypi/openstack/simple/
ARG MAGNUM_VERSION=17.0.2+a8e.6.0
RUN <<EOF bash -xe
uv pip install \
    --constraint /upper-constraints.txt \
        "magnum==${MAGNUM_VERSION}" \
        magnum-cluster-api==0.38.2
EOF

FROM ghcr.io/vexxhost/python-base:2023.2@sha256:f4dc4023a2c6415c80a8d1455a5b2847e2f52f442b8cefa0f38de809d2e0e55c
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
