CONTAINER_ENGINE ?= podman
PWD              ?= $(shell pwd)			

verify: 
	$(CONTAINER_ENGINE) run -it --rm -v $(PWD):/root/:Z projectatomic/dockerfile-lint dockerfile_lint -f Dockerfile
