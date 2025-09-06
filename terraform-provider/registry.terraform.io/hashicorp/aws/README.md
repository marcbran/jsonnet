# terraform-provider-aws

> Terraform provider aws

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/terraform-provider/registry.terraform.io/hashicorp/aws/terraform-provider-aws/main.libsonnet): Inlined code published for usage in other projects

## Installation

You can install the library into your project using the [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

```shell
jb install https://github.com/marcbran/jsonnet/terraform-provider-aws@terraform-provider/registry.terraform.io/hashicorp/aws
```

Then you can import it into your file in order to use it:

```jsonnet
local aws = import 'terraform-provider-aws/main.libsonnet';
```

## Description

