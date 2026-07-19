# plugin/kubernetes

> Read-only Kubernetes API requests authenticated via kubectl contexts.

- [Source Code](https://github.com/marcbran/jsonnet-plugin-kubernetes): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/plugin/kubernetes/plugin/kubernetes/main.libsonnet): Inlined code published for usage in other projects

## Installation

You can install the library into your project using the [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

```shell
jb install https://github.com/marcbran/jsonnet/plugin/kubernetes@plugin/kubernetes
```

Then you can import it into your file in order to use it:

```jsonnet
local kubernetes = import 'plugin/kubernetes/main.libsonnet';
```

## Description

Use `get(ctx, path)` to fetch resources from a cluster, or `contexts()` to list available kubectl contexts.
The kubectl context resolves the API server URL and credentials automatically.

## Fields

### contexts

Returns all kubectl contexts from the local kubeconfig as an array.

```jsonnet
kubernetes.contexts()
```

Each entry contains `name`, `current`, `cluster`, `authInfo`, and `namespace`.

### get

Sends a GET request to the Kubernetes API server at `path` using the kubectl context `ctx`.

```jsonnet
kubernetes.get()
```

On success returns parsed JSON. On failure returns a `Status` object (`kind: "Status"`).
