local build = {
  expression(val):
    if std.type(val) == 'object' then
      if std.objectHas(val, '_')
      then
        if std.objectHas(val._, 'ref')
        then val._.ref
        else '"%s"' % [val._.str]
      else '{%s}' % [std.join(',', std.map(function(key) '%s:%s' % [self.expression(key), self.expression(val[key])], std.objectFields(val)))]
    else if std.type(val) == 'array' then '[%s]' % [std.join(',', std.map(function(element) self.expression(element), val))]
    else if std.type(val) == 'string' then '"%s"' % [val]
    else '"%s"' % [val],
  template(val):
    if std.type(val) == 'object' then
      if std.objectHas(val, '_')
      then
        if std.objectHas(val._, 'ref')
        then std.strReplace(self.string(val), '\n', '\\n')
        else val._.str
      else std.mapWithKey(function(key, value) self.template(value), val)
    else if std.type(val) == 'array' then std.map(function(element) self.template(element), val)
    else if std.type(val) == 'string' then std.strReplace(self.string(val), '\n', '\\n')
    else val,
  string(val):
    if std.type(val) == 'object' then
      if std.objectHas(val, '_')
      then
        if std.objectHas(val._, 'ref')
        then '${%s}' % [val._.ref]
        else val._.str
      else '${%s}' % [self.expression(val)]
    else if std.type(val) == 'array' then '${%s}' % [self.expression(val)]
    else if std.type(val) == 'string' then val
    else val,
  blocks(val):
    if std.type(val) == 'object'
    then
      if std.objectHas(val, '_')
      then
        if std.objectHas(val._, 'blocks')
        then val._.blocks
        else
          if std.objectHas(val._, 'block')
          then { [val._.ref]: val._.block }
          else {}
      else std.foldl(function(acc, val) std.mergePatch(acc, val), std.map(function(key) build.blocks(val[key]), std.objectFields(val)), {})
    else if std.type(val) == 'array'
    then std.foldl(function(acc, val) std.mergePatch(acc, val), std.map(function(element) build.blocks(element), val), {})
    else {},
};

local providerTemplate(provider, requirements, rawConfiguration, configuration) = {
  local providerRequirements = {
    ['terraform.required_providers.%s' % [provider]]: requirements,
  },
  local providerAlias = if configuration == null then null else std.get(configuration, 'alias', null),
  local providerConfiguration =
    if configuration == null then { _: { refBlock: {}, blocks: [] } } else {
      _: {
        local _ = self,
        ref: '%s.%s' % [provider, configuration.alias],
        refBlock: {
          provider: _.ref,
        },
        block: {
          provider: {
            [provider]: std.prune(configuration),
          },
        },
        blocks: build.blocks(rawConfiguration) + {
          [_.ref]: _.block,
        },
      },
    },
  blockType(blockType): {
    local blockTypePath = if blockType == 'resource' then [] else ['data'],
    resource(type, name): {
      local resourceType = std.substr(type, std.length(provider) + 1, std.length(type)),
      local resourcePath = blockTypePath + [type, name],
      _(rawBlock, block): {
        local _ = self,
        local metaBlock = {
          depends_on: build.template(std.get(rawBlock, 'depends_on', null)),
          count: build.template(std.get(rawBlock, 'count', null)),
          for_each: build.template(std.get(rawBlock, 'for_each', null)),
        },
        type: if std.objectHas(rawBlock, 'for_each') then 'map' else if std.objectHas(rawBlock, 'count') then 'list' else 'object',
        provider: provider,
        providerAlias: providerAlias,
        resourceType: resourceType,
        name: name,
        ref: std.join('.', resourcePath),
        block: {
          [blockType]: {
            [type]: {
              [name]: std.prune(providerConfiguration._.refBlock + metaBlock + block),
            },
          },
        },
        blocks: build.blocks([providerConfiguration] + [rawBlock]) + providerRequirements + {
          [_.ref]: _.block,
        },
      },
      field(blocks, fieldName): {
        local fieldPath = resourcePath + [fieldName],
        _: {
          ref: std.join('.', fieldPath),
          blocks: blocks,
        },
      },
    },
  },
  func(name, parameters=[]): {
    local parameterString = std.join(', ', [build.expression(parameter) for parameter in parameters]),
    _: {
      ref: 'provider::%s::%s(%s)' % [provider, name, parameterString],
      blocks: build.blocks([providerConfiguration] + [parameters]) + providerRequirements,
    },
  },
};

local provider(rawConfiguration, configuration) = {
  local requirements = {
    source: 'registry.terraform.io/hashicorp/kubernetes',
    version: '2.36.0',
  },
  local provider = providerTemplate('kubernetes', requirements, rawConfiguration, configuration),
  resource: {
    local blockType = provider.blockType('resource'),
    annotations(name, block): {
      local resource = blockType.resource('kubernetes_annotations', name),
      _: resource._(block, {
        annotations: build.template(std.get(block, 'annotations', null)),
        api_version: build.template(block.api_version),
        field_manager: build.template(std.get(block, 'field_manager', null)),
        force: build.template(std.get(block, 'force', null)),
        id: build.template(std.get(block, 'id', null)),
        kind: build.template(block.kind),
        template_annotations: build.template(std.get(block, 'template_annotations', null)),
      }),
      annotations: resource.field(self._.blocks, 'annotations'),
      api_version: resource.field(self._.blocks, 'api_version'),
      field_manager: resource.field(self._.blocks, 'field_manager'),
      force: resource.field(self._.blocks, 'force'),
      id: resource.field(self._.blocks, 'id'),
      kind: resource.field(self._.blocks, 'kind'),
      template_annotations: resource.field(self._.blocks, 'template_annotations'),
    },
    api_service(name, block): {
      local resource = blockType.resource('kubernetes_api_service', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    api_service_v1(name, block): {
      local resource = blockType.resource('kubernetes_api_service_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    certificate_signing_request(name, block): {
      local resource = blockType.resource('kubernetes_certificate_signing_request', name),
      _: resource._(block, {
        auto_approve: build.template(std.get(block, 'auto_approve', null)),
        certificate: build.template(std.get(block, 'certificate', null)),
        id: build.template(std.get(block, 'id', null)),
      }),
      auto_approve: resource.field(self._.blocks, 'auto_approve'),
      certificate: resource.field(self._.blocks, 'certificate'),
      id: resource.field(self._.blocks, 'id'),
    },
    certificate_signing_request_v1(name, block): {
      local resource = blockType.resource('kubernetes_certificate_signing_request_v1', name),
      _: resource._(block, {
        auto_approve: build.template(std.get(block, 'auto_approve', null)),
        certificate: build.template(std.get(block, 'certificate', null)),
        id: build.template(std.get(block, 'id', null)),
      }),
      auto_approve: resource.field(self._.blocks, 'auto_approve'),
      certificate: resource.field(self._.blocks, 'certificate'),
      id: resource.field(self._.blocks, 'id'),
    },
    cluster_role(name, block): {
      local resource = blockType.resource('kubernetes_cluster_role', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    cluster_role_binding(name, block): {
      local resource = blockType.resource('kubernetes_cluster_role_binding', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    cluster_role_binding_v1(name, block): {
      local resource = blockType.resource('kubernetes_cluster_role_binding_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    cluster_role_v1(name, block): {
      local resource = blockType.resource('kubernetes_cluster_role_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    config_map(name, block): {
      local resource = blockType.resource('kubernetes_config_map', name),
      _: resource._(block, {
        binary_data: build.template(std.get(block, 'binary_data', null)),
        data: build.template(std.get(block, 'data', null)),
        id: build.template(std.get(block, 'id', null)),
        immutable: build.template(std.get(block, 'immutable', null)),
      }),
      binary_data: resource.field(self._.blocks, 'binary_data'),
      data: resource.field(self._.blocks, 'data'),
      id: resource.field(self._.blocks, 'id'),
      immutable: resource.field(self._.blocks, 'immutable'),
    },
    config_map_v1(name, block): {
      local resource = blockType.resource('kubernetes_config_map_v1', name),
      _: resource._(block, {
        binary_data: build.template(std.get(block, 'binary_data', null)),
        data: build.template(std.get(block, 'data', null)),
        id: build.template(std.get(block, 'id', null)),
        immutable: build.template(std.get(block, 'immutable', null)),
      }),
      binary_data: resource.field(self._.blocks, 'binary_data'),
      data: resource.field(self._.blocks, 'data'),
      id: resource.field(self._.blocks, 'id'),
      immutable: resource.field(self._.blocks, 'immutable'),
    },
    config_map_v1_data(name, block): {
      local resource = blockType.resource('kubernetes_config_map_v1_data', name),
      _: resource._(block, {
        data: build.template(block.data),
        field_manager: build.template(std.get(block, 'field_manager', null)),
        force: build.template(std.get(block, 'force', null)),
        id: build.template(std.get(block, 'id', null)),
      }),
      data: resource.field(self._.blocks, 'data'),
      field_manager: resource.field(self._.blocks, 'field_manager'),
      force: resource.field(self._.blocks, 'force'),
      id: resource.field(self._.blocks, 'id'),
    },
    cron_job(name, block): {
      local resource = blockType.resource('kubernetes_cron_job', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    cron_job_v1(name, block): {
      local resource = blockType.resource('kubernetes_cron_job_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    csi_driver(name, block): {
      local resource = blockType.resource('kubernetes_csi_driver', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    csi_driver_v1(name, block): {
      local resource = blockType.resource('kubernetes_csi_driver_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    daemon_set_v1(name, block): {
      local resource = blockType.resource('kubernetes_daemon_set_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        wait_for_rollout: build.template(std.get(block, 'wait_for_rollout', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      wait_for_rollout: resource.field(self._.blocks, 'wait_for_rollout'),
    },
    daemonset(name, block): {
      local resource = blockType.resource('kubernetes_daemonset', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        wait_for_rollout: build.template(std.get(block, 'wait_for_rollout', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      wait_for_rollout: resource.field(self._.blocks, 'wait_for_rollout'),
    },
    default_service_account(name, block): {
      local resource = blockType.resource('kubernetes_default_service_account', name),
      _: resource._(block, {
        automount_service_account_token: build.template(std.get(block, 'automount_service_account_token', null)),
        default_secret_name: build.template(std.get(block, 'default_secret_name', null)),
        id: build.template(std.get(block, 'id', null)),
      }),
      automount_service_account_token: resource.field(self._.blocks, 'automount_service_account_token'),
      default_secret_name: resource.field(self._.blocks, 'default_secret_name'),
      id: resource.field(self._.blocks, 'id'),
    },
    default_service_account_v1(name, block): {
      local resource = blockType.resource('kubernetes_default_service_account_v1', name),
      _: resource._(block, {
        automount_service_account_token: build.template(std.get(block, 'automount_service_account_token', null)),
        default_secret_name: build.template(std.get(block, 'default_secret_name', null)),
        id: build.template(std.get(block, 'id', null)),
      }),
      automount_service_account_token: resource.field(self._.blocks, 'automount_service_account_token'),
      default_secret_name: resource.field(self._.blocks, 'default_secret_name'),
      id: resource.field(self._.blocks, 'id'),
    },
    deployment(name, block): {
      local resource = blockType.resource('kubernetes_deployment', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        wait_for_rollout: build.template(std.get(block, 'wait_for_rollout', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      wait_for_rollout: resource.field(self._.blocks, 'wait_for_rollout'),
    },
    deployment_v1(name, block): {
      local resource = blockType.resource('kubernetes_deployment_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        wait_for_rollout: build.template(std.get(block, 'wait_for_rollout', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      wait_for_rollout: resource.field(self._.blocks, 'wait_for_rollout'),
    },
    endpoint_slice_v1(name, block): {
      local resource = blockType.resource('kubernetes_endpoint_slice_v1', name),
      _: resource._(block, {
        address_type: build.template(block.address_type),
        id: build.template(std.get(block, 'id', null)),
      }),
      address_type: resource.field(self._.blocks, 'address_type'),
      id: resource.field(self._.blocks, 'id'),
    },
    endpoints(name, block): {
      local resource = blockType.resource('kubernetes_endpoints', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    endpoints_v1(name, block): {
      local resource = blockType.resource('kubernetes_endpoints_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    env(name, block): {
      local resource = blockType.resource('kubernetes_env', name),
      _: resource._(block, {
        api_version: build.template(block.api_version),
        container: build.template(std.get(block, 'container', null)),
        field_manager: build.template(std.get(block, 'field_manager', null)),
        force: build.template(std.get(block, 'force', null)),
        id: build.template(std.get(block, 'id', null)),
        init_container: build.template(std.get(block, 'init_container', null)),
        kind: build.template(block.kind),
      }),
      api_version: resource.field(self._.blocks, 'api_version'),
      container: resource.field(self._.blocks, 'container'),
      field_manager: resource.field(self._.blocks, 'field_manager'),
      force: resource.field(self._.blocks, 'force'),
      id: resource.field(self._.blocks, 'id'),
      init_container: resource.field(self._.blocks, 'init_container'),
      kind: resource.field(self._.blocks, 'kind'),
    },
    horizontal_pod_autoscaler(name, block): {
      local resource = blockType.resource('kubernetes_horizontal_pod_autoscaler', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    horizontal_pod_autoscaler_v1(name, block): {
      local resource = blockType.resource('kubernetes_horizontal_pod_autoscaler_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    horizontal_pod_autoscaler_v2(name, block): {
      local resource = blockType.resource('kubernetes_horizontal_pod_autoscaler_v2', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    horizontal_pod_autoscaler_v2beta2(name, block): {
      local resource = blockType.resource('kubernetes_horizontal_pod_autoscaler_v2beta2', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    ingress(name, block): {
      local resource = blockType.resource('kubernetes_ingress', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        status: build.template(std.get(block, 'status', null)),
        wait_for_load_balancer: build.template(std.get(block, 'wait_for_load_balancer', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      status: resource.field(self._.blocks, 'status'),
      wait_for_load_balancer: resource.field(self._.blocks, 'wait_for_load_balancer'),
    },
    ingress_class(name, block): {
      local resource = blockType.resource('kubernetes_ingress_class', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    ingress_class_v1(name, block): {
      local resource = blockType.resource('kubernetes_ingress_class_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    ingress_v1(name, block): {
      local resource = blockType.resource('kubernetes_ingress_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        status: build.template(std.get(block, 'status', null)),
        wait_for_load_balancer: build.template(std.get(block, 'wait_for_load_balancer', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      status: resource.field(self._.blocks, 'status'),
      wait_for_load_balancer: resource.field(self._.blocks, 'wait_for_load_balancer'),
    },
    job(name, block): {
      local resource = blockType.resource('kubernetes_job', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        wait_for_completion: build.template(std.get(block, 'wait_for_completion', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      wait_for_completion: resource.field(self._.blocks, 'wait_for_completion'),
    },
    job_v1(name, block): {
      local resource = blockType.resource('kubernetes_job_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        wait_for_completion: build.template(std.get(block, 'wait_for_completion', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      wait_for_completion: resource.field(self._.blocks, 'wait_for_completion'),
    },
    labels(name, block): {
      local resource = blockType.resource('kubernetes_labels', name),
      _: resource._(block, {
        api_version: build.template(block.api_version),
        field_manager: build.template(std.get(block, 'field_manager', null)),
        force: build.template(std.get(block, 'force', null)),
        id: build.template(std.get(block, 'id', null)),
        kind: build.template(block.kind),
        labels: build.template(block.labels),
      }),
      api_version: resource.field(self._.blocks, 'api_version'),
      field_manager: resource.field(self._.blocks, 'field_manager'),
      force: resource.field(self._.blocks, 'force'),
      id: resource.field(self._.blocks, 'id'),
      kind: resource.field(self._.blocks, 'kind'),
      labels: resource.field(self._.blocks, 'labels'),
    },
    limit_range(name, block): {
      local resource = blockType.resource('kubernetes_limit_range', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    limit_range_v1(name, block): {
      local resource = blockType.resource('kubernetes_limit_range_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    manifest(name, block): {
      local resource = blockType.resource('kubernetes_manifest', name),
      _: resource._(block, {
        computed_fields: build.template(std.get(block, 'computed_fields', null)),
        manifest: build.template(block.manifest),
        object: build.template(std.get(block, 'object', null)),
        wait_for: build.template(std.get(block, 'wait_for', null)),
      }),
      computed_fields: resource.field(self._.blocks, 'computed_fields'),
      manifest: resource.field(self._.blocks, 'manifest'),
      object: resource.field(self._.blocks, 'object'),
      wait_for: resource.field(self._.blocks, 'wait_for'),
    },
    mutating_webhook_configuration(name, block): {
      local resource = blockType.resource('kubernetes_mutating_webhook_configuration', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    mutating_webhook_configuration_v1(name, block): {
      local resource = blockType.resource('kubernetes_mutating_webhook_configuration_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    namespace(name, block): {
      local resource = blockType.resource('kubernetes_namespace', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        wait_for_default_service_account: build.template(std.get(block, 'wait_for_default_service_account', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      wait_for_default_service_account: resource.field(self._.blocks, 'wait_for_default_service_account'),
    },
    namespace_v1(name, block): {
      local resource = blockType.resource('kubernetes_namespace_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        wait_for_default_service_account: build.template(std.get(block, 'wait_for_default_service_account', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      wait_for_default_service_account: resource.field(self._.blocks, 'wait_for_default_service_account'),
    },
    network_policy(name, block): {
      local resource = blockType.resource('kubernetes_network_policy', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    network_policy_v1(name, block): {
      local resource = blockType.resource('kubernetes_network_policy_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    node_taint(name, block): {
      local resource = blockType.resource('kubernetes_node_taint', name),
      _: resource._(block, {
        field_manager: build.template(std.get(block, 'field_manager', null)),
        force: build.template(std.get(block, 'force', null)),
        id: build.template(std.get(block, 'id', null)),
      }),
      field_manager: resource.field(self._.blocks, 'field_manager'),
      force: resource.field(self._.blocks, 'force'),
      id: resource.field(self._.blocks, 'id'),
    },
    persistent_volume(name, block): {
      local resource = blockType.resource('kubernetes_persistent_volume', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    persistent_volume_claim(name, block): {
      local resource = blockType.resource('kubernetes_persistent_volume_claim', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        wait_until_bound: build.template(std.get(block, 'wait_until_bound', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      wait_until_bound: resource.field(self._.blocks, 'wait_until_bound'),
    },
    persistent_volume_claim_v1(name, block): {
      local resource = blockType.resource('kubernetes_persistent_volume_claim_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        wait_until_bound: build.template(std.get(block, 'wait_until_bound', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      wait_until_bound: resource.field(self._.blocks, 'wait_until_bound'),
    },
    persistent_volume_v1(name, block): {
      local resource = blockType.resource('kubernetes_persistent_volume_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    pod(name, block): {
      local resource = blockType.resource('kubernetes_pod', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        target_state: build.template(std.get(block, 'target_state', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      target_state: resource.field(self._.blocks, 'target_state'),
    },
    pod_disruption_budget(name, block): {
      local resource = blockType.resource('kubernetes_pod_disruption_budget', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    pod_disruption_budget_v1(name, block): {
      local resource = blockType.resource('kubernetes_pod_disruption_budget_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    pod_security_policy(name, block): {
      local resource = blockType.resource('kubernetes_pod_security_policy', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    pod_security_policy_v1beta1(name, block): {
      local resource = blockType.resource('kubernetes_pod_security_policy_v1beta1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    pod_v1(name, block): {
      local resource = blockType.resource('kubernetes_pod_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        target_state: build.template(std.get(block, 'target_state', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      target_state: resource.field(self._.blocks, 'target_state'),
    },
    priority_class(name, block): {
      local resource = blockType.resource('kubernetes_priority_class', name),
      _: resource._(block, {
        description: build.template(std.get(block, 'description', null)),
        global_default: build.template(std.get(block, 'global_default', null)),
        id: build.template(std.get(block, 'id', null)),
        preemption_policy: build.template(std.get(block, 'preemption_policy', null)),
        value: build.template(block.value),
      }),
      description: resource.field(self._.blocks, 'description'),
      global_default: resource.field(self._.blocks, 'global_default'),
      id: resource.field(self._.blocks, 'id'),
      preemption_policy: resource.field(self._.blocks, 'preemption_policy'),
      value: resource.field(self._.blocks, 'value'),
    },
    priority_class_v1(name, block): {
      local resource = blockType.resource('kubernetes_priority_class_v1', name),
      _: resource._(block, {
        description: build.template(std.get(block, 'description', null)),
        global_default: build.template(std.get(block, 'global_default', null)),
        id: build.template(std.get(block, 'id', null)),
        preemption_policy: build.template(std.get(block, 'preemption_policy', null)),
        value: build.template(block.value),
      }),
      description: resource.field(self._.blocks, 'description'),
      global_default: resource.field(self._.blocks, 'global_default'),
      id: resource.field(self._.blocks, 'id'),
      preemption_policy: resource.field(self._.blocks, 'preemption_policy'),
      value: resource.field(self._.blocks, 'value'),
    },
    replication_controller(name, block): {
      local resource = blockType.resource('kubernetes_replication_controller', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    replication_controller_v1(name, block): {
      local resource = blockType.resource('kubernetes_replication_controller_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    resource_quota(name, block): {
      local resource = blockType.resource('kubernetes_resource_quota', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    resource_quota_v1(name, block): {
      local resource = blockType.resource('kubernetes_resource_quota_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    role(name, block): {
      local resource = blockType.resource('kubernetes_role', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    role_binding(name, block): {
      local resource = blockType.resource('kubernetes_role_binding', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    role_binding_v1(name, block): {
      local resource = blockType.resource('kubernetes_role_binding_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    role_v1(name, block): {
      local resource = blockType.resource('kubernetes_role_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    runtime_class_v1(name, block): {
      local resource = blockType.resource('kubernetes_runtime_class_v1', name),
      _: resource._(block, {
        handler: build.template(block.handler),
        id: build.template(std.get(block, 'id', null)),
      }),
      handler: resource.field(self._.blocks, 'handler'),
      id: resource.field(self._.blocks, 'id'),
    },
    secret(name, block): {
      local resource = blockType.resource('kubernetes_secret', name),
      _: resource._(block, {
        binary_data: build.template(std.get(block, 'binary_data', null)),
        data: build.template(std.get(block, 'data', null)),
        id: build.template(std.get(block, 'id', null)),
        immutable: build.template(std.get(block, 'immutable', null)),
        type: build.template(std.get(block, 'type', null)),
        wait_for_service_account_token: build.template(std.get(block, 'wait_for_service_account_token', null)),
      }),
      binary_data: resource.field(self._.blocks, 'binary_data'),
      data: resource.field(self._.blocks, 'data'),
      id: resource.field(self._.blocks, 'id'),
      immutable: resource.field(self._.blocks, 'immutable'),
      type: resource.field(self._.blocks, 'type'),
      wait_for_service_account_token: resource.field(self._.blocks, 'wait_for_service_account_token'),
    },
    secret_v1(name, block): {
      local resource = blockType.resource('kubernetes_secret_v1', name),
      _: resource._(block, {
        binary_data: build.template(std.get(block, 'binary_data', null)),
        data: build.template(std.get(block, 'data', null)),
        id: build.template(std.get(block, 'id', null)),
        immutable: build.template(std.get(block, 'immutable', null)),
        type: build.template(std.get(block, 'type', null)),
        wait_for_service_account_token: build.template(std.get(block, 'wait_for_service_account_token', null)),
      }),
      binary_data: resource.field(self._.blocks, 'binary_data'),
      data: resource.field(self._.blocks, 'data'),
      id: resource.field(self._.blocks, 'id'),
      immutable: resource.field(self._.blocks, 'immutable'),
      type: resource.field(self._.blocks, 'type'),
      wait_for_service_account_token: resource.field(self._.blocks, 'wait_for_service_account_token'),
    },
    service(name, block): {
      local resource = blockType.resource('kubernetes_service', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        status: build.template(std.get(block, 'status', null)),
        wait_for_load_balancer: build.template(std.get(block, 'wait_for_load_balancer', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      status: resource.field(self._.blocks, 'status'),
      wait_for_load_balancer: resource.field(self._.blocks, 'wait_for_load_balancer'),
    },
    service_account(name, block): {
      local resource = blockType.resource('kubernetes_service_account', name),
      _: resource._(block, {
        automount_service_account_token: build.template(std.get(block, 'automount_service_account_token', null)),
        default_secret_name: build.template(std.get(block, 'default_secret_name', null)),
        id: build.template(std.get(block, 'id', null)),
      }),
      automount_service_account_token: resource.field(self._.blocks, 'automount_service_account_token'),
      default_secret_name: resource.field(self._.blocks, 'default_secret_name'),
      id: resource.field(self._.blocks, 'id'),
    },
    service_account_v1(name, block): {
      local resource = blockType.resource('kubernetes_service_account_v1', name),
      _: resource._(block, {
        automount_service_account_token: build.template(std.get(block, 'automount_service_account_token', null)),
        default_secret_name: build.template(std.get(block, 'default_secret_name', null)),
        id: build.template(std.get(block, 'id', null)),
      }),
      automount_service_account_token: resource.field(self._.blocks, 'automount_service_account_token'),
      default_secret_name: resource.field(self._.blocks, 'default_secret_name'),
      id: resource.field(self._.blocks, 'id'),
    },
    service_v1(name, block): {
      local resource = blockType.resource('kubernetes_service_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        status: build.template(std.get(block, 'status', null)),
        wait_for_load_balancer: build.template(std.get(block, 'wait_for_load_balancer', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      status: resource.field(self._.blocks, 'status'),
      wait_for_load_balancer: resource.field(self._.blocks, 'wait_for_load_balancer'),
    },
    stateful_set(name, block): {
      local resource = blockType.resource('kubernetes_stateful_set', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        wait_for_rollout: build.template(std.get(block, 'wait_for_rollout', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      wait_for_rollout: resource.field(self._.blocks, 'wait_for_rollout'),
    },
    stateful_set_v1(name, block): {
      local resource = blockType.resource('kubernetes_stateful_set_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        wait_for_rollout: build.template(std.get(block, 'wait_for_rollout', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      wait_for_rollout: resource.field(self._.blocks, 'wait_for_rollout'),
    },
    storage_class(name, block): {
      local resource = blockType.resource('kubernetes_storage_class', name),
      _: resource._(block, {
        allow_volume_expansion: build.template(std.get(block, 'allow_volume_expansion', null)),
        id: build.template(std.get(block, 'id', null)),
        mount_options: build.template(std.get(block, 'mount_options', null)),
        parameters: build.template(std.get(block, 'parameters', null)),
        reclaim_policy: build.template(std.get(block, 'reclaim_policy', null)),
        storage_provisioner: build.template(block.storage_provisioner),
        volume_binding_mode: build.template(std.get(block, 'volume_binding_mode', null)),
      }),
      allow_volume_expansion: resource.field(self._.blocks, 'allow_volume_expansion'),
      id: resource.field(self._.blocks, 'id'),
      mount_options: resource.field(self._.blocks, 'mount_options'),
      parameters: resource.field(self._.blocks, 'parameters'),
      reclaim_policy: resource.field(self._.blocks, 'reclaim_policy'),
      storage_provisioner: resource.field(self._.blocks, 'storage_provisioner'),
      volume_binding_mode: resource.field(self._.blocks, 'volume_binding_mode'),
    },
    storage_class_v1(name, block): {
      local resource = blockType.resource('kubernetes_storage_class_v1', name),
      _: resource._(block, {
        allow_volume_expansion: build.template(std.get(block, 'allow_volume_expansion', null)),
        id: build.template(std.get(block, 'id', null)),
        mount_options: build.template(std.get(block, 'mount_options', null)),
        parameters: build.template(std.get(block, 'parameters', null)),
        reclaim_policy: build.template(std.get(block, 'reclaim_policy', null)),
        storage_provisioner: build.template(block.storage_provisioner),
        volume_binding_mode: build.template(std.get(block, 'volume_binding_mode', null)),
      }),
      allow_volume_expansion: resource.field(self._.blocks, 'allow_volume_expansion'),
      id: resource.field(self._.blocks, 'id'),
      mount_options: resource.field(self._.blocks, 'mount_options'),
      parameters: resource.field(self._.blocks, 'parameters'),
      reclaim_policy: resource.field(self._.blocks, 'reclaim_policy'),
      storage_provisioner: resource.field(self._.blocks, 'storage_provisioner'),
      volume_binding_mode: resource.field(self._.blocks, 'volume_binding_mode'),
    },
    token_request_v1(name, block): {
      local resource = blockType.resource('kubernetes_token_request_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        token: build.template(std.get(block, 'token', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      token: resource.field(self._.blocks, 'token'),
    },
    validating_webhook_configuration(name, block): {
      local resource = blockType.resource('kubernetes_validating_webhook_configuration', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    validating_webhook_configuration_v1(name, block): {
      local resource = blockType.resource('kubernetes_validating_webhook_configuration_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
  },
  data: {
    local blockType = provider.blockType('data'),
    all_namespaces(name, block): {
      local resource = blockType.resource('kubernetes_all_namespaces', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        namespaces: build.template(std.get(block, 'namespaces', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      namespaces: resource.field(self._.blocks, 'namespaces'),
    },
    config_map(name, block): {
      local resource = blockType.resource('kubernetes_config_map', name),
      _: resource._(block, {
        binary_data: build.template(std.get(block, 'binary_data', null)),
        data: build.template(std.get(block, 'data', null)),
        id: build.template(std.get(block, 'id', null)),
        immutable: build.template(std.get(block, 'immutable', null)),
      }),
      binary_data: resource.field(self._.blocks, 'binary_data'),
      data: resource.field(self._.blocks, 'data'),
      id: resource.field(self._.blocks, 'id'),
      immutable: resource.field(self._.blocks, 'immutable'),
    },
    config_map_v1(name, block): {
      local resource = blockType.resource('kubernetes_config_map_v1', name),
      _: resource._(block, {
        binary_data: build.template(std.get(block, 'binary_data', null)),
        data: build.template(std.get(block, 'data', null)),
        id: build.template(std.get(block, 'id', null)),
        immutable: build.template(std.get(block, 'immutable', null)),
      }),
      binary_data: resource.field(self._.blocks, 'binary_data'),
      data: resource.field(self._.blocks, 'data'),
      id: resource.field(self._.blocks, 'id'),
      immutable: resource.field(self._.blocks, 'immutable'),
    },
    endpoints_v1(name, block): {
      local resource = blockType.resource('kubernetes_endpoints_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    ingress(name, block): {
      local resource = blockType.resource('kubernetes_ingress', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        spec: build.template(std.get(block, 'spec', null)),
        status: build.template(std.get(block, 'status', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      spec: resource.field(self._.blocks, 'spec'),
      status: resource.field(self._.blocks, 'status'),
    },
    ingress_v1(name, block): {
      local resource = blockType.resource('kubernetes_ingress_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        spec: build.template(std.get(block, 'spec', null)),
        status: build.template(std.get(block, 'status', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      spec: resource.field(self._.blocks, 'spec'),
      status: resource.field(self._.blocks, 'status'),
    },
    mutating_webhook_configuration_v1(name, block): {
      local resource = blockType.resource('kubernetes_mutating_webhook_configuration_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        webhook: build.template(std.get(block, 'webhook', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      webhook: resource.field(self._.blocks, 'webhook'),
    },
    namespace(name, block): {
      local resource = blockType.resource('kubernetes_namespace', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        spec: build.template(std.get(block, 'spec', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      spec: resource.field(self._.blocks, 'spec'),
    },
    namespace_v1(name, block): {
      local resource = blockType.resource('kubernetes_namespace_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        spec: build.template(std.get(block, 'spec', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      spec: resource.field(self._.blocks, 'spec'),
    },
    nodes(name, block): {
      local resource = blockType.resource('kubernetes_nodes', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        nodes: build.template(std.get(block, 'nodes', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      nodes: resource.field(self._.blocks, 'nodes'),
    },
    persistent_volume_claim(name, block): {
      local resource = blockType.resource('kubernetes_persistent_volume_claim', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    persistent_volume_claim_v1(name, block): {
      local resource = blockType.resource('kubernetes_persistent_volume_claim_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    persistent_volume_v1(name, block): {
      local resource = blockType.resource('kubernetes_persistent_volume_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
    },
    pod(name, block): {
      local resource = blockType.resource('kubernetes_pod', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        spec: build.template(std.get(block, 'spec', null)),
        status: build.template(std.get(block, 'status', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      spec: resource.field(self._.blocks, 'spec'),
      status: resource.field(self._.blocks, 'status'),
    },
    pod_v1(name, block): {
      local resource = blockType.resource('kubernetes_pod_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        spec: build.template(std.get(block, 'spec', null)),
        status: build.template(std.get(block, 'status', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      spec: resource.field(self._.blocks, 'spec'),
      status: resource.field(self._.blocks, 'status'),
    },
    resource(name, block): {
      local resource = blockType.resource('kubernetes_resource', name),
      _: resource._(block, {
        api_version: build.template(block.api_version),
        kind: build.template(block.kind),
        object: build.template(std.get(block, 'object', null)),
      }),
      api_version: resource.field(self._.blocks, 'api_version'),
      kind: resource.field(self._.blocks, 'kind'),
      object: resource.field(self._.blocks, 'object'),
    },
    resources(name, block): {
      local resource = blockType.resource('kubernetes_resources', name),
      _: resource._(block, {
        api_version: build.template(block.api_version),
        field_selector: build.template(std.get(block, 'field_selector', null)),
        kind: build.template(block.kind),
        label_selector: build.template(std.get(block, 'label_selector', null)),
        limit: build.template(std.get(block, 'limit', null)),
        namespace: build.template(std.get(block, 'namespace', null)),
        objects: build.template(std.get(block, 'objects', null)),
      }),
      api_version: resource.field(self._.blocks, 'api_version'),
      field_selector: resource.field(self._.blocks, 'field_selector'),
      kind: resource.field(self._.blocks, 'kind'),
      label_selector: resource.field(self._.blocks, 'label_selector'),
      limit: resource.field(self._.blocks, 'limit'),
      namespace: resource.field(self._.blocks, 'namespace'),
      objects: resource.field(self._.blocks, 'objects'),
    },
    secret(name, block): {
      local resource = blockType.resource('kubernetes_secret', name),
      _: resource._(block, {
        binary_data: build.template(std.get(block, 'binary_data', null)),
        data: build.template(std.get(block, 'data', null)),
        id: build.template(std.get(block, 'id', null)),
        immutable: build.template(std.get(block, 'immutable', null)),
        type: build.template(std.get(block, 'type', null)),
      }),
      binary_data: resource.field(self._.blocks, 'binary_data'),
      data: resource.field(self._.blocks, 'data'),
      id: resource.field(self._.blocks, 'id'),
      immutable: resource.field(self._.blocks, 'immutable'),
      type: resource.field(self._.blocks, 'type'),
    },
    secret_v1(name, block): {
      local resource = blockType.resource('kubernetes_secret_v1', name),
      _: resource._(block, {
        binary_data: build.template(std.get(block, 'binary_data', null)),
        data: build.template(std.get(block, 'data', null)),
        id: build.template(std.get(block, 'id', null)),
        immutable: build.template(std.get(block, 'immutable', null)),
        type: build.template(std.get(block, 'type', null)),
      }),
      binary_data: resource.field(self._.blocks, 'binary_data'),
      data: resource.field(self._.blocks, 'data'),
      id: resource.field(self._.blocks, 'id'),
      immutable: resource.field(self._.blocks, 'immutable'),
      type: resource.field(self._.blocks, 'type'),
    },
    server_version(name, block): {
      local resource = blockType.resource('kubernetes_server_version', name),
      _: resource._(block, {
        build_date: build.template(std.get(block, 'build_date', null)),
        compiler: build.template(std.get(block, 'compiler', null)),
        git_commit: build.template(std.get(block, 'git_commit', null)),
        git_tree_state: build.template(std.get(block, 'git_tree_state', null)),
        git_version: build.template(std.get(block, 'git_version', null)),
        go_version: build.template(std.get(block, 'go_version', null)),
        id: build.template(std.get(block, 'id', null)),
        major: build.template(std.get(block, 'major', null)),
        minor: build.template(std.get(block, 'minor', null)),
        platform: build.template(std.get(block, 'platform', null)),
        version: build.template(std.get(block, 'version', null)),
      }),
      build_date: resource.field(self._.blocks, 'build_date'),
      compiler: resource.field(self._.blocks, 'compiler'),
      git_commit: resource.field(self._.blocks, 'git_commit'),
      git_tree_state: resource.field(self._.blocks, 'git_tree_state'),
      git_version: resource.field(self._.blocks, 'git_version'),
      go_version: resource.field(self._.blocks, 'go_version'),
      id: resource.field(self._.blocks, 'id'),
      major: resource.field(self._.blocks, 'major'),
      minor: resource.field(self._.blocks, 'minor'),
      platform: resource.field(self._.blocks, 'platform'),
      version: resource.field(self._.blocks, 'version'),
    },
    service(name, block): {
      local resource = blockType.resource('kubernetes_service', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        spec: build.template(std.get(block, 'spec', null)),
        status: build.template(std.get(block, 'status', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      spec: resource.field(self._.blocks, 'spec'),
      status: resource.field(self._.blocks, 'status'),
    },
    service_account(name, block): {
      local resource = blockType.resource('kubernetes_service_account', name),
      _: resource._(block, {
        automount_service_account_token: build.template(std.get(block, 'automount_service_account_token', null)),
        default_secret_name: build.template(std.get(block, 'default_secret_name', null)),
        id: build.template(std.get(block, 'id', null)),
        image_pull_secret: build.template(std.get(block, 'image_pull_secret', null)),
        secret: build.template(std.get(block, 'secret', null)),
      }),
      automount_service_account_token: resource.field(self._.blocks, 'automount_service_account_token'),
      default_secret_name: resource.field(self._.blocks, 'default_secret_name'),
      id: resource.field(self._.blocks, 'id'),
      image_pull_secret: resource.field(self._.blocks, 'image_pull_secret'),
      secret: resource.field(self._.blocks, 'secret'),
    },
    service_account_v1(name, block): {
      local resource = blockType.resource('kubernetes_service_account_v1', name),
      _: resource._(block, {
        automount_service_account_token: build.template(std.get(block, 'automount_service_account_token', null)),
        default_secret_name: build.template(std.get(block, 'default_secret_name', null)),
        id: build.template(std.get(block, 'id', null)),
        image_pull_secret: build.template(std.get(block, 'image_pull_secret', null)),
        secret: build.template(std.get(block, 'secret', null)),
      }),
      automount_service_account_token: resource.field(self._.blocks, 'automount_service_account_token'),
      default_secret_name: resource.field(self._.blocks, 'default_secret_name'),
      id: resource.field(self._.blocks, 'id'),
      image_pull_secret: resource.field(self._.blocks, 'image_pull_secret'),
      secret: resource.field(self._.blocks, 'secret'),
    },
    service_v1(name, block): {
      local resource = blockType.resource('kubernetes_service_v1', name),
      _: resource._(block, {
        id: build.template(std.get(block, 'id', null)),
        spec: build.template(std.get(block, 'spec', null)),
        status: build.template(std.get(block, 'status', null)),
      }),
      id: resource.field(self._.blocks, 'id'),
      spec: resource.field(self._.blocks, 'spec'),
      status: resource.field(self._.blocks, 'status'),
    },
    storage_class(name, block): {
      local resource = blockType.resource('kubernetes_storage_class', name),
      _: resource._(block, {
        allow_volume_expansion: build.template(std.get(block, 'allow_volume_expansion', null)),
        id: build.template(std.get(block, 'id', null)),
        mount_options: build.template(std.get(block, 'mount_options', null)),
        parameters: build.template(std.get(block, 'parameters', null)),
        reclaim_policy: build.template(std.get(block, 'reclaim_policy', null)),
        storage_provisioner: build.template(std.get(block, 'storage_provisioner', null)),
        volume_binding_mode: build.template(std.get(block, 'volume_binding_mode', null)),
      }),
      allow_volume_expansion: resource.field(self._.blocks, 'allow_volume_expansion'),
      id: resource.field(self._.blocks, 'id'),
      mount_options: resource.field(self._.blocks, 'mount_options'),
      parameters: resource.field(self._.blocks, 'parameters'),
      reclaim_policy: resource.field(self._.blocks, 'reclaim_policy'),
      storage_provisioner: resource.field(self._.blocks, 'storage_provisioner'),
      volume_binding_mode: resource.field(self._.blocks, 'volume_binding_mode'),
    },
    storage_class_v1(name, block): {
      local resource = blockType.resource('kubernetes_storage_class_v1', name),
      _: resource._(block, {
        allow_volume_expansion: build.template(std.get(block, 'allow_volume_expansion', null)),
        id: build.template(std.get(block, 'id', null)),
        mount_options: build.template(std.get(block, 'mount_options', null)),
        parameters: build.template(std.get(block, 'parameters', null)),
        reclaim_policy: build.template(std.get(block, 'reclaim_policy', null)),
        storage_provisioner: build.template(std.get(block, 'storage_provisioner', null)),
        volume_binding_mode: build.template(std.get(block, 'volume_binding_mode', null)),
      }),
      allow_volume_expansion: resource.field(self._.blocks, 'allow_volume_expansion'),
      id: resource.field(self._.blocks, 'id'),
      mount_options: resource.field(self._.blocks, 'mount_options'),
      parameters: resource.field(self._.blocks, 'parameters'),
      reclaim_policy: resource.field(self._.blocks, 'reclaim_policy'),
      storage_provisioner: resource.field(self._.blocks, 'storage_provisioner'),
      volume_binding_mode: resource.field(self._.blocks, 'volume_binding_mode'),
    },
  },
  func: {
    manifest_decode(manifest): provider.func('manifest_decode', [manifest]),
    manifest_decode_multi(manifest): provider.func('manifest_decode_multi', [manifest]),
    manifest_encode(manifest): provider.func('manifest_encode', [manifest]),
  },
};

local providerWithConfiguration = provider(null, null) + {
  withConfiguration(alias, block): provider(block, {
    alias: alias,
    client_certificate: build.template(std.get(block, 'client_certificate', null)),
    client_key: build.template(std.get(block, 'client_key', null)),
    cluster_ca_certificate: build.template(std.get(block, 'cluster_ca_certificate', null)),
    config_context: build.template(std.get(block, 'config_context', null)),
    config_context_auth_info: build.template(std.get(block, 'config_context_auth_info', null)),
    config_context_cluster: build.template(std.get(block, 'config_context_cluster', null)),
    config_path: build.template(std.get(block, 'config_path', null)),
    config_paths: build.template(std.get(block, 'config_paths', null)),
    host: build.template(std.get(block, 'host', null)),
    ignore_annotations: build.template(std.get(block, 'ignore_annotations', null)),
    ignore_labels: build.template(std.get(block, 'ignore_labels', null)),
    insecure: build.template(std.get(block, 'insecure', null)),
    password: build.template(std.get(block, 'password', null)),
    proxy_url: build.template(std.get(block, 'proxy_url', null)),
    tls_server_name: build.template(std.get(block, 'tls_server_name', null)),
    token: build.template(std.get(block, 'token', null)),
    username: build.template(std.get(block, 'username', null)),
  }),
};

providerWithConfiguration
