# Makefile — predefined build/run convention for the dev container.
#
# Encodes the image tag, build metadata, and the host <-> container output
# volume in one place so day-to-day use is `make build`, `make shell`, etc.,
# instead of remembering long `docker run` invocations.
#
# Override any variable on the command line, e.g.:
#   make build VERSION=1.1.0
#   make shell WORKSPACE=$(pwd)/out

IMAGE        ?= husk:ubuntu-26.04
NAME         ?= devbox
HOSTNAME     ?= devbox

# host directory bind-mounted to /workspace in the container. Outputs written
# here inside the container show up on the host and survive the container.
WORKSPACE    ?= $(CURDIR)/workspace
WORKDIR_PATH ?= /workspace

# build metadata baked into image labels.
VERSION      ?= 1.0.0
BUILD_DATE   := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
VCS_REF      := $(shell git rev-parse --short HEAD 2>/dev/null || echo unknown)

# `--init` runs a real init as PID 1: it reaps zombie processes and propagates
# signals, which matters for a long-lived container. Not a security control.
RUN_FLAGS    ?= --init

.PHONY: help build shell run start stop logs clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

build: ## Build the image with pinned args and metadata
	docker build -t $(IMAGE) \
		--build-arg VERSION=$(VERSION) \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg VCS_REF=$(VCS_REF) \
		--build-arg WORKDIR_PATH=$(WORKDIR_PATH) \
		.

shell: ## Run a throwaway interactive container (auto-removed on exit)
	@mkdir -p "$(WORKSPACE)"
	docker run -it --rm $(RUN_FLAGS) \
		--hostname $(HOSTNAME) \
		-v "$(WORKSPACE):$(WORKDIR_PATH)" \
		$(IMAGE)

run: ## Create a long-lived named container (hours-to-weeks workflow)
	@mkdir -p "$(WORKSPACE)"
	docker run -dit $(RUN_FLAGS) \
		--hostname $(HOSTNAME) \
		--name $(NAME) \
		-v "$(WORKSPACE):$(WORKDIR_PATH)" \
		$(IMAGE)

start: ## Attach to the existing named container
	docker start -ai $(NAME)

stop: ## Stop the named container
	docker stop $(NAME)

logs: ## Follow the named container's logs
	docker logs -f $(NAME)

clean: ## Remove the named container (keeps the ./workspace output)
	-docker rm -f $(NAME)
