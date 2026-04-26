# plugin/kubectl

> Read-only access to Kubernetes resources via client-go, similar to `kubectl get`.

- [Source Code](https://github.com/marcbran/jsonnet-plugin-kubectl): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/plugin/kubectl/plugin/kubectl/main.libsonnet): Inlined code published for usage in other projects

## Installation

You can install the library into your project using the [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

```shell
jb install https://github.com/marcbran/jsonnet/plugin/kubectl@plugin/kubectl
```

Then you can import it into your file in order to use it:

```jsonnet
local kubectl = import 'plugin/kubectl/main.libsonnet';
```

## Description


## Fields

### get

Fetches one resource by name or lists resources. Pass `name: null` (default) to list.

```jsonnet
kubectl.get()
```

`options` may include `context` and `namespace`; omitted values use kubeconfig defaults.

On success returns the API object or list JSON. On failure returns a Kubernetes `Status` object (`kind: "Status"`).
