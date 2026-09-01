# SPDX-FileCopyrightText: © 2025 VEXXHOST, Inc.
# SPDX-License-Identifier: GPL-3.0-or-later
# Atmosphere-Rebuild-Time: 2024-06-25T22:49:25Z

FROM ubuntu@sha256:2260313b31c8c011cd2eebe728008efac1b3982be73eb71348ea2648d2c0e09b AS helm
ARG TARGETOS
ARG TARGETARCH
ARG HELM_VERSION=3.14.0
ADD https://get.helm.sh/helm-v${HELM_VERSION}-${TARGETOS}-${TARGETARCH}.tar.gz /helm.tar.gz
RUN tar -xzf /helm.tar.gz
RUN mv /${TARGETOS}-${TARGETARCH}/helm /usr/bin/helm

FROM ghcr.io/vexxhost/openstack-venv-builder:main@sha256:dd3adf3788a31aad0997c9ed789457b74bb4b7f1d83723aafae9af458cd942ce AS build
ENV UV_INDEX=https://packages.vexxhost.com/pypi/openstack/simple/
ARG MAGNUM_VERSION=22.0.0+a8e.9.0
RUN <<EOF bash -xe
uv pip install \
    --constraint /upper-constraints.txt \
        "magnum==${MAGNUM_VERSION}" \
        magnum-cluster-api==0.38.2
EOF

# PBR 7.0.3 cannot parse PEP 440 local versions such as the downstream
# Magnum version above.  Carry the focused upstream fix until a non-yanked
# PBR release includes it:
# https://github.com/openstack/pbr/commit/8e66303b735aa3464c9124db8aa12156e442c50a
COPY patches/pbr-local-version.patch /tmp/pbr-local-version.patch
RUN <<'EOF' bash -xe
pbr_root="$(/var/lib/openstack/bin/python -c 'import pathlib; import pbr.version; print(pathlib.Path(pbr.version.__file__).parent.parent)')"
cd "${pbr_root}"
git apply /tmp/pbr-local-version.patch
rm /tmp/pbr-local-version.patch

/var/lib/openstack/bin/python -c 'import magnum; assert magnum.__version__ == "22.0.0"'
/var/lib/openstack/bin/magnum-db-manage --help >/dev/null
EOF

FROM ghcr.io/vexxhost/python-base:main@sha256:cd5f90fbe48ea093f842d4a685b9edfa5c80f4768b066f9b9957bbf47155c245
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
