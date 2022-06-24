export DOCKER_BUILDKIT=1

COMMIT_SHA := $(shell git rev-parse --short HEAD)
VERSION ?= $(shell git describe --contains $(COMMIT_SHA) 2> /dev/null)
REPOSITORY := https://github.com/grgate/demo-e2e-runner
DOCKER_IMAGE := grgate/demo-e2e-runner

.PHONY: \
	build-image \
	push-image \
	retag-image

build-image:
	docker build \
		--cache-from $(DOCKER_IMAGE) \
		--label org.opencontainers.image.revision=$(COMMIT_SHA) \
		--label org.opencontainers.image.source=$(REPOSITORY) \
		--label org.opencontainers.image.version=$(VERSION) \
		--build-arg BUILDKIT_INLINE_CACHE=1 \
		-t $(DOCKER_IMAGE):$(COMMIT_SHA) \
		.

push-image:
	docker push $(DOCKER_IMAGE):$(COMMIT_SHA)

retag-image:
	docker pull $(DOCKER_IMAGE):$(COMMIT_SHA)
	docker tag $(DOCKER_IMAGE):$(COMMIT_SHA) $(DOCKER_IMAGE):$(VERSION)
	docker push $(DOCKER_IMAGE):$(VERSION)
