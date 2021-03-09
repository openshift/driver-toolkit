FROM registry.access.redhat.com/ubi8/ubi 

ARG KERNEL_VERSION
ARG RT_KERNEL_VERSION
ARG RHEL_VERSION

RUN yum install -y git make

RUN yum repolist \
&& sed -i "/rhel-8-for-x86_64-rt-rpms/,+5s/enabled = 0/enabled = 1/" /etc/yum.repos.d/redhat.repo

RUN yum list | grep kernel; 

RUN yum -y --best install \
    kernel-core-${KERNEL_VERSION} \
    kernel-devel-${KERNEL_VERSION} \
    kernel-headers-${KERNEL_VERSION} \
    kernel-modules-${KERNEL_VERSION} \
    kernel-modules-extra-${KERNEL_VERSION} \
    kernel-rt-core-${RT_KERNEL_VERSION} \
    kernel-rt-devel-${RT_KERNEL_VERSION} \
    kernel-rt-headers-${RT_KERNEL_VERSION} \
    kernel-rt-modules-${RT_KERNEL_VERSION} \
    kernel-rt-modules-extra-${RT_KERNEL_VERSION}

    # Additional packages that are mandatory for driver-containers
RUN yum -y --best install elfutils-libelf-devel kmod binutils kabi-dw kernel-abi-whitelists

RUN cd kmods-via-containers && \
    make install DESTDIR=/usr/local CONFDIR=/etc/

