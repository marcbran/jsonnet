# arcourse/aws/arcourse-aws

> Arcourse entry nodes for AWS: the `aws` node listing the configured accounts and the

- [Source Code](https://github.com/marcbran/jsonnet-plugin-aws/tree/main/pkg/arcourse-aws): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/aws/arcourse-aws/arcourse/aws/arcourse-aws/main.libsonnet): Inlined code published for usage in other projects

## Installation

You can install the library into your project using the [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

```shell
jb install https://github.com/marcbran/jsonnet/arcourse/aws/arcourse-aws@arcourse/aws/arcourse-aws
```

Then you can import it into your file in order to use it:

```jsonnet
local arcourse-aws = import 'arcourse/aws/arcourse-aws/main.libsonnet';
```

## Description

packages, which link themselves from the region nodes.

## Fields

### accounts

Accounts to browse, as `{ [accountId]: { name, regions: [...] } }`; none by default.

```jsonnet
arcourse-aws.accounts
```


### nodeList

The `aws` and `aws/$account` nodes for the configured accounts.

```jsonnet
arcourse-aws.nodeList
```

