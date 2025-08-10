# terraform-provider-docker

> Terraform provider docker

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/terraform-provider/registry.terraform.io/kreuzwerker/docker/terraform-provider-docker/main.libsonnet): Inlined code published for usage in other projects

## Installation

You can install the library into your project using the [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

```shell
jb install https://github.com/marcbran/jsonnet/terraform-provider-docker@terraform-provider/registry.terraform.io/kreuzwerker/docker
```

Then you can import it into your file in order to use it:

```jsonnet
local docker = import 'terraform-provider-docker/main.libsonnet';
```

## Description

