# arcourse/arcourse-kubernetes

> Arcourse graph for browsing Kubernetes resources.

- [Source Code](https://github.com/marcbran/arcourse/tree/main/pkg/arcourse-kubernetes): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/arcourse-kubernetes/arcourse/arcourse-kubernetes/main.libsonnet): Inlined code published for usage in other projects

## Installation

You can install the library into your project using the [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

```shell
jb install https://github.com/marcbran/jsonnet/arcourse/arcourse-kubernetes@arcourse/arcourse-kubernetes
```

Then you can import it into your file in order to use it:

```jsonnet
local arcourse-kubernetes = import 'arcourse/arcourse-kubernetes/main.libsonnet';
```

## Description


## Fields

### apps

Pod and replicaset tables plus restart and scale actions for workloads.

```jsonnet
arcourse-kubernetes.apps
```


### core

Pod tables.

```jsonnet
arcourse-kubernetes.core
```


### graph

Generates list and detail nodes for the resources of the configured contexts.

```jsonnet
arcourse-kubernetes.graph
```


### networking.k8s.io

External links for ingress hosts.

```jsonnet
arcourse-kubernetes.networking.k8s.io
```

