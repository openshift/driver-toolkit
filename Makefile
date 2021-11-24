CONTAINER_ENGINE ?= docker
PWD              ?= $(shell pwd)			

verify: 
	cat ./Dockerfile

test-e2e:
	./test/e2e
