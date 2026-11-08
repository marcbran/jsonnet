# Jsonnet

This repository hosts reusable Jsonnet packages prepared for easy integration in other projects.
Each package has been processed by inlining all its code into a single file.
Additionally, each output file has been placed onto a separate branch.
This enables lightweight and straightforward usage with the [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler).
## arcourse/arcourse-course

> Node specs exposing an arcourse instance's own course history as part of the graph

- [Readme](arcourse/arcourse-course/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/arcourse/tree/main/pkg/arcourse-course): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/arcourse-course/arcourse/arcourse-course/main.libsonnet): Inlined code published for usage in other projects
## arcourse/arcourse-echarts

> Shared views for rendering arcourse graph nodes as ECharts charts and dashboards,

- [Readme](arcourse/arcourse-echarts/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/jsonnet-plugin-telemetry/tree/main/pkg/arcourse-echarts): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/arcourse-echarts/arcourse/arcourse-echarts/main.libsonnet): Inlined code published for usage in other projects
## arcourse/arcourse-graph

> Path-addressable node graph primitives used to compose arcourse resource explorers.

- [Readme](arcourse/arcourse-graph/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/arcourse/tree/main/pkg/arcourse-graph): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/arcourse-graph/arcourse/arcourse-graph/main.libsonnet): Inlined code published for usage in other projects
## arcourse/arcourse-kubernetes

> Arcourse graph for browsing Kubernetes resources.

- [Readme](arcourse/arcourse-kubernetes/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/jsonnet-plugin-kubernetes/tree/main/pkg/arcourse-kubernetes): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/arcourse-kubernetes/arcourse/arcourse-kubernetes/main.libsonnet): Inlined code published for usage in other projects
## arcourse/arcourse-openapi

> Generates an arcourse graph for browsing any OpenAPI-described service.

- [Readme](arcourse/arcourse-openapi/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/jsonnet-plugin-openapi/tree/main/pkg/arcourse-openapi): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/arcourse-openapi/arcourse/arcourse-openapi/main.libsonnet): Inlined code published for usage in other projects
## arcourse/arcourse-telemetry-kubernetes

> Ready-made Kubernetes telemetry entities for arcourse-telemetry, mounted under

- [Readme](arcourse/arcourse-telemetry-kubernetes/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/jsonnet-plugin-kubernetes/tree/main/pkg/arcourse-telemetry-kubernetes): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/arcourse-telemetry-kubernetes/arcourse/arcourse-telemetry-kubernetes/main.libsonnet): Inlined code published for usage in other projects
## arcourse/arcourse-telemetry

> Backend-agnostic `chart`/`logs`/`dashboard` nodes rendering telemetry

- [Readme](arcourse/arcourse-telemetry/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/jsonnet-plugin-telemetry/tree/main/pkg/arcourse-telemetry): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/arcourse-telemetry/arcourse/arcourse-telemetry/main.libsonnet): Inlined code published for usage in other projects
## arcourse/arcourse-ui

> Shared views for rendering arcourse graph nodes as HTML, built on top of

- [Readme](arcourse/arcourse-ui/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/arcourse/tree/main/pkg/arcourse-ui): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/arcourse-ui/arcourse/arcourse-ui/main.libsonnet): Inlined code published for usage in other projects
## arcourse/aws/arcourse-aws-ec2

> Arcourse nodes for Amazon Elastic Compute Cloud, below `aws/$account/$region/ec2`.

- [Readme](arcourse/aws/arcourse-aws-ec2/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/jsonnet-plugin-aws/tree/main/pkg/arcourse-aws-ec2): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/aws/arcourse-aws-ec2/arcourse/aws/arcourse-aws-ec2/main.libsonnet): Inlined code published for usage in other projects
## arcourse/aws/arcourse-aws-ecr

> Arcourse nodes for Amazon Elastic Container Registry, below `aws/$account/$region/ecr`.

- [Readme](arcourse/aws/arcourse-aws-ecr/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/jsonnet-plugin-aws/tree/main/pkg/arcourse-aws-ecr): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/aws/arcourse-aws-ecr/arcourse/aws/arcourse-aws-ecr/main.libsonnet): Inlined code published for usage in other projects
## arcourse/aws/arcourse-aws-iam

> Arcourse nodes for AWS Identity and Access Management, below `aws/$account/iam`.

- [Readme](arcourse/aws/arcourse-aws-iam/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/jsonnet-plugin-aws/tree/main/pkg/arcourse-aws-iam): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/aws/arcourse-aws-iam/arcourse/aws/arcourse-aws-iam/main.libsonnet): Inlined code published for usage in other projects
## arcourse/aws/arcourse-aws-opensearch

> Arcourse nodes for Amazon OpenSearch Service, below `aws/$account/$region/opensearch`.

- [Readme](arcourse/aws/arcourse-aws-opensearch/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/jsonnet-plugin-aws/tree/main/pkg/arcourse-aws-opensearch): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/aws/arcourse-aws-opensearch/arcourse/aws/arcourse-aws-opensearch/main.libsonnet): Inlined code published for usage in other projects
## arcourse/aws/arcourse-aws-rds

> Arcourse nodes for Amazon Relational Database Service, below `aws/$account/$region/rds`.

- [Readme](arcourse/aws/arcourse-aws-rds/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/jsonnet-plugin-aws/tree/main/pkg/arcourse-aws-rds): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/aws/arcourse-aws-rds/arcourse/aws/arcourse-aws-rds/main.libsonnet): Inlined code published for usage in other projects
## arcourse/aws/arcourse-aws-s3

> Arcourse nodes for Amazon Simple Storage Service, below `aws/$account/$region/s3`.

- [Readme](arcourse/aws/arcourse-aws-s3/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/jsonnet-plugin-aws/tree/main/pkg/arcourse-aws-s3): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/aws/arcourse-aws-s3/arcourse/aws/arcourse-aws-s3/main.libsonnet): Inlined code published for usage in other projects
## arcourse/aws/arcourse-aws

> Arcourse entry nodes for AWS: the `aws` node listing the configured accounts and the

- [Readme](arcourse/aws/arcourse-aws/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/jsonnet-plugin-aws/tree/main/pkg/arcourse-aws): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/aws/arcourse-aws/arcourse/aws/arcourse-aws/main.libsonnet): Inlined code published for usage in other projects
## arcourse/gcp/arcourse-gcp-compute

> Arcourse nodes for Compute Engine, below `gcp/$project/compute`.

- [Readme](arcourse/gcp/arcourse-gcp-compute/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/jsonnet-plugin-gcp/tree/main/pkg/arcourse-gcp-compute): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/gcp/arcourse-gcp-compute/arcourse/gcp/arcourse-gcp-compute/main.libsonnet): Inlined code published for usage in other projects
## arcourse/gcp/arcourse-gcp-storage

> Arcourse nodes for Cloud Storage, below `gcp/$project/storage`.

- [Readme](arcourse/gcp/arcourse-gcp-storage/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/jsonnet-plugin-gcp/tree/main/pkg/arcourse-gcp-storage): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/gcp/arcourse-gcp-storage/arcourse/gcp/arcourse-gcp-storage/main.libsonnet): Inlined code published for usage in other projects
## arcourse/gcp/arcourse-gcp

> Arcourse entry nodes for Google Cloud: the `gcp` node listing the configured projects and the

- [Readme](arcourse/gcp/arcourse-gcp/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/jsonnet-plugin-gcp/tree/main/pkg/arcourse-gcp): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/arcourse/gcp/arcourse-gcp/arcourse/gcp/arcourse-gcp/main.libsonnet): Inlined code published for usage in other projects
## pkg

> Jsonnet package definitions.

- [Readme](pkg/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/jpoet/tree/main/pkg/pkg/lib): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/pkg/pkg/main.libsonnet): Inlined code published for usage in other projects
## plugin/aws

> Read-only calls against AWS service APIs, driven by the services' Smithy models. Services and credentials are configured when the plugin is started or embedded in Go.

- [Readme](plugin/aws/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/jsonnet-plugin-aws/tree/main/pkg/jsonnet-plugin-aws): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/plugin/aws/plugin/aws/main.libsonnet): Inlined code published for usage in other projects
## plugin/gcp

> Read-only calls against Google Cloud APIs, driven by the services' Discovery documents. Services and credentials are configured when the plugin is started or embedded in Go.

- [Readme](plugin/gcp/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/jsonnet-plugin-gcp/tree/main/pkg/jsonnet-plugin-gcp): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/plugin/gcp/plugin/gcp/main.libsonnet): Inlined code published for usage in other projects
## plugin/html

> Object-based DSL for creating HTML documents.

- [Readme](plugin/html/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/jsonnet-plugin-html/tree/main/pkg/jsonnet-plugin-html): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/plugin/html/plugin/html/main.libsonnet): Inlined code published for usage in other projects
## plugin/http

> HTTP requests against a REST API. Base URL and default headers are configured when the plugin is started or embedded in Go.

- [Readme](plugin/http/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/jsonnet-plugin-http/tree/main/pkg/jsonnet-plugin-http): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/plugin/http/plugin/http/main.libsonnet): Inlined code published for usage in other projects
## plugin/jsonnet

> DSL for creating Jsonnet code.

- [Readme](plugin/jsonnet/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/jsonnet-plugin-jsonnet/tree/main/pkg/jsonnet-plugin-jsonnet): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/plugin/jsonnet/plugin/jsonnet/main.libsonnet): Inlined code published for usage in other projects
## plugin/kubernetes

> Kubernetes API access authenticated via kubectl contexts.

- [Readme](plugin/kubernetes/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/jsonnet-plugin-kubernetes/tree/main/pkg/jsonnet-plugin-kubernetes): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/plugin/kubernetes/plugin/kubernetes/main.libsonnet): Inlined code published for usage in other projects
## plugin/markdown

> DSL for creating Markdown documents.

- [Readme](plugin/markdown/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/jsonnet-plugin-markdown/tree/main/pkg/jsonnet-plugin-markdown): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/plugin/markdown/plugin/markdown/main.libsonnet): Inlined code published for usage in other projects
## plugin/openapi

> OpenAPI-oriented native functions and code generation support for Jsonnet.

- [Readme](plugin/openapi/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/jsonnet-plugin-openapi/tree/main/pkg/jsonnet-plugin-openapi): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/plugin/openapi/plugin/openapi/main.libsonnet): Inlined code published for usage in other projects
## plugin/telemetry

> Batched telemetry queries: send a mix of query mechanisms (`promql`, `logql`, ...) in one call, distinguished by a `type` field, and let the configured backend batch as many of them as it can into as few round trips as possible.

- [Readme](plugin/telemetry/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/jsonnet-plugin-telemetry/tree/main/pkg/jsonnet-plugin-telemetry): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/plugin/telemetry/plugin/telemetry/main.libsonnet): Inlined code published for usage in other projects
## plugin/time

> Relative time resolution: get the current time, and add a signed duration spec to it. `y`(ear) and `M`(onth) use calendar-aware arithmetic, so they land on the right day even though months and years aren't a fixed length - `M` is uppercase since lowercase `m` means minute. `w`(eek) and `d`(ay) are fixed-length (7/1 days). The remainder - `h`, `m`, `s`, `ms`, `us`, `ns` - is also fixed-length duration.

- [Readme](plugin/time/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/jsonnet-plugin-time/tree/main/pkg/jsonnet-plugin-time): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/plugin/time/plugin/time/main.libsonnet): Inlined code published for usage in other projects
## plugin/url

> URL building, parsing and escaping backed by Go's `net/url`. Path segments and query parameters are escaped the way Go escapes them: a path segment keeps characters like `:`, `@` and `+`, while query keys and values escape them and encode spaces as `+`. Query parameters are objects whose values are strings, numbers, booleans or arrays of those; arrays become repeated keys and `null` values are omitted.

- [Readme](plugin/url/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/jsonnet-plugin-url/tree/main/pkg/jsonnet-plugin-url): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/plugin/url/plugin/url/main.libsonnet): Inlined code published for usage in other projects
## promql

> Jsonnet library that implements a DSL for PromQL.

- [Readme](promql/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/jsonnet-libs): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/promql/promql/main.libsonnet): Inlined code published for usage in other projects
## terraform-provider-cloudflare

> Terraform provider cloudflare

- [Readme](terraform-provider/registry.terraform.io/cloudflare/cloudflare/README.md): Documentation of installation and usage

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/terraform-provider/registry.terraform.io/cloudflare/cloudflare/terraform-provider-cloudflare/main.libsonnet): Inlined code published for usage in other projects
## terraform-provider-authentik

> Terraform provider authentik

- [Readme](terraform-provider/registry.terraform.io/goauthentik/authentik/README.md): Documentation of installation and usage

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/terraform-provider/registry.terraform.io/goauthentik/authentik/terraform-provider-authentik/main.libsonnet): Inlined code published for usage in other projects
## terraform-provider-grafana

> Terraform provider grafana

- [Readme](terraform-provider/registry.terraform.io/grafana/grafana/README.md): Documentation of installation and usage

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/terraform-provider/registry.terraform.io/grafana/grafana/terraform-provider-grafana/main.libsonnet): Inlined code published for usage in other projects
## terraform-provider-assert

> Terraform provider assert

- [Readme](terraform-provider/registry.terraform.io/hashicorp/assert/README.md): Documentation of installation and usage

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/terraform-provider/registry.terraform.io/hashicorp/assert/terraform-provider-assert/main.libsonnet): Inlined code published for usage in other projects
## terraform-provider-aws

> Terraform provider aws

- [Readme](terraform-provider/registry.terraform.io/hashicorp/aws/README.md): Documentation of installation and usage

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/terraform-provider/registry.terraform.io/hashicorp/aws/terraform-provider-aws/main.libsonnet): Inlined code published for usage in other projects
## terraform-provider-azurerm

> Terraform provider azurerm

- [Readme](terraform-provider/registry.terraform.io/hashicorp/azurerm/README.md): Documentation of installation and usage

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/terraform-provider/registry.terraform.io/hashicorp/azurerm/terraform-provider-azurerm/main.libsonnet): Inlined code published for usage in other projects
## terraform-provider-dns

> Terraform provider dns

- [Readme](terraform-provider/registry.terraform.io/hashicorp/dns/README.md): Documentation of installation and usage

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/terraform-provider/registry.terraform.io/hashicorp/dns/terraform-provider-dns/main.libsonnet): Inlined code published for usage in other projects
## terraform-provider-external

> Terraform provider external

- [Readme](terraform-provider/registry.terraform.io/hashicorp/external/README.md): Documentation of installation and usage

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/terraform-provider/registry.terraform.io/hashicorp/external/terraform-provider-external/main.libsonnet): Inlined code published for usage in other projects
## terraform-provider-google

> Terraform provider google

- [Readme](terraform-provider/registry.terraform.io/hashicorp/google/README.md): Documentation of installation and usage

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/terraform-provider/registry.terraform.io/hashicorp/google/terraform-provider-google/main.libsonnet): Inlined code published for usage in other projects
## terraform-provider-http

> Terraform provider http

- [Readme](terraform-provider/registry.terraform.io/hashicorp/http/README.md): Documentation of installation and usage

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/terraform-provider/registry.terraform.io/hashicorp/http/terraform-provider-http/main.libsonnet): Inlined code published for usage in other projects
## terraform-provider-local

> Terraform provider local

- [Readme](terraform-provider/registry.terraform.io/hashicorp/local/README.md): Documentation of installation and usage

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/terraform-provider/registry.terraform.io/hashicorp/local/terraform-provider-local/main.libsonnet): Inlined code published for usage in other projects
## terraform-provider-null

> Terraform provider null

- [Readme](terraform-provider/registry.terraform.io/hashicorp/null/README.md): Documentation of installation and usage

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/terraform-provider/registry.terraform.io/hashicorp/null/terraform-provider-null/main.libsonnet): Inlined code published for usage in other projects
## terraform-provider-tfmigrate

> Terraform provider tfmigrate

- [Readme](terraform-provider/registry.terraform.io/hashicorp/tfmigrate/README.md): Documentation of installation and usage

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/terraform-provider/registry.terraform.io/hashicorp/tfmigrate/terraform-provider-tfmigrate/main.libsonnet): Inlined code published for usage in other projects
## terraform-provider-time

> Terraform provider time

- [Readme](terraform-provider/registry.terraform.io/hashicorp/time/README.md): Documentation of installation and usage

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/terraform-provider/registry.terraform.io/hashicorp/time/terraform-provider-time/main.libsonnet): Inlined code published for usage in other projects
## terraform-provider-tls

> Terraform provider tls

- [Readme](terraform-provider/registry.terraform.io/hashicorp/tls/README.md): Documentation of installation and usage

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/terraform-provider/registry.terraform.io/hashicorp/tls/terraform-provider-tls/main.libsonnet): Inlined code published for usage in other projects
## terraform-provider-github

> Terraform provider github

- [Readme](terraform-provider/registry.terraform.io/integrations/github/README.md): Documentation of installation and usage

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/terraform-provider/registry.terraform.io/integrations/github/terraform-provider-github/main.libsonnet): Inlined code published for usage in other projects
## terraform-provider-docker

> Terraform provider docker

- [Readme](terraform-provider/registry.terraform.io/kreuzwerker/docker/README.md): Documentation of installation and usage

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/terraform-provider/registry.terraform.io/kreuzwerker/docker/terraform-provider-docker/main.libsonnet): Inlined code published for usage in other projects
## terraform-provider-logzio

> Terraform provider logzio

- [Readme](terraform-provider/registry.terraform.io/logzio/logzio/README.md): Documentation of installation and usage

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/terraform-provider/registry.terraform.io/logzio/logzio/terraform-provider-logzio/main.libsonnet): Inlined code published for usage in other projects
## terraform-provider-dolt

> Terraform provider dolt

- [Readme](terraform-provider/registry.terraform.io/marcbran/dolt/README.md): Documentation of installation and usage

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/terraform-provider/registry.terraform.io/marcbran/dolt/terraform-provider-dolt/main.libsonnet): Inlined code published for usage in other projects
## terraform-provider-jsonnet

> Terraform provider jsonnet

- [Readme](terraform-provider/registry.terraform.io/marcbran/jsonnet/README.md): Documentation of installation and usage

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/terraform-provider/registry.terraform.io/marcbran/jsonnet/terraform-provider-jsonnet/main.libsonnet): Inlined code published for usage in other projects
## terraform-provider-newrelic

> Terraform provider newrelic

- [Readme](terraform-provider/registry.terraform.io/newrelic/newrelic/README.md): Documentation of installation and usage

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/terraform-provider/registry.terraform.io/newrelic/newrelic/terraform-provider-newrelic/main.libsonnet): Inlined code published for usage in other projects
## terraform

> DSL for creating Terraform modules.

- [Readme](terraform/README.md): Documentation of installation and usage

- [Source Code](https://github.com/marcbran/terraform/pkg/terraform): Original source code

- [Inlined Code](https://github.com/marcbran/jsonnet/blob/terraform/terraform/main.libsonnet): Inlined code published for usage in other projects
