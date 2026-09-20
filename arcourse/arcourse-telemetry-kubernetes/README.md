# arcourse/arcourse-telemetry-kubernetes

> Ready-made Kubernetes telemetry entities for arcourse-telemetry, mounted under

- [Source Code](https://github.com/marcbran/arcourse/tree/main/pkg/arcourse-telemetry-kubernetes): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/arcourse-telemetry-kubernetes/arcourse/arcourse-telemetry-kubernetes/main.libsonnet): Inlined code published for usage in other projects

## Installation

You can install the library into your project using the [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

```shell
jb install https://github.com/marcbran/jsonnet/arcourse/arcourse-telemetry-kubernetes@arcourse/arcourse-telemetry-kubernetes
```

Then you can import it into your file in order to use it:

```jsonnet
local arcourse-telemetry-kubernetes = import 'arcourse/arcourse-telemetry-kubernetes/main.libsonnet';
```

## Description

`pod`, `container`, `pvc`, `deployment`, `node`) via kube-state-metrics and
cAdvisor queries, with drilldown charts and cross-links to the matching
`arcourse-kubernetes` resource nodes (and back). The `context`, `namespace`,
`pod`, and `container` entities also expose a `logs` view.

This is an opinionated, backend-coupled convenience layer: metric drilldowns
assume Prometheus/PromQL (kube-state-metrics + cAdvisor), and the `logs`
selectors assume Loki/LogQL, with `cluster`/`namespace`/`container` as indexed
labels and `pod` as structured metadata (`| pod="..."`). Each entity's queries
are overridable fields, so a different metrics or logs backend can be swapped
in per entity.

Assumes a `cluster` label identifies the context and that the resource tree is
mounted at `root.kubernetes`. Each entity is exposed as an overridable field;
`nodeList` materializes them all through `arcourse-telemetry`'s `entities.nodeList`.

## Fields

### container

Entity spec for the container dimension, with restarts/cpu/memory drilldowns and a logs view.

```jsonnet
arcourse-telemetry-kubernetes.container
```


### context

Entity spec for the cluster/context dimension, with a logs view.

```jsonnet
arcourse-telemetry-kubernetes.context
```


### deployment

Entity spec for the deployment dimension, with an availability drilldown.

```jsonnet
arcourse-telemetry-kubernetes.deployment
```


### namespace

Entity spec for the namespace dimension, with a logs view.

```jsonnet
arcourse-telemetry-kubernetes.namespace
```


### node

Entity spec for the node dimension, with a conditions drilldown.

```jsonnet
arcourse-telemetry-kubernetes.node
```


### nodeList

All entity specs materialized through `entities.nodeList`.

```jsonnet
arcourse-telemetry-kubernetes.nodeList
```


### pod

Entity spec for the pod dimension, with a pod-phase state timeline drilldown and a logs view.

```jsonnet
arcourse-telemetry-kubernetes.pod
```


### pvc

Entity spec for the persistent volume claim dimension, with a usage drilldown.

```jsonnet
arcourse-telemetry-kubernetes.pvc
```

