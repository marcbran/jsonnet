# plugin/kubernetes

> Kubernetes API access authenticated via kubectl contexts.

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

Use `get(ctx, path)` to fetch resources from a cluster, `exec(ctx, target, command)` to run a command in a pod,
`proxy(ctx, target, path, options)` to send an HTTP request to a pod or service through the API server, or
`contexts()` to list available kubectl contexts.
The kubectl context resolves the API server URL and credentials automatically.

Mutating operations are exposed as plugin actions rather than jsonnet functions, so they are not
callable during evaluation. The host invokes them by name: `patch` and `delete`.

`exec` and `proxy` are also available as actions, for commands or requests with side effects. They take
the same parameters as the functions as named fields (`{ ctx, target, command }` and
`{ ctx, target, path, options }`, with `options` optional) and return the same result as JSON.

## Fields

### contexts

Returns all kubectl contexts from the local kubeconfig as an array.

```jsonnet
kubernetes.contexts()
```

Each entry contains `name`, `current`, `cluster`, `authInfo`, and `namespace`.

### exec

Runs `command` (an array of strings) in a pod using the kubectl context `ctx`.

```jsonnet
kubernetes.exec()
```

`target` is `{ namespace, pod, container }`. An omitted `container` selects the pod's default container.

Returns `{ exitCode, stdout, stderr }`. A non-zero exit code is returned as a result, not as an error.
The hidden field `json` holds `stdout` parsed as JSON.

### get

Sends a GET request to the Kubernetes API server at `path` using the kubectl context `ctx`.

```jsonnet
kubernetes.get()
```

On success returns parsed JSON. On failure returns a `Status` object (`kind: "Status"`).

### proxy

Sends an HTTP request to a pod or service through the API server's proxy subresource, using the kubectl

```jsonnet
kubernetes.proxy()
```


`target` is `{ namespace, service, port, scheme }` or `{ namespace, pod, port, scheme }`. `port` is a number
or a port name and may be omitted. `scheme` is `http` (default) or `https`; the API server does not verify
the target's TLS certificate.

`path` is the request path including the query string, e.g. `/_cat/indices?format=json`.

`options` is `{ method, headers, body }`. `method` defaults to `GET`, `body` is a string.

Returns `{ status, statusText, headers, body }`. Header names are lowercase and repeated values are
joined with `, `. A non-2xx status is returned as a result, not as an error; this includes errors from
the API server itself, such as a missing pod or a service without ready endpoints. The hidden
field `json` holds `body` parsed as JSON.

The API server consumes the `Authorization` header, so targets that require their own `Authorization`
header cannot be reached this way.
