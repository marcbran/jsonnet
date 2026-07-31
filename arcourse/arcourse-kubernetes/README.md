# arcourse/arcourse-kubernetes

> Generates an arcourse graph for browsing Kubernetes resources via the raw REST API.

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

Discovers API groups/resources for one or more configured contexts and generates
Jsonnet source (via jsonnet-plugin-jsonnet) that wires up list/detail nodes per
resource, reading data through jsonnet-plugin-kubernetes. Supports custom columns
and links, either explicit or derived from an OpenAPI discovery document.

## Fields

### graph

Root package. `contexts` are the configured kubeconfig context(s), `columns` and

```jsonnet
arcourse-kubernetes.graph
```

`manifest` (default `true`) controls whether `_view.jsonnet` is rendered as a
string or returned as an AST.
