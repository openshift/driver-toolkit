# Driver-toolkit imagestream

In OCP, you will find the driver-toolkit imagestream that will contain a tag for each RHCOS version running in the cluster.

The name of the imagestream is `driver-toolkit` in the `openshift` namespace.

In order to generate such imagestream during the cluster installation, there are multiple parts that needs to be taken into consideration:

* DTK: add an [templated imagestream](../manifests/01-openshift-imagestream.yaml) to the payload.
* ART: adding that imagestream to the cluster deployment (templeted) by running `oc adm release new ...`.
* OC: Owning the code for `oc adm release new …` which will scrape the [machine-os-content](https://github.com/openshift/machine-config-operator/blob/master/docs/OSUpgrades.md#os-updates).
* MCO: owns the machine-os-content.
