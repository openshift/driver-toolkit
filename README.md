# Driver Toolkit
The Driver Toolkit is a container image in the OpenShift payload which is meant to be used as a base image on which to build driver containers. The Driver Toolkit image [contains](https://github.com/openshift/driver-toolkit/blob/master/Dockerfile "contains") the kernel packages commonly required as dependencies to build or install kernel modules as well as a few tools needed in driver containers. The version of these packages will match the kernel version running on the RHCOS nodes in the corresponding OpenShift release. 

Driver containers are container images used for building and deploying out-of-tree kernel modules and drivers on container OSs like Red Hat Enterprise Linux CoreOS (RHCOS). Kernel modules and drivers are software libraries running with a high level of privilege in the operating system kernel. They extend the kernel functionalities or provide the hardware-specific code required to control new devices.  Examples include hardware devices like FPGAs or GPUs, and software defined storage (SDS) solutions like Lustre parallel filesystem, which all require kernel modules on client machines. Driver containers are the first layer of the software stack used to enable these technologies on Kubernetes.

The list of kernel packages in the Driver Toolkit includes the following and their dependencies:

* `kernel-core`
* `kernel-devel`
* `kernel-headers`
* `kernel-modules`
* `kernel-modules-extra`

In addition, the Driver Toolkit also includes the corresponding real-time kernel packages:

* `kernel-rt-core`
* `kernel-rt-devel`
* `kernel-rt-modules`
* `kernel-rt-modules-extra`

The Driver Toolkit also has several tools which are commonly needed to build and install kernel modules, including:

* `elfutils-libelf-devel`
* `kmod`
* `binutilskabi-dw`
* `kernel-abi-whitelists`
* dependencies for the above

##  Purpose
Prior to the Driver Toolkit's existence, you could install kernel packages in a pod or build config on OpenShift using [entitled builds](https://www.openshift.com/blog/how-to-use-entitled-image-builds-to-build-drivercontainers-with-ubi-on-openshift "entitled builds") or by installing from the kernel RPMs in the hosts `machine-os-content`. The Driver Toolkit simplifies the process by removing the entitlement step, and avoids the privileged operation of accessing the machine-os-content in a pod. The Driver Toolkit can also be used by partners who have access to pre-released OpenShift versions to prebuild driver-containers for their hardware devices for future OpenShift releases.

The Driver Toolkit is also used by the [Special Resource Operator (SRO)](https://github.com/openshift-psap/special-resource-operator "Special Resource Operator (SRO)"), which is currently available as a community Operator on OperatorHub. SRO supports out-of-tree and third-party kernel drivers and the support software for the underlying operating system. Users can create _recipes_ for SRO to build and deploy a driver container, as well as support software like a device plug-in, or metrics. Recipes can include a build config to build a driver container based on the Driver Toolkit, or SRO can deploy a prebuilt driver container.

## Pulling the image
### How to get the image from the Red Hat Ecosystem Catalog

The `driver-toolkit` image is available from the [Container images section of the Red Hat Ecosystem Catalog](https://registry.redhat.io/ "Container images section of the Red Hat Ecosystem Catalog") and in the OpenShift release payload. The image corresponding to the most recent minor release of OpenShift will be tagged with the version number in the catalog. The image URL for a specific release can be found using the `oc adm` CLI command.

Instructions for pulling the `driver-toolkit` image from registry.redhat.io with podman, or in OpenShift can be found on the [Red Hat Ecosystem Catalog](https://catalog.redhat.com/software/containers/openshift4/driver-toolkit-rhel8/604009d6122bd89307e00865?container-tabs=gti "Red Hat Ecosystem Catalog").

The driver-toolkit image for the latest minor release will be tagged with the minor release version on registry.redhat.io for example `registry.redhat.io/openshift4/driver-toolkit-rhel8:v4.8`. 

### Finding the Driver Toolkit image URL in the payload
The following steps require the image pull secret needed to perform an installation of OpenShift, and the `oc` CLI.

The image URL of the `driver-toolkit` corresponding to a certain release can be extracted from the release image using the `oc adm` command:
```bash
$ oc adm release info 4.8.0 --image-for=driver-toolkit
```

Example output:
```
quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:0fd84aee79606178b6561ac71f8540f404d518ae5deff45f6d6ac8f02636c7f4
```

This image can be pulled using a valid pull secret.
```bash
$ podman pull --authfile=path/to/pullsecret.json <image from previous output>
```

## Example usage
The Driver Toolkit can be used as the base image for building a very simple kernel module called simple-kmod. For these steps, you will need to be logged into an OpenShift cluster as a user with cluster-admin privileges, and access to the `oc` CLI.

Create a namespace for the resources:
```bash
$ oc new-project simple-kmod-demo
```

The following YAML defines an `ImageStream` for storing the simple-kmod driver container image, and a `BuildConfig` for building the container. Save [this YAML](https://raw.githubusercontent.com/dagrayvid/blog-artifacts/driver-toolkit-blog/introducing-driver-toolkit/0000-buildconfig.yaml.template "this YAML") as `0000-buildconfig.yaml.template`.
```yaml
apiVersion: image.openshift.io/v1
kind: ImageStream
metadata:
  labels:
    app: simple-kmod-driver-container
  name: simple-kmod-driver-container
  namespace: simple-kmod-demo
spec: {}
---
apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  labels:
    app: simple-kmod-driver-build
  name: simple-kmod-driver-build
  namespace: simple-kmod-demo
spec:
  nodeSelector:
    node-role.kubernetes.io/worker: ""
  runPolicy: "Serial"
  triggers:
    - type: "ConfigChange"
    - type: "ImageChange"
  source:
    git:
      ref: "master"
      uri: "https://github.com/openshift-psap/kvc-simple-kmod.git"
    type: Git
    dockerfile: |
      FROM DRIVER_TOOLKIT_IMAGE

      WORKDIR /build/

      RUN yum -y install git make sudo gcc \
      && yum clean all \
      && rm -rf /var/cache/dnf

      # Expecting kmod software version as an input to the build
      ARG KMODVER

      # Grab the software from upstream
      RUN git clone https://github.com/openshift-psap/simple-kmod.git
      WORKDIR simple-kmod

      # Prep and build the module
      RUN make buildprep KVER=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}"  kernel-core) KMODVER=${KMODVER} \
      && make all       KVER=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}"  kernel-core) KMODVER=${KMODVER} \
      && make install   KVER=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}"  kernel-core) KMODVER=${KMODVER}

      # Add the helper tools
      WORKDIR /root/kvc-simple-kmod
      ADD Makefile .
      ADD simple-kmod-lib.sh .
      ADD simple-kmod-wrapper.sh .
      ADD simple-kmod.conf .
      RUN mkdir -p /usr/lib/kvc/ \
      && mkdir -p /etc/kvc/ \
      && make install

      RUN systemctl enable kmods-via-containers@simple-kmod
  strategy:
    dockerStrategy:
      buildArgs:
        - name: KMODVER
          value: DEMO
  output:
    to:
      kind: ImageStreamTag
      name: simple-kmod-driver-container:demo
```

Substitute the correct driver toolkit image for the OpenShift version you are running in place of `DRIVER_TOOLKIT_IMAGE` with the following commands. Note that the driver toolkit was introduced in 4.6 as of version 4.6.30, in 4.7 as of version 4.7.11, and will be a part of 4.8.

```bash
$ OCP_VERSION=$(oc get clusterversion/version -ojsonpath={.status.desired.version})
$ DRIVER_TOOLKIT_IMAGE=$(oc adm release info $OCP_VERSION --image-for=driver-toolkit)
$ sed “s#DRIVER_TOOLKIT_IMAGE#$DRIVER_TOOLKIT_IMAGE#” 0000-buildconfig.yaml.template > 0000-buildconfig.yaml
```

Once the builder pod completes successfully, deploy the driver container image as a DaemonSet. The driver container needs to run with the privileged security context in order to load the kernel modules on the host. The following .yaml file contains the RBAC rules and the DaemonSet for running the driver container. Save [this YAML](https://raw.githubusercontent.com/dagrayvid/blog-artifacts/driver-toolkit-blog/introducing-driver-toolkit/1000-driver-container.yaml "this YAML") as `1000-driver-container.yaml`.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: simple-kmod-driver-container
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: simple-kmod-driver-container
rules:
- apiGroups:
  - security.openshift.io
  resources:
  - securitycontextconstraints
  verbs:
  - use
  resourceNames:
  - privileged
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: simple-kmod-driver-container
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: simple-kmod-driver-container
subjects:
- kind: ServiceAccount
  name: simple-kmod-driver-container
userNames:
- system:serviceaccount:simple-kmod-demo:simple-kmod-driver-container
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: simple-kmod-driver-container
spec:
  selector:
    matchLabels:
      app: simple-kmod-driver-container
  template:
    metadata:
      labels:
        app: simple-kmod-driver-container
    spec:
      serviceAccount: simple-kmod-driver-container
      serviceAccountName: simple-kmod-driver-container
      containers:
      - image: image-registry.openshift-image-registry.svc:5000/simple-kmod-demo/simple-kmod-driver-container:demo
        name: simple-kmod-driver-container
        imagePullPolicy: Always
        command: ["/sbin/init"]
        lifecycle:
          preStop:
            exec:
              command: ["/bin/sh", "-c", "systemctl stop kmods-via-containers@simple-kmod"]
        securityContext:
          privileged: true
      nodeSelector:
        node-role.kubernetes.io/worker: ""

```

Create the RBAC rules and daemon set:
```bash
$ oc create -f 1000-drivercontainer.yaml
```

Once the pods are running on the worker nodes, we can verify that the `simple_kmod` kernel module is loaded successfully on the host machines with `lsmod`.

Verify the pods are running:
```bash
$ oc get pod -n simple-kmod-demo
```
Example output:
```
NAME                                  READY       STATUS       RESTARTS    AGE
simple-kmod-driver-build-1-build      0/1         Completed    0           6m
simple-kmod-driver-container-b22fd    1/1         Running      0           40s
simple-kmod-driver-container-jz9vn    1/1         Running      0           40s
simple-kmod-driver-container-p45cc    1/1         Running      0           40s
```
Execute the `lsmod` command in the driver container pod:
```bash
$ oc exec -it pod/simple-kmod-driver-container-p45cc -- lsmod | grep simple
```
Example output
```
simple_procfs_kmod     16384  0
simple_kmod            16384  0
```

