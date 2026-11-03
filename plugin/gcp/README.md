# plugin/gcp

> Read-only calls against Google Cloud APIs, driven by the services' Discovery documents. Services and credentials are configured when the plugin is started or embedded in Go.

- [Source Code](https://github.com/marcbran/jsonnet-plugin-gcp): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/plugin/gcp/plugin/gcp/main.libsonnet): Inlined code published for usage in other projects

## Installation

You can install the library into your project using the [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

```shell
jb install https://github.com/marcbran/jsonnet/plugin/gcp@plugin/gcp
```

Then you can import it into your file in order to use it:

```jsonnet
local gcp = import 'plugin/gcp/main.libsonnet';
```

## Description


## Fields

### call

Calls a read method (HTTP `GET`, not denied). `ctx` is `{ project }`, `service` is the Discovery API name (e.g. `compute`),

```jsonnet
gcp.call()
```

`project` is taken from `ctx` wherever the method declares it and must not be passed in `params`. Null parameters are
omitted. Pagination tokens and page sizes are ordinary parameters and response fields.

On success returns the decoded response body. On failure returns a `Status` object (`kind: "Status"`).
