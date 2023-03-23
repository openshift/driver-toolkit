CONTAINER_ENGINE ?= docker
PWD              ?= $(shell pwd)			

verify: 
	cat ./Dockerfile

# test comment
test-e2e:
	./test/e2e
