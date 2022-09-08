CONTAINER_ENGINE ?= docker
PWD              ?= $(shell pwd)			

verify: 
	cat ./Dockerfile
	echo hello

test-e2e:
	./test/e2e
