FROM registry.ci.openshift.org/ocp/4.9:base

ARG KERNEL_VERSION=''
ARG RT_KERNEL_VERSION=''
ARG RHEL_VERSION=''

RUN echo ${RHEL_VERSION} > /etc/yum/vars/releasever \
    && yum config-manager --best --setopt=install_weak_deps=False --save

# kernel packages needed to build drivers / kmods 
RUN yum -y install \
    kernel-core${KERNEL_VERSION:+-}${KERNEL_VERSION} \
    kernel-devel${KERNEL_VERSION:+-}${KERNEL_VERSION} \
    kernel-headers${KERNEL_VERSION:+-}${KERNEL_VERSION} \
    kernel-modules${KERNEL_VERSION:+-}${KERNEL_VERSION} \
    kernel-modules-extra${KERNEL_VERSION:+-}${KERNEL_VERSION} \
    && yum clean all

# real-time kernel packages
RUN if [ $(arch) = x86_64 ]; then \
    yum -y install \
    kernel-rt-core${RT_KERNEL_VERSION:+-}${RT_KERNEL_VERSION} \
    kernel-rt-devel${RT_KERNEL_VERSION:+-}${RT_KERNEL_VERSION} \
    kernel-rt-modules${RT_KERNEL_VERSION:+-}${RT_KERNEL_VERSION} \
    kernel-rt-modules-extra${RT_KERNEL_VERSION:+-}${RT_KERNEL_VERSION} \
    && yum clean all ; fi

# Additional packages that are mandatory for driver-containers
RUN yum -y install elfutils-libelf-devel kmod binutils kabi-dw kernel-abi-whitelists \
    && yum clean all
    
# Find and install the GCC version used to compile the kernel
# If it cannot be found (fails on some architecutres), install the default gcc
RUN curl -fsSL -o /usr/local/bin/extract-vmlinux https://raw.githubusercontent.com/torvalds/linux/master/scripts/extract-vmlinux \
&& chmod +x /usr/local/bin/extract-vmlinux \
&& export INSTALLED_KERNEL=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}"  kernel-core) \
&& /usr/local/bin/extract-vmlinux /lib/modules/${INSTALLED_KERNEL}/vmlinuz | strings | grep -E '^Linux version'  > /tmp/kernel_info \
&& GCC_VERSION=$(cat /tmp/kernel_info | grep -Eo "gcc version ([0-9\.]+)" | grep -Eo "([0-9\.]+)") \
&& yum -y install gcc-${GCC_VERSION} \
|| yum -y install gcc && \
yum clean all

# Additional packages that are needed for a subset (e.g DPDK) of driver-containers
RUN yum -y install xz diffutils \
    && yum clean all
    
# Packages needed to build kmods-via-containers and likely needed for driver-containers
RUN yum -y install git make \
    && yum clean all

# Packages needed to sign and run externally build kernel modules
RUN if [ $(arch) == "x86_64" ] || [ $(arch) == "aarch64" ]; then \
    ARCH_DEP_PKGS="mokutil"; fi \
    && yum -y install openssl keyutils $ARCH_DEP_PKGS \
    && yum clean all

# Add and build kmods-via-containers
COPY kmods-via-containers /tmp/kmods-via-containers

WORKDIR /tmp/kmods-via-containers

RUN make install DESTDIR=/usr/local CONFDIR=/etc/

LABEL io.k8s.description="driver-toolkit is a container with the kernel packages necessary for building driver containers for deploying kernel modules/drivers on OpenShift" \
      name="driver-toolkit" \
      io.openshift.release.operator=true \
      version="0.1"

# Last layer for metadata for mapping the driver-toolkit to a specific kernel version
RUN export INSTALLED_KERNEL=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}"  kernel-core); \
    export INSTALLED_RT_KERNEL=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}"  kernel-rt-core); \
    echo "{ \"KERNEL_VERSION\": \"${KERNEL_VERSION:-${INSTALLED_KERNEL}}\", \"RT_KERNEL_VERSION\": \"${RT_KERNEL_VERSION:-${INSTALLED_RT_KERNEL}}\", \"RHEL_VERSION\": \"${RHEL_VERSION}\" }" > /etc/driver-toolkit-release.json
