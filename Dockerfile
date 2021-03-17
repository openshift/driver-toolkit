FROM registry.access.redhat.com/ubi8/ubi 

RUN echo ${RHEL_VERSION} > /etc/yum/vars/releasever \
    && yum config-manager --best --setopt=install_weak_deps=False --save

# kernel packages needed to build drivers / kmods 
RUN yum -y install \
    kernel-core \
    kernel-devel \
    kernel-headers \
    kernel-modules \
    kernel-modules-extra \
    && yum clean all

# real-time kernel packages
RUN if [ $(arch) = x86_64 ]; then \
    yum -y install \
    kernel-rt-core \
    kernel-rt-devel \
    kernel-rt-modules \
    kernel-rt-modules-extra \
    && yum clean all ; fi

# Additional packages that are mandatory for driver-containers
RUN yum -y install elfutils-libelf-devel kmod binutils kabi-dw kernel-abi-whitelists \
    && yum clean all

# Packages needed to build kmods-via-containers and likely needed for driver-containers
RUN yum -y install git make \
    && yum clean all

# Add and build kmods-via-containers
COPY kmods-via-containers /tmp/kmods-via-containers

WORKDIR /tmp/kmods-via-containers

RUN make install DESTDIR=/usr/local CONFDIR=/etc/

LABEL io.k8s.description="driver-toolkit is a container with the kernel packages necessary for building driver containers for deploying kernel modules/drivers on OpenShift" \
      name="driver-toolkit" \
      version="0.1"
