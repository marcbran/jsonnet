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

### apps

`nodeList` adds pod tables for deployments, statefulsets and daemonsets (selected

```jsonnet
arcourse-kubernetes.apps
```


### core

Hand-written core layers on top of the generated graph. `nodeList` adds the pod

```jsonnet
arcourse-kubernetes.core
```

pod columns including computed Ready and Restarts.

### graph

Root package. `contexts` are the configured kubeconfig context(s), `columns` and

```jsonnet
arcourse-kubernetes.graph
```

`manifest` (default `true`) controls whether `_view.jsonnet` is rendered as a
string or returned as an AST. Each API group is shown on the context and namespace
views as a card linking its resources directly. Groups are ordered as groups without
dots, then the rest as a domain tree so a subdomain follows its parent domain. `favoriteGroups` (default `[]`) is a list of domain
patterns shown first: a pattern matches the group itself and its subdomains, `*.domain`
matches only the subdomains and `*` matches every group; each group ranks at the
position of its most specific matching favorite. `hiddenGroups` (default `[]`) takes
the same patterns for groups whose cards are left out; their resources' nodes still
exist. When a group matches both lists, the more specific pattern wins and a tie goes
to the favorite.
`hiddenResources` (default `{}`) maps an API group (`''` for core) to resource names
left out of its card; the resources' nodes still exist.
`listColumns` (default `4`) is the number of columns the context node and
the namespace detail node lay out their links in; the namespace detail node also
shows its YAML above the links. `namespaces` (default `{}`) maps a namespace name to
overrides of `favoriteGroups`, `hiddenGroups`, `hiddenResources` and `listColumns` for
that namespace's detail node; each set field replaces the top-level one, the rest
fall back to it, and the context node always uses the top-level settings. Both the
context and the namespace node get an `apiResources` child linking every listable
resource of their scope as cards per API group, ordered by `favoriteGroups` and laid
out in `listColumns`, but ignoring `hiddenGroups` and `hiddenResources`.

### networking.k8s.io

`nodeList` adds an external https link per ingress rule host.

```jsonnet
arcourse-kubernetes.networking.k8s.io
```

