# mq-qm01

This project contains necessary artifacts for deploying queuemanager on Openshift.

## Table of Contents

* [Introduction](#introduction)
* [Pre-requisites](#pre-requisites)
* [Queuemanager Details](#queuemanager-details)

## Introduction

This guide provides a walkthrough on how to set up an Queuemanager.  The Github repository is a template containing a Dockerfile and Kustomize resources which is used with the [Cloud Native Toolkit](https://cloudnativetoolkit.dev/) to register a Tekton pipeline to build a Queuemanager image and deploy it on a containerized instance of IBM MQ. Optionally, it also contains a Helm chart which can be used by the developer to deploy the queuemanager using Helm.

This repo contains the below artifacts.

```
.
├── Dockerfile
├── README.md
├── chart
│   └── base
│       ├── Chart.yaml
│       ├── config
│       │   └── config.mqsc
│       ├── security
│       │   └── config.mqsc
│       ├── templates
│       │   ├── NOTES.txt
│       │   ├── _helpers.tpl
│       │   ├── configmap.yaml
│       │   └── qm-template.yaml
│       └── values.yaml
└── kustomize
    ├── base
    │   ├── generic-qmgr
    │   │   ├── kustomization.yaml
    │   │   ├── queuemanager.yaml
    │   │   └── static-definitions.mqsc
    │   └── native-ha-qmgr
    └── components
        ├── dynamic-mqsc
        │   └── generic-qmgr
        │       ├── dynamic-definitions.mqsc
        │       ├── kustomization.yaml
        │       └── queuemanager.yaml
        └── scripts
            ├── kustomization.yaml
            ├── start-mqsc.sh
            └── stop-mqsc.sh
```

- `ibm-mqadvanced-server-integration` docker image that comes with CloudPaks. This image can be further customized if we need additional configurations that are part of queuemanager.
- `Helm Charts` - Currently, we are using quickstart template as our base and building additional things on top of it for deploying the queuemanager.
- `Kustomize` - Currently, kustomize folder includes two variants of queuemanager, one is using the basic template and the other is using the native-ha template. Using these bases, additonal things are built on top of them for deploying the desired queuemanager.
- `Configurations` - Like mentioned earlier, the configurations can be embedded as part of Dockerfile. Alternatively, they can also be injected as configmaps.

## Pre-requisites

- [IBM Catalog Operator](https://www.ibm.com/docs/en/app-connect/11.0.0?topic=iicia-enabling-operator-catalog-cloud-pak-foundational-services-operator)
- [IBM Common Services](https://github.com/IBM/ibm-common-service-operator)
- [IBM MQ Operator](https://www.ibm.com/docs/en/ibm-mq/9.2?topic=integration-using-mq-in-cloud-pak-openshift)

## Queuemanager Details

### Kustomize

- `generic-qmgr` contains the basic queuemanager resources. In this, security and native HA are disabled.
- To enable high availability, use the queuemanager resources from `native-ha-qmgr`.
- Similarly, we can define different variants of queuemanager under the `base` based on our requirements. For instance, we can enable the security on top of the basic template and create resources for generic queuemanager with security turned on and place it in a folder named `generic-qmgr-with-security` under base.

Note: This project demonstrates how to add in the `mqsc` configuration files. Similarly, if you want to configure an `static-definitions.ini`, please create an `ini` file for the same and inject it under `configMapGenerator` in the `kustomization.yaml` using the below snippet.

```yaml
configMapGenerator:
# Create an MQSC configMap using generic MQSC which will be added to all queue managers and applied during bootstrap.
- name: ini-configmap
  behavior: create
  files:
  - static-definitions.ini
```

#### Static Configurations

This queuemanager will use the `static-definitions.mqsc` to populate the necessary configurations. Whenever, there is a change in the configuration, the queuemanager should be restarted to enable the changes.

#### Dynamic Configurations

To avoid the downtime, we can alternatively use the `dynamic-definitions.mqsc` to populate the necessary configurations. This doesn't need the queuemanager restart and the changes will be automatically picked up.

For this functionality, we used kustomize `components` to generate the dynamic definitions. By default, these configurations are in place.

### Helm Chart

- Intially, security and native HA are disabled.
- To enable security, set `security` to true in `Values.yaml`.
- To enable high availability, set `ha` to true in `Values.yaml`.

Note: This project demonstrates how to add in the `mqsc` configuration files. Similarly, if you want to configure an `qm.ini`, please create a configMap for the same and inject it under `spec.queueManager` in the `qm-template.yaml` using the below snippet.

```yaml
ini:
- configMap:
    name: {{ .Values.ini.configmap }}
    items:
    - {{ .Values.ini.name }}
```

### Configuration

- Create required queues to store info.
- Create channel to provide necessary communication links.
- For this queuemanager, channel authentication is disabled.

## Enable Security

If you want to enable the queuemanager to use security, we need to set the `security` flag to `true` in `Values.yaml` if using Helm. By default, it is always `false`. If you are using kustomize, use the flavor of queuemanager where security is enabled.

### Configuration

- Create required queues to store info.
- Except for the channel used by MQ Explorer, all channels with inbound connections are blocked.
- Create channel to provide necessary communication links.
- Allow access to the LDAP channel.
- Privileged user IDs asserted by a client-connection channel are blocked by means of the special value *MQADMIN* by default. We are removing this default rule.
- For authentication, our queuemanage is using LDAP. We define necessary LDAP configurations. Our sample configurations as follows.

  ```
    DEFINE AUTHINFO(USE.LDAP) +
    AUTHTYPE(IDPWLDAP) +
    CONNAME('openldap.openldap(389)') +
    LDAPUSER('cn=admin,dc=ibm,dc=com') LDAPPWD('admin') +
    SECCOMM(NO) +
    USRFIELD('uid') +
    SHORTUSR('uid') +
    BASEDNU('ou=people,dc=ibm,dc=com') +
    AUTHORMD(SEARCHGRP) +
    BASEDNG('ou=groups,dc=ibm,dc=com') +
    GRPFIELD('cn') +
    CLASSGRP('groupOfUniqueNames') +
    FINDGRP('uniqueMember') +
    CHCKCLNT(REQUIRED) +
    REPLACE
    ALTER QMGR CONNAUTH(USE.LDAP)
  ```
- Enable TLS protocol security. We can specify the cryptographic algorithms that are used by the TLS protocol by supplying a CipherSpec as part of the channel definition along with the authenticated user information.
- This privileged user will be allowed to access the queue manager and interact with it.

## Enable Native HA

If you want to enable the queuemanager to use native high avaibility capability, we need to set the `ha` flag to `true` in `Values.yaml` if using Helm. By default, it is always `false`. If you are using kustomize, use the flavor of queuemanager where native ha is enabled.

- A Native HA configuration provides a highly available queue manager where the recoverable MQ data (for example, the messages)  are replicated across multiple sets of storage, preventing loss from storage failures.
- This is suitable for use with cloud block storage.
