#   Copyright 2018 NephoSolutions SPRL, Sebastian Trebitz
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

ARG ALPINE_VERSION=3.8
ARG RUBY_VERSION=2.5.3

FROM alpine:${ALPINE_VERSION} as google

WORKDIR /tmp

ARG CLOUD_SDK_VERSION
ENV CLOUD_SDK_VERSION ${CLOUD_SDK_VERSION:-225.0.0}

ADD https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz
RUN tar -xzf google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz

ARG KUBE_VERSION
ENV KUBE_VERSION ${KUBE_VERSION:-1.12.2}

WORKDIR /usr/local/bin

ADD https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/linux/amd64/kubectl kubectl
RUN chmod 0755 kubectl


FROM alpine:${ALPINE_VERSION} as hashicorp

RUN apk add --no-cache --update \
      gnupg

WORKDIR /tmp

COPY hashicorp-releases-public-key.asc .
RUN gpg --import hashicorp-releases-public-key.asc

ARG PACKER_VERSION
ENV PACKER_VERSION ${PACKER_VERSION:-1.3.2}

ADD https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip packer_${PACKER_VERSION}_linux_amd64.zip
ADD https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_SHA256SUMS.sig packer_${PACKER_VERSION}_SHA256SUMS.sig
ADD https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_SHA256SUMS packer_${PACKER_VERSION}_SHA256SUMS

RUN gpg --verify packer_${PACKER_VERSION}_SHA256SUMS.sig packer_${PACKER_VERSION}_SHA256SUMS

RUN grep linux_amd64 packer_${PACKER_VERSION}_SHA256SUMS > packer_${PACKER_VERSION}_SHA256SUMS_linux_amd64
RUN sha256sum -cs packer_${PACKER_VERSION}_SHA256SUMS_linux_amd64

ARG TERRAFORM_VERSION
ENV TERRAFORM_VERSION ${TERRAFORM_VERSION:-0.11.10}

ADD https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip terraform_${TERRAFORM_VERSION}_linux_amd64.zip
ADD https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS.sig terraform_${TERRAFORM_VERSION}_SHA256SUMS.sig
ADD https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS terraform_${TERRAFORM_VERSION}_SHA256SUMS

RUN gpg --verify terraform_${TERRAFORM_VERSION}_SHA256SUMS.sig terraform_${TERRAFORM_VERSION}_SHA256SUMS

RUN grep linux_amd64 terraform_${TERRAFORM_VERSION}_SHA256SUMS >terraform_${TERRAFORM_VERSION}_SHA256SUMS_linux_amd64
RUN sha256sum -cs terraform_${TERRAFORM_VERSION}_SHA256SUMS_linux_amd64

ARG TERRAFORM_PROVIDER_ACME_VERSION
ENV TERRAFORM_PROVIDER_ACME_VERSION ${TERRAFORM_PROVIDER_ACME_VERSION:-1.0.0}

ADD https://github.com/vancluever/terraform-provider-acme/releases/download/v${TERRAFORM_PROVIDER_ACME_VERSION}/terraform-provider-acme_v${TERRAFORM_PROVIDER_ACME_VERSION}_linux_amd64.zip terraform-provider-acme_v${TERRAFORM_PROVIDER_ACME_VERSION}_linux_amd64.zip

WORKDIR /usr/local/bin

RUN unzip /tmp/packer_${PACKER_VERSION}_linux_amd64.zip
RUN unzip /tmp/terraform_${TERRAFORM_VERSION}_linux_amd64.zip

WORKDIR /tmp/terraform.d/plugins

RUN unzip /tmp/terraform-provider-acme_v${TERRAFORM_PROVIDER_ACME_VERSION}_linux_amd64.zip && \
    mv terraform-provider-acme terraform-provider-acme_v${TERRAFORM_PROVIDER_ACME_VERSION}


FROM alpine:${ALPINE_VERSION} as python

ARG REQUIREMENTS
ENV REQUIREMENTS ${REQUIREMENTS:-frozen}

RUN apk add --no-cache --update \
  build-base \
  ca-certificates \
  libffi-dev \
  openssl-dev \
  py-pip \
  python-dev

RUN pip install --upgrade pip

COPY requirements*.txt /tmp/

RUN if [ "${REQUIREMENTS}" == "frozen" ]; then \
      pip install --quiet --requirement /tmp/requirements-frozen.txt; \
    else \
      pip install --quiet --upgrade --requirement /tmp/requirements.txt; \
    fi


FROM ruby:${RUBY_VERSION}-alpine${ALPINE_VERSION}
LABEL maintainer="sebastian@nephosolutions.com"

ARG GIT_CRYPT_VERSION
ENV GIT_CRYPT_VERSION ${GIT_CRYPT_VERSION:-0.6.0-r0}

RUN addgroup circleci && \
    adduser -G circleci -D circleci

RUN apk add --no-cache --update \
  bash \
  build-base \
  ca-certificates \
  git \
  groff \
  jq \
  less \
  libc6-compat \
  make \
  openssh-client \
  openssl \
  py-pip \
  python

RUN ln -s /lib /lib64

ADD https://raw.githubusercontent.com/sgerrand/alpine-pkg-git-crypt/master/sgerrand.rsa.pub /etc/apk/keys/sgerrand.rsa.pub
ADD https://github.com/sgerrand/alpine-pkg-git-crypt/releases/download/${GIT_CRYPT_VERSION}/git-crypt-${GIT_CRYPT_VERSION}.apk /var/cache/apk/
RUN apk add /var/cache/apk/git-crypt-${GIT_CRYPT_VERSION}.apk

COPY --from=google /tmp/google-cloud-sdk /opt/google/cloud-sdk
ENV PATH /opt/google/cloud-sdk/bin:$PATH

COPY --from=google /usr/local/bin/kubectl /usr/local/bin/kubectl

RUN gcloud config set core/disable_usage_reporting true
RUN gcloud config set component_manager/disable_update_check true

COPY --from=hashicorp /usr/local/bin/packer /usr/local/bin/packer
COPY --from=hashicorp /usr/local/bin/terraform /usr/local/bin/terraform

COPY --from=python /usr/bin/ansible* /usr/bin/
COPY --from=python /usr/bin/aws* /usr/bin/
COPY --from=python /usr/lib/python2.7 /usr/lib/python2.7

USER circleci

WORKDIR /home/circleci

COPY --from=hashicorp --chown=circleci:circleci /tmp/terraform.d .terraform.d
