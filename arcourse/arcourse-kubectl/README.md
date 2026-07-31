# arcourse/arcourse-kubectl

> Generates an arcourse graph for browsing Kubernetes resources via `kubectl`.

- [Source Code](https://github.com/marcbran/arcourse/tree/main/pkg/arcourse-kubectl): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/arcourse-kubectl/arcourse/arcourse-kubectl/main.libsonnet): Inlined code published for usage in other projects

## Installation

You can install the library into your project using the [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

```shell
jb install https://github.com/marcbran/jsonnet/arcourse/arcourse-kubectl@arcourse/arcourse-kubectl
```

Then you can import it into your file in order to use it:

```jsonnet
local arcourse-kubectl = import 'arcourse/arcourse-kubectl/main.libsonnet';
```

## Description

Discovers API resources for one or more configured contexts and generates Jsonnet
source (via jsonnet-plugin-jsonnet) that wires up list/detail nodes per resource,
reading data through jsonnet-plugin-kubectl.

## Fields

### graph

Root package. `data.contexts` are the configured kubeconfig context(s) and

```jsonnet
arcourse-kubectl.graph
```

string or returned as an AST.
