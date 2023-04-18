FROM registry.ci.openshift.org/ocp/4.14:base-rhel9
ARG KERNEL_VERSION=''
ARG RT_KERNEL_VERSION=''
ARG RHEL_VERSION=''
RUN echo ${RHEL_VERSION} > /etc/yum/vars/releasever \
    && dnf config-manager --best --setopt=install_weak_deps=False --save

# kernel packages needed to build drivers / kmods 
RUN dnf -y install \
    kernel-devel${KERNEL_VERSION:+-}${KERNEL_VERSION} \
    kernel-headers${KERNEL_VERSION:+-}${KERNEL_VERSION} \
    kernel-modules${KERNEL_VERSION:+-}${KERNEL_VERSION} \
    kernel-modules-extra${KERNEL_VERSION:+-}${KERNEL_VERSION}

# real-time kernel packages
RUN if [ $(arch) = x86_64 ]; then \
    dnf -y install \
    kernel-rt-devel${RT_KERNEL_VERSION:+-}${RT_KERNEL_VERSION} \
    kernel-rt-modules${RT_KERNEL_VERSION:+-}${RT_KERNEL_VERSION} \
    kernel-rt-modules-extra${RT_KERNEL_VERSION:+-}${RT_KERNEL_VERSION}; \
    fi

RUN dnf -y install kernel-rpm-macros

# Additional packages that are mandatory for driver-containers
RUN dnf -y install elfutils-libelf-devel kmod binutils kabi-dw glibc
    
# Find and install the GCC version used to compile the kernel
# If it cannot be found (fails on some architectures), install the default gcc
RUN export INSTALLED_KERNEL=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}"  kernel-devel) && \
    GCC_VERSION=$(cat /lib/modules/${INSTALLED_KERNEL}/config | grep -Eo "gcc \(GCC\) ([0-9\.]+)" | grep -Eo "([0-9\.]+)") && \
    dnf -y install gcc-${GCC_VERSION} || dnf -y install gcc

# Additional packages that are needed for a subset (e.g DPDK) of driver-containers
RUN dnf -y install xz diffutils flex bison

# Packages needed to build driver-containers
RUN dnf -y install git make rpm-build

# Packages needed to sign and run externally build kernel modules
RUN if [ $(arch) == "x86_64" ] || [ $(arch) == "aarch64" ]; then \
    ARCH_DEP_PKGS="mokutil"; fi \
    && dnf -y install openssl keyutils $ARCH_DEP_PKGS

RUN dnf clean all

COPY manifests /manifests

LABEL io.k8s.description="driver-toolkit is a container with the kernel packages necessary for building driver containers for deploying kernel modules/drivers on OpenShift" \
      name="driver-toolkit" \
      io.openshift.release.operator=true \
      version="0.1"

# Last layer for metadata for mapping the driver-toolkit to a specific kernel version
RUN export INSTALLED_KERNEL=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}"  kernel-devel); \
    export INSTALLED_RT_KERNEL=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}"  kernel-rt-core); \
    echo "{ \"KERNEL_VERSION\": \"${INSTALLED_KERNEL}\", \"RT_KERNEL_VERSION\": \"${INSTALLED_RT_KERNEL}\", \"RHEL_VERSION\": \"${RHEL_VERSION}\" }" > /etc/driver-toolkit-release.json

