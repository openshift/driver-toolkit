FROM registry.access.redhat.com/ubi8/ubi 

ARG KERNEL_VERSION
ARG RT_KERNEL_VERSION
ARG RHEL_VERSION

# kernel packages needed to build drivers / kmods 
RUN yum -y --best install \
    kernel-core-${KERNEL_VERSION} \
    kernel-devel-${KERNEL_VERSION} \
    kernel-headers-${KERNEL_VERSION} \
    kernel-modules-${KERNEL_VERSION} \
    kernel-modules-extra-${KERNEL_VERSION} 

# real-time kernel packages
RUN yum -y --best install \
    kernel-rt-core-${RT_KERNEL_VERSION} \
    kernel-rt-devel-${RT_KERNEL_VERSION} \
    kernel-rt-modules-${RT_KERNEL_VERSION} \
    kernel-rt-modules-extra-${RT_KERNEL_VERSION}

# Additional packages that are mandatory for driver-containers
RUN yum -y --best install elfutils-libelf-devel kmod binutils kabi-dw kernel-abi-whitelists

# Packages needed to build kmods-via-containers and likely needed for driver-containers
RUN yum -y --best install git make

# Add and build kmods-via-containers
COPY kmods-via-containers /tmp/kmods-via-containers

WORKDIR /tmp/kmods-via-containers

RUN make install DESTDIR=/usr/local CONFDIR=/etc/

