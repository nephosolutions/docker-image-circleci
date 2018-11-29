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

DOCKER_IMAGE_OWNER	:= nephosolutions
DOCKER_IMAGE_NAME		:= circleci

ALPINE_VERSION		:= 3.8
CLOUD_SDK_VERSION	:= 226.0.0
GIT_CRYPT_VERSION	:= 0.6.0-r0
KUBE_VERSION			:= 1.12.2
PACKER_VERSION		:= 1.3.2
RUBY_VERSION			:= 2.5.3
TERRAFORM_VERSION	:= 0.11.10

TERRAFORM_PROVIDER_ACME_VERSION	:= 1.0.0

CACHE_DIR := .cache
REQUIREMENTS := frozen

remove = $(if $(strip $1),rm -rf $(strip $1))

$(DOCKER_IMAGE_OWNER)/$(DOCKER_IMAGE_NAME):
	$(if $(wildcard $(CACHE_DIR)/$(DOCKER_IMAGE_OWNER)/$(DOCKER_IMAGE_NAME).tar),docker load --input $(CACHE_DIR)/$(DOCKER_IMAGE_OWNER)/$(DOCKER_IMAGE_NAME).tar)

	docker build \
	--build-arg ALPINE_VERSION=$(ALPINE_VERSION) \
	--build-arg CLOUD_SDK_VERSION=$(CLOUD_SDK_VERSION) \
	--build-arg GIT_CRYPT_VERSION=$(GIT_CRYPT_VERSION) \
	--build-arg KUBE_VERSION=$(KUBE_VERSION) \
	--build-arg PACKER_VERSION=$(PACKER_VERSION) \
	--build-arg RUBY_VERSION=$(RUBY_VERSION) \
	--build-arg TERRAFORM_VERSION=$(TERRAFORM_VERSION) \
	--build-arg TERRAFORM_PROVIDER_ACME_VERSION=$(TERRAFORM_PROVIDER_ACME_VERSION) \
	--build-arg REQUIREMENTS=$(REQUIREMENTS) \
	--cache-from=$(DOCKER_IMAGE_OWNER)/$(DOCKER_IMAGE_NAME) \
	--tag $(DOCKER_IMAGE_OWNER)/$(DOCKER_IMAGE_NAME) .

$(CACHE_DIR)/$(DOCKER_IMAGE_OWNER)/$(DOCKER_IMAGE_NAME).tar: $(DOCKER_IMAGE_OWNER)/$(DOCKER_IMAGE_NAME)
	mkdir -p $(CACHE_DIR)/$(DOCKER_IMAGE_OWNER)
	docker save --output $(CACHE_DIR)/$(DOCKER_IMAGE_OWNER)/$(DOCKER_IMAGE_NAME).tar $(DOCKER_IMAGE_OWNER)/$(DOCKER_IMAGE_NAME)

requirements-frozen.txt:
	$(MAKE) $(DOCKER_IMAGE_OWNER)/$(DOCKER_IMAGE_NAME) REQUIREMENTS=upgrade
	docker run --rm $(DOCKER_IMAGE_OWNER)/$(DOCKER_IMAGE_NAME) pip freeze --quiet > requirements-frozen.txt

clean:
	$(call remove,$(wildcard $(CACHE_DIR)))

.PHONY: clean $(DOCKER_IMAGE_OWNER)/$(DOCKER_IMAGE_NAME) requirements-frozen.txt
