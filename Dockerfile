# SPDX-FileCopyrightText: © 2025 VEXXHOST, Inc.
# SPDX-License-Identifier: GPL-3.0-or-later
# Atmosphere-Rebuild-Time: 2024-06-25T22:49:25Z

FROM ubuntu@sha256:3595d7fc4286a33fad0fd853a4063e654287a9c3787437d7937c94ca3f7a804e AS helm
ARG TARGETOS
ARG TARGETARCH
ARG HELM_VERSION=3.14.0
ADD https://get.helm.sh/helm-v${HELM_VERSION}-${TARGETOS}-${TARGETARCH}.tar.gz /helm.tar.gz
RUN tar -xzf /helm.tar.gz
RUN mv /${TARGETOS}-${TARGETARCH}/helm /usr/bin/helm

FROM ghcr.io/vexxhost/openstack-venv-builder:2024.2@sha256:a9593d9f39f40e9795d9a98e3f8de75b41cb21695fdb6a800449088680b897f9 AS build
ENV UV_INDEX=https://packages.vexxhost.com/pypi/openstack/simple/
ARG MAGNUM_VERSION=19.0.1+a8e.0.0
RUN <<EOF bash -xe
uv pip install \
    --constraint /upper-constraints.txt \
        "magnum==${MAGNUM_VERSION}" \
        magnum-cluster-api==0.38.2
EOF

FROM ghcr.io/vexxhost/python-base:2024.2@sha256:31b81988a0e492e0c595b5641019c1d58654ed5fdedc9fa191977a71c06a86fb
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
