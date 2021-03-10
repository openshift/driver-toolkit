CONTAINER_ENGINE ?= docker
PWD              ?= $(shell pwd)			

verify: 
	cat ./Dockerfile
