# plugin/aws

> Read-only calls against AWS service APIs, driven by the services' Smithy models. Services and credentials are configured when the plugin is started or embedded in Go.

- [Source Code](https://github.com/marcbran/jsonnet-plugin-aws/tree/main/pkg/jsonnet-plugin-aws): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/plugin/aws/plugin/aws/main.libsonnet): Inlined code published for usage in other projects

## Installation

You can install the library into your project using the [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

```shell
jb install https://github.com/marcbran/jsonnet/plugin/aws@plugin/aws
```

Then you can import it into your file in order to use it:

```jsonnet
local aws = import 'plugin/aws/main.libsonnet';
```

## Description


## Fields

### call

Calls a read operation (`Describe*`, `List*`, `Get*`, `Head*`, `BatchGet*`). `ctx` is `{ account, region }`, `service` is the

```jsonnet
aws.call()
```

Null members are omitted. Pagination tokens and page sizes are ordinary input and output members.

On success returns the decoded output structure. On failure returns a `Status` object (`kind: "Status"`).
