local build = {
  expression(val):
    if std.type(val) == 'object' then
      if std.objectHas(val, '_') then
        if std.objectHas(val._, 'ref')
        then val._.ref
        else '"%s"' % [val._.str]
      else '{%s}' % [std.join(',', std.map(function(key) '%s:%s' % [self.expression(key), self.expression(val[key])], std.objectFields(val)))]
    else if std.type(val) == 'array' then '[%s]' % [std.join(',', std.map(function(element) self.expression(element), val))]
    else if std.type(val) == 'string' then '"%s"' % [val]
    else '"%s"' % [val],
  template(val):
    if std.type(val) == 'object' then
      if std.objectHas(val, '_') then
        if std.objectHas(val._, 'ref')
        then std.strReplace(self.string(val), '\n', '\\n')
        else val._.str
      else std.mapWithKey(function(key, value) self.template(value), val)
    else if std.type(val) == 'array' then std.map(function(element) self.template(element), val)
    else if std.type(val) == 'string' then std.strReplace(self.string(val), '\n', '\\n')
    else val,
  string(val):
    if std.type(val) == 'object' then
      if std.objectHas(val, '_') then
        if std.objectHas(val._, 'ref')
        then '${%s}' % [val._.ref]
        else val._.str
      else '${%s}' % [self.expression(val)]
    else if std.type(val) == 'array' then '${%s}' % [self.expression(val)]
    else if std.type(val) == 'string' then val
    else val,
  blocks(val):
    if std.type(val) == 'object' then
      if std.objectHas(val, '_') then
        if std.objectHas(val._, 'blocks')
        then val._.blocks
        else
          if std.objectHas(val._, 'block')
          then { [val._.ref]: val._.block }
          else {}
      else std.foldl(
        function(acc, val) std.mergePatch(acc, val),
        std.map(function(key) build.blocks(val[key]), std.objectFields(val)),
        {}
      )
    else
      if std.type(val) == 'array' then std.foldl(
        function(acc, val) std.mergePatch(acc, val),
        std.map(function(element) build.blocks(element), val),
        {}
      )
      else {},
};
local providerTemplate(provider, requirements, rawConfiguration, configuration) = {
  local providerRequirements = { ['terraform.required_providers.%s' % [provider]]: requirements },
  local providerAlias = if configuration == null then null else std.get(configuration, 'alias', null),
  local providerConfiguration = if configuration == null then { _: { refBlock: {}, blocks: [] } } else {
    _: {
      local _ = self,
      ref: '%s.%s' % [provider, configuration.alias],
      refBlock: {
        provider: _.ref,
      },
      block: {
        provider: {
          provider: std.prune(configuration),
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
              [name]: providerConfiguration._.refBlock + metaBlock + block,
            },
          },
        },
        blocks: build.blocks([providerConfiguration] + [rawBlock]) + providerRequirements + { [_.ref]: _.block },
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
local attribute(block, name, required=false) = if !required && !std.objectHas(block, name) then {} else {
  [name]: build.template(block[name]),
};
local blockObj(block, name, body, nestingMode, required=false) = if !required && !std.objectHas(block, name) then {} else {
  [name]: if nestingMode == 'list' then [body(block) for block in block[name]] else body(block[name]),
};
local provider(rawConfiguration, configuration) = {
  local requirements = {
    source: 'registry.terraform.io/cloudflare/cloudflare',
    version: '5.19.1',
  },
  local provider = providerTemplate('cloudflare', requirements, rawConfiguration, configuration),
  resource: {
    local blockType = provider.blockType('resource'),
    access_rule(name, block): {
      local resource = blockType.resource('cloudflare_access_rule', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'allowed_modes') +
        attribute(block, 'configuration', true) +
        attribute(block, 'created_on') +
        attribute(block, 'id') +
        attribute(block, 'mode', true) +
        attribute(block, 'modified_on') +
        attribute(block, 'notes') +
        attribute(block, 'scope') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      allowed_modes: resource.field(self._.blocks, 'allowed_modes'),
      configuration: resource.field(self._.blocks, 'configuration'),
      created_on: resource.field(self._.blocks, 'created_on'),
      id: resource.field(self._.blocks, 'id'),
      mode: resource.field(self._.blocks, 'mode'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      notes: resource.field(self._.blocks, 'notes'),
      scope: resource.field(self._.blocks, 'scope'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    account(name, block): {
      local resource = blockType.resource('cloudflare_account', name),
      _: resource._(
        block,
        attribute(block, 'created_on') +
        attribute(block, 'id') +
        attribute(block, 'managed_by') +
        attribute(block, 'name', true) +
        attribute(block, 'settings') +
        attribute(block, 'type') +
        attribute(block, 'unit')
      ),
      created_on: resource.field(self._.blocks, 'created_on'),
      id: resource.field(self._.blocks, 'id'),
      managed_by: resource.field(self._.blocks, 'managed_by'),
      name: resource.field(self._.blocks, 'name'),
      settings: resource.field(self._.blocks, 'settings'),
      type: resource.field(self._.blocks, 'type'),
      unit: resource.field(self._.blocks, 'unit'),
    },
    account_dns_settings(name, block): {
      local resource = blockType.resource('cloudflare_account_dns_settings', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'enforce_dns_only') +
        attribute(block, 'zone_defaults')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      enforce_dns_only: resource.field(self._.blocks, 'enforce_dns_only'),
      zone_defaults: resource.field(self._.blocks, 'zone_defaults'),
    },
    account_dns_settings_internal_view(name, block): {
      local resource = blockType.resource('cloudflare_account_dns_settings_internal_view', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_time') +
        attribute(block, 'id') +
        attribute(block, 'modified_time') +
        attribute(block, 'name', true) +
        attribute(block, 'zones', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_time: resource.field(self._.blocks, 'created_time'),
      id: resource.field(self._.blocks, 'id'),
      modified_time: resource.field(self._.blocks, 'modified_time'),
      name: resource.field(self._.blocks, 'name'),
      zones: resource.field(self._.blocks, 'zones'),
    },
    account_member(name, block): {
      local resource = blockType.resource('cloudflare_account_member', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'email', true) +
        attribute(block, 'id') +
        attribute(block, 'policies') +
        attribute(block, 'roles') +
        attribute(block, 'status') +
        attribute(block, 'user')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      email: resource.field(self._.blocks, 'email'),
      id: resource.field(self._.blocks, 'id'),
      policies: resource.field(self._.blocks, 'policies'),
      roles: resource.field(self._.blocks, 'roles'),
      status: resource.field(self._.blocks, 'status'),
      user: resource.field(self._.blocks, 'user'),
    },
    account_subscription(name, block): {
      local resource = blockType.resource('cloudflare_account_subscription', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'currency') +
        attribute(block, 'current_period_end') +
        attribute(block, 'current_period_start') +
        attribute(block, 'frequency') +
        attribute(block, 'id') +
        attribute(block, 'price') +
        attribute(block, 'rate_plan') +
        attribute(block, 'state')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      currency: resource.field(self._.blocks, 'currency'),
      current_period_end: resource.field(self._.blocks, 'current_period_end'),
      current_period_start: resource.field(self._.blocks, 'current_period_start'),
      frequency: resource.field(self._.blocks, 'frequency'),
      id: resource.field(self._.blocks, 'id'),
      price: resource.field(self._.blocks, 'price'),
      rate_plan: resource.field(self._.blocks, 'rate_plan'),
      state: resource.field(self._.blocks, 'state'),
    },
    account_token(name, block): {
      local resource = blockType.resource('cloudflare_account_token', name),
      _: resource._(
        block,
        attribute(block, 'account_id', true) +
        attribute(block, 'condition') +
        attribute(block, 'expires_on') +
        attribute(block, 'id') +
        attribute(block, 'issued_on') +
        attribute(block, 'last_used_on') +
        attribute(block, 'modified_on') +
        attribute(block, 'name', true) +
        attribute(block, 'not_before') +
        attribute(block, 'policies', true) +
        attribute(block, 'status') +
        attribute(block, 'value')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      condition: resource.field(self._.blocks, 'condition'),
      expires_on: resource.field(self._.blocks, 'expires_on'),
      id: resource.field(self._.blocks, 'id'),
      issued_on: resource.field(self._.blocks, 'issued_on'),
      last_used_on: resource.field(self._.blocks, 'last_used_on'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      not_before: resource.field(self._.blocks, 'not_before'),
      policies: resource.field(self._.blocks, 'policies'),
      status: resource.field(self._.blocks, 'status'),
      value: resource.field(self._.blocks, 'value'),
    },
    address_map(name, block): {
      local resource = blockType.resource('cloudflare_address_map', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'can_delete') +
        attribute(block, 'can_modify_ips') +
        attribute(block, 'created_at') +
        attribute(block, 'default_sni') +
        attribute(block, 'description') +
        attribute(block, 'enabled') +
        attribute(block, 'id') +
        attribute(block, 'ips') +
        attribute(block, 'memberships') +
        attribute(block, 'modified_at')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      can_delete: resource.field(self._.blocks, 'can_delete'),
      can_modify_ips: resource.field(self._.blocks, 'can_modify_ips'),
      created_at: resource.field(self._.blocks, 'created_at'),
      default_sni: resource.field(self._.blocks, 'default_sni'),
      description: resource.field(self._.blocks, 'description'),
      enabled: resource.field(self._.blocks, 'enabled'),
      id: resource.field(self._.blocks, 'id'),
      ips: resource.field(self._.blocks, 'ips'),
      memberships: resource.field(self._.blocks, 'memberships'),
      modified_at: resource.field(self._.blocks, 'modified_at'),
    },
    ai_gateway(name, block): {
      local resource = blockType.resource('cloudflare_ai_gateway', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'authentication') +
        attribute(block, 'cache_invalidate_on_update', true) +
        attribute(block, 'cache_ttl', true) +
        attribute(block, 'collect_logs', true) +
        attribute(block, 'created_at') +
        attribute(block, 'dlp') +
        attribute(block, 'id', true) +
        attribute(block, 'is_default') +
        attribute(block, 'log_management') +
        attribute(block, 'log_management_strategy') +
        attribute(block, 'logpush') +
        attribute(block, 'logpush_public_key') +
        attribute(block, 'modified_at') +
        attribute(block, 'otel') +
        attribute(block, 'rate_limiting_interval', true) +
        attribute(block, 'rate_limiting_limit', true) +
        attribute(block, 'rate_limiting_technique') +
        attribute(block, 'retry_backoff') +
        attribute(block, 'retry_delay') +
        attribute(block, 'retry_max_attempts') +
        attribute(block, 'store_id') +
        attribute(block, 'stripe') +
        attribute(block, 'workers_ai_billing_mode') +
        attribute(block, 'zdr')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      authentication: resource.field(self._.blocks, 'authentication'),
      cache_invalidate_on_update: resource.field(self._.blocks, 'cache_invalidate_on_update'),
      cache_ttl: resource.field(self._.blocks, 'cache_ttl'),
      collect_logs: resource.field(self._.blocks, 'collect_logs'),
      created_at: resource.field(self._.blocks, 'created_at'),
      dlp: resource.field(self._.blocks, 'dlp'),
      id: resource.field(self._.blocks, 'id'),
      is_default: resource.field(self._.blocks, 'is_default'),
      log_management: resource.field(self._.blocks, 'log_management'),
      log_management_strategy: resource.field(self._.blocks, 'log_management_strategy'),
      logpush: resource.field(self._.blocks, 'logpush'),
      logpush_public_key: resource.field(self._.blocks, 'logpush_public_key'),
      modified_at: resource.field(self._.blocks, 'modified_at'),
      otel: resource.field(self._.blocks, 'otel'),
      rate_limiting_interval: resource.field(self._.blocks, 'rate_limiting_interval'),
      rate_limiting_limit: resource.field(self._.blocks, 'rate_limiting_limit'),
      rate_limiting_technique: resource.field(self._.blocks, 'rate_limiting_technique'),
      retry_backoff: resource.field(self._.blocks, 'retry_backoff'),
      retry_delay: resource.field(self._.blocks, 'retry_delay'),
      retry_max_attempts: resource.field(self._.blocks, 'retry_max_attempts'),
      store_id: resource.field(self._.blocks, 'store_id'),
      stripe: resource.field(self._.blocks, 'stripe'),
      workers_ai_billing_mode: resource.field(self._.blocks, 'workers_ai_billing_mode'),
      zdr: resource.field(self._.blocks, 'zdr'),
    },
    ai_gateway_dynamic_routing(name, block): {
      local resource = blockType.resource('cloudflare_ai_gateway_dynamic_routing', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_at') +
        attribute(block, 'deployment') +
        attribute(block, 'elements', true) +
        attribute(block, 'gateway_id', true) +
        attribute(block, 'id') +
        attribute(block, 'modified_at') +
        attribute(block, 'name', true) +
        attribute(block, 'route') +
        attribute(block, 'success') +
        attribute(block, 'version')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_at: resource.field(self._.blocks, 'created_at'),
      deployment: resource.field(self._.blocks, 'deployment'),
      elements: resource.field(self._.blocks, 'elements'),
      gateway_id: resource.field(self._.blocks, 'gateway_id'),
      id: resource.field(self._.blocks, 'id'),
      modified_at: resource.field(self._.blocks, 'modified_at'),
      name: resource.field(self._.blocks, 'name'),
      route: resource.field(self._.blocks, 'route'),
      success: resource.field(self._.blocks, 'success'),
      version: resource.field(self._.blocks, 'version'),
    },
    ai_search_instance(name, block): {
      local resource = blockType.resource('cloudflare_ai_search_instance', name),
      _: resource._(
        block,
        attribute(block, 'account_id', true) +
        attribute(block, 'ai_gateway_id') +
        attribute(block, 'aisearch_model') +
        attribute(block, 'cache') +
        attribute(block, 'cache_threshold') +
        attribute(block, 'chunk') +
        attribute(block, 'chunk_overlap') +
        attribute(block, 'chunk_size') +
        attribute(block, 'created_at') +
        attribute(block, 'created_by') +
        attribute(block, 'custom_metadata') +
        attribute(block, 'embedding_model') +
        attribute(block, 'enable') +
        attribute(block, 'engine_version') +
        attribute(block, 'fusion_method') +
        attribute(block, 'hybrid_search_enabled') +
        attribute(block, 'id', true) +
        attribute(block, 'index_method') +
        attribute(block, 'indexing_options') +
        attribute(block, 'last_activity') +
        attribute(block, 'max_num_results') +
        attribute(block, 'metadata') +
        attribute(block, 'modified_at') +
        attribute(block, 'modified_by') +
        attribute(block, 'namespace') +
        attribute(block, 'paused') +
        attribute(block, 'public_endpoint_id') +
        attribute(block, 'public_endpoint_params') +
        attribute(block, 'reranking') +
        attribute(block, 'reranking_model') +
        attribute(block, 'retrieval_options') +
        attribute(block, 'rewrite_model') +
        attribute(block, 'rewrite_query') +
        attribute(block, 'score_threshold') +
        attribute(block, 'source') +
        attribute(block, 'source_params') +
        attribute(block, 'status') +
        attribute(block, 'summarization') +
        attribute(block, 'summarization_model') +
        attribute(block, 'sync_interval') +
        attribute(block, 'system_prompt_aisearch') +
        attribute(block, 'system_prompt_index_summarization') +
        attribute(block, 'system_prompt_rewrite_query') +
        attribute(block, 'token_id') +
        attribute(block, 'type') +
        attribute(block, 'vectorize_name')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      ai_gateway_id: resource.field(self._.blocks, 'ai_gateway_id'),
      aisearch_model: resource.field(self._.blocks, 'aisearch_model'),
      cache: resource.field(self._.blocks, 'cache'),
      cache_threshold: resource.field(self._.blocks, 'cache_threshold'),
      chunk: resource.field(self._.blocks, 'chunk'),
      chunk_overlap: resource.field(self._.blocks, 'chunk_overlap'),
      chunk_size: resource.field(self._.blocks, 'chunk_size'),
      created_at: resource.field(self._.blocks, 'created_at'),
      created_by: resource.field(self._.blocks, 'created_by'),
      custom_metadata: resource.field(self._.blocks, 'custom_metadata'),
      embedding_model: resource.field(self._.blocks, 'embedding_model'),
      enable: resource.field(self._.blocks, 'enable'),
      engine_version: resource.field(self._.blocks, 'engine_version'),
      fusion_method: resource.field(self._.blocks, 'fusion_method'),
      hybrid_search_enabled: resource.field(self._.blocks, 'hybrid_search_enabled'),
      id: resource.field(self._.blocks, 'id'),
      index_method: resource.field(self._.blocks, 'index_method'),
      indexing_options: resource.field(self._.blocks, 'indexing_options'),
      last_activity: resource.field(self._.blocks, 'last_activity'),
      max_num_results: resource.field(self._.blocks, 'max_num_results'),
      metadata: resource.field(self._.blocks, 'metadata'),
      modified_at: resource.field(self._.blocks, 'modified_at'),
      modified_by: resource.field(self._.blocks, 'modified_by'),
      namespace: resource.field(self._.blocks, 'namespace'),
      paused: resource.field(self._.blocks, 'paused'),
      public_endpoint_id: resource.field(self._.blocks, 'public_endpoint_id'),
      public_endpoint_params: resource.field(self._.blocks, 'public_endpoint_params'),
      reranking: resource.field(self._.blocks, 'reranking'),
      reranking_model: resource.field(self._.blocks, 'reranking_model'),
      retrieval_options: resource.field(self._.blocks, 'retrieval_options'),
      rewrite_model: resource.field(self._.blocks, 'rewrite_model'),
      rewrite_query: resource.field(self._.blocks, 'rewrite_query'),
      score_threshold: resource.field(self._.blocks, 'score_threshold'),
      source: resource.field(self._.blocks, 'source'),
      source_params: resource.field(self._.blocks, 'source_params'),
      status: resource.field(self._.blocks, 'status'),
      summarization: resource.field(self._.blocks, 'summarization'),
      summarization_model: resource.field(self._.blocks, 'summarization_model'),
      sync_interval: resource.field(self._.blocks, 'sync_interval'),
      system_prompt_aisearch: resource.field(self._.blocks, 'system_prompt_aisearch'),
      system_prompt_index_summarization: resource.field(self._.blocks, 'system_prompt_index_summarization'),
      system_prompt_rewrite_query: resource.field(self._.blocks, 'system_prompt_rewrite_query'),
      token_id: resource.field(self._.blocks, 'token_id'),
      type: resource.field(self._.blocks, 'type'),
      vectorize_name: resource.field(self._.blocks, 'vectorize_name'),
    },
    ai_search_token(name, block): {
      local resource = blockType.resource('cloudflare_ai_search_token', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'cf_api_id', true) +
        attribute(block, 'cf_api_key', true) +
        attribute(block, 'created_at') +
        attribute(block, 'created_by') +
        attribute(block, 'enabled') +
        attribute(block, 'id') +
        attribute(block, 'legacy') +
        attribute(block, 'modified_at') +
        attribute(block, 'modified_by') +
        attribute(block, 'name', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      cf_api_id: resource.field(self._.blocks, 'cf_api_id'),
      cf_api_key: resource.field(self._.blocks, 'cf_api_key'),
      created_at: resource.field(self._.blocks, 'created_at'),
      created_by: resource.field(self._.blocks, 'created_by'),
      enabled: resource.field(self._.blocks, 'enabled'),
      id: resource.field(self._.blocks, 'id'),
      legacy: resource.field(self._.blocks, 'legacy'),
      modified_at: resource.field(self._.blocks, 'modified_at'),
      modified_by: resource.field(self._.blocks, 'modified_by'),
      name: resource.field(self._.blocks, 'name'),
    },
    api_shield(name, block): {
      local resource = blockType.resource('cloudflare_api_shield', name),
      _: resource._(
        block,
        attribute(block, 'auth_id_characteristics', true) +
        attribute(block, 'id') +
        attribute(block, 'zone_id', true)
      ),
      auth_id_characteristics: resource.field(self._.blocks, 'auth_id_characteristics'),
      id: resource.field(self._.blocks, 'id'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    api_shield_discovery_operation(name, block): {
      local resource = blockType.resource('cloudflare_api_shield_discovery_operation', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'operation_id', true) +
        attribute(block, 'state') +
        attribute(block, 'zone_id')
      ),
      id: resource.field(self._.blocks, 'id'),
      operation_id: resource.field(self._.blocks, 'operation_id'),
      state: resource.field(self._.blocks, 'state'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    api_shield_operation(name, block): {
      local resource = blockType.resource('cloudflare_api_shield_operation', name),
      _: resource._(
        block,
        attribute(block, 'endpoint', true) +
        attribute(block, 'features') +
        attribute(block, 'host', true) +
        attribute(block, 'id') +
        attribute(block, 'last_updated') +
        attribute(block, 'method', true) +
        attribute(block, 'operation_id') +
        attribute(block, 'zone_id')
      ),
      endpoint: resource.field(self._.blocks, 'endpoint'),
      features: resource.field(self._.blocks, 'features'),
      host: resource.field(self._.blocks, 'host'),
      id: resource.field(self._.blocks, 'id'),
      last_updated: resource.field(self._.blocks, 'last_updated'),
      method: resource.field(self._.blocks, 'method'),
      operation_id: resource.field(self._.blocks, 'operation_id'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    api_shield_operation_schema_validation_settings(name, block): {
      local resource = blockType.resource('cloudflare_api_shield_operation_schema_validation_settings', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'mitigation_action') +
        attribute(block, 'operation_id', true) +
        attribute(block, 'zone_id')
      ),
      id: resource.field(self._.blocks, 'id'),
      mitigation_action: resource.field(self._.blocks, 'mitigation_action'),
      operation_id: resource.field(self._.blocks, 'operation_id'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    api_shield_schema(name, block): {
      local resource = blockType.resource('cloudflare_api_shield_schema', name),
      _: resource._(
        block,
        attribute(block, 'created_at') +
        attribute(block, 'file', true) +
        attribute(block, 'kind', true) +
        attribute(block, 'name') +
        attribute(block, 'schema') +
        attribute(block, 'schema_id') +
        attribute(block, 'source') +
        attribute(block, 'upload_details') +
        attribute(block, 'validation_enabled') +
        attribute(block, 'zone_id')
      ),
      created_at: resource.field(self._.blocks, 'created_at'),
      file: resource.field(self._.blocks, 'file'),
      kind: resource.field(self._.blocks, 'kind'),
      name: resource.field(self._.blocks, 'name'),
      schema: resource.field(self._.blocks, 'schema'),
      schema_id: resource.field(self._.blocks, 'schema_id'),
      source: resource.field(self._.blocks, 'source'),
      upload_details: resource.field(self._.blocks, 'upload_details'),
      validation_enabled: resource.field(self._.blocks, 'validation_enabled'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    api_shield_schema_validation_settings(name, block): {
      local resource = blockType.resource('cloudflare_api_shield_schema_validation_settings', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'validation_default_mitigation_action', true) +
        attribute(block, 'validation_override_mitigation_action') +
        attribute(block, 'zone_id', true)
      ),
      id: resource.field(self._.blocks, 'id'),
      validation_default_mitigation_action: resource.field(self._.blocks, 'validation_default_mitigation_action'),
      validation_override_mitigation_action: resource.field(self._.blocks, 'validation_override_mitigation_action'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    api_token(name, block): {
      local resource = blockType.resource('cloudflare_api_token', name),
      _: resource._(
        block,
        attribute(block, 'condition') +
        attribute(block, 'expires_on') +
        attribute(block, 'id') +
        attribute(block, 'issued_on') +
        attribute(block, 'last_used_on') +
        attribute(block, 'modified_on') +
        attribute(block, 'name', true) +
        attribute(block, 'not_before') +
        attribute(block, 'policies', true) +
        attribute(block, 'status') +
        attribute(block, 'value')
      ),
      condition: resource.field(self._.blocks, 'condition'),
      expires_on: resource.field(self._.blocks, 'expires_on'),
      id: resource.field(self._.blocks, 'id'),
      issued_on: resource.field(self._.blocks, 'issued_on'),
      last_used_on: resource.field(self._.blocks, 'last_used_on'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      not_before: resource.field(self._.blocks, 'not_before'),
      policies: resource.field(self._.blocks, 'policies'),
      status: resource.field(self._.blocks, 'status'),
      value: resource.field(self._.blocks, 'value'),
    },
    argo_smart_routing(name, block): {
      local resource = blockType.resource('cloudflare_argo_smart_routing', name),
      _: resource._(
        block,
        attribute(block, 'editable') +
        attribute(block, 'id') +
        attribute(block, 'modified_on') +
        attribute(block, 'value', true) +
        attribute(block, 'zone_id', true)
      ),
      editable: resource.field(self._.blocks, 'editable'),
      id: resource.field(self._.blocks, 'id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      value: resource.field(self._.blocks, 'value'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    argo_tiered_caching(name, block): {
      local resource = blockType.resource('cloudflare_argo_tiered_caching', name),
      _: resource._(
        block,
        attribute(block, 'editable') +
        attribute(block, 'id') +
        attribute(block, 'modified_on') +
        attribute(block, 'value', true) +
        attribute(block, 'zone_id', true)
      ),
      editable: resource.field(self._.blocks, 'editable'),
      id: resource.field(self._.blocks, 'id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      value: resource.field(self._.blocks, 'value'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    authenticated_origin_pulls(name, block): {
      local resource = blockType.resource('cloudflare_authenticated_origin_pulls', name),
      _: resource._(
        block,
        attribute(block, 'cert_id') +
        attribute(block, 'cert_status') +
        attribute(block, 'cert_updated_at') +
        attribute(block, 'cert_uploaded_on') +
        attribute(block, 'certificate') +
        attribute(block, 'config', true) +
        attribute(block, 'created_at') +
        attribute(block, 'enabled') +
        attribute(block, 'expires_on') +
        attribute(block, 'hostname') +
        attribute(block, 'id') +
        attribute(block, 'issuer') +
        attribute(block, 'private_key') +
        attribute(block, 'serial_number') +
        attribute(block, 'signature') +
        attribute(block, 'status') +
        attribute(block, 'updated_at') +
        attribute(block, 'zone_id', true)
      ),
      cert_id: resource.field(self._.blocks, 'cert_id'),
      cert_status: resource.field(self._.blocks, 'cert_status'),
      cert_updated_at: resource.field(self._.blocks, 'cert_updated_at'),
      cert_uploaded_on: resource.field(self._.blocks, 'cert_uploaded_on'),
      certificate: resource.field(self._.blocks, 'certificate'),
      config: resource.field(self._.blocks, 'config'),
      created_at: resource.field(self._.blocks, 'created_at'),
      enabled: resource.field(self._.blocks, 'enabled'),
      expires_on: resource.field(self._.blocks, 'expires_on'),
      hostname: resource.field(self._.blocks, 'hostname'),
      id: resource.field(self._.blocks, 'id'),
      issuer: resource.field(self._.blocks, 'issuer'),
      private_key: resource.field(self._.blocks, 'private_key'),
      serial_number: resource.field(self._.blocks, 'serial_number'),
      signature: resource.field(self._.blocks, 'signature'),
      status: resource.field(self._.blocks, 'status'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    authenticated_origin_pulls_certificate(name, block): {
      local resource = blockType.resource('cloudflare_authenticated_origin_pulls_certificate', name),
      _: resource._(
        block,
        attribute(block, 'certificate', true) +
        attribute(block, 'certificate_id') +
        attribute(block, 'enabled') +
        attribute(block, 'expires_on') +
        attribute(block, 'id') +
        attribute(block, 'issuer') +
        attribute(block, 'private_key', true) +
        attribute(block, 'serial_number') +
        attribute(block, 'signature') +
        attribute(block, 'status') +
        attribute(block, 'uploaded_on') +
        attribute(block, 'zone_id', true)
      ),
      certificate: resource.field(self._.blocks, 'certificate'),
      certificate_id: resource.field(self._.blocks, 'certificate_id'),
      enabled: resource.field(self._.blocks, 'enabled'),
      expires_on: resource.field(self._.blocks, 'expires_on'),
      id: resource.field(self._.blocks, 'id'),
      issuer: resource.field(self._.blocks, 'issuer'),
      private_key: resource.field(self._.blocks, 'private_key'),
      serial_number: resource.field(self._.blocks, 'serial_number'),
      signature: resource.field(self._.blocks, 'signature'),
      status: resource.field(self._.blocks, 'status'),
      uploaded_on: resource.field(self._.blocks, 'uploaded_on'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    authenticated_origin_pulls_hostname_certificate(name, block): {
      local resource = blockType.resource('cloudflare_authenticated_origin_pulls_hostname_certificate', name),
      _: resource._(
        block,
        attribute(block, 'certificate', true) +
        attribute(block, 'expires_on') +
        attribute(block, 'id') +
        attribute(block, 'issuer') +
        attribute(block, 'private_key', true) +
        attribute(block, 'serial_number') +
        attribute(block, 'signature') +
        attribute(block, 'status') +
        attribute(block, 'uploaded_on') +
        attribute(block, 'zone_id', true)
      ),
      certificate: resource.field(self._.blocks, 'certificate'),
      expires_on: resource.field(self._.blocks, 'expires_on'),
      id: resource.field(self._.blocks, 'id'),
      issuer: resource.field(self._.blocks, 'issuer'),
      private_key: resource.field(self._.blocks, 'private_key'),
      serial_number: resource.field(self._.blocks, 'serial_number'),
      signature: resource.field(self._.blocks, 'signature'),
      status: resource.field(self._.blocks, 'status'),
      uploaded_on: resource.field(self._.blocks, 'uploaded_on'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    authenticated_origin_pulls_settings(name, block): {
      local resource = blockType.resource('cloudflare_authenticated_origin_pulls_settings', name),
      _: resource._(
        block,
        attribute(block, 'enabled', true) +
        attribute(block, 'id') +
        attribute(block, 'zone_id', true)
      ),
      enabled: resource.field(self._.blocks, 'enabled'),
      id: resource.field(self._.blocks, 'id'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    bot_management(name, block): {
      local resource = blockType.resource('cloudflare_bot_management', name),
      _: resource._(
        block,
        attribute(block, 'ai_bots_protection') +
        attribute(block, 'auto_update_model') +
        attribute(block, 'bm_cookie_enabled') +
        attribute(block, 'cf_robots_variant') +
        attribute(block, 'content_bots_protection') +
        attribute(block, 'crawler_protection') +
        attribute(block, 'enable_js') +
        attribute(block, 'fight_mode') +
        attribute(block, 'id') +
        attribute(block, 'is_robots_txt_managed') +
        attribute(block, 'optimize_wordpress') +
        attribute(block, 'sbfm_definitely_automated') +
        attribute(block, 'sbfm_likely_automated') +
        attribute(block, 'sbfm_static_resource_protection') +
        attribute(block, 'sbfm_verified_bots') +
        attribute(block, 'stale_zone_configuration') +
        attribute(block, 'suppress_session_score') +
        attribute(block, 'using_latest_model') +
        attribute(block, 'zone_id', true)
      ),
      ai_bots_protection: resource.field(self._.blocks, 'ai_bots_protection'),
      auto_update_model: resource.field(self._.blocks, 'auto_update_model'),
      bm_cookie_enabled: resource.field(self._.blocks, 'bm_cookie_enabled'),
      cf_robots_variant: resource.field(self._.blocks, 'cf_robots_variant'),
      content_bots_protection: resource.field(self._.blocks, 'content_bots_protection'),
      crawler_protection: resource.field(self._.blocks, 'crawler_protection'),
      enable_js: resource.field(self._.blocks, 'enable_js'),
      fight_mode: resource.field(self._.blocks, 'fight_mode'),
      id: resource.field(self._.blocks, 'id'),
      is_robots_txt_managed: resource.field(self._.blocks, 'is_robots_txt_managed'),
      optimize_wordpress: resource.field(self._.blocks, 'optimize_wordpress'),
      sbfm_definitely_automated: resource.field(self._.blocks, 'sbfm_definitely_automated'),
      sbfm_likely_automated: resource.field(self._.blocks, 'sbfm_likely_automated'),
      sbfm_static_resource_protection: resource.field(self._.blocks, 'sbfm_static_resource_protection'),
      sbfm_verified_bots: resource.field(self._.blocks, 'sbfm_verified_bots'),
      stale_zone_configuration: resource.field(self._.blocks, 'stale_zone_configuration'),
      suppress_session_score: resource.field(self._.blocks, 'suppress_session_score'),
      using_latest_model: resource.field(self._.blocks, 'using_latest_model'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    byo_ip_prefix(name, block): {
      local resource = blockType.resource('cloudflare_byo_ip_prefix', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'advertised') +
        attribute(block, 'advertised_modified_at') +
        attribute(block, 'approved') +
        attribute(block, 'asn', true) +
        attribute(block, 'cidr', true) +
        attribute(block, 'created_at') +
        attribute(block, 'delegate_loa_creation') +
        attribute(block, 'description') +
        attribute(block, 'id') +
        attribute(block, 'irr_validation_state') +
        attribute(block, 'loa_document_id') +
        attribute(block, 'modified_at') +
        attribute(block, 'on_demand_enabled') +
        attribute(block, 'on_demand_locked') +
        attribute(block, 'ownership_validation_state') +
        attribute(block, 'ownership_validation_token') +
        attribute(block, 'rpki_validation_state')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      advertised: resource.field(self._.blocks, 'advertised'),
      advertised_modified_at: resource.field(self._.blocks, 'advertised_modified_at'),
      approved: resource.field(self._.blocks, 'approved'),
      asn: resource.field(self._.blocks, 'asn'),
      cidr: resource.field(self._.blocks, 'cidr'),
      created_at: resource.field(self._.blocks, 'created_at'),
      delegate_loa_creation: resource.field(self._.blocks, 'delegate_loa_creation'),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      irr_validation_state: resource.field(self._.blocks, 'irr_validation_state'),
      loa_document_id: resource.field(self._.blocks, 'loa_document_id'),
      modified_at: resource.field(self._.blocks, 'modified_at'),
      on_demand_enabled: resource.field(self._.blocks, 'on_demand_enabled'),
      on_demand_locked: resource.field(self._.blocks, 'on_demand_locked'),
      ownership_validation_state: resource.field(self._.blocks, 'ownership_validation_state'),
      ownership_validation_token: resource.field(self._.blocks, 'ownership_validation_token'),
      rpki_validation_state: resource.field(self._.blocks, 'rpki_validation_state'),
    },
    calls_sfu_app(name, block): {
      local resource = blockType.resource('cloudflare_calls_sfu_app', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'app_id') +
        attribute(block, 'created') +
        attribute(block, 'modified') +
        attribute(block, 'name') +
        attribute(block, 'secret') +
        attribute(block, 'uid')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      app_id: resource.field(self._.blocks, 'app_id'),
      created: resource.field(self._.blocks, 'created'),
      modified: resource.field(self._.blocks, 'modified'),
      name: resource.field(self._.blocks, 'name'),
      secret: resource.field(self._.blocks, 'secret'),
      uid: resource.field(self._.blocks, 'uid'),
    },
    calls_turn_app(name, block): {
      local resource = blockType.resource('cloudflare_calls_turn_app', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created') +
        attribute(block, 'key') +
        attribute(block, 'key_id') +
        attribute(block, 'modified') +
        attribute(block, 'name') +
        attribute(block, 'uid')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created: resource.field(self._.blocks, 'created'),
      key: resource.field(self._.blocks, 'key'),
      key_id: resource.field(self._.blocks, 'key_id'),
      modified: resource.field(self._.blocks, 'modified'),
      name: resource.field(self._.blocks, 'name'),
      uid: resource.field(self._.blocks, 'uid'),
    },
    certificate_authorities_hostname_associations(name, block): {
      local resource = blockType.resource('cloudflare_certificate_authorities_hostname_associations', name),
      _: resource._(
        block,
        attribute(block, 'hostnames') +
        attribute(block, 'id') +
        attribute(block, 'mtls_certificate_id') +
        attribute(block, 'zone_id', true)
      ),
      hostnames: resource.field(self._.blocks, 'hostnames'),
      id: resource.field(self._.blocks, 'id'),
      mtls_certificate_id: resource.field(self._.blocks, 'mtls_certificate_id'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    certificate_pack(name, block): {
      local resource = blockType.resource('cloudflare_certificate_pack', name),
      _: resource._(
        block,
        attribute(block, 'certificate_authority', true) +
        attribute(block, 'certificates') +
        attribute(block, 'cloudflare_branding') +
        attribute(block, 'dcv_delegation_records') +
        attribute(block, 'hosts') +
        attribute(block, 'id') +
        attribute(block, 'primary_certificate') +
        attribute(block, 'status') +
        attribute(block, 'type', true) +
        attribute(block, 'validation_errors') +
        attribute(block, 'validation_method', true) +
        attribute(block, 'validation_records') +
        attribute(block, 'validity_days', true) +
        attribute(block, 'zone_id')
      ),
      certificate_authority: resource.field(self._.blocks, 'certificate_authority'),
      certificates: resource.field(self._.blocks, 'certificates'),
      cloudflare_branding: resource.field(self._.blocks, 'cloudflare_branding'),
      dcv_delegation_records: resource.field(self._.blocks, 'dcv_delegation_records'),
      hosts: resource.field(self._.blocks, 'hosts'),
      id: resource.field(self._.blocks, 'id'),
      primary_certificate: resource.field(self._.blocks, 'primary_certificate'),
      status: resource.field(self._.blocks, 'status'),
      type: resource.field(self._.blocks, 'type'),
      validation_errors: resource.field(self._.blocks, 'validation_errors'),
      validation_method: resource.field(self._.blocks, 'validation_method'),
      validation_records: resource.field(self._.blocks, 'validation_records'),
      validity_days: resource.field(self._.blocks, 'validity_days'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    client_certificate(name, block): {
      local resource = blockType.resource('cloudflare_client_certificate', name),
      _: resource._(
        block,
        attribute(block, 'certificate') +
        attribute(block, 'certificate_authority') +
        attribute(block, 'common_name') +
        attribute(block, 'country') +
        attribute(block, 'csr', true) +
        attribute(block, 'expires_on') +
        attribute(block, 'fingerprint_sha256') +
        attribute(block, 'id') +
        attribute(block, 'issued_on') +
        attribute(block, 'location') +
        attribute(block, 'organization') +
        attribute(block, 'organizational_unit') +
        attribute(block, 'reactivate') +
        attribute(block, 'serial_number') +
        attribute(block, 'signature') +
        attribute(block, 'ski') +
        attribute(block, 'state') +
        attribute(block, 'status') +
        attribute(block, 'validity_days', true) +
        attribute(block, 'zone_id')
      ),
      certificate: resource.field(self._.blocks, 'certificate'),
      certificate_authority: resource.field(self._.blocks, 'certificate_authority'),
      common_name: resource.field(self._.blocks, 'common_name'),
      country: resource.field(self._.blocks, 'country'),
      csr: resource.field(self._.blocks, 'csr'),
      expires_on: resource.field(self._.blocks, 'expires_on'),
      fingerprint_sha256: resource.field(self._.blocks, 'fingerprint_sha256'),
      id: resource.field(self._.blocks, 'id'),
      issued_on: resource.field(self._.blocks, 'issued_on'),
      location: resource.field(self._.blocks, 'location'),
      organization: resource.field(self._.blocks, 'organization'),
      organizational_unit: resource.field(self._.blocks, 'organizational_unit'),
      reactivate: resource.field(self._.blocks, 'reactivate'),
      serial_number: resource.field(self._.blocks, 'serial_number'),
      signature: resource.field(self._.blocks, 'signature'),
      ski: resource.field(self._.blocks, 'ski'),
      state: resource.field(self._.blocks, 'state'),
      status: resource.field(self._.blocks, 'status'),
      validity_days: resource.field(self._.blocks, 'validity_days'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    cloud_connector_rules(name, block): {
      local resource = blockType.resource('cloudflare_cloud_connector_rules', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'rules') +
        attribute(block, 'zone_id', true)
      ),
      id: resource.field(self._.blocks, 'id'),
      rules: resource.field(self._.blocks, 'rules'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    cloudforce_one_request(name, block): {
      local resource = blockType.resource('cloudflare_cloudforce_one_request', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'completed') +
        attribute(block, 'content') +
        attribute(block, 'created') +
        attribute(block, 'id') +
        attribute(block, 'message_tokens') +
        attribute(block, 'priority') +
        attribute(block, 'readable_id') +
        attribute(block, 'request') +
        attribute(block, 'request_type') +
        attribute(block, 'status') +
        attribute(block, 'summary') +
        attribute(block, 'tlp') +
        attribute(block, 'tokens') +
        attribute(block, 'updated')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      completed: resource.field(self._.blocks, 'completed'),
      content: resource.field(self._.blocks, 'content'),
      created: resource.field(self._.blocks, 'created'),
      id: resource.field(self._.blocks, 'id'),
      message_tokens: resource.field(self._.blocks, 'message_tokens'),
      priority: resource.field(self._.blocks, 'priority'),
      readable_id: resource.field(self._.blocks, 'readable_id'),
      request: resource.field(self._.blocks, 'request'),
      request_type: resource.field(self._.blocks, 'request_type'),
      status: resource.field(self._.blocks, 'status'),
      summary: resource.field(self._.blocks, 'summary'),
      tlp: resource.field(self._.blocks, 'tlp'),
      tokens: resource.field(self._.blocks, 'tokens'),
      updated: resource.field(self._.blocks, 'updated'),
    },
    cloudforce_one_request_asset(name, block): {
      local resource = blockType.resource('cloudflare_cloudforce_one_request_asset', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created') +
        attribute(block, 'description') +
        attribute(block, 'file_type') +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'page', true) +
        attribute(block, 'per_page', true) +
        attribute(block, 'request_id', true) +
        attribute(block, 'source')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created: resource.field(self._.blocks, 'created'),
      description: resource.field(self._.blocks, 'description'),
      file_type: resource.field(self._.blocks, 'file_type'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      page: resource.field(self._.blocks, 'page'),
      per_page: resource.field(self._.blocks, 'per_page'),
      request_id: resource.field(self._.blocks, 'request_id'),
      source: resource.field(self._.blocks, 'source'),
    },
    cloudforce_one_request_message(name, block): {
      local resource = blockType.resource('cloudflare_cloudforce_one_request_message', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'author') +
        attribute(block, 'content') +
        attribute(block, 'created') +
        attribute(block, 'id') +
        attribute(block, 'is_follow_on_request') +
        attribute(block, 'request_id', true) +
        attribute(block, 'updated')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      author: resource.field(self._.blocks, 'author'),
      content: resource.field(self._.blocks, 'content'),
      created: resource.field(self._.blocks, 'created'),
      id: resource.field(self._.blocks, 'id'),
      is_follow_on_request: resource.field(self._.blocks, 'is_follow_on_request'),
      request_id: resource.field(self._.blocks, 'request_id'),
      updated: resource.field(self._.blocks, 'updated'),
    },
    cloudforce_one_request_priority(name, block): {
      local resource = blockType.resource('cloudflare_cloudforce_one_request_priority', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'completed') +
        attribute(block, 'content') +
        attribute(block, 'created') +
        attribute(block, 'id') +
        attribute(block, 'labels', true) +
        attribute(block, 'message_tokens') +
        attribute(block, 'priority', true) +
        attribute(block, 'readable_id') +
        attribute(block, 'request') +
        attribute(block, 'requirement', true) +
        attribute(block, 'status') +
        attribute(block, 'summary') +
        attribute(block, 'tlp', true) +
        attribute(block, 'tokens') +
        attribute(block, 'updated')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      completed: resource.field(self._.blocks, 'completed'),
      content: resource.field(self._.blocks, 'content'),
      created: resource.field(self._.blocks, 'created'),
      id: resource.field(self._.blocks, 'id'),
      labels: resource.field(self._.blocks, 'labels'),
      message_tokens: resource.field(self._.blocks, 'message_tokens'),
      priority: resource.field(self._.blocks, 'priority'),
      readable_id: resource.field(self._.blocks, 'readable_id'),
      request: resource.field(self._.blocks, 'request'),
      requirement: resource.field(self._.blocks, 'requirement'),
      status: resource.field(self._.blocks, 'status'),
      summary: resource.field(self._.blocks, 'summary'),
      tlp: resource.field(self._.blocks, 'tlp'),
      tokens: resource.field(self._.blocks, 'tokens'),
      updated: resource.field(self._.blocks, 'updated'),
    },
    connectivity_directory_service(name, block): {
      local resource = blockType.resource('cloudflare_connectivity_directory_service', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'app_protocol') +
        attribute(block, 'created_at') +
        attribute(block, 'host', true) +
        attribute(block, 'http_port') +
        attribute(block, 'https_port') +
        attribute(block, 'id') +
        attribute(block, 'name', true) +
        attribute(block, 'service_id') +
        attribute(block, 'tcp_port') +
        attribute(block, 'tls_settings') +
        attribute(block, 'type', true) +
        attribute(block, 'updated_at')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      app_protocol: resource.field(self._.blocks, 'app_protocol'),
      created_at: resource.field(self._.blocks, 'created_at'),
      host: resource.field(self._.blocks, 'host'),
      http_port: resource.field(self._.blocks, 'http_port'),
      https_port: resource.field(self._.blocks, 'https_port'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      service_id: resource.field(self._.blocks, 'service_id'),
      tcp_port: resource.field(self._.blocks, 'tcp_port'),
      tls_settings: resource.field(self._.blocks, 'tls_settings'),
      type: resource.field(self._.blocks, 'type'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
    },
    content_scanning(name, block): {
      local resource = blockType.resource('cloudflare_content_scanning', name),
      _: resource._(
        block,
        attribute(block, 'modified') +
        attribute(block, 'value', true) +
        attribute(block, 'zone_id')
      ),
      modified: resource.field(self._.blocks, 'modified'),
      value: resource.field(self._.blocks, 'value'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    content_scanning_expression(name, block): {
      local resource = blockType.resource('cloudflare_content_scanning_expression', name),
      _: resource._(
        block,
        attribute(block, 'body', true) +
        attribute(block, 'id') +
        attribute(block, 'zone_id')
      ),
      body: resource.field(self._.blocks, 'body'),
      id: resource.field(self._.blocks, 'id'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    custom_hostname(name, block): {
      local resource = blockType.resource('cloudflare_custom_hostname', name),
      _: resource._(
        block,
        attribute(block, 'created_at') +
        attribute(block, 'custom_metadata') +
        attribute(block, 'custom_origin_server') +
        attribute(block, 'custom_origin_sni') +
        attribute(block, 'hostname', true) +
        attribute(block, 'id') +
        attribute(block, 'ownership_verification') +
        attribute(block, 'ownership_verification_http') +
        attribute(block, 'ssl') +
        attribute(block, 'status') +
        attribute(block, 'verification_errors') +
        attribute(block, 'zone_id')
      ),
      created_at: resource.field(self._.blocks, 'created_at'),
      custom_metadata: resource.field(self._.blocks, 'custom_metadata'),
      custom_origin_server: resource.field(self._.blocks, 'custom_origin_server'),
      custom_origin_sni: resource.field(self._.blocks, 'custom_origin_sni'),
      hostname: resource.field(self._.blocks, 'hostname'),
      id: resource.field(self._.blocks, 'id'),
      ownership_verification: resource.field(self._.blocks, 'ownership_verification'),
      ownership_verification_http: resource.field(self._.blocks, 'ownership_verification_http'),
      ssl: resource.field(self._.blocks, 'ssl'),
      status: resource.field(self._.blocks, 'status'),
      verification_errors: resource.field(self._.blocks, 'verification_errors'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    custom_hostname_fallback_origin(name, block): {
      local resource = blockType.resource('cloudflare_custom_hostname_fallback_origin', name),
      _: resource._(
        block,
        attribute(block, 'created_at') +
        attribute(block, 'errors') +
        attribute(block, 'id') +
        attribute(block, 'origin', true) +
        attribute(block, 'status') +
        attribute(block, 'updated_at') +
        attribute(block, 'zone_id', true)
      ),
      created_at: resource.field(self._.blocks, 'created_at'),
      errors: resource.field(self._.blocks, 'errors'),
      id: resource.field(self._.blocks, 'id'),
      origin: resource.field(self._.blocks, 'origin'),
      status: resource.field(self._.blocks, 'status'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    custom_origin_trust_store(name, block): {
      local resource = blockType.resource('cloudflare_custom_origin_trust_store', name),
      _: resource._(
        block,
        attribute(block, 'certificate', true) +
        attribute(block, 'expires_on') +
        attribute(block, 'id') +
        attribute(block, 'issuer') +
        attribute(block, 'signature') +
        attribute(block, 'status') +
        attribute(block, 'updated_at') +
        attribute(block, 'uploaded_on') +
        attribute(block, 'zone_id')
      ),
      certificate: resource.field(self._.blocks, 'certificate'),
      expires_on: resource.field(self._.blocks, 'expires_on'),
      id: resource.field(self._.blocks, 'id'),
      issuer: resource.field(self._.blocks, 'issuer'),
      signature: resource.field(self._.blocks, 'signature'),
      status: resource.field(self._.blocks, 'status'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      uploaded_on: resource.field(self._.blocks, 'uploaded_on'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    custom_page_asset(name, block): {
      local resource = blockType.resource('cloudflare_custom_page_asset', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'description', true) +
        attribute(block, 'id') +
        attribute(block, 'last_updated') +
        attribute(block, 'name', true) +
        attribute(block, 'size_bytes') +
        attribute(block, 'url', true) +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      last_updated: resource.field(self._.blocks, 'last_updated'),
      name: resource.field(self._.blocks, 'name'),
      size_bytes: resource.field(self._.blocks, 'size_bytes'),
      url: resource.field(self._.blocks, 'url'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    custom_pages(name, block): {
      local resource = blockType.resource('cloudflare_custom_pages', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_on') +
        attribute(block, 'description') +
        attribute(block, 'id') +
        attribute(block, 'identifier', true) +
        attribute(block, 'modified_on') +
        attribute(block, 'preview_target') +
        attribute(block, 'required_tokens') +
        attribute(block, 'state', true) +
        attribute(block, 'url') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_on: resource.field(self._.blocks, 'created_on'),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      identifier: resource.field(self._.blocks, 'identifier'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      preview_target: resource.field(self._.blocks, 'preview_target'),
      required_tokens: resource.field(self._.blocks, 'required_tokens'),
      state: resource.field(self._.blocks, 'state'),
      url: resource.field(self._.blocks, 'url'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    custom_ssl(name, block): {
      local resource = blockType.resource('cloudflare_custom_ssl', name),
      _: resource._(
        block,
        attribute(block, 'bundle_method') +
        attribute(block, 'certificate', true) +
        attribute(block, 'custom_csr_id') +
        attribute(block, 'deploy') +
        attribute(block, 'expires_on') +
        attribute(block, 'geo_restrictions') +
        attribute(block, 'hosts') +
        attribute(block, 'id') +
        attribute(block, 'issuer') +
        attribute(block, 'keyless_server') +
        attribute(block, 'modified_on') +
        attribute(block, 'policy') +
        attribute(block, 'policy_restrictions') +
        attribute(block, 'priority') +
        attribute(block, 'private_key', true) +
        attribute(block, 'signature') +
        attribute(block, 'status') +
        attribute(block, 'type') +
        attribute(block, 'uploaded_on') +
        attribute(block, 'zone_id')
      ),
      bundle_method: resource.field(self._.blocks, 'bundle_method'),
      certificate: resource.field(self._.blocks, 'certificate'),
      custom_csr_id: resource.field(self._.blocks, 'custom_csr_id'),
      deploy: resource.field(self._.blocks, 'deploy'),
      expires_on: resource.field(self._.blocks, 'expires_on'),
      geo_restrictions: resource.field(self._.blocks, 'geo_restrictions'),
      hosts: resource.field(self._.blocks, 'hosts'),
      id: resource.field(self._.blocks, 'id'),
      issuer: resource.field(self._.blocks, 'issuer'),
      keyless_server: resource.field(self._.blocks, 'keyless_server'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      policy: resource.field(self._.blocks, 'policy'),
      policy_restrictions: resource.field(self._.blocks, 'policy_restrictions'),
      priority: resource.field(self._.blocks, 'priority'),
      private_key: resource.field(self._.blocks, 'private_key'),
      signature: resource.field(self._.blocks, 'signature'),
      status: resource.field(self._.blocks, 'status'),
      type: resource.field(self._.blocks, 'type'),
      uploaded_on: resource.field(self._.blocks, 'uploaded_on'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    d1_database(name, block): {
      local resource = blockType.resource('cloudflare_d1_database', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_at') +
        attribute(block, 'file_size') +
        attribute(block, 'id') +
        attribute(block, 'jurisdiction') +
        attribute(block, 'name', true) +
        attribute(block, 'num_tables') +
        attribute(block, 'primary_location_hint') +
        attribute(block, 'read_replication') +
        attribute(block, 'uuid') +
        attribute(block, 'version')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_at: resource.field(self._.blocks, 'created_at'),
      file_size: resource.field(self._.blocks, 'file_size'),
      id: resource.field(self._.blocks, 'id'),
      jurisdiction: resource.field(self._.blocks, 'jurisdiction'),
      name: resource.field(self._.blocks, 'name'),
      num_tables: resource.field(self._.blocks, 'num_tables'),
      primary_location_hint: resource.field(self._.blocks, 'primary_location_hint'),
      read_replication: resource.field(self._.blocks, 'read_replication'),
      uuid: resource.field(self._.blocks, 'uuid'),
      version: resource.field(self._.blocks, 'version'),
    },
    dns_firewall(name, block): {
      local resource = blockType.resource('cloudflare_dns_firewall', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'attack_mitigation') +
        attribute(block, 'deprecate_any_requests') +
        attribute(block, 'dns_firewall_ips') +
        attribute(block, 'ecs_fallback') +
        attribute(block, 'id') +
        attribute(block, 'maximum_cache_ttl') +
        attribute(block, 'minimum_cache_ttl') +
        attribute(block, 'modified_on') +
        attribute(block, 'name', true) +
        attribute(block, 'negative_cache_ttl') +
        attribute(block, 'ratelimit') +
        attribute(block, 'retries') +
        attribute(block, 'upstream_ips', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      attack_mitigation: resource.field(self._.blocks, 'attack_mitigation'),
      deprecate_any_requests: resource.field(self._.blocks, 'deprecate_any_requests'),
      dns_firewall_ips: resource.field(self._.blocks, 'dns_firewall_ips'),
      ecs_fallback: resource.field(self._.blocks, 'ecs_fallback'),
      id: resource.field(self._.blocks, 'id'),
      maximum_cache_ttl: resource.field(self._.blocks, 'maximum_cache_ttl'),
      minimum_cache_ttl: resource.field(self._.blocks, 'minimum_cache_ttl'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      negative_cache_ttl: resource.field(self._.blocks, 'negative_cache_ttl'),
      ratelimit: resource.field(self._.blocks, 'ratelimit'),
      retries: resource.field(self._.blocks, 'retries'),
      upstream_ips: resource.field(self._.blocks, 'upstream_ips'),
    },
    dns_record(name, block): {
      local resource = blockType.resource('cloudflare_dns_record', name),
      _: resource._(
        block,
        attribute(block, 'comment') +
        attribute(block, 'comment_modified_on') +
        attribute(block, 'content') +
        attribute(block, 'created_on') +
        attribute(block, 'data') +
        attribute(block, 'id') +
        attribute(block, 'meta') +
        attribute(block, 'modified_on') +
        attribute(block, 'name', true) +
        attribute(block, 'priority') +
        attribute(block, 'private_routing') +
        attribute(block, 'proxiable') +
        attribute(block, 'proxied') +
        attribute(block, 'settings') +
        attribute(block, 'tags') +
        attribute(block, 'tags_modified_on') +
        attribute(block, 'ttl', true) +
        attribute(block, 'type', true) +
        attribute(block, 'zone_id')
      ),
      comment: resource.field(self._.blocks, 'comment'),
      comment_modified_on: resource.field(self._.blocks, 'comment_modified_on'),
      content: resource.field(self._.blocks, 'content'),
      created_on: resource.field(self._.blocks, 'created_on'),
      data: resource.field(self._.blocks, 'data'),
      id: resource.field(self._.blocks, 'id'),
      meta: resource.field(self._.blocks, 'meta'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      priority: resource.field(self._.blocks, 'priority'),
      private_routing: resource.field(self._.blocks, 'private_routing'),
      proxiable: resource.field(self._.blocks, 'proxiable'),
      proxied: resource.field(self._.blocks, 'proxied'),
      settings: resource.field(self._.blocks, 'settings'),
      tags: resource.field(self._.blocks, 'tags'),
      tags_modified_on: resource.field(self._.blocks, 'tags_modified_on'),
      ttl: resource.field(self._.blocks, 'ttl'),
      type: resource.field(self._.blocks, 'type'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    dns_zone_transfers_acl(name, block): {
      local resource = blockType.resource('cloudflare_dns_zone_transfers_acl', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'id') +
        attribute(block, 'ip_range', true) +
        attribute(block, 'name', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      id: resource.field(self._.blocks, 'id'),
      ip_range: resource.field(self._.blocks, 'ip_range'),
      name: resource.field(self._.blocks, 'name'),
    },
    dns_zone_transfers_incoming(name, block): {
      local resource = blockType.resource('cloudflare_dns_zone_transfers_incoming', name),
      _: resource._(
        block,
        attribute(block, 'auto_refresh_seconds') +
        attribute(block, 'checked_time') +
        attribute(block, 'created_time') +
        attribute(block, 'id') +
        attribute(block, 'modified_time') +
        attribute(block, 'name', true) +
        attribute(block, 'peers', true) +
        attribute(block, 'soa_serial') +
        attribute(block, 'zone_id')
      ),
      auto_refresh_seconds: resource.field(self._.blocks, 'auto_refresh_seconds'),
      checked_time: resource.field(self._.blocks, 'checked_time'),
      created_time: resource.field(self._.blocks, 'created_time'),
      id: resource.field(self._.blocks, 'id'),
      modified_time: resource.field(self._.blocks, 'modified_time'),
      name: resource.field(self._.blocks, 'name'),
      peers: resource.field(self._.blocks, 'peers'),
      soa_serial: resource.field(self._.blocks, 'soa_serial'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    dns_zone_transfers_outgoing(name, block): {
      local resource = blockType.resource('cloudflare_dns_zone_transfers_outgoing', name),
      _: resource._(
        block,
        attribute(block, 'checked_time') +
        attribute(block, 'created_time') +
        attribute(block, 'id') +
        attribute(block, 'last_transferred_time') +
        attribute(block, 'name', true) +
        attribute(block, 'peers', true) +
        attribute(block, 'soa_serial') +
        attribute(block, 'zone_id')
      ),
      checked_time: resource.field(self._.blocks, 'checked_time'),
      created_time: resource.field(self._.blocks, 'created_time'),
      id: resource.field(self._.blocks, 'id'),
      last_transferred_time: resource.field(self._.blocks, 'last_transferred_time'),
      name: resource.field(self._.blocks, 'name'),
      peers: resource.field(self._.blocks, 'peers'),
      soa_serial: resource.field(self._.blocks, 'soa_serial'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    dns_zone_transfers_peer(name, block): {
      local resource = blockType.resource('cloudflare_dns_zone_transfers_peer', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'id') +
        attribute(block, 'ip') +
        attribute(block, 'ixfr_enable') +
        attribute(block, 'name', true) +
        attribute(block, 'port') +
        attribute(block, 'tsig_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      id: resource.field(self._.blocks, 'id'),
      ip: resource.field(self._.blocks, 'ip'),
      ixfr_enable: resource.field(self._.blocks, 'ixfr_enable'),
      name: resource.field(self._.blocks, 'name'),
      port: resource.field(self._.blocks, 'port'),
      tsig_id: resource.field(self._.blocks, 'tsig_id'),
    },
    dns_zone_transfers_tsig(name, block): {
      local resource = blockType.resource('cloudflare_dns_zone_transfers_tsig', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'algo', true) +
        attribute(block, 'id') +
        attribute(block, 'name', true) +
        attribute(block, 'secret', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      algo: resource.field(self._.blocks, 'algo'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      secret: resource.field(self._.blocks, 'secret'),
    },
    email_routing_address(name, block): {
      local resource = blockType.resource('cloudflare_email_routing_address', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created') +
        attribute(block, 'email', true) +
        attribute(block, 'id') +
        attribute(block, 'modified') +
        attribute(block, 'tag') +
        attribute(block, 'verified')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created: resource.field(self._.blocks, 'created'),
      email: resource.field(self._.blocks, 'email'),
      id: resource.field(self._.blocks, 'id'),
      modified: resource.field(self._.blocks, 'modified'),
      tag: resource.field(self._.blocks, 'tag'),
      verified: resource.field(self._.blocks, 'verified'),
    },
    email_routing_catch_all(name, block): {
      local resource = blockType.resource('cloudflare_email_routing_catch_all', name),
      _: resource._(
        block,
        attribute(block, 'actions', true) +
        attribute(block, 'enabled') +
        attribute(block, 'id') +
        attribute(block, 'matchers', true) +
        attribute(block, 'name') +
        attribute(block, 'tag') +
        attribute(block, 'zone_id', true)
      ),
      actions: resource.field(self._.blocks, 'actions'),
      enabled: resource.field(self._.blocks, 'enabled'),
      id: resource.field(self._.blocks, 'id'),
      matchers: resource.field(self._.blocks, 'matchers'),
      name: resource.field(self._.blocks, 'name'),
      tag: resource.field(self._.blocks, 'tag'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    email_routing_dns(name, block): {
      local resource = blockType.resource('cloudflare_email_routing_dns', name),
      _: resource._(
        block,
        attribute(block, 'created') +
        attribute(block, 'enabled') +
        attribute(block, 'errors') +
        attribute(block, 'id') +
        attribute(block, 'messages') +
        attribute(block, 'modified') +
        attribute(block, 'name') +
        attribute(block, 'result') +
        attribute(block, 'result_info') +
        attribute(block, 'skip_wizard') +
        attribute(block, 'status') +
        attribute(block, 'success') +
        attribute(block, 'tag') +
        attribute(block, 'zone_id', true)
      ),
      created: resource.field(self._.blocks, 'created'),
      enabled: resource.field(self._.blocks, 'enabled'),
      errors: resource.field(self._.blocks, 'errors'),
      id: resource.field(self._.blocks, 'id'),
      messages: resource.field(self._.blocks, 'messages'),
      modified: resource.field(self._.blocks, 'modified'),
      name: resource.field(self._.blocks, 'name'),
      result: resource.field(self._.blocks, 'result'),
      result_info: resource.field(self._.blocks, 'result_info'),
      skip_wizard: resource.field(self._.blocks, 'skip_wizard'),
      status: resource.field(self._.blocks, 'status'),
      success: resource.field(self._.blocks, 'success'),
      tag: resource.field(self._.blocks, 'tag'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    email_routing_rule(name, block): {
      local resource = blockType.resource('cloudflare_email_routing_rule', name),
      _: resource._(
        block,
        attribute(block, 'actions', true) +
        attribute(block, 'enabled') +
        attribute(block, 'id') +
        attribute(block, 'matchers', true) +
        attribute(block, 'name') +
        attribute(block, 'priority') +
        attribute(block, 'tag') +
        attribute(block, 'zone_id')
      ),
      actions: resource.field(self._.blocks, 'actions'),
      enabled: resource.field(self._.blocks, 'enabled'),
      id: resource.field(self._.blocks, 'id'),
      matchers: resource.field(self._.blocks, 'matchers'),
      name: resource.field(self._.blocks, 'name'),
      priority: resource.field(self._.blocks, 'priority'),
      tag: resource.field(self._.blocks, 'tag'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    email_routing_settings(name, block): {
      local resource = blockType.resource('cloudflare_email_routing_settings', name),
      _: resource._(
        block,
        attribute(block, 'created') +
        attribute(block, 'enabled') +
        attribute(block, 'id') +
        attribute(block, 'modified') +
        attribute(block, 'name') +
        attribute(block, 'skip_wizard') +
        attribute(block, 'status') +
        attribute(block, 'tag') +
        attribute(block, 'zone_id')
      ),
      created: resource.field(self._.blocks, 'created'),
      enabled: resource.field(self._.blocks, 'enabled'),
      id: resource.field(self._.blocks, 'id'),
      modified: resource.field(self._.blocks, 'modified'),
      name: resource.field(self._.blocks, 'name'),
      skip_wizard: resource.field(self._.blocks, 'skip_wizard'),
      status: resource.field(self._.blocks, 'status'),
      tag: resource.field(self._.blocks, 'tag'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    email_security_block_sender(name, block): {
      local resource = blockType.resource('cloudflare_email_security_block_sender', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'comments') +
        attribute(block, 'created_at') +
        attribute(block, 'id') +
        attribute(block, 'is_regex', true) +
        attribute(block, 'last_modified') +
        attribute(block, 'pattern', true) +
        attribute(block, 'pattern_type', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      comments: resource.field(self._.blocks, 'comments'),
      created_at: resource.field(self._.blocks, 'created_at'),
      id: resource.field(self._.blocks, 'id'),
      is_regex: resource.field(self._.blocks, 'is_regex'),
      last_modified: resource.field(self._.blocks, 'last_modified'),
      pattern: resource.field(self._.blocks, 'pattern'),
      pattern_type: resource.field(self._.blocks, 'pattern_type'),
    },
    email_security_impersonation_registry(name, block): {
      local resource = blockType.resource('cloudflare_email_security_impersonation_registry', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'comments') +
        attribute(block, 'created_at') +
        attribute(block, 'directory_id') +
        attribute(block, 'directory_node_id') +
        attribute(block, 'email', true) +
        attribute(block, 'external_directory_node_id') +
        attribute(block, 'id') +
        attribute(block, 'is_email_regex', true) +
        attribute(block, 'last_modified') +
        attribute(block, 'name', true) +
        attribute(block, 'provenance')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      comments: resource.field(self._.blocks, 'comments'),
      created_at: resource.field(self._.blocks, 'created_at'),
      directory_id: resource.field(self._.blocks, 'directory_id'),
      directory_node_id: resource.field(self._.blocks, 'directory_node_id'),
      email: resource.field(self._.blocks, 'email'),
      external_directory_node_id: resource.field(self._.blocks, 'external_directory_node_id'),
      id: resource.field(self._.blocks, 'id'),
      is_email_regex: resource.field(self._.blocks, 'is_email_regex'),
      last_modified: resource.field(self._.blocks, 'last_modified'),
      name: resource.field(self._.blocks, 'name'),
      provenance: resource.field(self._.blocks, 'provenance'),
    },
    email_security_trusted_domains(name, block): {
      local resource = blockType.resource('cloudflare_email_security_trusted_domains', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'body') +
        attribute(block, 'comments') +
        attribute(block, 'created_at') +
        attribute(block, 'id') +
        attribute(block, 'is_recent') +
        attribute(block, 'is_regex') +
        attribute(block, 'is_similarity') +
        attribute(block, 'last_modified') +
        attribute(block, 'pattern')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      body: resource.field(self._.blocks, 'body'),
      comments: resource.field(self._.blocks, 'comments'),
      created_at: resource.field(self._.blocks, 'created_at'),
      id: resource.field(self._.blocks, 'id'),
      is_recent: resource.field(self._.blocks, 'is_recent'),
      is_regex: resource.field(self._.blocks, 'is_regex'),
      is_similarity: resource.field(self._.blocks, 'is_similarity'),
      last_modified: resource.field(self._.blocks, 'last_modified'),
      pattern: resource.field(self._.blocks, 'pattern'),
    },
    filter(name, block): {
      local resource = blockType.resource('cloudflare_filter', name),
      _: resource._(
        block,
        attribute(block, 'body', true) +
        attribute(block, 'description') +
        attribute(block, 'expression') +
        attribute(block, 'id') +
        attribute(block, 'paused') +
        attribute(block, 'ref') +
        attribute(block, 'zone_id')
      ),
      body: resource.field(self._.blocks, 'body'),
      description: resource.field(self._.blocks, 'description'),
      expression: resource.field(self._.blocks, 'expression'),
      id: resource.field(self._.blocks, 'id'),
      paused: resource.field(self._.blocks, 'paused'),
      ref: resource.field(self._.blocks, 'ref'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    firewall_rule(name, block): {
      local resource = blockType.resource('cloudflare_firewall_rule', name),
      _: resource._(
        block,
        attribute(block, 'action', true) +
        attribute(block, 'description') +
        attribute(block, 'filter', true) +
        attribute(block, 'id') +
        attribute(block, 'paused') +
        attribute(block, 'priority') +
        attribute(block, 'products') +
        attribute(block, 'ref') +
        attribute(block, 'zone_id')
      ),
      action: resource.field(self._.blocks, 'action'),
      description: resource.field(self._.blocks, 'description'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      paused: resource.field(self._.blocks, 'paused'),
      priority: resource.field(self._.blocks, 'priority'),
      products: resource.field(self._.blocks, 'products'),
      ref: resource.field(self._.blocks, 'ref'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    healthcheck(name, block): {
      local resource = blockType.resource('cloudflare_healthcheck', name),
      _: resource._(
        block,
        attribute(block, 'address', true) +
        attribute(block, 'check_regions') +
        attribute(block, 'consecutive_fails') +
        attribute(block, 'consecutive_successes') +
        attribute(block, 'created_on') +
        attribute(block, 'description') +
        attribute(block, 'failure_reason') +
        attribute(block, 'http_config') +
        attribute(block, 'id') +
        attribute(block, 'interval') +
        attribute(block, 'modified_on') +
        attribute(block, 'name', true) +
        attribute(block, 'retries') +
        attribute(block, 'status') +
        attribute(block, 'suspended') +
        attribute(block, 'tcp_config') +
        attribute(block, 'timeout') +
        attribute(block, 'type') +
        attribute(block, 'zone_id')
      ),
      address: resource.field(self._.blocks, 'address'),
      check_regions: resource.field(self._.blocks, 'check_regions'),
      consecutive_fails: resource.field(self._.blocks, 'consecutive_fails'),
      consecutive_successes: resource.field(self._.blocks, 'consecutive_successes'),
      created_on: resource.field(self._.blocks, 'created_on'),
      description: resource.field(self._.blocks, 'description'),
      failure_reason: resource.field(self._.blocks, 'failure_reason'),
      http_config: resource.field(self._.blocks, 'http_config'),
      id: resource.field(self._.blocks, 'id'),
      interval: resource.field(self._.blocks, 'interval'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      retries: resource.field(self._.blocks, 'retries'),
      status: resource.field(self._.blocks, 'status'),
      suspended: resource.field(self._.blocks, 'suspended'),
      tcp_config: resource.field(self._.blocks, 'tcp_config'),
      timeout: resource.field(self._.blocks, 'timeout'),
      type: resource.field(self._.blocks, 'type'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    hostname_tls_setting(name, block): {
      local resource = blockType.resource('cloudflare_hostname_tls_setting', name),
      _: resource._(
        block,
        attribute(block, 'created_at') +
        attribute(block, 'hostname', true) +
        attribute(block, 'id') +
        attribute(block, 'setting_id', true) +
        attribute(block, 'status') +
        attribute(block, 'updated_at') +
        attribute(block, 'value', true) +
        attribute(block, 'zone_id')
      ),
      created_at: resource.field(self._.blocks, 'created_at'),
      hostname: resource.field(self._.blocks, 'hostname'),
      id: resource.field(self._.blocks, 'id'),
      setting_id: resource.field(self._.blocks, 'setting_id'),
      status: resource.field(self._.blocks, 'status'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      value: resource.field(self._.blocks, 'value'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    hyperdrive_config(name, block): {
      local resource = blockType.resource('cloudflare_hyperdrive_config', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'caching') +
        attribute(block, 'created_on') +
        attribute(block, 'id') +
        attribute(block, 'modified_on') +
        attribute(block, 'mtls') +
        attribute(block, 'name', true) +
        attribute(block, 'origin', true) +
        attribute(block, 'origin_connection_limit')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      caching: resource.field(self._.blocks, 'caching'),
      created_on: resource.field(self._.blocks, 'created_on'),
      id: resource.field(self._.blocks, 'id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      mtls: resource.field(self._.blocks, 'mtls'),
      name: resource.field(self._.blocks, 'name'),
      origin: resource.field(self._.blocks, 'origin'),
      origin_connection_limit: resource.field(self._.blocks, 'origin_connection_limit'),
    },
    image(name, block): {
      local resource = blockType.resource('cloudflare_image', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'creator') +
        attribute(block, 'file') +
        attribute(block, 'filename') +
        attribute(block, 'id', true) +
        attribute(block, 'meta') +
        attribute(block, 'metadata') +
        attribute(block, 'require_signed_urls') +
        attribute(block, 'uploaded') +
        attribute(block, 'url') +
        attribute(block, 'variants')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      creator: resource.field(self._.blocks, 'creator'),
      file: resource.field(self._.blocks, 'file'),
      filename: resource.field(self._.blocks, 'filename'),
      id: resource.field(self._.blocks, 'id'),
      meta: resource.field(self._.blocks, 'meta'),
      metadata: resource.field(self._.blocks, 'metadata'),
      require_signed_urls: resource.field(self._.blocks, 'require_signed_urls'),
      uploaded: resource.field(self._.blocks, 'uploaded'),
      url: resource.field(self._.blocks, 'url'),
      variants: resource.field(self._.blocks, 'variants'),
    },
    image_variant(name, block): {
      local resource = blockType.resource('cloudflare_image_variant', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'id', true) +
        attribute(block, 'never_require_signed_urls') +
        attribute(block, 'options', true) +
        attribute(block, 'variant')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      id: resource.field(self._.blocks, 'id'),
      never_require_signed_urls: resource.field(self._.blocks, 'never_require_signed_urls'),
      options: resource.field(self._.blocks, 'options'),
      variant: resource.field(self._.blocks, 'variant'),
    },
    keyless_certificate(name, block): {
      local resource = blockType.resource('cloudflare_keyless_certificate', name),
      _: resource._(
        block,
        attribute(block, 'bundle_method') +
        attribute(block, 'certificate', true) +
        attribute(block, 'created_on') +
        attribute(block, 'enabled') +
        attribute(block, 'host', true) +
        attribute(block, 'id') +
        attribute(block, 'modified_on') +
        attribute(block, 'name') +
        attribute(block, 'permissions') +
        attribute(block, 'port') +
        attribute(block, 'status') +
        attribute(block, 'tunnel') +
        attribute(block, 'zone_id')
      ),
      bundle_method: resource.field(self._.blocks, 'bundle_method'),
      certificate: resource.field(self._.blocks, 'certificate'),
      created_on: resource.field(self._.blocks, 'created_on'),
      enabled: resource.field(self._.blocks, 'enabled'),
      host: resource.field(self._.blocks, 'host'),
      id: resource.field(self._.blocks, 'id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      permissions: resource.field(self._.blocks, 'permissions'),
      port: resource.field(self._.blocks, 'port'),
      status: resource.field(self._.blocks, 'status'),
      tunnel: resource.field(self._.blocks, 'tunnel'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    leaked_credential_check(name, block): {
      local resource = blockType.resource('cloudflare_leaked_credential_check', name),
      _: resource._(
        block,
        attribute(block, 'enabled') +
        attribute(block, 'zone_id')
      ),
      enabled: resource.field(self._.blocks, 'enabled'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    leaked_credential_check_rule(name, block): {
      local resource = blockType.resource('cloudflare_leaked_credential_check_rule', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'password') +
        attribute(block, 'username') +
        attribute(block, 'zone_id')
      ),
      id: resource.field(self._.blocks, 'id'),
      password: resource.field(self._.blocks, 'password'),
      username: resource.field(self._.blocks, 'username'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    list(name, block): {
      local resource = blockType.resource('cloudflare_list', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_on') +
        attribute(block, 'description') +
        attribute(block, 'id') +
        attribute(block, 'items') +
        attribute(block, 'kind', true) +
        attribute(block, 'modified_on') +
        attribute(block, 'name', true) +
        attribute(block, 'num_items') +
        attribute(block, 'num_referencing_filters')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_on: resource.field(self._.blocks, 'created_on'),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      items: resource.field(self._.blocks, 'items'),
      kind: resource.field(self._.blocks, 'kind'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      num_items: resource.field(self._.blocks, 'num_items'),
      num_referencing_filters: resource.field(self._.blocks, 'num_referencing_filters'),
    },
    list_item(name, block): {
      local resource = blockType.resource('cloudflare_list_item', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'asn') +
        attribute(block, 'comment') +
        attribute(block, 'created_on') +
        attribute(block, 'hostname') +
        attribute(block, 'id') +
        attribute(block, 'ip') +
        attribute(block, 'list_id', true) +
        attribute(block, 'modified_on') +
        attribute(block, 'operation_id') +
        attribute(block, 'redirect')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      asn: resource.field(self._.blocks, 'asn'),
      comment: resource.field(self._.blocks, 'comment'),
      created_on: resource.field(self._.blocks, 'created_on'),
      hostname: resource.field(self._.blocks, 'hostname'),
      id: resource.field(self._.blocks, 'id'),
      ip: resource.field(self._.blocks, 'ip'),
      list_id: resource.field(self._.blocks, 'list_id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      operation_id: resource.field(self._.blocks, 'operation_id'),
      redirect: resource.field(self._.blocks, 'redirect'),
    },
    load_balancer(name, block): {
      local resource = blockType.resource('cloudflare_load_balancer', name),
      _: resource._(
        block,
        attribute(block, 'adaptive_routing') +
        attribute(block, 'country_pools') +
        attribute(block, 'created_on') +
        attribute(block, 'default_pools', true) +
        attribute(block, 'description') +
        attribute(block, 'enabled') +
        attribute(block, 'fallback_pool', true) +
        attribute(block, 'id') +
        attribute(block, 'location_strategy') +
        attribute(block, 'modified_on') +
        attribute(block, 'name', true) +
        attribute(block, 'networks') +
        attribute(block, 'pop_pools') +
        attribute(block, 'proxied') +
        attribute(block, 'random_steering') +
        attribute(block, 'region_pools') +
        attribute(block, 'rules') +
        attribute(block, 'session_affinity') +
        attribute(block, 'session_affinity_attributes') +
        attribute(block, 'session_affinity_ttl') +
        attribute(block, 'steering_policy') +
        attribute(block, 'ttl') +
        attribute(block, 'zone_id') +
        attribute(block, 'zone_name')
      ),
      adaptive_routing: resource.field(self._.blocks, 'adaptive_routing'),
      country_pools: resource.field(self._.blocks, 'country_pools'),
      created_on: resource.field(self._.blocks, 'created_on'),
      default_pools: resource.field(self._.blocks, 'default_pools'),
      description: resource.field(self._.blocks, 'description'),
      enabled: resource.field(self._.blocks, 'enabled'),
      fallback_pool: resource.field(self._.blocks, 'fallback_pool'),
      id: resource.field(self._.blocks, 'id'),
      location_strategy: resource.field(self._.blocks, 'location_strategy'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      networks: resource.field(self._.blocks, 'networks'),
      pop_pools: resource.field(self._.blocks, 'pop_pools'),
      proxied: resource.field(self._.blocks, 'proxied'),
      random_steering: resource.field(self._.blocks, 'random_steering'),
      region_pools: resource.field(self._.blocks, 'region_pools'),
      rules: resource.field(self._.blocks, 'rules'),
      session_affinity: resource.field(self._.blocks, 'session_affinity'),
      session_affinity_attributes: resource.field(self._.blocks, 'session_affinity_attributes'),
      session_affinity_ttl: resource.field(self._.blocks, 'session_affinity_ttl'),
      steering_policy: resource.field(self._.blocks, 'steering_policy'),
      ttl: resource.field(self._.blocks, 'ttl'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
      zone_name: resource.field(self._.blocks, 'zone_name'),
    },
    load_balancer_monitor(name, block): {
      local resource = blockType.resource('cloudflare_load_balancer_monitor', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'allow_insecure') +
        attribute(block, 'consecutive_down') +
        attribute(block, 'consecutive_up') +
        attribute(block, 'created_on') +
        attribute(block, 'description') +
        attribute(block, 'expected_body') +
        attribute(block, 'expected_codes') +
        attribute(block, 'follow_redirects') +
        attribute(block, 'header') +
        attribute(block, 'id') +
        attribute(block, 'interval') +
        attribute(block, 'method') +
        attribute(block, 'modified_on') +
        attribute(block, 'path') +
        attribute(block, 'port') +
        attribute(block, 'probe_zone') +
        attribute(block, 'retries') +
        attribute(block, 'timeout') +
        attribute(block, 'type')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      allow_insecure: resource.field(self._.blocks, 'allow_insecure'),
      consecutive_down: resource.field(self._.blocks, 'consecutive_down'),
      consecutive_up: resource.field(self._.blocks, 'consecutive_up'),
      created_on: resource.field(self._.blocks, 'created_on'),
      description: resource.field(self._.blocks, 'description'),
      expected_body: resource.field(self._.blocks, 'expected_body'),
      expected_codes: resource.field(self._.blocks, 'expected_codes'),
      follow_redirects: resource.field(self._.blocks, 'follow_redirects'),
      header: resource.field(self._.blocks, 'header'),
      id: resource.field(self._.blocks, 'id'),
      interval: resource.field(self._.blocks, 'interval'),
      method: resource.field(self._.blocks, 'method'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      path: resource.field(self._.blocks, 'path'),
      port: resource.field(self._.blocks, 'port'),
      probe_zone: resource.field(self._.blocks, 'probe_zone'),
      retries: resource.field(self._.blocks, 'retries'),
      timeout: resource.field(self._.blocks, 'timeout'),
      type: resource.field(self._.blocks, 'type'),
    },
    load_balancer_pool(name, block): {
      local resource = blockType.resource('cloudflare_load_balancer_pool', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'check_regions') +
        attribute(block, 'created_on') +
        attribute(block, 'description') +
        attribute(block, 'disabled_at') +
        attribute(block, 'enabled') +
        attribute(block, 'id') +
        attribute(block, 'latitude') +
        attribute(block, 'load_shedding') +
        attribute(block, 'longitude') +
        attribute(block, 'minimum_origins') +
        attribute(block, 'modified_on') +
        attribute(block, 'monitor') +
        attribute(block, 'monitor_group') +
        attribute(block, 'name', true) +
        attribute(block, 'networks') +
        attribute(block, 'notification_email') +
        attribute(block, 'notification_filter') +
        attribute(block, 'origin_steering') +
        attribute(block, 'origins', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      check_regions: resource.field(self._.blocks, 'check_regions'),
      created_on: resource.field(self._.blocks, 'created_on'),
      description: resource.field(self._.blocks, 'description'),
      disabled_at: resource.field(self._.blocks, 'disabled_at'),
      enabled: resource.field(self._.blocks, 'enabled'),
      id: resource.field(self._.blocks, 'id'),
      latitude: resource.field(self._.blocks, 'latitude'),
      load_shedding: resource.field(self._.blocks, 'load_shedding'),
      longitude: resource.field(self._.blocks, 'longitude'),
      minimum_origins: resource.field(self._.blocks, 'minimum_origins'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      monitor: resource.field(self._.blocks, 'monitor'),
      monitor_group: resource.field(self._.blocks, 'monitor_group'),
      name: resource.field(self._.blocks, 'name'),
      networks: resource.field(self._.blocks, 'networks'),
      notification_email: resource.field(self._.blocks, 'notification_email'),
      notification_filter: resource.field(self._.blocks, 'notification_filter'),
      origin_steering: resource.field(self._.blocks, 'origin_steering'),
      origins: resource.field(self._.blocks, 'origins'),
    },
    logpull_retention(name, block): {
      local resource = blockType.resource('cloudflare_logpull_retention', name),
      _: resource._(
        block,
        attribute(block, 'flag') +
        attribute(block, 'id') +
        attribute(block, 'zone_id', true)
      ),
      flag: resource.field(self._.blocks, 'flag'),
      id: resource.field(self._.blocks, 'id'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    logpush_job(name, block): {
      local resource = blockType.resource('cloudflare_logpush_job', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'dataset') +
        attribute(block, 'destination_conf', true) +
        attribute(block, 'enabled') +
        attribute(block, 'error_message') +
        attribute(block, 'filter') +
        attribute(block, 'frequency') +
        attribute(block, 'id') +
        attribute(block, 'kind') +
        attribute(block, 'last_complete') +
        attribute(block, 'last_error') +
        attribute(block, 'logpull_options') +
        attribute(block, 'max_upload_bytes') +
        attribute(block, 'max_upload_interval_seconds') +
        attribute(block, 'max_upload_records') +
        attribute(block, 'name') +
        attribute(block, 'output_options') +
        attribute(block, 'ownership_challenge') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      dataset: resource.field(self._.blocks, 'dataset'),
      destination_conf: resource.field(self._.blocks, 'destination_conf'),
      enabled: resource.field(self._.blocks, 'enabled'),
      error_message: resource.field(self._.blocks, 'error_message'),
      filter: resource.field(self._.blocks, 'filter'),
      frequency: resource.field(self._.blocks, 'frequency'),
      id: resource.field(self._.blocks, 'id'),
      kind: resource.field(self._.blocks, 'kind'),
      last_complete: resource.field(self._.blocks, 'last_complete'),
      last_error: resource.field(self._.blocks, 'last_error'),
      logpull_options: resource.field(self._.blocks, 'logpull_options'),
      max_upload_bytes: resource.field(self._.blocks, 'max_upload_bytes'),
      max_upload_interval_seconds: resource.field(self._.blocks, 'max_upload_interval_seconds'),
      max_upload_records: resource.field(self._.blocks, 'max_upload_records'),
      name: resource.field(self._.blocks, 'name'),
      output_options: resource.field(self._.blocks, 'output_options'),
      ownership_challenge: resource.field(self._.blocks, 'ownership_challenge'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    logpush_ownership_challenge(name, block): {
      local resource = blockType.resource('cloudflare_logpush_ownership_challenge', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'destination_conf', true) +
        attribute(block, 'filename') +
        attribute(block, 'message') +
        attribute(block, 'valid') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      destination_conf: resource.field(self._.blocks, 'destination_conf'),
      filename: resource.field(self._.blocks, 'filename'),
      message: resource.field(self._.blocks, 'message'),
      valid: resource.field(self._.blocks, 'valid'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    magic_network_monitoring_configuration(name, block): {
      local resource = blockType.resource('cloudflare_magic_network_monitoring_configuration', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'default_sampling') +
        attribute(block, 'name', true) +
        attribute(block, 'router_ips') +
        attribute(block, 'warp_devices')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      default_sampling: resource.field(self._.blocks, 'default_sampling'),
      name: resource.field(self._.blocks, 'name'),
      router_ips: resource.field(self._.blocks, 'router_ips'),
      warp_devices: resource.field(self._.blocks, 'warp_devices'),
    },
    magic_network_monitoring_rule(name, block): {
      local resource = blockType.resource('cloudflare_magic_network_monitoring_rule', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'automatic_advertisement', true) +
        attribute(block, 'bandwidth_threshold') +
        attribute(block, 'duration') +
        attribute(block, 'id') +
        attribute(block, 'name', true) +
        attribute(block, 'packet_threshold') +
        attribute(block, 'prefix_match') +
        attribute(block, 'prefixes', true) +
        attribute(block, 'type', true) +
        attribute(block, 'zscore_sensitivity') +
        attribute(block, 'zscore_target')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      automatic_advertisement: resource.field(self._.blocks, 'automatic_advertisement'),
      bandwidth_threshold: resource.field(self._.blocks, 'bandwidth_threshold'),
      duration: resource.field(self._.blocks, 'duration'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      packet_threshold: resource.field(self._.blocks, 'packet_threshold'),
      prefix_match: resource.field(self._.blocks, 'prefix_match'),
      prefixes: resource.field(self._.blocks, 'prefixes'),
      type: resource.field(self._.blocks, 'type'),
      zscore_sensitivity: resource.field(self._.blocks, 'zscore_sensitivity'),
      zscore_target: resource.field(self._.blocks, 'zscore_target'),
    },
    magic_transit_connector(name, block): {
      local resource = blockType.resource('cloudflare_magic_transit_connector', name),
      _: resource._(
        block,
        attribute(block, 'account_id', true) +
        attribute(block, 'activated') +
        attribute(block, 'device', true) +
        attribute(block, 'id') +
        attribute(block, 'interrupt_window_duration_hours') +
        attribute(block, 'interrupt_window_hour_of_day') +
        attribute(block, 'license_key') +
        attribute(block, 'notes') +
        attribute(block, 'timezone')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      activated: resource.field(self._.blocks, 'activated'),
      device: resource.field(self._.blocks, 'device'),
      id: resource.field(self._.blocks, 'id'),
      interrupt_window_duration_hours: resource.field(self._.blocks, 'interrupt_window_duration_hours'),
      interrupt_window_hour_of_day: resource.field(self._.blocks, 'interrupt_window_hour_of_day'),
      license_key: resource.field(self._.blocks, 'license_key'),
      notes: resource.field(self._.blocks, 'notes'),
      timezone: resource.field(self._.blocks, 'timezone'),
    },
    magic_transit_site(name, block): {
      local resource = blockType.resource('cloudflare_magic_transit_site', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'connector_id') +
        attribute(block, 'description') +
        attribute(block, 'ha_mode') +
        attribute(block, 'id') +
        attribute(block, 'location') +
        attribute(block, 'name', true) +
        attribute(block, 'secondary_connector_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      connector_id: resource.field(self._.blocks, 'connector_id'),
      description: resource.field(self._.blocks, 'description'),
      ha_mode: resource.field(self._.blocks, 'ha_mode'),
      id: resource.field(self._.blocks, 'id'),
      location: resource.field(self._.blocks, 'location'),
      name: resource.field(self._.blocks, 'name'),
      secondary_connector_id: resource.field(self._.blocks, 'secondary_connector_id'),
    },
    magic_transit_site_acl(name, block): {
      local resource = blockType.resource('cloudflare_magic_transit_site_acl', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'description') +
        attribute(block, 'forward_locally') +
        attribute(block, 'id') +
        attribute(block, 'lan_1', true) +
        attribute(block, 'lan_2', true) +
        attribute(block, 'name', true) +
        attribute(block, 'protocols') +
        attribute(block, 'site_id', true) +
        attribute(block, 'unidirectional')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      description: resource.field(self._.blocks, 'description'),
      forward_locally: resource.field(self._.blocks, 'forward_locally'),
      id: resource.field(self._.blocks, 'id'),
      lan_1: resource.field(self._.blocks, 'lan_1'),
      lan_2: resource.field(self._.blocks, 'lan_2'),
      name: resource.field(self._.blocks, 'name'),
      protocols: resource.field(self._.blocks, 'protocols'),
      site_id: resource.field(self._.blocks, 'site_id'),
      unidirectional: resource.field(self._.blocks, 'unidirectional'),
    },
    magic_transit_site_lan(name, block): {
      local resource = blockType.resource('cloudflare_magic_transit_site_lan', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'bond_id') +
        attribute(block, 'ha_link') +
        attribute(block, 'id') +
        attribute(block, 'is_breakout') +
        attribute(block, 'is_prioritized') +
        attribute(block, 'name') +
        attribute(block, 'nat') +
        attribute(block, 'physport') +
        attribute(block, 'routed_subnets') +
        attribute(block, 'site_id', true) +
        attribute(block, 'static_addressing') +
        attribute(block, 'vlan_tag')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      bond_id: resource.field(self._.blocks, 'bond_id'),
      ha_link: resource.field(self._.blocks, 'ha_link'),
      id: resource.field(self._.blocks, 'id'),
      is_breakout: resource.field(self._.blocks, 'is_breakout'),
      is_prioritized: resource.field(self._.blocks, 'is_prioritized'),
      name: resource.field(self._.blocks, 'name'),
      nat: resource.field(self._.blocks, 'nat'),
      physport: resource.field(self._.blocks, 'physport'),
      routed_subnets: resource.field(self._.blocks, 'routed_subnets'),
      site_id: resource.field(self._.blocks, 'site_id'),
      static_addressing: resource.field(self._.blocks, 'static_addressing'),
      vlan_tag: resource.field(self._.blocks, 'vlan_tag'),
    },
    magic_transit_site_wan(name, block): {
      local resource = blockType.resource('cloudflare_magic_transit_site_wan', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'health_check_rate') +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'physport', true) +
        attribute(block, 'priority') +
        attribute(block, 'site_id', true) +
        attribute(block, 'static_addressing') +
        attribute(block, 'vlan_tag')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      health_check_rate: resource.field(self._.blocks, 'health_check_rate'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      physport: resource.field(self._.blocks, 'physport'),
      priority: resource.field(self._.blocks, 'priority'),
      site_id: resource.field(self._.blocks, 'site_id'),
      static_addressing: resource.field(self._.blocks, 'static_addressing'),
      vlan_tag: resource.field(self._.blocks, 'vlan_tag'),
    },
    magic_wan_gre_tunnel(name, block): {
      local resource = blockType.resource('cloudflare_magic_wan_gre_tunnel', name),
      _: resource._(
        block,
        attribute(block, 'account_id', true) +
        attribute(block, 'automatic_return_routing') +
        attribute(block, 'bgp') +
        attribute(block, 'bgp_status') +
        attribute(block, 'cloudflare_gre_endpoint', true) +
        attribute(block, 'created_on') +
        attribute(block, 'customer_gre_endpoint', true) +
        attribute(block, 'description') +
        attribute(block, 'health_check') +
        attribute(block, 'id') +
        attribute(block, 'interface_address', true) +
        attribute(block, 'interface_address6') +
        attribute(block, 'modified_on') +
        attribute(block, 'mtu') +
        attribute(block, 'name', true) +
        attribute(block, 'ttl')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      automatic_return_routing: resource.field(self._.blocks, 'automatic_return_routing'),
      bgp: resource.field(self._.blocks, 'bgp'),
      bgp_status: resource.field(self._.blocks, 'bgp_status'),
      cloudflare_gre_endpoint: resource.field(self._.blocks, 'cloudflare_gre_endpoint'),
      created_on: resource.field(self._.blocks, 'created_on'),
      customer_gre_endpoint: resource.field(self._.blocks, 'customer_gre_endpoint'),
      description: resource.field(self._.blocks, 'description'),
      health_check: resource.field(self._.blocks, 'health_check'),
      id: resource.field(self._.blocks, 'id'),
      interface_address: resource.field(self._.blocks, 'interface_address'),
      interface_address6: resource.field(self._.blocks, 'interface_address6'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      mtu: resource.field(self._.blocks, 'mtu'),
      name: resource.field(self._.blocks, 'name'),
      ttl: resource.field(self._.blocks, 'ttl'),
    },
    magic_wan_ipsec_tunnel(name, block): {
      local resource = blockType.resource('cloudflare_magic_wan_ipsec_tunnel', name),
      _: resource._(
        block,
        attribute(block, 'account_id', true) +
        attribute(block, 'allow_null_cipher') +
        attribute(block, 'automatic_return_routing') +
        attribute(block, 'bgp') +
        attribute(block, 'bgp_status') +
        attribute(block, 'cloudflare_endpoint', true) +
        attribute(block, 'created_on') +
        attribute(block, 'custom_remote_identities') +
        attribute(block, 'customer_endpoint') +
        attribute(block, 'description') +
        attribute(block, 'health_check') +
        attribute(block, 'id') +
        attribute(block, 'interface_address', true) +
        attribute(block, 'interface_address6') +
        attribute(block, 'modified_on') +
        attribute(block, 'name', true) +
        attribute(block, 'psk') +
        attribute(block, 'psk_metadata') +
        attribute(block, 'replay_protection')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      allow_null_cipher: resource.field(self._.blocks, 'allow_null_cipher'),
      automatic_return_routing: resource.field(self._.blocks, 'automatic_return_routing'),
      bgp: resource.field(self._.blocks, 'bgp'),
      bgp_status: resource.field(self._.blocks, 'bgp_status'),
      cloudflare_endpoint: resource.field(self._.blocks, 'cloudflare_endpoint'),
      created_on: resource.field(self._.blocks, 'created_on'),
      custom_remote_identities: resource.field(self._.blocks, 'custom_remote_identities'),
      customer_endpoint: resource.field(self._.blocks, 'customer_endpoint'),
      description: resource.field(self._.blocks, 'description'),
      health_check: resource.field(self._.blocks, 'health_check'),
      id: resource.field(self._.blocks, 'id'),
      interface_address: resource.field(self._.blocks, 'interface_address'),
      interface_address6: resource.field(self._.blocks, 'interface_address6'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      psk: resource.field(self._.blocks, 'psk'),
      psk_metadata: resource.field(self._.blocks, 'psk_metadata'),
      replay_protection: resource.field(self._.blocks, 'replay_protection'),
    },
    magic_wan_static_route(name, block): {
      local resource = blockType.resource('cloudflare_magic_wan_static_route', name),
      _: resource._(
        block,
        attribute(block, 'account_id', true) +
        attribute(block, 'created_on') +
        attribute(block, 'description') +
        attribute(block, 'id') +
        attribute(block, 'modified_on') +
        attribute(block, 'nexthop', true) +
        attribute(block, 'prefix', true) +
        attribute(block, 'priority', true) +
        attribute(block, 'scope') +
        attribute(block, 'weight')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_on: resource.field(self._.blocks, 'created_on'),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      nexthop: resource.field(self._.blocks, 'nexthop'),
      prefix: resource.field(self._.blocks, 'prefix'),
      priority: resource.field(self._.blocks, 'priority'),
      scope: resource.field(self._.blocks, 'scope'),
      weight: resource.field(self._.blocks, 'weight'),
    },
    managed_transforms(name, block): {
      local resource = blockType.resource('cloudflare_managed_transforms', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'managed_request_headers', true) +
        attribute(block, 'managed_response_headers', true) +
        attribute(block, 'zone_id', true)
      ),
      id: resource.field(self._.blocks, 'id'),
      managed_request_headers: resource.field(self._.blocks, 'managed_request_headers'),
      managed_response_headers: resource.field(self._.blocks, 'managed_response_headers'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    mtls_certificate(name, block): {
      local resource = blockType.resource('cloudflare_mtls_certificate', name),
      _: resource._(
        block,
        attribute(block, 'account_id', true) +
        attribute(block, 'ca', true) +
        attribute(block, 'certificates', true) +
        attribute(block, 'expires_on') +
        attribute(block, 'id') +
        attribute(block, 'issuer') +
        attribute(block, 'name') +
        attribute(block, 'private_key') +
        attribute(block, 'serial_number') +
        attribute(block, 'signature') +
        attribute(block, 'updated_at') +
        attribute(block, 'uploaded_on')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      ca: resource.field(self._.blocks, 'ca'),
      certificates: resource.field(self._.blocks, 'certificates'),
      expires_on: resource.field(self._.blocks, 'expires_on'),
      id: resource.field(self._.blocks, 'id'),
      issuer: resource.field(self._.blocks, 'issuer'),
      name: resource.field(self._.blocks, 'name'),
      private_key: resource.field(self._.blocks, 'private_key'),
      serial_number: resource.field(self._.blocks, 'serial_number'),
      signature: resource.field(self._.blocks, 'signature'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      uploaded_on: resource.field(self._.blocks, 'uploaded_on'),
    },
    notification_policy(name, block): {
      local resource = blockType.resource('cloudflare_notification_policy', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'alert_interval') +
        attribute(block, 'alert_type', true) +
        attribute(block, 'created') +
        attribute(block, 'description') +
        attribute(block, 'enabled') +
        attribute(block, 'filters') +
        attribute(block, 'id') +
        attribute(block, 'mechanisms', true) +
        attribute(block, 'modified') +
        attribute(block, 'name', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      alert_interval: resource.field(self._.blocks, 'alert_interval'),
      alert_type: resource.field(self._.blocks, 'alert_type'),
      created: resource.field(self._.blocks, 'created'),
      description: resource.field(self._.blocks, 'description'),
      enabled: resource.field(self._.blocks, 'enabled'),
      filters: resource.field(self._.blocks, 'filters'),
      id: resource.field(self._.blocks, 'id'),
      mechanisms: resource.field(self._.blocks, 'mechanisms'),
      modified: resource.field(self._.blocks, 'modified'),
      name: resource.field(self._.blocks, 'name'),
    },
    notification_policy_webhooks(name, block): {
      local resource = blockType.resource('cloudflare_notification_policy_webhooks', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_at') +
        attribute(block, 'id') +
        attribute(block, 'last_failure') +
        attribute(block, 'last_success') +
        attribute(block, 'name', true) +
        attribute(block, 'secret') +
        attribute(block, 'type') +
        attribute(block, 'url', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_at: resource.field(self._.blocks, 'created_at'),
      id: resource.field(self._.blocks, 'id'),
      last_failure: resource.field(self._.blocks, 'last_failure'),
      last_success: resource.field(self._.blocks, 'last_success'),
      name: resource.field(self._.blocks, 'name'),
      secret: resource.field(self._.blocks, 'secret'),
      type: resource.field(self._.blocks, 'type'),
      url: resource.field(self._.blocks, 'url'),
    },
    observatory_scheduled_test(name, block): {
      local resource = blockType.resource('cloudflare_observatory_scheduled_test', name),
      _: resource._(
        block,
        attribute(block, 'frequency') +
        attribute(block, 'id') +
        attribute(block, 'region') +
        attribute(block, 'schedule') +
        attribute(block, 'test') +
        attribute(block, 'url', true) +
        attribute(block, 'zone_id')
      ),
      frequency: resource.field(self._.blocks, 'frequency'),
      id: resource.field(self._.blocks, 'id'),
      region: resource.field(self._.blocks, 'region'),
      schedule: resource.field(self._.blocks, 'schedule'),
      test: resource.field(self._.blocks, 'test'),
      url: resource.field(self._.blocks, 'url'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    organization(name, block): {
      local resource = blockType.resource('cloudflare_organization', name),
      _: resource._(
        block,
        attribute(block, 'create_time') +
        attribute(block, 'id') +
        attribute(block, 'meta') +
        attribute(block, 'name', true) +
        attribute(block, 'parent') +
        attribute(block, 'profile')
      ),
      create_time: resource.field(self._.blocks, 'create_time'),
      id: resource.field(self._.blocks, 'id'),
      meta: resource.field(self._.blocks, 'meta'),
      name: resource.field(self._.blocks, 'name'),
      parent: resource.field(self._.blocks, 'parent'),
      profile: resource.field(self._.blocks, 'profile'),
    },
    organization_profile(name, block): {
      local resource = blockType.resource('cloudflare_organization_profile', name),
      _: resource._(
        block,
        attribute(block, 'business_address', true) +
        attribute(block, 'business_email', true) +
        attribute(block, 'business_name', true) +
        attribute(block, 'business_phone', true) +
        attribute(block, 'external_metadata', true) +
        attribute(block, 'organization_id', true)
      ),
      business_address: resource.field(self._.blocks, 'business_address'),
      business_email: resource.field(self._.blocks, 'business_email'),
      business_name: resource.field(self._.blocks, 'business_name'),
      business_phone: resource.field(self._.blocks, 'business_phone'),
      external_metadata: resource.field(self._.blocks, 'external_metadata'),
      organization_id: resource.field(self._.blocks, 'organization_id'),
    },
    origin_ca_certificate(name, block): {
      local resource = blockType.resource('cloudflare_origin_ca_certificate', name),
      _: resource._(
        block,
        attribute(block, 'certificate') +
        attribute(block, 'csr', true) +
        attribute(block, 'expires_on') +
        attribute(block, 'hostnames', true) +
        attribute(block, 'id') +
        attribute(block, 'request_type', true) +
        attribute(block, 'requested_validity')
      ),
      certificate: resource.field(self._.blocks, 'certificate'),
      csr: resource.field(self._.blocks, 'csr'),
      expires_on: resource.field(self._.blocks, 'expires_on'),
      hostnames: resource.field(self._.blocks, 'hostnames'),
      id: resource.field(self._.blocks, 'id'),
      request_type: resource.field(self._.blocks, 'request_type'),
      requested_validity: resource.field(self._.blocks, 'requested_validity'),
    },
    page_rule(name, block): {
      local resource = blockType.resource('cloudflare_page_rule', name),
      _: resource._(
        block,
        attribute(block, 'actions', true) +
        attribute(block, 'created_on') +
        attribute(block, 'id') +
        attribute(block, 'modified_on') +
        attribute(block, 'priority') +
        attribute(block, 'status') +
        attribute(block, 'target', true) +
        attribute(block, 'zone_id')
      ),
      actions: resource.field(self._.blocks, 'actions'),
      created_on: resource.field(self._.blocks, 'created_on'),
      id: resource.field(self._.blocks, 'id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      priority: resource.field(self._.blocks, 'priority'),
      status: resource.field(self._.blocks, 'status'),
      target: resource.field(self._.blocks, 'target'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    page_shield_policy(name, block): {
      local resource = blockType.resource('cloudflare_page_shield_policy', name),
      _: resource._(
        block,
        attribute(block, 'action', true) +
        attribute(block, 'description', true) +
        attribute(block, 'enabled', true) +
        attribute(block, 'expression', true) +
        attribute(block, 'id') +
        attribute(block, 'value', true) +
        attribute(block, 'zone_id')
      ),
      action: resource.field(self._.blocks, 'action'),
      description: resource.field(self._.blocks, 'description'),
      enabled: resource.field(self._.blocks, 'enabled'),
      expression: resource.field(self._.blocks, 'expression'),
      id: resource.field(self._.blocks, 'id'),
      value: resource.field(self._.blocks, 'value'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    pages_domain(name, block): {
      local resource = blockType.resource('cloudflare_pages_domain', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'certificate_authority') +
        attribute(block, 'created_on') +
        attribute(block, 'domain_id') +
        attribute(block, 'id') +
        attribute(block, 'name', true) +
        attribute(block, 'project_name', true) +
        attribute(block, 'status') +
        attribute(block, 'validation_data') +
        attribute(block, 'verification_data') +
        attribute(block, 'zone_tag')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      certificate_authority: resource.field(self._.blocks, 'certificate_authority'),
      created_on: resource.field(self._.blocks, 'created_on'),
      domain_id: resource.field(self._.blocks, 'domain_id'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      project_name: resource.field(self._.blocks, 'project_name'),
      status: resource.field(self._.blocks, 'status'),
      validation_data: resource.field(self._.blocks, 'validation_data'),
      verification_data: resource.field(self._.blocks, 'verification_data'),
      zone_tag: resource.field(self._.blocks, 'zone_tag'),
    },
    pages_project(name, block): {
      local resource = blockType.resource('cloudflare_pages_project', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'build_config') +
        attribute(block, 'canonical_deployment') +
        attribute(block, 'created_on') +
        attribute(block, 'deployment_configs') +
        attribute(block, 'domains') +
        attribute(block, 'framework') +
        attribute(block, 'framework_version') +
        attribute(block, 'id') +
        attribute(block, 'latest_deployment') +
        attribute(block, 'name', true) +
        attribute(block, 'preview_script_name') +
        attribute(block, 'production_branch', true) +
        attribute(block, 'production_script_name') +
        attribute(block, 'source') +
        attribute(block, 'subdomain') +
        attribute(block, 'uses_functions')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      build_config: resource.field(self._.blocks, 'build_config'),
      canonical_deployment: resource.field(self._.blocks, 'canonical_deployment'),
      created_on: resource.field(self._.blocks, 'created_on'),
      deployment_configs: resource.field(self._.blocks, 'deployment_configs'),
      domains: resource.field(self._.blocks, 'domains'),
      framework: resource.field(self._.blocks, 'framework'),
      framework_version: resource.field(self._.blocks, 'framework_version'),
      id: resource.field(self._.blocks, 'id'),
      latest_deployment: resource.field(self._.blocks, 'latest_deployment'),
      name: resource.field(self._.blocks, 'name'),
      preview_script_name: resource.field(self._.blocks, 'preview_script_name'),
      production_branch: resource.field(self._.blocks, 'production_branch'),
      production_script_name: resource.field(self._.blocks, 'production_script_name'),
      source: resource.field(self._.blocks, 'source'),
      subdomain: resource.field(self._.blocks, 'subdomain'),
      uses_functions: resource.field(self._.blocks, 'uses_functions'),
    },
    pipeline(name, block): {
      local resource = blockType.resource('cloudflare_pipeline', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_at') +
        attribute(block, 'failure_reason') +
        attribute(block, 'id') +
        attribute(block, 'modified_at') +
        attribute(block, 'name', true) +
        attribute(block, 'sql', true) +
        attribute(block, 'status') +
        attribute(block, 'tables')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_at: resource.field(self._.blocks, 'created_at'),
      failure_reason: resource.field(self._.blocks, 'failure_reason'),
      id: resource.field(self._.blocks, 'id'),
      modified_at: resource.field(self._.blocks, 'modified_at'),
      name: resource.field(self._.blocks, 'name'),
      sql: resource.field(self._.blocks, 'sql'),
      status: resource.field(self._.blocks, 'status'),
      tables: resource.field(self._.blocks, 'tables'),
    },
    pipeline_sink(name, block): {
      local resource = blockType.resource('cloudflare_pipeline_sink', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'config') +
        attribute(block, 'created_at') +
        attribute(block, 'format') +
        attribute(block, 'id') +
        attribute(block, 'modified_at') +
        attribute(block, 'name', true) +
        attribute(block, 'schema') +
        attribute(block, 'type', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      config: resource.field(self._.blocks, 'config'),
      created_at: resource.field(self._.blocks, 'created_at'),
      format: resource.field(self._.blocks, 'format'),
      id: resource.field(self._.blocks, 'id'),
      modified_at: resource.field(self._.blocks, 'modified_at'),
      name: resource.field(self._.blocks, 'name'),
      schema: resource.field(self._.blocks, 'schema'),
      type: resource.field(self._.blocks, 'type'),
    },
    pipeline_stream(name, block): {
      local resource = blockType.resource('cloudflare_pipeline_stream', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_at') +
        attribute(block, 'endpoint') +
        attribute(block, 'format') +
        attribute(block, 'http') +
        attribute(block, 'id') +
        attribute(block, 'modified_at') +
        attribute(block, 'name', true) +
        attribute(block, 'schema') +
        attribute(block, 'version') +
        attribute(block, 'worker_binding')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_at: resource.field(self._.blocks, 'created_at'),
      endpoint: resource.field(self._.blocks, 'endpoint'),
      format: resource.field(self._.blocks, 'format'),
      http: resource.field(self._.blocks, 'http'),
      id: resource.field(self._.blocks, 'id'),
      modified_at: resource.field(self._.blocks, 'modified_at'),
      name: resource.field(self._.blocks, 'name'),
      schema: resource.field(self._.blocks, 'schema'),
      version: resource.field(self._.blocks, 'version'),
      worker_binding: resource.field(self._.blocks, 'worker_binding'),
    },
    queue(name, block): {
      local resource = blockType.resource('cloudflare_queue', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'consumers') +
        attribute(block, 'consumers_total_count') +
        attribute(block, 'created_on') +
        attribute(block, 'id') +
        attribute(block, 'modified_on') +
        attribute(block, 'producers') +
        attribute(block, 'producers_total_count') +
        attribute(block, 'queue_id') +
        attribute(block, 'queue_name', true) +
        attribute(block, 'settings')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      consumers: resource.field(self._.blocks, 'consumers'),
      consumers_total_count: resource.field(self._.blocks, 'consumers_total_count'),
      created_on: resource.field(self._.blocks, 'created_on'),
      id: resource.field(self._.blocks, 'id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      producers: resource.field(self._.blocks, 'producers'),
      producers_total_count: resource.field(self._.blocks, 'producers_total_count'),
      queue_id: resource.field(self._.blocks, 'queue_id'),
      queue_name: resource.field(self._.blocks, 'queue_name'),
      settings: resource.field(self._.blocks, 'settings'),
    },
    queue_consumer(name, block): {
      local resource = blockType.resource('cloudflare_queue_consumer', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'consumer_id') +
        attribute(block, 'created_on') +
        attribute(block, 'dead_letter_queue') +
        attribute(block, 'queue_id', true) +
        attribute(block, 'queue_name') +
        attribute(block, 'script_name') +
        attribute(block, 'settings') +
        attribute(block, 'type', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      consumer_id: resource.field(self._.blocks, 'consumer_id'),
      created_on: resource.field(self._.blocks, 'created_on'),
      dead_letter_queue: resource.field(self._.blocks, 'dead_letter_queue'),
      queue_id: resource.field(self._.blocks, 'queue_id'),
      queue_name: resource.field(self._.blocks, 'queue_name'),
      script_name: resource.field(self._.blocks, 'script_name'),
      settings: resource.field(self._.blocks, 'settings'),
      type: resource.field(self._.blocks, 'type'),
    },
    r2_bucket(name, block): {
      local resource = blockType.resource('cloudflare_r2_bucket', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'creation_date') +
        attribute(block, 'id') +
        attribute(block, 'jurisdiction') +
        attribute(block, 'location') +
        attribute(block, 'name', true) +
        attribute(block, 'storage_class')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      creation_date: resource.field(self._.blocks, 'creation_date'),
      id: resource.field(self._.blocks, 'id'),
      jurisdiction: resource.field(self._.blocks, 'jurisdiction'),
      location: resource.field(self._.blocks, 'location'),
      name: resource.field(self._.blocks, 'name'),
      storage_class: resource.field(self._.blocks, 'storage_class'),
    },
    r2_bucket_cors(name, block): {
      local resource = blockType.resource('cloudflare_r2_bucket_cors', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'bucket_name', true) +
        attribute(block, 'jurisdiction') +
        attribute(block, 'rules')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      bucket_name: resource.field(self._.blocks, 'bucket_name'),
      jurisdiction: resource.field(self._.blocks, 'jurisdiction'),
      rules: resource.field(self._.blocks, 'rules'),
    },
    r2_bucket_event_notification(name, block): {
      local resource = blockType.resource('cloudflare_r2_bucket_event_notification', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'bucket_name', true) +
        attribute(block, 'jurisdiction') +
        attribute(block, 'queue_id', true) +
        attribute(block, 'queue_name') +
        attribute(block, 'rules', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      bucket_name: resource.field(self._.blocks, 'bucket_name'),
      jurisdiction: resource.field(self._.blocks, 'jurisdiction'),
      queue_id: resource.field(self._.blocks, 'queue_id'),
      queue_name: resource.field(self._.blocks, 'queue_name'),
      rules: resource.field(self._.blocks, 'rules'),
    },
    r2_bucket_lifecycle(name, block): {
      local resource = blockType.resource('cloudflare_r2_bucket_lifecycle', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'bucket_name', true) +
        attribute(block, 'jurisdiction') +
        attribute(block, 'rules')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      bucket_name: resource.field(self._.blocks, 'bucket_name'),
      jurisdiction: resource.field(self._.blocks, 'jurisdiction'),
      rules: resource.field(self._.blocks, 'rules'),
    },
    r2_bucket_lock(name, block): {
      local resource = blockType.resource('cloudflare_r2_bucket_lock', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'bucket_name', true) +
        attribute(block, 'jurisdiction') +
        attribute(block, 'rules')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      bucket_name: resource.field(self._.blocks, 'bucket_name'),
      jurisdiction: resource.field(self._.blocks, 'jurisdiction'),
      rules: resource.field(self._.blocks, 'rules'),
    },
    r2_bucket_sippy(name, block): {
      local resource = blockType.resource('cloudflare_r2_bucket_sippy', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'bucket_name', true) +
        attribute(block, 'destination') +
        attribute(block, 'enabled') +
        attribute(block, 'jurisdiction') +
        attribute(block, 'source')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      bucket_name: resource.field(self._.blocks, 'bucket_name'),
      destination: resource.field(self._.blocks, 'destination'),
      enabled: resource.field(self._.blocks, 'enabled'),
      jurisdiction: resource.field(self._.blocks, 'jurisdiction'),
      source: resource.field(self._.blocks, 'source'),
    },
    r2_custom_domain(name, block): {
      local resource = blockType.resource('cloudflare_r2_custom_domain', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'bucket_name', true) +
        attribute(block, 'ciphers') +
        attribute(block, 'domain', true) +
        attribute(block, 'enabled', true) +
        attribute(block, 'jurisdiction') +
        attribute(block, 'min_tls') +
        attribute(block, 'status') +
        attribute(block, 'zone_id', true) +
        attribute(block, 'zone_name')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      bucket_name: resource.field(self._.blocks, 'bucket_name'),
      ciphers: resource.field(self._.blocks, 'ciphers'),
      domain: resource.field(self._.blocks, 'domain'),
      enabled: resource.field(self._.blocks, 'enabled'),
      jurisdiction: resource.field(self._.blocks, 'jurisdiction'),
      min_tls: resource.field(self._.blocks, 'min_tls'),
      status: resource.field(self._.blocks, 'status'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
      zone_name: resource.field(self._.blocks, 'zone_name'),
    },
    r2_data_catalog(name, block): {
      local resource = blockType.resource('cloudflare_r2_data_catalog', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'bucket') +
        attribute(block, 'bucket_name', true) +
        attribute(block, 'credential_status') +
        attribute(block, 'id') +
        attribute(block, 'maintenance_config') +
        attribute(block, 'name') +
        attribute(block, 'status')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      bucket: resource.field(self._.blocks, 'bucket'),
      bucket_name: resource.field(self._.blocks, 'bucket_name'),
      credential_status: resource.field(self._.blocks, 'credential_status'),
      id: resource.field(self._.blocks, 'id'),
      maintenance_config: resource.field(self._.blocks, 'maintenance_config'),
      name: resource.field(self._.blocks, 'name'),
      status: resource.field(self._.blocks, 'status'),
    },
    r2_managed_domain(name, block): {
      local resource = blockType.resource('cloudflare_r2_managed_domain', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'bucket_id') +
        attribute(block, 'bucket_name', true) +
        attribute(block, 'domain') +
        attribute(block, 'enabled', true) +
        attribute(block, 'jurisdiction')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      bucket_id: resource.field(self._.blocks, 'bucket_id'),
      bucket_name: resource.field(self._.blocks, 'bucket_name'),
      domain: resource.field(self._.blocks, 'domain'),
      enabled: resource.field(self._.blocks, 'enabled'),
      jurisdiction: resource.field(self._.blocks, 'jurisdiction'),
    },
    rate_limit(name, block): {
      local resource = blockType.resource('cloudflare_rate_limit', name),
      _: resource._(
        block,
        attribute(block, 'action', true) +
        attribute(block, 'bypass') +
        attribute(block, 'description') +
        attribute(block, 'disabled') +
        attribute(block, 'id') +
        attribute(block, 'match', true) +
        attribute(block, 'period', true) +
        attribute(block, 'threshold', true) +
        attribute(block, 'zone_id')
      ),
      action: resource.field(self._.blocks, 'action'),
      bypass: resource.field(self._.blocks, 'bypass'),
      description: resource.field(self._.blocks, 'description'),
      disabled: resource.field(self._.blocks, 'disabled'),
      id: resource.field(self._.blocks, 'id'),
      match: resource.field(self._.blocks, 'match'),
      period: resource.field(self._.blocks, 'period'),
      threshold: resource.field(self._.blocks, 'threshold'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    regional_hostname(name, block): {
      local resource = blockType.resource('cloudflare_regional_hostname', name),
      _: resource._(
        block,
        attribute(block, 'created_on') +
        attribute(block, 'hostname', true) +
        attribute(block, 'id') +
        attribute(block, 'region_key', true) +
        attribute(block, 'routing') +
        attribute(block, 'zone_id')
      ),
      created_on: resource.field(self._.blocks, 'created_on'),
      hostname: resource.field(self._.blocks, 'hostname'),
      id: resource.field(self._.blocks, 'id'),
      region_key: resource.field(self._.blocks, 'region_key'),
      routing: resource.field(self._.blocks, 'routing'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    regional_tiered_cache(name, block): {
      local resource = blockType.resource('cloudflare_regional_tiered_cache', name),
      _: resource._(
        block,
        attribute(block, 'editable') +
        attribute(block, 'id') +
        attribute(block, 'modified_on') +
        attribute(block, 'value') +
        attribute(block, 'zone_id', true)
      ),
      editable: resource.field(self._.blocks, 'editable'),
      id: resource.field(self._.blocks, 'id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      value: resource.field(self._.blocks, 'value'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    registrar_domain(name, block): {
      local resource = blockType.resource('cloudflare_registrar_domain', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'auto_renew') +
        attribute(block, 'domain_name', true) +
        attribute(block, 'locked') +
        attribute(block, 'privacy')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      auto_renew: resource.field(self._.blocks, 'auto_renew'),
      domain_name: resource.field(self._.blocks, 'domain_name'),
      locked: resource.field(self._.blocks, 'locked'),
      privacy: resource.field(self._.blocks, 'privacy'),
    },
    ruleset(name, block): {
      local resource = blockType.resource('cloudflare_ruleset', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'description') +
        attribute(block, 'id') +
        attribute(block, 'kind', true) +
        attribute(block, 'last_updated') +
        attribute(block, 'name', true) +
        attribute(block, 'phase', true) +
        attribute(block, 'rules') +
        attribute(block, 'version') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      kind: resource.field(self._.blocks, 'kind'),
      last_updated: resource.field(self._.blocks, 'last_updated'),
      name: resource.field(self._.blocks, 'name'),
      phase: resource.field(self._.blocks, 'phase'),
      rules: resource.field(self._.blocks, 'rules'),
      version: resource.field(self._.blocks, 'version'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    schema_validation_operation_settings(name, block): {
      local resource = blockType.resource('cloudflare_schema_validation_operation_settings', name),
      _: resource._(
        block,
        attribute(block, 'mitigation_action', true) +
        attribute(block, 'operation_id', true) +
        attribute(block, 'zone_id')
      ),
      mitigation_action: resource.field(self._.blocks, 'mitigation_action'),
      operation_id: resource.field(self._.blocks, 'operation_id'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    schema_validation_schemas(name, block): {
      local resource = blockType.resource('cloudflare_schema_validation_schemas', name),
      _: resource._(
        block,
        attribute(block, 'created_at') +
        attribute(block, 'id') +
        attribute(block, 'kind', true) +
        attribute(block, 'name', true) +
        attribute(block, 'schema_id') +
        attribute(block, 'source', true) +
        attribute(block, 'validation_enabled', true) +
        attribute(block, 'zone_id')
      ),
      created_at: resource.field(self._.blocks, 'created_at'),
      id: resource.field(self._.blocks, 'id'),
      kind: resource.field(self._.blocks, 'kind'),
      name: resource.field(self._.blocks, 'name'),
      schema_id: resource.field(self._.blocks, 'schema_id'),
      source: resource.field(self._.blocks, 'source'),
      validation_enabled: resource.field(self._.blocks, 'validation_enabled'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    schema_validation_settings(name, block): {
      local resource = blockType.resource('cloudflare_schema_validation_settings', name),
      _: resource._(
        block,
        attribute(block, 'validation_default_mitigation_action', true) +
        attribute(block, 'validation_override_mitigation_action') +
        attribute(block, 'zone_id')
      ),
      validation_default_mitigation_action: resource.field(self._.blocks, 'validation_default_mitigation_action'),
      validation_override_mitigation_action: resource.field(self._.blocks, 'validation_override_mitigation_action'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    snippet(name, block): {
      local resource = blockType.resource('cloudflare_snippet', name),
      _: resource._(
        block,
        attribute(block, 'created_on') +
        attribute(block, 'files', true) +
        attribute(block, 'metadata', true) +
        attribute(block, 'modified_on') +
        attribute(block, 'snippet_name', true) +
        attribute(block, 'zone_id')
      ),
      created_on: resource.field(self._.blocks, 'created_on'),
      files: resource.field(self._.blocks, 'files'),
      metadata: resource.field(self._.blocks, 'metadata'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      snippet_name: resource.field(self._.blocks, 'snippet_name'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    snippet_rules(name, block): {
      local resource = blockType.resource('cloudflare_snippet_rules', name),
      _: resource._(
        block,
        attribute(block, 'rules', true) +
        attribute(block, 'zone_id')
      ),
      rules: resource.field(self._.blocks, 'rules'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    snippets(name, block): {
      local resource = blockType.resource('cloudflare_snippets', name),
      _: resource._(
        block,
        attribute(block, 'created_on') +
        attribute(block, 'files', true) +
        attribute(block, 'metadata', true) +
        attribute(block, 'modified_on') +
        attribute(block, 'snippet_name', true) +
        attribute(block, 'zone_id', true)
      ),
      created_on: resource.field(self._.blocks, 'created_on'),
      files: resource.field(self._.blocks, 'files'),
      metadata: resource.field(self._.blocks, 'metadata'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      snippet_name: resource.field(self._.blocks, 'snippet_name'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    spectrum_application(name, block): {
      local resource = blockType.resource('cloudflare_spectrum_application', name),
      _: resource._(
        block,
        attribute(block, 'argo_smart_routing') +
        attribute(block, 'created_on') +
        attribute(block, 'dns', true) +
        attribute(block, 'edge_ips') +
        attribute(block, 'id') +
        attribute(block, 'ip_firewall') +
        attribute(block, 'modified_on') +
        attribute(block, 'origin_direct') +
        attribute(block, 'origin_dns') +
        attribute(block, 'origin_port') +
        attribute(block, 'protocol', true) +
        attribute(block, 'proxy_protocol') +
        attribute(block, 'tls') +
        attribute(block, 'traffic_type') +
        attribute(block, 'zone_id')
      ),
      argo_smart_routing: resource.field(self._.blocks, 'argo_smart_routing'),
      created_on: resource.field(self._.blocks, 'created_on'),
      dns: resource.field(self._.blocks, 'dns'),
      edge_ips: resource.field(self._.blocks, 'edge_ips'),
      id: resource.field(self._.blocks, 'id'),
      ip_firewall: resource.field(self._.blocks, 'ip_firewall'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      origin_direct: resource.field(self._.blocks, 'origin_direct'),
      origin_dns: resource.field(self._.blocks, 'origin_dns'),
      origin_port: resource.field(self._.blocks, 'origin_port'),
      protocol: resource.field(self._.blocks, 'protocol'),
      proxy_protocol: resource.field(self._.blocks, 'proxy_protocol'),
      tls: resource.field(self._.blocks, 'tls'),
      traffic_type: resource.field(self._.blocks, 'traffic_type'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    sso_connector(name, block): {
      local resource = blockType.resource('cloudflare_sso_connector', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'begin_verification') +
        attribute(block, 'created_on') +
        attribute(block, 'email_domain', true) +
        attribute(block, 'enabled') +
        attribute(block, 'id') +
        attribute(block, 'updated_on') +
        attribute(block, 'use_fedramp_language') +
        attribute(block, 'verification')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      begin_verification: resource.field(self._.blocks, 'begin_verification'),
      created_on: resource.field(self._.blocks, 'created_on'),
      email_domain: resource.field(self._.blocks, 'email_domain'),
      enabled: resource.field(self._.blocks, 'enabled'),
      id: resource.field(self._.blocks, 'id'),
      updated_on: resource.field(self._.blocks, 'updated_on'),
      use_fedramp_language: resource.field(self._.blocks, 'use_fedramp_language'),
      verification: resource.field(self._.blocks, 'verification'),
    },
    stream(name, block): {
      local resource = blockType.resource('cloudflare_stream', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'allowed_origins') +
        attribute(block, 'clipped_from') +
        attribute(block, 'created') +
        attribute(block, 'creator') +
        attribute(block, 'duration') +
        attribute(block, 'identifier') +
        attribute(block, 'input') +
        attribute(block, 'live_input') +
        attribute(block, 'max_duration_seconds') +
        attribute(block, 'max_size_bytes') +
        attribute(block, 'meta') +
        attribute(block, 'modified') +
        attribute(block, 'playback') +
        attribute(block, 'preview') +
        attribute(block, 'public_details') +
        attribute(block, 'ready_to_stream') +
        attribute(block, 'ready_to_stream_at') +
        attribute(block, 'require_signed_urls') +
        attribute(block, 'scheduled_deletion') +
        attribute(block, 'size') +
        attribute(block, 'status') +
        attribute(block, 'thumbnail') +
        attribute(block, 'thumbnail_timestamp_pct') +
        attribute(block, 'uid') +
        attribute(block, 'upload_expiry') +
        attribute(block, 'uploaded') +
        attribute(block, 'watermark')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      allowed_origins: resource.field(self._.blocks, 'allowed_origins'),
      clipped_from: resource.field(self._.blocks, 'clipped_from'),
      created: resource.field(self._.blocks, 'created'),
      creator: resource.field(self._.blocks, 'creator'),
      duration: resource.field(self._.blocks, 'duration'),
      identifier: resource.field(self._.blocks, 'identifier'),
      input: resource.field(self._.blocks, 'input'),
      live_input: resource.field(self._.blocks, 'live_input'),
      max_duration_seconds: resource.field(self._.blocks, 'max_duration_seconds'),
      max_size_bytes: resource.field(self._.blocks, 'max_size_bytes'),
      meta: resource.field(self._.blocks, 'meta'),
      modified: resource.field(self._.blocks, 'modified'),
      playback: resource.field(self._.blocks, 'playback'),
      preview: resource.field(self._.blocks, 'preview'),
      public_details: resource.field(self._.blocks, 'public_details'),
      ready_to_stream: resource.field(self._.blocks, 'ready_to_stream'),
      ready_to_stream_at: resource.field(self._.blocks, 'ready_to_stream_at'),
      require_signed_urls: resource.field(self._.blocks, 'require_signed_urls'),
      scheduled_deletion: resource.field(self._.blocks, 'scheduled_deletion'),
      size: resource.field(self._.blocks, 'size'),
      status: resource.field(self._.blocks, 'status'),
      thumbnail: resource.field(self._.blocks, 'thumbnail'),
      thumbnail_timestamp_pct: resource.field(self._.blocks, 'thumbnail_timestamp_pct'),
      uid: resource.field(self._.blocks, 'uid'),
      upload_expiry: resource.field(self._.blocks, 'upload_expiry'),
      uploaded: resource.field(self._.blocks, 'uploaded'),
      watermark: resource.field(self._.blocks, 'watermark'),
    },
    stream_audio_track(name, block): {
      local resource = blockType.resource('cloudflare_stream_audio_track', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'audio') +
        attribute(block, 'audio_identifier') +
        attribute(block, 'default') +
        attribute(block, 'identifier', true) +
        attribute(block, 'label') +
        attribute(block, 'status') +
        attribute(block, 'uid')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      audio: resource.field(self._.blocks, 'audio'),
      audio_identifier: resource.field(self._.blocks, 'audio_identifier'),
      default: resource.field(self._.blocks, 'default'),
      identifier: resource.field(self._.blocks, 'identifier'),
      label: resource.field(self._.blocks, 'label'),
      status: resource.field(self._.blocks, 'status'),
      uid: resource.field(self._.blocks, 'uid'),
    },
    stream_caption_language(name, block): {
      local resource = blockType.resource('cloudflare_stream_caption_language', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'file') +
        attribute(block, 'generated') +
        attribute(block, 'identifier', true) +
        attribute(block, 'label') +
        attribute(block, 'language', true) +
        attribute(block, 'status')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      file: resource.field(self._.blocks, 'file'),
      generated: resource.field(self._.blocks, 'generated'),
      identifier: resource.field(self._.blocks, 'identifier'),
      label: resource.field(self._.blocks, 'label'),
      language: resource.field(self._.blocks, 'language'),
      status: resource.field(self._.blocks, 'status'),
    },
    stream_download(name, block): {
      local resource = blockType.resource('cloudflare_stream_download', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'audio') +
        attribute(block, 'default') +
        attribute(block, 'identifier', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      audio: resource.field(self._.blocks, 'audio'),
      default: resource.field(self._.blocks, 'default'),
      identifier: resource.field(self._.blocks, 'identifier'),
    },
    stream_key(name, block): {
      local resource = blockType.resource('cloudflare_stream_key', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created') +
        attribute(block, 'id') +
        attribute(block, 'jwk') +
        attribute(block, 'key_id') +
        attribute(block, 'pem')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created: resource.field(self._.blocks, 'created'),
      id: resource.field(self._.blocks, 'id'),
      jwk: resource.field(self._.blocks, 'jwk'),
      key_id: resource.field(self._.blocks, 'key_id'),
      pem: resource.field(self._.blocks, 'pem'),
    },
    stream_live_input(name, block): {
      local resource = blockType.resource('cloudflare_stream_live_input', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created') +
        attribute(block, 'default_creator') +
        attribute(block, 'delete_recording_after_days') +
        attribute(block, 'enabled') +
        attribute(block, 'live_input_identifier') +
        attribute(block, 'meta') +
        attribute(block, 'modified') +
        attribute(block, 'recording') +
        attribute(block, 'rtmps') +
        attribute(block, 'rtmps_playback') +
        attribute(block, 'srt') +
        attribute(block, 'srt_playback') +
        attribute(block, 'status') +
        attribute(block, 'uid') +
        attribute(block, 'web_rtc') +
        attribute(block, 'web_rtc_playback')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created: resource.field(self._.blocks, 'created'),
      default_creator: resource.field(self._.blocks, 'default_creator'),
      delete_recording_after_days: resource.field(self._.blocks, 'delete_recording_after_days'),
      enabled: resource.field(self._.blocks, 'enabled'),
      live_input_identifier: resource.field(self._.blocks, 'live_input_identifier'),
      meta: resource.field(self._.blocks, 'meta'),
      modified: resource.field(self._.blocks, 'modified'),
      recording: resource.field(self._.blocks, 'recording'),
      rtmps: resource.field(self._.blocks, 'rtmps'),
      rtmps_playback: resource.field(self._.blocks, 'rtmps_playback'),
      srt: resource.field(self._.blocks, 'srt'),
      srt_playback: resource.field(self._.blocks, 'srt_playback'),
      status: resource.field(self._.blocks, 'status'),
      uid: resource.field(self._.blocks, 'uid'),
      web_rtc: resource.field(self._.blocks, 'web_rtc'),
      web_rtc_playback: resource.field(self._.blocks, 'web_rtc_playback'),
    },
    stream_watermark(name, block): {
      local resource = blockType.resource('cloudflare_stream_watermark', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created') +
        attribute(block, 'downloaded_from') +
        attribute(block, 'height') +
        attribute(block, 'identifier') +
        attribute(block, 'name') +
        attribute(block, 'opacity') +
        attribute(block, 'padding') +
        attribute(block, 'position') +
        attribute(block, 'scale') +
        attribute(block, 'size') +
        attribute(block, 'uid') +
        attribute(block, 'url') +
        attribute(block, 'width')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created: resource.field(self._.blocks, 'created'),
      downloaded_from: resource.field(self._.blocks, 'downloaded_from'),
      height: resource.field(self._.blocks, 'height'),
      identifier: resource.field(self._.blocks, 'identifier'),
      name: resource.field(self._.blocks, 'name'),
      opacity: resource.field(self._.blocks, 'opacity'),
      padding: resource.field(self._.blocks, 'padding'),
      position: resource.field(self._.blocks, 'position'),
      scale: resource.field(self._.blocks, 'scale'),
      size: resource.field(self._.blocks, 'size'),
      uid: resource.field(self._.blocks, 'uid'),
      url: resource.field(self._.blocks, 'url'),
      width: resource.field(self._.blocks, 'width'),
    },
    stream_webhook(name, block): {
      local resource = blockType.resource('cloudflare_stream_webhook', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'modified') +
        attribute(block, 'notification_url') +
        attribute(block, 'secret')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      modified: resource.field(self._.blocks, 'modified'),
      notification_url: resource.field(self._.blocks, 'notification_url'),
      secret: resource.field(self._.blocks, 'secret'),
    },
    tiered_cache(name, block): {
      local resource = blockType.resource('cloudflare_tiered_cache', name),
      _: resource._(
        block,
        attribute(block, 'editable') +
        attribute(block, 'id') +
        attribute(block, 'modified_on') +
        attribute(block, 'value', true) +
        attribute(block, 'zone_id', true)
      ),
      editable: resource.field(self._.blocks, 'editable'),
      id: resource.field(self._.blocks, 'id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      value: resource.field(self._.blocks, 'value'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    token_validation_config(name, block): {
      local resource = blockType.resource('cloudflare_token_validation_config', name),
      _: resource._(
        block,
        attribute(block, 'created_at') +
        attribute(block, 'credentials', true) +
        attribute(block, 'description', true) +
        attribute(block, 'id') +
        attribute(block, 'last_updated') +
        attribute(block, 'title', true) +
        attribute(block, 'token_sources', true) +
        attribute(block, 'token_type', true) +
        attribute(block, 'zone_id')
      ),
      created_at: resource.field(self._.blocks, 'created_at'),
      credentials: resource.field(self._.blocks, 'credentials'),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      last_updated: resource.field(self._.blocks, 'last_updated'),
      title: resource.field(self._.blocks, 'title'),
      token_sources: resource.field(self._.blocks, 'token_sources'),
      token_type: resource.field(self._.blocks, 'token_type'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    token_validation_rules(name, block): {
      local resource = blockType.resource('cloudflare_token_validation_rules', name),
      _: resource._(
        block,
        attribute(block, 'action', true) +
        attribute(block, 'created_at') +
        attribute(block, 'description', true) +
        attribute(block, 'enabled', true) +
        attribute(block, 'expression', true) +
        attribute(block, 'id') +
        attribute(block, 'last_updated') +
        attribute(block, 'position') +
        attribute(block, 'selector', true) +
        attribute(block, 'title', true) +
        attribute(block, 'zone_id')
      ),
      action: resource.field(self._.blocks, 'action'),
      created_at: resource.field(self._.blocks, 'created_at'),
      description: resource.field(self._.blocks, 'description'),
      enabled: resource.field(self._.blocks, 'enabled'),
      expression: resource.field(self._.blocks, 'expression'),
      id: resource.field(self._.blocks, 'id'),
      last_updated: resource.field(self._.blocks, 'last_updated'),
      position: resource.field(self._.blocks, 'position'),
      selector: resource.field(self._.blocks, 'selector'),
      title: resource.field(self._.blocks, 'title'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    total_tls(name, block): {
      local resource = blockType.resource('cloudflare_total_tls', name),
      _: resource._(
        block,
        attribute(block, 'certificate_authority') +
        attribute(block, 'enabled', true) +
        attribute(block, 'id') +
        attribute(block, 'validity_period') +
        attribute(block, 'zone_id', true)
      ),
      certificate_authority: resource.field(self._.blocks, 'certificate_authority'),
      enabled: resource.field(self._.blocks, 'enabled'),
      id: resource.field(self._.blocks, 'id'),
      validity_period: resource.field(self._.blocks, 'validity_period'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    turnstile_widget(name, block): {
      local resource = blockType.resource('cloudflare_turnstile_widget', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'bot_fight_mode') +
        attribute(block, 'clearance_level') +
        attribute(block, 'created_on') +
        attribute(block, 'domains', true) +
        attribute(block, 'ephemeral_id') +
        attribute(block, 'id') +
        attribute(block, 'mode', true) +
        attribute(block, 'modified_on') +
        attribute(block, 'name', true) +
        attribute(block, 'offlabel') +
        attribute(block, 'region') +
        attribute(block, 'secret') +
        attribute(block, 'sitekey')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      bot_fight_mode: resource.field(self._.blocks, 'bot_fight_mode'),
      clearance_level: resource.field(self._.blocks, 'clearance_level'),
      created_on: resource.field(self._.blocks, 'created_on'),
      domains: resource.field(self._.blocks, 'domains'),
      ephemeral_id: resource.field(self._.blocks, 'ephemeral_id'),
      id: resource.field(self._.blocks, 'id'),
      mode: resource.field(self._.blocks, 'mode'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      offlabel: resource.field(self._.blocks, 'offlabel'),
      region: resource.field(self._.blocks, 'region'),
      secret: resource.field(self._.blocks, 'secret'),
      sitekey: resource.field(self._.blocks, 'sitekey'),
    },
    universal_ssl_setting(name, block): {
      local resource = blockType.resource('cloudflare_universal_ssl_setting', name),
      _: resource._(
        block,
        attribute(block, 'enabled') +
        attribute(block, 'id') +
        attribute(block, 'zone_id', true)
      ),
      enabled: resource.field(self._.blocks, 'enabled'),
      id: resource.field(self._.blocks, 'id'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    url_normalization_settings(name, block): {
      local resource = blockType.resource('cloudflare_url_normalization_settings', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'scope', true) +
        attribute(block, 'type', true) +
        attribute(block, 'zone_id', true)
      ),
      id: resource.field(self._.blocks, 'id'),
      scope: resource.field(self._.blocks, 'scope'),
      type: resource.field(self._.blocks, 'type'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    user(name, block): {
      local resource = blockType.resource('cloudflare_user', name),
      _: resource._(
        block,
        attribute(block, 'betas') +
        attribute(block, 'country') +
        attribute(block, 'first_name') +
        attribute(block, 'has_business_zones') +
        attribute(block, 'has_enterprise_zones') +
        attribute(block, 'has_pro_zones') +
        attribute(block, 'id') +
        attribute(block, 'last_name') +
        attribute(block, 'organizations') +
        attribute(block, 'suspended') +
        attribute(block, 'telephone') +
        attribute(block, 'two_factor_authentication_enabled') +
        attribute(block, 'two_factor_authentication_locked') +
        attribute(block, 'zipcode')
      ),
      betas: resource.field(self._.blocks, 'betas'),
      country: resource.field(self._.blocks, 'country'),
      first_name: resource.field(self._.blocks, 'first_name'),
      has_business_zones: resource.field(self._.blocks, 'has_business_zones'),
      has_enterprise_zones: resource.field(self._.blocks, 'has_enterprise_zones'),
      has_pro_zones: resource.field(self._.blocks, 'has_pro_zones'),
      id: resource.field(self._.blocks, 'id'),
      last_name: resource.field(self._.blocks, 'last_name'),
      organizations: resource.field(self._.blocks, 'organizations'),
      suspended: resource.field(self._.blocks, 'suspended'),
      telephone: resource.field(self._.blocks, 'telephone'),
      two_factor_authentication_enabled: resource.field(self._.blocks, 'two_factor_authentication_enabled'),
      two_factor_authentication_locked: resource.field(self._.blocks, 'two_factor_authentication_locked'),
      zipcode: resource.field(self._.blocks, 'zipcode'),
    },
    user_agent_blocking_rule(name, block): {
      local resource = blockType.resource('cloudflare_user_agent_blocking_rule', name),
      _: resource._(
        block,
        attribute(block, 'configuration', true) +
        attribute(block, 'description') +
        attribute(block, 'id') +
        attribute(block, 'mode', true) +
        attribute(block, 'paused') +
        attribute(block, 'zone_id')
      ),
      configuration: resource.field(self._.blocks, 'configuration'),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      mode: resource.field(self._.blocks, 'mode'),
      paused: resource.field(self._.blocks, 'paused'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    user_group(name, block): {
      local resource = blockType.resource('cloudflare_user_group', name),
      _: resource._(
        block,
        attribute(block, 'account_id', true) +
        attribute(block, 'created_on') +
        attribute(block, 'id') +
        attribute(block, 'modified_on') +
        attribute(block, 'name', true) +
        attribute(block, 'policies')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_on: resource.field(self._.blocks, 'created_on'),
      id: resource.field(self._.blocks, 'id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      policies: resource.field(self._.blocks, 'policies'),
    },
    user_group_members(name, block): {
      local resource = blockType.resource('cloudflare_user_group_members', name),
      _: resource._(
        block,
        attribute(block, 'account_id', true) +
        attribute(block, 'id') +
        attribute(block, 'members', true) +
        attribute(block, 'user_group_id', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      id: resource.field(self._.blocks, 'id'),
      members: resource.field(self._.blocks, 'members'),
      user_group_id: resource.field(self._.blocks, 'user_group_id'),
    },
    vulnerability_scanner_credential(name, block): {
      local resource = blockType.resource('cloudflare_vulnerability_scanner_credential', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'credential_set_id', true) +
        attribute(block, 'id') +
        attribute(block, 'location', true) +
        attribute(block, 'location_name', true) +
        attribute(block, 'name', true) +
        attribute(block, 'value', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      credential_set_id: resource.field(self._.blocks, 'credential_set_id'),
      id: resource.field(self._.blocks, 'id'),
      location: resource.field(self._.blocks, 'location'),
      location_name: resource.field(self._.blocks, 'location_name'),
      name: resource.field(self._.blocks, 'name'),
      value: resource.field(self._.blocks, 'value'),
    },
    vulnerability_scanner_credential_set(name, block): {
      local resource = blockType.resource('cloudflare_vulnerability_scanner_credential_set', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'id') +
        attribute(block, 'name', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
    },
    vulnerability_scanner_target_environment(name, block): {
      local resource = blockType.resource('cloudflare_vulnerability_scanner_target_environment', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'description') +
        attribute(block, 'id') +
        attribute(block, 'name', true) +
        attribute(block, 'target', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      target: resource.field(self._.blocks, 'target'),
    },
    waiting_room(name, block): {
      local resource = blockType.resource('cloudflare_waiting_room', name),
      _: resource._(
        block,
        attribute(block, 'additional_routes') +
        attribute(block, 'cookie_attributes') +
        attribute(block, 'cookie_suffix') +
        attribute(block, 'created_on') +
        attribute(block, 'custom_page_html') +
        attribute(block, 'default_template_language') +
        attribute(block, 'description') +
        attribute(block, 'disable_session_renewal') +
        attribute(block, 'enabled_origin_commands') +
        attribute(block, 'host', true) +
        attribute(block, 'id') +
        attribute(block, 'json_response_enabled') +
        attribute(block, 'modified_on') +
        attribute(block, 'name', true) +
        attribute(block, 'new_users_per_minute', true) +
        attribute(block, 'next_event_prequeue_start_time') +
        attribute(block, 'next_event_start_time') +
        attribute(block, 'path') +
        attribute(block, 'queue_all') +
        attribute(block, 'queueing_method') +
        attribute(block, 'queueing_status_code') +
        attribute(block, 'session_duration') +
        attribute(block, 'suspended') +
        attribute(block, 'total_active_users', true) +
        attribute(block, 'turnstile_action') +
        attribute(block, 'turnstile_mode') +
        attribute(block, 'zone_id')
      ),
      additional_routes: resource.field(self._.blocks, 'additional_routes'),
      cookie_attributes: resource.field(self._.blocks, 'cookie_attributes'),
      cookie_suffix: resource.field(self._.blocks, 'cookie_suffix'),
      created_on: resource.field(self._.blocks, 'created_on'),
      custom_page_html: resource.field(self._.blocks, 'custom_page_html'),
      default_template_language: resource.field(self._.blocks, 'default_template_language'),
      description: resource.field(self._.blocks, 'description'),
      disable_session_renewal: resource.field(self._.blocks, 'disable_session_renewal'),
      enabled_origin_commands: resource.field(self._.blocks, 'enabled_origin_commands'),
      host: resource.field(self._.blocks, 'host'),
      id: resource.field(self._.blocks, 'id'),
      json_response_enabled: resource.field(self._.blocks, 'json_response_enabled'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      new_users_per_minute: resource.field(self._.blocks, 'new_users_per_minute'),
      next_event_prequeue_start_time: resource.field(self._.blocks, 'next_event_prequeue_start_time'),
      next_event_start_time: resource.field(self._.blocks, 'next_event_start_time'),
      path: resource.field(self._.blocks, 'path'),
      queue_all: resource.field(self._.blocks, 'queue_all'),
      queueing_method: resource.field(self._.blocks, 'queueing_method'),
      queueing_status_code: resource.field(self._.blocks, 'queueing_status_code'),
      session_duration: resource.field(self._.blocks, 'session_duration'),
      suspended: resource.field(self._.blocks, 'suspended'),
      total_active_users: resource.field(self._.blocks, 'total_active_users'),
      turnstile_action: resource.field(self._.blocks, 'turnstile_action'),
      turnstile_mode: resource.field(self._.blocks, 'turnstile_mode'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    waiting_room_event(name, block): {
      local resource = blockType.resource('cloudflare_waiting_room_event', name),
      _: resource._(
        block,
        attribute(block, 'created_on') +
        attribute(block, 'custom_page_html') +
        attribute(block, 'description') +
        attribute(block, 'disable_session_renewal') +
        attribute(block, 'event_end_time', true) +
        attribute(block, 'event_start_time', true) +
        attribute(block, 'id') +
        attribute(block, 'modified_on') +
        attribute(block, 'name', true) +
        attribute(block, 'new_users_per_minute') +
        attribute(block, 'prequeue_start_time') +
        attribute(block, 'queueing_method') +
        attribute(block, 'session_duration') +
        attribute(block, 'shuffle_at_event_start') +
        attribute(block, 'suspended') +
        attribute(block, 'total_active_users') +
        attribute(block, 'turnstile_action') +
        attribute(block, 'turnstile_mode') +
        attribute(block, 'waiting_room_id', true) +
        attribute(block, 'zone_id')
      ),
      created_on: resource.field(self._.blocks, 'created_on'),
      custom_page_html: resource.field(self._.blocks, 'custom_page_html'),
      description: resource.field(self._.blocks, 'description'),
      disable_session_renewal: resource.field(self._.blocks, 'disable_session_renewal'),
      event_end_time: resource.field(self._.blocks, 'event_end_time'),
      event_start_time: resource.field(self._.blocks, 'event_start_time'),
      id: resource.field(self._.blocks, 'id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      new_users_per_minute: resource.field(self._.blocks, 'new_users_per_minute'),
      prequeue_start_time: resource.field(self._.blocks, 'prequeue_start_time'),
      queueing_method: resource.field(self._.blocks, 'queueing_method'),
      session_duration: resource.field(self._.blocks, 'session_duration'),
      shuffle_at_event_start: resource.field(self._.blocks, 'shuffle_at_event_start'),
      suspended: resource.field(self._.blocks, 'suspended'),
      total_active_users: resource.field(self._.blocks, 'total_active_users'),
      turnstile_action: resource.field(self._.blocks, 'turnstile_action'),
      turnstile_mode: resource.field(self._.blocks, 'turnstile_mode'),
      waiting_room_id: resource.field(self._.blocks, 'waiting_room_id'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    waiting_room_rules(name, block): {
      local resource = blockType.resource('cloudflare_waiting_room_rules', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'rules', true) +
        attribute(block, 'waiting_room_id', true) +
        attribute(block, 'zone_id')
      ),
      id: resource.field(self._.blocks, 'id'),
      rules: resource.field(self._.blocks, 'rules'),
      waiting_room_id: resource.field(self._.blocks, 'waiting_room_id'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    waiting_room_settings(name, block): {
      local resource = blockType.resource('cloudflare_waiting_room_settings', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'search_engine_crawler_bypass') +
        attribute(block, 'zone_id', true)
      ),
      id: resource.field(self._.blocks, 'id'),
      search_engine_crawler_bypass: resource.field(self._.blocks, 'search_engine_crawler_bypass'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    web3_hostname(name, block): {
      local resource = blockType.resource('cloudflare_web3_hostname', name),
      _: resource._(
        block,
        attribute(block, 'created_on') +
        attribute(block, 'description') +
        attribute(block, 'dnslink') +
        attribute(block, 'id') +
        attribute(block, 'modified_on') +
        attribute(block, 'name', true) +
        attribute(block, 'status') +
        attribute(block, 'target', true) +
        attribute(block, 'zone_id')
      ),
      created_on: resource.field(self._.blocks, 'created_on'),
      description: resource.field(self._.blocks, 'description'),
      dnslink: resource.field(self._.blocks, 'dnslink'),
      id: resource.field(self._.blocks, 'id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      status: resource.field(self._.blocks, 'status'),
      target: resource.field(self._.blocks, 'target'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    web_analytics_rule(name, block): {
      local resource = blockType.resource('cloudflare_web_analytics_rule', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created') +
        attribute(block, 'host') +
        attribute(block, 'id') +
        attribute(block, 'inclusive') +
        attribute(block, 'is_paused') +
        attribute(block, 'paths') +
        attribute(block, 'priority') +
        attribute(block, 'ruleset_id', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created: resource.field(self._.blocks, 'created'),
      host: resource.field(self._.blocks, 'host'),
      id: resource.field(self._.blocks, 'id'),
      inclusive: resource.field(self._.blocks, 'inclusive'),
      is_paused: resource.field(self._.blocks, 'is_paused'),
      paths: resource.field(self._.blocks, 'paths'),
      priority: resource.field(self._.blocks, 'priority'),
      ruleset_id: resource.field(self._.blocks, 'ruleset_id'),
    },
    web_analytics_site(name, block): {
      local resource = blockType.resource('cloudflare_web_analytics_site', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'auto_install') +
        attribute(block, 'created') +
        attribute(block, 'enabled') +
        attribute(block, 'host') +
        attribute(block, 'id') +
        attribute(block, 'lite') +
        attribute(block, 'rules') +
        attribute(block, 'ruleset') +
        attribute(block, 'site_tag') +
        attribute(block, 'site_token') +
        attribute(block, 'snippet') +
        attribute(block, 'zone_tag')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      auto_install: resource.field(self._.blocks, 'auto_install'),
      created: resource.field(self._.blocks, 'created'),
      enabled: resource.field(self._.blocks, 'enabled'),
      host: resource.field(self._.blocks, 'host'),
      id: resource.field(self._.blocks, 'id'),
      lite: resource.field(self._.blocks, 'lite'),
      rules: resource.field(self._.blocks, 'rules'),
      ruleset: resource.field(self._.blocks, 'ruleset'),
      site_tag: resource.field(self._.blocks, 'site_tag'),
      site_token: resource.field(self._.blocks, 'site_token'),
      snippet: resource.field(self._.blocks, 'snippet'),
      zone_tag: resource.field(self._.blocks, 'zone_tag'),
    },
    worker(name, block): {
      local resource = blockType.resource('cloudflare_worker', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_on') +
        attribute(block, 'deployed_on') +
        attribute(block, 'id') +
        attribute(block, 'logpush') +
        attribute(block, 'name', true) +
        attribute(block, 'observability') +
        attribute(block, 'references') +
        attribute(block, 'subdomain') +
        attribute(block, 'tags') +
        attribute(block, 'tail_consumers') +
        attribute(block, 'updated_on')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_on: resource.field(self._.blocks, 'created_on'),
      deployed_on: resource.field(self._.blocks, 'deployed_on'),
      id: resource.field(self._.blocks, 'id'),
      logpush: resource.field(self._.blocks, 'logpush'),
      name: resource.field(self._.blocks, 'name'),
      observability: resource.field(self._.blocks, 'observability'),
      references: resource.field(self._.blocks, 'references'),
      subdomain: resource.field(self._.blocks, 'subdomain'),
      tags: resource.field(self._.blocks, 'tags'),
      tail_consumers: resource.field(self._.blocks, 'tail_consumers'),
      updated_on: resource.field(self._.blocks, 'updated_on'),
    },
    worker_version(name, block): {
      local resource = blockType.resource('cloudflare_worker_version', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'annotations') +
        attribute(block, 'assets') +
        attribute(block, 'bindings') +
        attribute(block, 'compatibility_date') +
        attribute(block, 'compatibility_flags') +
        attribute(block, 'containers') +
        attribute(block, 'created_on') +
        attribute(block, 'id') +
        attribute(block, 'limits') +
        attribute(block, 'main_module') +
        attribute(block, 'main_script_base64') +
        attribute(block, 'migration_tag') +
        attribute(block, 'migrations') +
        attribute(block, 'modules') +
        attribute(block, 'number') +
        attribute(block, 'placement') +
        attribute(block, 'source') +
        attribute(block, 'startup_time_ms') +
        attribute(block, 'urls') +
        attribute(block, 'usage_model') +
        attribute(block, 'worker_id', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      annotations: resource.field(self._.blocks, 'annotations'),
      assets: resource.field(self._.blocks, 'assets'),
      bindings: resource.field(self._.blocks, 'bindings'),
      compatibility_date: resource.field(self._.blocks, 'compatibility_date'),
      compatibility_flags: resource.field(self._.blocks, 'compatibility_flags'),
      containers: resource.field(self._.blocks, 'containers'),
      created_on: resource.field(self._.blocks, 'created_on'),
      id: resource.field(self._.blocks, 'id'),
      limits: resource.field(self._.blocks, 'limits'),
      main_module: resource.field(self._.blocks, 'main_module'),
      main_script_base64: resource.field(self._.blocks, 'main_script_base64'),
      migration_tag: resource.field(self._.blocks, 'migration_tag'),
      migrations: resource.field(self._.blocks, 'migrations'),
      modules: resource.field(self._.blocks, 'modules'),
      number: resource.field(self._.blocks, 'number'),
      placement: resource.field(self._.blocks, 'placement'),
      source: resource.field(self._.blocks, 'source'),
      startup_time_ms: resource.field(self._.blocks, 'startup_time_ms'),
      urls: resource.field(self._.blocks, 'urls'),
      usage_model: resource.field(self._.blocks, 'usage_model'),
      worker_id: resource.field(self._.blocks, 'worker_id'),
    },
    workers_cron_trigger(name, block): {
      local resource = blockType.resource('cloudflare_workers_cron_trigger', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'id') +
        attribute(block, 'schedules', true) +
        attribute(block, 'script_name', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      id: resource.field(self._.blocks, 'id'),
      schedules: resource.field(self._.blocks, 'schedules'),
      script_name: resource.field(self._.blocks, 'script_name'),
    },
    workers_custom_domain(name, block): {
      local resource = blockType.resource('cloudflare_workers_custom_domain', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'cert_id') +
        attribute(block, 'environment') +
        attribute(block, 'hostname', true) +
        attribute(block, 'id') +
        attribute(block, 'service', true) +
        attribute(block, 'zone_id') +
        attribute(block, 'zone_name')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      cert_id: resource.field(self._.blocks, 'cert_id'),
      environment: resource.field(self._.blocks, 'environment'),
      hostname: resource.field(self._.blocks, 'hostname'),
      id: resource.field(self._.blocks, 'id'),
      service: resource.field(self._.blocks, 'service'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
      zone_name: resource.field(self._.blocks, 'zone_name'),
    },
    workers_deployment(name, block): {
      local resource = blockType.resource('cloudflare_workers_deployment', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'annotations') +
        attribute(block, 'author_email') +
        attribute(block, 'created_on') +
        attribute(block, 'id') +
        attribute(block, 'script_name', true) +
        attribute(block, 'source') +
        attribute(block, 'strategy', true) +
        attribute(block, 'versions', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      annotations: resource.field(self._.blocks, 'annotations'),
      author_email: resource.field(self._.blocks, 'author_email'),
      created_on: resource.field(self._.blocks, 'created_on'),
      id: resource.field(self._.blocks, 'id'),
      script_name: resource.field(self._.blocks, 'script_name'),
      source: resource.field(self._.blocks, 'source'),
      strategy: resource.field(self._.blocks, 'strategy'),
      versions: resource.field(self._.blocks, 'versions'),
    },
    workers_for_platforms_dispatch_namespace(name, block): {
      local resource = blockType.resource('cloudflare_workers_for_platforms_dispatch_namespace', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_by') +
        attribute(block, 'created_on') +
        attribute(block, 'id') +
        attribute(block, 'modified_by') +
        attribute(block, 'modified_on') +
        attribute(block, 'name') +
        attribute(block, 'namespace_id') +
        attribute(block, 'namespace_name') +
        attribute(block, 'script_count') +
        attribute(block, 'trusted_workers')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_by: resource.field(self._.blocks, 'created_by'),
      created_on: resource.field(self._.blocks, 'created_on'),
      id: resource.field(self._.blocks, 'id'),
      modified_by: resource.field(self._.blocks, 'modified_by'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      namespace_id: resource.field(self._.blocks, 'namespace_id'),
      namespace_name: resource.field(self._.blocks, 'namespace_name'),
      script_count: resource.field(self._.blocks, 'script_count'),
      trusted_workers: resource.field(self._.blocks, 'trusted_workers'),
    },
    workers_kv(name, block): {
      local resource = blockType.resource('cloudflare_workers_kv', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'id') +
        attribute(block, 'key_name', true) +
        attribute(block, 'metadata') +
        attribute(block, 'namespace_id', true) +
        attribute(block, 'value', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      id: resource.field(self._.blocks, 'id'),
      key_name: resource.field(self._.blocks, 'key_name'),
      metadata: resource.field(self._.blocks, 'metadata'),
      namespace_id: resource.field(self._.blocks, 'namespace_id'),
      value: resource.field(self._.blocks, 'value'),
    },
    workers_kv_namespace(name, block): {
      local resource = blockType.resource('cloudflare_workers_kv_namespace', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'id') +
        attribute(block, 'supports_url_encoding') +
        attribute(block, 'title', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      id: resource.field(self._.blocks, 'id'),
      supports_url_encoding: resource.field(self._.blocks, 'supports_url_encoding'),
      title: resource.field(self._.blocks, 'title'),
    },
    workers_route(name, block): {
      local resource = blockType.resource('cloudflare_workers_route', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'pattern', true) +
        attribute(block, 'script') +
        attribute(block, 'zone_id')
      ),
      id: resource.field(self._.blocks, 'id'),
      pattern: resource.field(self._.blocks, 'pattern'),
      script: resource.field(self._.blocks, 'script'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    workers_script(name, block): {
      local resource = blockType.resource('cloudflare_workers_script', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'annotations') +
        attribute(block, 'assets') +
        attribute(block, 'bindings') +
        attribute(block, 'body_part') +
        attribute(block, 'compatibility_date') +
        attribute(block, 'compatibility_flags') +
        attribute(block, 'content') +
        attribute(block, 'content_file') +
        attribute(block, 'content_sha256') +
        attribute(block, 'content_type') +
        attribute(block, 'created_on') +
        attribute(block, 'etag') +
        attribute(block, 'handlers') +
        attribute(block, 'has_assets') +
        attribute(block, 'has_modules') +
        attribute(block, 'id') +
        attribute(block, 'keep_assets') +
        attribute(block, 'keep_bindings') +
        attribute(block, 'last_deployed_from') +
        attribute(block, 'limits') +
        attribute(block, 'logpush') +
        attribute(block, 'main_module') +
        attribute(block, 'migration_tag') +
        attribute(block, 'migrations') +
        attribute(block, 'modified_on') +
        attribute(block, 'named_handlers') +
        attribute(block, 'observability') +
        attribute(block, 'placement') +
        attribute(block, 'placement_mode') +
        attribute(block, 'placement_status') +
        attribute(block, 'script_name', true) +
        attribute(block, 'startup_time_ms') +
        attribute(block, 'tail_consumers') +
        attribute(block, 'usage_model')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      annotations: resource.field(self._.blocks, 'annotations'),
      assets: resource.field(self._.blocks, 'assets'),
      bindings: resource.field(self._.blocks, 'bindings'),
      body_part: resource.field(self._.blocks, 'body_part'),
      compatibility_date: resource.field(self._.blocks, 'compatibility_date'),
      compatibility_flags: resource.field(self._.blocks, 'compatibility_flags'),
      content: resource.field(self._.blocks, 'content'),
      content_file: resource.field(self._.blocks, 'content_file'),
      content_sha256: resource.field(self._.blocks, 'content_sha256'),
      content_type: resource.field(self._.blocks, 'content_type'),
      created_on: resource.field(self._.blocks, 'created_on'),
      etag: resource.field(self._.blocks, 'etag'),
      handlers: resource.field(self._.blocks, 'handlers'),
      has_assets: resource.field(self._.blocks, 'has_assets'),
      has_modules: resource.field(self._.blocks, 'has_modules'),
      id: resource.field(self._.blocks, 'id'),
      keep_assets: resource.field(self._.blocks, 'keep_assets'),
      keep_bindings: resource.field(self._.blocks, 'keep_bindings'),
      last_deployed_from: resource.field(self._.blocks, 'last_deployed_from'),
      limits: resource.field(self._.blocks, 'limits'),
      logpush: resource.field(self._.blocks, 'logpush'),
      main_module: resource.field(self._.blocks, 'main_module'),
      migration_tag: resource.field(self._.blocks, 'migration_tag'),
      migrations: resource.field(self._.blocks, 'migrations'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      named_handlers: resource.field(self._.blocks, 'named_handlers'),
      observability: resource.field(self._.blocks, 'observability'),
      placement: resource.field(self._.blocks, 'placement'),
      placement_mode: resource.field(self._.blocks, 'placement_mode'),
      placement_status: resource.field(self._.blocks, 'placement_status'),
      script_name: resource.field(self._.blocks, 'script_name'),
      startup_time_ms: resource.field(self._.blocks, 'startup_time_ms'),
      tail_consumers: resource.field(self._.blocks, 'tail_consumers'),
      usage_model: resource.field(self._.blocks, 'usage_model'),
    },
    workers_script_subdomain(name, block): {
      local resource = blockType.resource('cloudflare_workers_script_subdomain', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'enabled', true) +
        attribute(block, 'id') +
        attribute(block, 'previews_enabled') +
        attribute(block, 'script_name', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      enabled: resource.field(self._.blocks, 'enabled'),
      id: resource.field(self._.blocks, 'id'),
      previews_enabled: resource.field(self._.blocks, 'previews_enabled'),
      script_name: resource.field(self._.blocks, 'script_name'),
    },
    workflow(name, block): {
      local resource = blockType.resource('cloudflare_workflow', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'class_name', true) +
        attribute(block, 'created_on') +
        attribute(block, 'id') +
        attribute(block, 'instances') +
        attribute(block, 'is_deleted') +
        attribute(block, 'limits') +
        attribute(block, 'modified_on') +
        attribute(block, 'name') +
        attribute(block, 'script_name', true) +
        attribute(block, 'terminator_running') +
        attribute(block, 'triggered_on') +
        attribute(block, 'version_id') +
        attribute(block, 'workflow_name', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      class_name: resource.field(self._.blocks, 'class_name'),
      created_on: resource.field(self._.blocks, 'created_on'),
      id: resource.field(self._.blocks, 'id'),
      instances: resource.field(self._.blocks, 'instances'),
      is_deleted: resource.field(self._.blocks, 'is_deleted'),
      limits: resource.field(self._.blocks, 'limits'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      script_name: resource.field(self._.blocks, 'script_name'),
      terminator_running: resource.field(self._.blocks, 'terminator_running'),
      triggered_on: resource.field(self._.blocks, 'triggered_on'),
      version_id: resource.field(self._.blocks, 'version_id'),
      workflow_name: resource.field(self._.blocks, 'workflow_name'),
    },
    zero_trust_access_ai_controls_mcp_portal(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_ai_controls_mcp_portal', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'allow_code_mode') +
        attribute(block, 'created_at') +
        attribute(block, 'created_by') +
        attribute(block, 'description') +
        attribute(block, 'hostname', true) +
        attribute(block, 'id', true) +
        attribute(block, 'modified_at') +
        attribute(block, 'modified_by') +
        attribute(block, 'name', true) +
        attribute(block, 'secure_web_gateway') +
        attribute(block, 'servers')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      allow_code_mode: resource.field(self._.blocks, 'allow_code_mode'),
      created_at: resource.field(self._.blocks, 'created_at'),
      created_by: resource.field(self._.blocks, 'created_by'),
      description: resource.field(self._.blocks, 'description'),
      hostname: resource.field(self._.blocks, 'hostname'),
      id: resource.field(self._.blocks, 'id'),
      modified_at: resource.field(self._.blocks, 'modified_at'),
      modified_by: resource.field(self._.blocks, 'modified_by'),
      name: resource.field(self._.blocks, 'name'),
      secure_web_gateway: resource.field(self._.blocks, 'secure_web_gateway'),
      servers: resource.field(self._.blocks, 'servers'),
    },
    zero_trust_access_ai_controls_mcp_server(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_ai_controls_mcp_server', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'auth_credentials') +
        attribute(block, 'auth_type', true) +
        attribute(block, 'created_at') +
        attribute(block, 'created_by') +
        attribute(block, 'description') +
        attribute(block, 'error') +
        attribute(block, 'hostname', true) +
        attribute(block, 'id', true) +
        attribute(block, 'last_successful_sync') +
        attribute(block, 'last_synced') +
        attribute(block, 'modified_at') +
        attribute(block, 'modified_by') +
        attribute(block, 'name', true) +
        attribute(block, 'prompts') +
        attribute(block, 'status') +
        attribute(block, 'tools') +
        attribute(block, 'updated_prompts') +
        attribute(block, 'updated_tools')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      auth_credentials: resource.field(self._.blocks, 'auth_credentials'),
      auth_type: resource.field(self._.blocks, 'auth_type'),
      created_at: resource.field(self._.blocks, 'created_at'),
      created_by: resource.field(self._.blocks, 'created_by'),
      description: resource.field(self._.blocks, 'description'),
      'error': resource.field(self._.blocks, 'error'),
      hostname: resource.field(self._.blocks, 'hostname'),
      id: resource.field(self._.blocks, 'id'),
      last_successful_sync: resource.field(self._.blocks, 'last_successful_sync'),
      last_synced: resource.field(self._.blocks, 'last_synced'),
      modified_at: resource.field(self._.blocks, 'modified_at'),
      modified_by: resource.field(self._.blocks, 'modified_by'),
      name: resource.field(self._.blocks, 'name'),
      prompts: resource.field(self._.blocks, 'prompts'),
      status: resource.field(self._.blocks, 'status'),
      tools: resource.field(self._.blocks, 'tools'),
      updated_prompts: resource.field(self._.blocks, 'updated_prompts'),
      updated_tools: resource.field(self._.blocks, 'updated_tools'),
    },
    zero_trust_access_application(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_application', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'allow_authenticate_via_warp') +
        attribute(block, 'allow_iframe') +
        attribute(block, 'allowed_idps') +
        attribute(block, 'app_launcher_logo_url') +
        attribute(block, 'app_launcher_visible') +
        attribute(block, 'aud') +
        attribute(block, 'auto_redirect_to_identity') +
        attribute(block, 'bg_color') +
        attribute(block, 'cors_headers') +
        attribute(block, 'custom_deny_message') +
        attribute(block, 'custom_deny_url') +
        attribute(block, 'custom_non_identity_deny_url') +
        attribute(block, 'custom_pages') +
        attribute(block, 'destinations') +
        attribute(block, 'domain') +
        attribute(block, 'enable_binding_cookie') +
        attribute(block, 'footer_links') +
        attribute(block, 'header_bg_color') +
        attribute(block, 'http_only_cookie_attribute') +
        attribute(block, 'id') +
        attribute(block, 'landing_page_design') +
        attribute(block, 'logo_url') +
        attribute(block, 'mfa_config') +
        attribute(block, 'name') +
        attribute(block, 'oauth_configuration') +
        attribute(block, 'options_preflight_bypass') +
        attribute(block, 'path_cookie_attribute') +
        attribute(block, 'policies') +
        attribute(block, 'read_service_tokens_from_header') +
        attribute(block, 'saas_app') +
        attribute(block, 'same_site_cookie_attribute') +
        attribute(block, 'scim_config') +
        attribute(block, 'self_hosted_domains') +
        attribute(block, 'service_auth_401_redirect') +
        attribute(block, 'session_duration') +
        attribute(block, 'skip_app_launcher_login_page') +
        attribute(block, 'skip_interstitial') +
        attribute(block, 'tags') +
        attribute(block, 'target_criteria') +
        attribute(block, 'type') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      allow_authenticate_via_warp: resource.field(self._.blocks, 'allow_authenticate_via_warp'),
      allow_iframe: resource.field(self._.blocks, 'allow_iframe'),
      allowed_idps: resource.field(self._.blocks, 'allowed_idps'),
      app_launcher_logo_url: resource.field(self._.blocks, 'app_launcher_logo_url'),
      app_launcher_visible: resource.field(self._.blocks, 'app_launcher_visible'),
      aud: resource.field(self._.blocks, 'aud'),
      auto_redirect_to_identity: resource.field(self._.blocks, 'auto_redirect_to_identity'),
      bg_color: resource.field(self._.blocks, 'bg_color'),
      cors_headers: resource.field(self._.blocks, 'cors_headers'),
      custom_deny_message: resource.field(self._.blocks, 'custom_deny_message'),
      custom_deny_url: resource.field(self._.blocks, 'custom_deny_url'),
      custom_non_identity_deny_url: resource.field(self._.blocks, 'custom_non_identity_deny_url'),
      custom_pages: resource.field(self._.blocks, 'custom_pages'),
      destinations: resource.field(self._.blocks, 'destinations'),
      domain: resource.field(self._.blocks, 'domain'),
      enable_binding_cookie: resource.field(self._.blocks, 'enable_binding_cookie'),
      footer_links: resource.field(self._.blocks, 'footer_links'),
      header_bg_color: resource.field(self._.blocks, 'header_bg_color'),
      http_only_cookie_attribute: resource.field(self._.blocks, 'http_only_cookie_attribute'),
      id: resource.field(self._.blocks, 'id'),
      landing_page_design: resource.field(self._.blocks, 'landing_page_design'),
      logo_url: resource.field(self._.blocks, 'logo_url'),
      mfa_config: resource.field(self._.blocks, 'mfa_config'),
      name: resource.field(self._.blocks, 'name'),
      oauth_configuration: resource.field(self._.blocks, 'oauth_configuration'),
      options_preflight_bypass: resource.field(self._.blocks, 'options_preflight_bypass'),
      path_cookie_attribute: resource.field(self._.blocks, 'path_cookie_attribute'),
      policies: resource.field(self._.blocks, 'policies'),
      read_service_tokens_from_header: resource.field(self._.blocks, 'read_service_tokens_from_header'),
      saas_app: resource.field(self._.blocks, 'saas_app'),
      same_site_cookie_attribute: resource.field(self._.blocks, 'same_site_cookie_attribute'),
      scim_config: resource.field(self._.blocks, 'scim_config'),
      self_hosted_domains: resource.field(self._.blocks, 'self_hosted_domains'),
      service_auth_401_redirect: resource.field(self._.blocks, 'service_auth_401_redirect'),
      session_duration: resource.field(self._.blocks, 'session_duration'),
      skip_app_launcher_login_page: resource.field(self._.blocks, 'skip_app_launcher_login_page'),
      skip_interstitial: resource.field(self._.blocks, 'skip_interstitial'),
      tags: resource.field(self._.blocks, 'tags'),
      target_criteria: resource.field(self._.blocks, 'target_criteria'),
      type: resource.field(self._.blocks, 'type'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zero_trust_access_custom_page(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_custom_page', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'custom_html', true) +
        attribute(block, 'id') +
        attribute(block, 'name', true) +
        attribute(block, 'type', true) +
        attribute(block, 'uid')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      custom_html: resource.field(self._.blocks, 'custom_html'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      type: resource.field(self._.blocks, 'type'),
      uid: resource.field(self._.blocks, 'uid'),
    },
    zero_trust_access_group(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_group', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'exclude') +
        attribute(block, 'id') +
        attribute(block, 'include', true) +
        attribute(block, 'is_default') +
        attribute(block, 'name', true) +
        attribute(block, 'require') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      exclude: resource.field(self._.blocks, 'exclude'),
      id: resource.field(self._.blocks, 'id'),
      include: resource.field(self._.blocks, 'include'),
      is_default: resource.field(self._.blocks, 'is_default'),
      name: resource.field(self._.blocks, 'name'),
      require: resource.field(self._.blocks, 'require'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zero_trust_access_identity_provider(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_identity_provider', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'config', true) +
        attribute(block, 'id') +
        attribute(block, 'name', true) +
        attribute(block, 'scim_config') +
        attribute(block, 'type', true) +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      config: resource.field(self._.blocks, 'config'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      scim_config: resource.field(self._.blocks, 'scim_config'),
      type: resource.field(self._.blocks, 'type'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zero_trust_access_infrastructure_target(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_infrastructure_target', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_at') +
        attribute(block, 'hostname', true) +
        attribute(block, 'id') +
        attribute(block, 'ip', true) +
        attribute(block, 'modified_at')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_at: resource.field(self._.blocks, 'created_at'),
      hostname: resource.field(self._.blocks, 'hostname'),
      id: resource.field(self._.blocks, 'id'),
      ip: resource.field(self._.blocks, 'ip'),
      modified_at: resource.field(self._.blocks, 'modified_at'),
    },
    zero_trust_access_key_configuration(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_key_configuration', name),
      _: resource._(
        block,
        attribute(block, 'account_id', true) +
        attribute(block, 'days_until_next_rotation') +
        attribute(block, 'id') +
        attribute(block, 'key_rotation_interval_days', true) +
        attribute(block, 'last_key_rotation_at')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      days_until_next_rotation: resource.field(self._.blocks, 'days_until_next_rotation'),
      id: resource.field(self._.blocks, 'id'),
      key_rotation_interval_days: resource.field(self._.blocks, 'key_rotation_interval_days'),
      last_key_rotation_at: resource.field(self._.blocks, 'last_key_rotation_at'),
    },
    zero_trust_access_mtls_certificate(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_mtls_certificate', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'associated_hostnames') +
        attribute(block, 'certificate', true) +
        attribute(block, 'expires_on') +
        attribute(block, 'fingerprint') +
        attribute(block, 'id') +
        attribute(block, 'name', true) +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      associated_hostnames: resource.field(self._.blocks, 'associated_hostnames'),
      certificate: resource.field(self._.blocks, 'certificate'),
      expires_on: resource.field(self._.blocks, 'expires_on'),
      fingerprint: resource.field(self._.blocks, 'fingerprint'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zero_trust_access_mtls_hostname_settings(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_mtls_hostname_settings', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'china_network') +
        attribute(block, 'client_certificate_forwarding') +
        attribute(block, 'hostname') +
        attribute(block, 'settings', true) +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      china_network: resource.field(self._.blocks, 'china_network'),
      client_certificate_forwarding: resource.field(self._.blocks, 'client_certificate_forwarding'),
      hostname: resource.field(self._.blocks, 'hostname'),
      settings: resource.field(self._.blocks, 'settings'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zero_trust_access_policy(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_policy', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'approval_groups') +
        attribute(block, 'approval_required') +
        attribute(block, 'connection_rules') +
        attribute(block, 'decision', true) +
        attribute(block, 'exclude') +
        attribute(block, 'id') +
        attribute(block, 'include') +
        attribute(block, 'isolation_required') +
        attribute(block, 'mfa_config') +
        attribute(block, 'name', true) +
        attribute(block, 'purpose_justification_prompt') +
        attribute(block, 'purpose_justification_required') +
        attribute(block, 'require') +
        attribute(block, 'session_duration')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      approval_groups: resource.field(self._.blocks, 'approval_groups'),
      approval_required: resource.field(self._.blocks, 'approval_required'),
      connection_rules: resource.field(self._.blocks, 'connection_rules'),
      decision: resource.field(self._.blocks, 'decision'),
      exclude: resource.field(self._.blocks, 'exclude'),
      id: resource.field(self._.blocks, 'id'),
      include: resource.field(self._.blocks, 'include'),
      isolation_required: resource.field(self._.blocks, 'isolation_required'),
      mfa_config: resource.field(self._.blocks, 'mfa_config'),
      name: resource.field(self._.blocks, 'name'),
      purpose_justification_prompt: resource.field(self._.blocks, 'purpose_justification_prompt'),
      purpose_justification_required: resource.field(self._.blocks, 'purpose_justification_required'),
      require: resource.field(self._.blocks, 'require'),
      session_duration: resource.field(self._.blocks, 'session_duration'),
    },
    zero_trust_access_service_token(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_service_token', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'client_id') +
        attribute(block, 'client_secret') +
        attribute(block, 'client_secret_version') +
        attribute(block, 'duration') +
        attribute(block, 'expires_at') +
        attribute(block, 'id') +
        attribute(block, 'name', true) +
        attribute(block, 'previous_client_secret_expires_at') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      client_id: resource.field(self._.blocks, 'client_id'),
      client_secret: resource.field(self._.blocks, 'client_secret'),
      client_secret_version: resource.field(self._.blocks, 'client_secret_version'),
      duration: resource.field(self._.blocks, 'duration'),
      expires_at: resource.field(self._.blocks, 'expires_at'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      previous_client_secret_expires_at: resource.field(self._.blocks, 'previous_client_secret_expires_at'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zero_trust_access_short_lived_certificate(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_short_lived_certificate', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'app_id', true) +
        attribute(block, 'aud') +
        attribute(block, 'id') +
        attribute(block, 'public_key') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      app_id: resource.field(self._.blocks, 'app_id'),
      aud: resource.field(self._.blocks, 'aud'),
      id: resource.field(self._.blocks, 'id'),
      public_key: resource.field(self._.blocks, 'public_key'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zero_trust_access_tag(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_tag', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'id') +
        attribute(block, 'name', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
    },
    zero_trust_device_custom_profile(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_device_custom_profile', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'allow_mode_switch') +
        attribute(block, 'allow_updates') +
        attribute(block, 'allowed_to_leave') +
        attribute(block, 'auto_connect') +
        attribute(block, 'captive_portal') +
        attribute(block, 'default') +
        attribute(block, 'description') +
        attribute(block, 'disable_auto_fallback') +
        attribute(block, 'enabled') +
        attribute(block, 'exclude') +
        attribute(block, 'exclude_office_ips') +
        attribute(block, 'fallback_domains') +
        attribute(block, 'gateway_unique_id') +
        attribute(block, 'id') +
        attribute(block, 'include') +
        attribute(block, 'lan_allow_minutes') +
        attribute(block, 'lan_allow_subnet_size') +
        attribute(block, 'match', true) +
        attribute(block, 'name', true) +
        attribute(block, 'policy_id') +
        attribute(block, 'precedence') +
        attribute(block, 'register_interface_ip_with_dns') +
        attribute(block, 'sccm_vpn_boundary_support') +
        attribute(block, 'service_mode_v2') +
        attribute(block, 'support_url') +
        attribute(block, 'switch_locked') +
        attribute(block, 'target_tests') +
        attribute(block, 'tunnel_protocol')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      allow_mode_switch: resource.field(self._.blocks, 'allow_mode_switch'),
      allow_updates: resource.field(self._.blocks, 'allow_updates'),
      allowed_to_leave: resource.field(self._.blocks, 'allowed_to_leave'),
      auto_connect: resource.field(self._.blocks, 'auto_connect'),
      captive_portal: resource.field(self._.blocks, 'captive_portal'),
      default: resource.field(self._.blocks, 'default'),
      description: resource.field(self._.blocks, 'description'),
      disable_auto_fallback: resource.field(self._.blocks, 'disable_auto_fallback'),
      enabled: resource.field(self._.blocks, 'enabled'),
      exclude: resource.field(self._.blocks, 'exclude'),
      exclude_office_ips: resource.field(self._.blocks, 'exclude_office_ips'),
      fallback_domains: resource.field(self._.blocks, 'fallback_domains'),
      gateway_unique_id: resource.field(self._.blocks, 'gateway_unique_id'),
      id: resource.field(self._.blocks, 'id'),
      include: resource.field(self._.blocks, 'include'),
      lan_allow_minutes: resource.field(self._.blocks, 'lan_allow_minutes'),
      lan_allow_subnet_size: resource.field(self._.blocks, 'lan_allow_subnet_size'),
      match: resource.field(self._.blocks, 'match'),
      name: resource.field(self._.blocks, 'name'),
      policy_id: resource.field(self._.blocks, 'policy_id'),
      precedence: resource.field(self._.blocks, 'precedence'),
      register_interface_ip_with_dns: resource.field(self._.blocks, 'register_interface_ip_with_dns'),
      sccm_vpn_boundary_support: resource.field(self._.blocks, 'sccm_vpn_boundary_support'),
      service_mode_v2: resource.field(self._.blocks, 'service_mode_v2'),
      support_url: resource.field(self._.blocks, 'support_url'),
      switch_locked: resource.field(self._.blocks, 'switch_locked'),
      target_tests: resource.field(self._.blocks, 'target_tests'),
      tunnel_protocol: resource.field(self._.blocks, 'tunnel_protocol'),
    },
    zero_trust_device_custom_profile_local_domain_fallback(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_device_custom_profile_local_domain_fallback', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'domains', true) +
        attribute(block, 'id') +
        attribute(block, 'policy_id', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      domains: resource.field(self._.blocks, 'domains'),
      id: resource.field(self._.blocks, 'id'),
      policy_id: resource.field(self._.blocks, 'policy_id'),
    },
    zero_trust_device_default_profile(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_device_default_profile', name),
      _: resource._(
        block,
        attribute(block, 'account_id', true) +
        attribute(block, 'allow_mode_switch') +
        attribute(block, 'allow_updates') +
        attribute(block, 'allowed_to_leave') +
        attribute(block, 'auto_connect') +
        attribute(block, 'captive_portal') +
        attribute(block, 'default') +
        attribute(block, 'disable_auto_fallback') +
        attribute(block, 'enabled') +
        attribute(block, 'exclude') +
        attribute(block, 'exclude_office_ips') +
        attribute(block, 'fallback_domains') +
        attribute(block, 'gateway_unique_id') +
        attribute(block, 'id') +
        attribute(block, 'include') +
        attribute(block, 'lan_allow_minutes') +
        attribute(block, 'lan_allow_subnet_size') +
        attribute(block, 'policy_id') +
        attribute(block, 'register_interface_ip_with_dns') +
        attribute(block, 'sccm_vpn_boundary_support') +
        attribute(block, 'service_mode_v2') +
        attribute(block, 'support_url') +
        attribute(block, 'switch_locked') +
        attribute(block, 'tunnel_protocol')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      allow_mode_switch: resource.field(self._.blocks, 'allow_mode_switch'),
      allow_updates: resource.field(self._.blocks, 'allow_updates'),
      allowed_to_leave: resource.field(self._.blocks, 'allowed_to_leave'),
      auto_connect: resource.field(self._.blocks, 'auto_connect'),
      captive_portal: resource.field(self._.blocks, 'captive_portal'),
      default: resource.field(self._.blocks, 'default'),
      disable_auto_fallback: resource.field(self._.blocks, 'disable_auto_fallback'),
      enabled: resource.field(self._.blocks, 'enabled'),
      exclude: resource.field(self._.blocks, 'exclude'),
      exclude_office_ips: resource.field(self._.blocks, 'exclude_office_ips'),
      fallback_domains: resource.field(self._.blocks, 'fallback_domains'),
      gateway_unique_id: resource.field(self._.blocks, 'gateway_unique_id'),
      id: resource.field(self._.blocks, 'id'),
      include: resource.field(self._.blocks, 'include'),
      lan_allow_minutes: resource.field(self._.blocks, 'lan_allow_minutes'),
      lan_allow_subnet_size: resource.field(self._.blocks, 'lan_allow_subnet_size'),
      policy_id: resource.field(self._.blocks, 'policy_id'),
      register_interface_ip_with_dns: resource.field(self._.blocks, 'register_interface_ip_with_dns'),
      sccm_vpn_boundary_support: resource.field(self._.blocks, 'sccm_vpn_boundary_support'),
      service_mode_v2: resource.field(self._.blocks, 'service_mode_v2'),
      support_url: resource.field(self._.blocks, 'support_url'),
      switch_locked: resource.field(self._.blocks, 'switch_locked'),
      tunnel_protocol: resource.field(self._.blocks, 'tunnel_protocol'),
    },
    zero_trust_device_default_profile_certificates(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_device_default_profile_certificates', name),
      _: resource._(
        block,
        attribute(block, 'enabled', true) +
        attribute(block, 'zone_id')
      ),
      enabled: resource.field(self._.blocks, 'enabled'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zero_trust_device_default_profile_local_domain_fallback(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_device_default_profile_local_domain_fallback', name),
      _: resource._(
        block,
        attribute(block, 'account_id', true) +
        attribute(block, 'domains', true) +
        attribute(block, 'id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      domains: resource.field(self._.blocks, 'domains'),
      id: resource.field(self._.blocks, 'id'),
    },
    zero_trust_device_ip_profile(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_device_ip_profile', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_at') +
        attribute(block, 'description') +
        attribute(block, 'enabled') +
        attribute(block, 'id') +
        attribute(block, 'match', true) +
        attribute(block, 'name', true) +
        attribute(block, 'precedence', true) +
        attribute(block, 'subnet_id', true) +
        attribute(block, 'updated_at')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_at: resource.field(self._.blocks, 'created_at'),
      description: resource.field(self._.blocks, 'description'),
      enabled: resource.field(self._.blocks, 'enabled'),
      id: resource.field(self._.blocks, 'id'),
      match: resource.field(self._.blocks, 'match'),
      name: resource.field(self._.blocks, 'name'),
      precedence: resource.field(self._.blocks, 'precedence'),
      subnet_id: resource.field(self._.blocks, 'subnet_id'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
    },
    zero_trust_device_managed_networks(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_device_managed_networks', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'config', true) +
        attribute(block, 'id') +
        attribute(block, 'name', true) +
        attribute(block, 'network_id') +
        attribute(block, 'type', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      config: resource.field(self._.blocks, 'config'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      network_id: resource.field(self._.blocks, 'network_id'),
      type: resource.field(self._.blocks, 'type'),
    },
    zero_trust_device_posture_integration(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_device_posture_integration', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'config', true) +
        attribute(block, 'id') +
        attribute(block, 'interval', true) +
        attribute(block, 'name', true) +
        attribute(block, 'type', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      config: resource.field(self._.blocks, 'config'),
      id: resource.field(self._.blocks, 'id'),
      interval: resource.field(self._.blocks, 'interval'),
      name: resource.field(self._.blocks, 'name'),
      type: resource.field(self._.blocks, 'type'),
    },
    zero_trust_device_posture_rule(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_device_posture_rule', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'description') +
        attribute(block, 'expiration') +
        attribute(block, 'id') +
        attribute(block, 'input') +
        attribute(block, 'match') +
        attribute(block, 'name') +
        attribute(block, 'schedule') +
        attribute(block, 'type', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      description: resource.field(self._.blocks, 'description'),
      expiration: resource.field(self._.blocks, 'expiration'),
      id: resource.field(self._.blocks, 'id'),
      input: resource.field(self._.blocks, 'input'),
      match: resource.field(self._.blocks, 'match'),
      name: resource.field(self._.blocks, 'name'),
      schedule: resource.field(self._.blocks, 'schedule'),
      type: resource.field(self._.blocks, 'type'),
    },
    zero_trust_device_settings(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_device_settings', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'disable_for_time') +
        attribute(block, 'external_emergency_signal_enabled') +
        attribute(block, 'external_emergency_signal_fingerprint') +
        attribute(block, 'external_emergency_signal_interval') +
        attribute(block, 'external_emergency_signal_url') +
        attribute(block, 'gateway_proxy_enabled') +
        attribute(block, 'gateway_udp_proxy_enabled') +
        attribute(block, 'root_certificate_installation_enabled') +
        attribute(block, 'use_zt_virtual_ip')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      disable_for_time: resource.field(self._.blocks, 'disable_for_time'),
      external_emergency_signal_enabled: resource.field(self._.blocks, 'external_emergency_signal_enabled'),
      external_emergency_signal_fingerprint: resource.field(self._.blocks, 'external_emergency_signal_fingerprint'),
      external_emergency_signal_interval: resource.field(self._.blocks, 'external_emergency_signal_interval'),
      external_emergency_signal_url: resource.field(self._.blocks, 'external_emergency_signal_url'),
      gateway_proxy_enabled: resource.field(self._.blocks, 'gateway_proxy_enabled'),
      gateway_udp_proxy_enabled: resource.field(self._.blocks, 'gateway_udp_proxy_enabled'),
      root_certificate_installation_enabled: resource.field(self._.blocks, 'root_certificate_installation_enabled'),
      use_zt_virtual_ip: resource.field(self._.blocks, 'use_zt_virtual_ip'),
    },
    zero_trust_device_subnet(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_device_subnet', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'comment') +
        attribute(block, 'created_at') +
        attribute(block, 'deleted_at') +
        attribute(block, 'id') +
        attribute(block, 'is_default_network') +
        attribute(block, 'name', true) +
        attribute(block, 'network', true) +
        attribute(block, 'subnet_type')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      comment: resource.field(self._.blocks, 'comment'),
      created_at: resource.field(self._.blocks, 'created_at'),
      deleted_at: resource.field(self._.blocks, 'deleted_at'),
      id: resource.field(self._.blocks, 'id'),
      is_default_network: resource.field(self._.blocks, 'is_default_network'),
      name: resource.field(self._.blocks, 'name'),
      network: resource.field(self._.blocks, 'network'),
      subnet_type: resource.field(self._.blocks, 'subnet_type'),
    },
    zero_trust_dex_rule(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dex_rule', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_at') +
        attribute(block, 'description') +
        attribute(block, 'id') +
        attribute(block, 'match', true) +
        attribute(block, 'name', true) +
        attribute(block, 'targeted_tests') +
        attribute(block, 'updated_at')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_at: resource.field(self._.blocks, 'created_at'),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      match: resource.field(self._.blocks, 'match'),
      name: resource.field(self._.blocks, 'name'),
      targeted_tests: resource.field(self._.blocks, 'targeted_tests'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
    },
    zero_trust_dex_test(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dex_test', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'data', true) +
        attribute(block, 'description') +
        attribute(block, 'enabled', true) +
        attribute(block, 'id') +
        attribute(block, 'interval', true) +
        attribute(block, 'name', true) +
        attribute(block, 'target_policies') +
        attribute(block, 'targeted') +
        attribute(block, 'test_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      data: resource.field(self._.blocks, 'data'),
      description: resource.field(self._.blocks, 'description'),
      enabled: resource.field(self._.blocks, 'enabled'),
      id: resource.field(self._.blocks, 'id'),
      interval: resource.field(self._.blocks, 'interval'),
      name: resource.field(self._.blocks, 'name'),
      target_policies: resource.field(self._.blocks, 'target_policies'),
      targeted: resource.field(self._.blocks, 'targeted'),
      test_id: resource.field(self._.blocks, 'test_id'),
    },
    zero_trust_dlp_custom_entry(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dlp_custom_entry', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'case_sensitive') +
        attribute(block, 'confidence') +
        attribute(block, 'created_at') +
        attribute(block, 'description') +
        attribute(block, 'enabled', true) +
        attribute(block, 'id') +
        attribute(block, 'name', true) +
        attribute(block, 'pattern', true) +
        attribute(block, 'profile_id') +
        attribute(block, 'profiles') +
        attribute(block, 'secret') +
        attribute(block, 'type') +
        attribute(block, 'updated_at') +
        attribute(block, 'upload_status') +
        attribute(block, 'variant') +
        attribute(block, 'word_list')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      case_sensitive: resource.field(self._.blocks, 'case_sensitive'),
      confidence: resource.field(self._.blocks, 'confidence'),
      created_at: resource.field(self._.blocks, 'created_at'),
      description: resource.field(self._.blocks, 'description'),
      enabled: resource.field(self._.blocks, 'enabled'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      pattern: resource.field(self._.blocks, 'pattern'),
      profile_id: resource.field(self._.blocks, 'profile_id'),
      profiles: resource.field(self._.blocks, 'profiles'),
      secret: resource.field(self._.blocks, 'secret'),
      type: resource.field(self._.blocks, 'type'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      upload_status: resource.field(self._.blocks, 'upload_status'),
      variant: resource.field(self._.blocks, 'variant'),
      word_list: resource.field(self._.blocks, 'word_list'),
    },
    zero_trust_dlp_custom_profile(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dlp_custom_profile', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'ai_context_enabled') +
        attribute(block, 'allowed_match_count') +
        attribute(block, 'confidence_threshold') +
        attribute(block, 'context_awareness') +
        attribute(block, 'created_at') +
        attribute(block, 'data_classes') +
        attribute(block, 'data_tags') +
        attribute(block, 'description') +
        attribute(block, 'entries') +
        attribute(block, 'id') +
        attribute(block, 'name', true) +
        attribute(block, 'ocr_enabled') +
        attribute(block, 'open_access') +
        attribute(block, 'sensitivity_levels') +
        attribute(block, 'shared_entries') +
        attribute(block, 'type') +
        attribute(block, 'updated_at')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      ai_context_enabled: resource.field(self._.blocks, 'ai_context_enabled'),
      allowed_match_count: resource.field(self._.blocks, 'allowed_match_count'),
      confidence_threshold: resource.field(self._.blocks, 'confidence_threshold'),
      context_awareness: resource.field(self._.blocks, 'context_awareness'),
      created_at: resource.field(self._.blocks, 'created_at'),
      data_classes: resource.field(self._.blocks, 'data_classes'),
      data_tags: resource.field(self._.blocks, 'data_tags'),
      description: resource.field(self._.blocks, 'description'),
      entries: resource.field(self._.blocks, 'entries'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      ocr_enabled: resource.field(self._.blocks, 'ocr_enabled'),
      open_access: resource.field(self._.blocks, 'open_access'),
      sensitivity_levels: resource.field(self._.blocks, 'sensitivity_levels'),
      shared_entries: resource.field(self._.blocks, 'shared_entries'),
      type: resource.field(self._.blocks, 'type'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
    },
    zero_trust_dlp_dataset(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dlp_dataset', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'case_sensitive') +
        attribute(block, 'columns') +
        attribute(block, 'created_at') +
        attribute(block, 'dataset') +
        attribute(block, 'dataset_id') +
        attribute(block, 'description') +
        attribute(block, 'encoding_version') +
        attribute(block, 'id') +
        attribute(block, 'max_cells') +
        attribute(block, 'name', true) +
        attribute(block, 'num_cells') +
        attribute(block, 'secret') +
        attribute(block, 'status') +
        attribute(block, 'updated_at') +
        attribute(block, 'uploads') +
        attribute(block, 'version')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      case_sensitive: resource.field(self._.blocks, 'case_sensitive'),
      columns: resource.field(self._.blocks, 'columns'),
      created_at: resource.field(self._.blocks, 'created_at'),
      dataset: resource.field(self._.blocks, 'dataset'),
      dataset_id: resource.field(self._.blocks, 'dataset_id'),
      description: resource.field(self._.blocks, 'description'),
      encoding_version: resource.field(self._.blocks, 'encoding_version'),
      id: resource.field(self._.blocks, 'id'),
      max_cells: resource.field(self._.blocks, 'max_cells'),
      name: resource.field(self._.blocks, 'name'),
      num_cells: resource.field(self._.blocks, 'num_cells'),
      secret: resource.field(self._.blocks, 'secret'),
      status: resource.field(self._.blocks, 'status'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      uploads: resource.field(self._.blocks, 'uploads'),
      version: resource.field(self._.blocks, 'version'),
    },
    zero_trust_dlp_entry(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dlp_entry', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'case_sensitive') +
        attribute(block, 'confidence') +
        attribute(block, 'created_at') +
        attribute(block, 'description') +
        attribute(block, 'enabled', true) +
        attribute(block, 'id') +
        attribute(block, 'name', true) +
        attribute(block, 'pattern', true) +
        attribute(block, 'profile_id') +
        attribute(block, 'profiles') +
        attribute(block, 'secret') +
        attribute(block, 'type') +
        attribute(block, 'updated_at') +
        attribute(block, 'upload_status') +
        attribute(block, 'variant') +
        attribute(block, 'word_list')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      case_sensitive: resource.field(self._.blocks, 'case_sensitive'),
      confidence: resource.field(self._.blocks, 'confidence'),
      created_at: resource.field(self._.blocks, 'created_at'),
      description: resource.field(self._.blocks, 'description'),
      enabled: resource.field(self._.blocks, 'enabled'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      pattern: resource.field(self._.blocks, 'pattern'),
      profile_id: resource.field(self._.blocks, 'profile_id'),
      profiles: resource.field(self._.blocks, 'profiles'),
      secret: resource.field(self._.blocks, 'secret'),
      type: resource.field(self._.blocks, 'type'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      upload_status: resource.field(self._.blocks, 'upload_status'),
      variant: resource.field(self._.blocks, 'variant'),
      word_list: resource.field(self._.blocks, 'word_list'),
    },
    zero_trust_dlp_integration_entry(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dlp_integration_entry', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'case_sensitive') +
        attribute(block, 'confidence') +
        attribute(block, 'created_at') +
        attribute(block, 'description') +
        attribute(block, 'enabled', true) +
        attribute(block, 'entry_id', true) +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'pattern') +
        attribute(block, 'profile_id') +
        attribute(block, 'profiles') +
        attribute(block, 'secret') +
        attribute(block, 'type') +
        attribute(block, 'updated_at') +
        attribute(block, 'upload_status') +
        attribute(block, 'variant') +
        attribute(block, 'word_list')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      case_sensitive: resource.field(self._.blocks, 'case_sensitive'),
      confidence: resource.field(self._.blocks, 'confidence'),
      created_at: resource.field(self._.blocks, 'created_at'),
      description: resource.field(self._.blocks, 'description'),
      enabled: resource.field(self._.blocks, 'enabled'),
      entry_id: resource.field(self._.blocks, 'entry_id'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      pattern: resource.field(self._.blocks, 'pattern'),
      profile_id: resource.field(self._.blocks, 'profile_id'),
      profiles: resource.field(self._.blocks, 'profiles'),
      secret: resource.field(self._.blocks, 'secret'),
      type: resource.field(self._.blocks, 'type'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      upload_status: resource.field(self._.blocks, 'upload_status'),
      variant: resource.field(self._.blocks, 'variant'),
      word_list: resource.field(self._.blocks, 'word_list'),
    },
    zero_trust_dlp_predefined_entry(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dlp_predefined_entry', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'case_sensitive') +
        attribute(block, 'confidence') +
        attribute(block, 'created_at') +
        attribute(block, 'description') +
        attribute(block, 'enabled', true) +
        attribute(block, 'entry_id', true) +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'pattern') +
        attribute(block, 'profile_id') +
        attribute(block, 'profiles') +
        attribute(block, 'secret') +
        attribute(block, 'type') +
        attribute(block, 'updated_at') +
        attribute(block, 'upload_status') +
        attribute(block, 'variant') +
        attribute(block, 'word_list')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      case_sensitive: resource.field(self._.blocks, 'case_sensitive'),
      confidence: resource.field(self._.blocks, 'confidence'),
      created_at: resource.field(self._.blocks, 'created_at'),
      description: resource.field(self._.blocks, 'description'),
      enabled: resource.field(self._.blocks, 'enabled'),
      entry_id: resource.field(self._.blocks, 'entry_id'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      pattern: resource.field(self._.blocks, 'pattern'),
      profile_id: resource.field(self._.blocks, 'profile_id'),
      profiles: resource.field(self._.blocks, 'profiles'),
      secret: resource.field(self._.blocks, 'secret'),
      type: resource.field(self._.blocks, 'type'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      upload_status: resource.field(self._.blocks, 'upload_status'),
      variant: resource.field(self._.blocks, 'variant'),
      word_list: resource.field(self._.blocks, 'word_list'),
    },
    zero_trust_dlp_predefined_profile(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dlp_predefined_profile', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'ai_context_enabled') +
        attribute(block, 'allowed_match_count') +
        attribute(block, 'confidence_threshold') +
        attribute(block, 'enabled_entries') +
        attribute(block, 'entries') +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'ocr_enabled') +
        attribute(block, 'open_access') +
        attribute(block, 'profile_id', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      ai_context_enabled: resource.field(self._.blocks, 'ai_context_enabled'),
      allowed_match_count: resource.field(self._.blocks, 'allowed_match_count'),
      confidence_threshold: resource.field(self._.blocks, 'confidence_threshold'),
      enabled_entries: resource.field(self._.blocks, 'enabled_entries'),
      entries: resource.field(self._.blocks, 'entries'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      ocr_enabled: resource.field(self._.blocks, 'ocr_enabled'),
      open_access: resource.field(self._.blocks, 'open_access'),
      profile_id: resource.field(self._.blocks, 'profile_id'),
    },
    zero_trust_dlp_settings(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dlp_settings', name),
      _: resource._(
        block,
        attribute(block, 'account_id', true) +
        attribute(block, 'ai_context_analysis') +
        attribute(block, 'id') +
        attribute(block, 'ocr') +
        attribute(block, 'payload_logging')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      ai_context_analysis: resource.field(self._.blocks, 'ai_context_analysis'),
      id: resource.field(self._.blocks, 'id'),
      ocr: resource.field(self._.blocks, 'ocr'),
      payload_logging: resource.field(self._.blocks, 'payload_logging'),
    },
    zero_trust_dns_location(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dns_location', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'client_default') +
        attribute(block, 'created_at') +
        attribute(block, 'dns_destination_ips_id') +
        attribute(block, 'dns_destination_ipv6_block_id') +
        attribute(block, 'doh_subdomain') +
        attribute(block, 'ecs_support') +
        attribute(block, 'endpoints') +
        attribute(block, 'id') +
        attribute(block, 'ip') +
        attribute(block, 'ipv4_destination') +
        attribute(block, 'ipv4_destination_backup') +
        attribute(block, 'name', true) +
        attribute(block, 'networks') +
        attribute(block, 'updated_at')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      client_default: resource.field(self._.blocks, 'client_default'),
      created_at: resource.field(self._.blocks, 'created_at'),
      dns_destination_ips_id: resource.field(self._.blocks, 'dns_destination_ips_id'),
      dns_destination_ipv6_block_id: resource.field(self._.blocks, 'dns_destination_ipv6_block_id'),
      doh_subdomain: resource.field(self._.blocks, 'doh_subdomain'),
      ecs_support: resource.field(self._.blocks, 'ecs_support'),
      endpoints: resource.field(self._.blocks, 'endpoints'),
      id: resource.field(self._.blocks, 'id'),
      ip: resource.field(self._.blocks, 'ip'),
      ipv4_destination: resource.field(self._.blocks, 'ipv4_destination'),
      ipv4_destination_backup: resource.field(self._.blocks, 'ipv4_destination_backup'),
      name: resource.field(self._.blocks, 'name'),
      networks: resource.field(self._.blocks, 'networks'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
    },
    zero_trust_gateway_certificate(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_gateway_certificate', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'activate') +
        attribute(block, 'binding_status') +
        attribute(block, 'certificate') +
        attribute(block, 'created_at') +
        attribute(block, 'expires_on') +
        attribute(block, 'fingerprint') +
        attribute(block, 'id') +
        attribute(block, 'in_use') +
        attribute(block, 'issuer_org') +
        attribute(block, 'issuer_raw') +
        attribute(block, 'type') +
        attribute(block, 'updated_at') +
        attribute(block, 'uploaded_on') +
        attribute(block, 'validity_period_days')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      activate: resource.field(self._.blocks, 'activate'),
      binding_status: resource.field(self._.blocks, 'binding_status'),
      certificate: resource.field(self._.blocks, 'certificate'),
      created_at: resource.field(self._.blocks, 'created_at'),
      expires_on: resource.field(self._.blocks, 'expires_on'),
      fingerprint: resource.field(self._.blocks, 'fingerprint'),
      id: resource.field(self._.blocks, 'id'),
      in_use: resource.field(self._.blocks, 'in_use'),
      issuer_org: resource.field(self._.blocks, 'issuer_org'),
      issuer_raw: resource.field(self._.blocks, 'issuer_raw'),
      type: resource.field(self._.blocks, 'type'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      uploaded_on: resource.field(self._.blocks, 'uploaded_on'),
      validity_period_days: resource.field(self._.blocks, 'validity_period_days'),
    },
    zero_trust_gateway_logging(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_gateway_logging', name),
      _: resource._(
        block,
        attribute(block, 'account_id', true) +
        attribute(block, 'id') +
        attribute(block, 'redact_pii') +
        attribute(block, 'settings_by_rule_type')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      id: resource.field(self._.blocks, 'id'),
      redact_pii: resource.field(self._.blocks, 'redact_pii'),
      settings_by_rule_type: resource.field(self._.blocks, 'settings_by_rule_type'),
    },
    zero_trust_gateway_pacfile(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_gateway_pacfile', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'contents', true) +
        attribute(block, 'created_at') +
        attribute(block, 'description') +
        attribute(block, 'id') +
        attribute(block, 'name', true) +
        attribute(block, 'slug') +
        attribute(block, 'updated_at') +
        attribute(block, 'url')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      contents: resource.field(self._.blocks, 'contents'),
      created_at: resource.field(self._.blocks, 'created_at'),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      slug: resource.field(self._.blocks, 'slug'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      url: resource.field(self._.blocks, 'url'),
    },
    zero_trust_gateway_policy(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_gateway_policy', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'action', true) +
        attribute(block, 'created_at') +
        attribute(block, 'deleted_at') +
        attribute(block, 'description') +
        attribute(block, 'device_posture') +
        attribute(block, 'enabled') +
        attribute(block, 'expiration') +
        attribute(block, 'filters') +
        attribute(block, 'id') +
        attribute(block, 'identity') +
        attribute(block, 'name', true) +
        attribute(block, 'precedence') +
        attribute(block, 'read_only') +
        attribute(block, 'rule_settings') +
        attribute(block, 'schedule') +
        attribute(block, 'sharable') +
        attribute(block, 'source_account') +
        attribute(block, 'traffic') +
        attribute(block, 'updated_at') +
        attribute(block, 'version') +
        attribute(block, 'warning_status')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      action: resource.field(self._.blocks, 'action'),
      created_at: resource.field(self._.blocks, 'created_at'),
      deleted_at: resource.field(self._.blocks, 'deleted_at'),
      description: resource.field(self._.blocks, 'description'),
      device_posture: resource.field(self._.blocks, 'device_posture'),
      enabled: resource.field(self._.blocks, 'enabled'),
      expiration: resource.field(self._.blocks, 'expiration'),
      filters: resource.field(self._.blocks, 'filters'),
      id: resource.field(self._.blocks, 'id'),
      identity: resource.field(self._.blocks, 'identity'),
      name: resource.field(self._.blocks, 'name'),
      precedence: resource.field(self._.blocks, 'precedence'),
      read_only: resource.field(self._.blocks, 'read_only'),
      rule_settings: resource.field(self._.blocks, 'rule_settings'),
      schedule: resource.field(self._.blocks, 'schedule'),
      sharable: resource.field(self._.blocks, 'sharable'),
      source_account: resource.field(self._.blocks, 'source_account'),
      traffic: resource.field(self._.blocks, 'traffic'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      version: resource.field(self._.blocks, 'version'),
      warning_status: resource.field(self._.blocks, 'warning_status'),
    },
    zero_trust_gateway_proxy_endpoint(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_gateway_proxy_endpoint', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_at') +
        attribute(block, 'id') +
        attribute(block, 'ips') +
        attribute(block, 'kind') +
        attribute(block, 'name', true) +
        attribute(block, 'subdomain') +
        attribute(block, 'updated_at')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_at: resource.field(self._.blocks, 'created_at'),
      id: resource.field(self._.blocks, 'id'),
      ips: resource.field(self._.blocks, 'ips'),
      kind: resource.field(self._.blocks, 'kind'),
      name: resource.field(self._.blocks, 'name'),
      subdomain: resource.field(self._.blocks, 'subdomain'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
    },
    zero_trust_gateway_settings(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_gateway_settings', name),
      _: resource._(
        block,
        attribute(block, 'account_id', true) +
        attribute(block, 'created_at') +
        attribute(block, 'id') +
        attribute(block, 'settings') +
        attribute(block, 'updated_at')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_at: resource.field(self._.blocks, 'created_at'),
      id: resource.field(self._.blocks, 'id'),
      settings: resource.field(self._.blocks, 'settings'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
    },
    zero_trust_list(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_list', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_at') +
        attribute(block, 'description') +
        attribute(block, 'id') +
        attribute(block, 'items') +
        attribute(block, 'list_count') +
        attribute(block, 'name', true) +
        attribute(block, 'type', true) +
        attribute(block, 'updated_at')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_at: resource.field(self._.blocks, 'created_at'),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      items: resource.field(self._.blocks, 'items'),
      list_count: resource.field(self._.blocks, 'list_count'),
      name: resource.field(self._.blocks, 'name'),
      type: resource.field(self._.blocks, 'type'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
    },
    zero_trust_network_hostname_route(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_network_hostname_route', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'comment') +
        attribute(block, 'created_at') +
        attribute(block, 'deleted_at') +
        attribute(block, 'hostname') +
        attribute(block, 'id') +
        attribute(block, 'tunnel_id') +
        attribute(block, 'tunnel_name')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      comment: resource.field(self._.blocks, 'comment'),
      created_at: resource.field(self._.blocks, 'created_at'),
      deleted_at: resource.field(self._.blocks, 'deleted_at'),
      hostname: resource.field(self._.blocks, 'hostname'),
      id: resource.field(self._.blocks, 'id'),
      tunnel_id: resource.field(self._.blocks, 'tunnel_id'),
      tunnel_name: resource.field(self._.blocks, 'tunnel_name'),
    },
    zero_trust_organization(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_organization', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'allow_authenticate_via_warp') +
        attribute(block, 'auth_domain') +
        attribute(block, 'auto_redirect_to_identity') +
        attribute(block, 'custom_pages') +
        attribute(block, 'deny_unmatched_requests') +
        attribute(block, 'deny_unmatched_requests_exempted_zone_names') +
        attribute(block, 'is_ui_read_only') +
        attribute(block, 'login_design') +
        attribute(block, 'mfa_config') +
        attribute(block, 'mfa_configuration_allowed') +
        attribute(block, 'mfa_required_for_all_apps') +
        attribute(block, 'mfa_ssh_piv_key_requirements') +
        attribute(block, 'name') +
        attribute(block, 'session_duration') +
        attribute(block, 'ui_read_only_toggle_reason') +
        attribute(block, 'user_seat_expiration_inactive_time') +
        attribute(block, 'warp_auth_session_duration') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      allow_authenticate_via_warp: resource.field(self._.blocks, 'allow_authenticate_via_warp'),
      auth_domain: resource.field(self._.blocks, 'auth_domain'),
      auto_redirect_to_identity: resource.field(self._.blocks, 'auto_redirect_to_identity'),
      custom_pages: resource.field(self._.blocks, 'custom_pages'),
      deny_unmatched_requests: resource.field(self._.blocks, 'deny_unmatched_requests'),
      deny_unmatched_requests_exempted_zone_names: resource.field(self._.blocks, 'deny_unmatched_requests_exempted_zone_names'),
      is_ui_read_only: resource.field(self._.blocks, 'is_ui_read_only'),
      login_design: resource.field(self._.blocks, 'login_design'),
      mfa_config: resource.field(self._.blocks, 'mfa_config'),
      mfa_configuration_allowed: resource.field(self._.blocks, 'mfa_configuration_allowed'),
      mfa_required_for_all_apps: resource.field(self._.blocks, 'mfa_required_for_all_apps'),
      mfa_ssh_piv_key_requirements: resource.field(self._.blocks, 'mfa_ssh_piv_key_requirements'),
      name: resource.field(self._.blocks, 'name'),
      session_duration: resource.field(self._.blocks, 'session_duration'),
      ui_read_only_toggle_reason: resource.field(self._.blocks, 'ui_read_only_toggle_reason'),
      user_seat_expiration_inactive_time: resource.field(self._.blocks, 'user_seat_expiration_inactive_time'),
      warp_auth_session_duration: resource.field(self._.blocks, 'warp_auth_session_duration'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zero_trust_risk_behavior(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_risk_behavior', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'behaviors', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      behaviors: resource.field(self._.blocks, 'behaviors'),
    },
    zero_trust_risk_scoring_integration(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_risk_scoring_integration', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'account_tag') +
        attribute(block, 'active') +
        attribute(block, 'created_at') +
        attribute(block, 'id') +
        attribute(block, 'integration_type', true) +
        attribute(block, 'reference_id') +
        attribute(block, 'tenant_url', true) +
        attribute(block, 'well_known_url')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      account_tag: resource.field(self._.blocks, 'account_tag'),
      active: resource.field(self._.blocks, 'active'),
      created_at: resource.field(self._.blocks, 'created_at'),
      id: resource.field(self._.blocks, 'id'),
      integration_type: resource.field(self._.blocks, 'integration_type'),
      reference_id: resource.field(self._.blocks, 'reference_id'),
      tenant_url: resource.field(self._.blocks, 'tenant_url'),
      well_known_url: resource.field(self._.blocks, 'well_known_url'),
    },
    zero_trust_tunnel_cloudflared(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_tunnel_cloudflared', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'account_tag') +
        attribute(block, 'config_src') +
        attribute(block, 'connections') +
        attribute(block, 'conns_active_at') +
        attribute(block, 'conns_inactive_at') +
        attribute(block, 'created_at') +
        attribute(block, 'deleted_at') +
        attribute(block, 'id') +
        attribute(block, 'metadata') +
        attribute(block, 'name', true) +
        attribute(block, 'remote_config') +
        attribute(block, 'status') +
        attribute(block, 'tun_type') +
        attribute(block, 'tunnel_secret')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      account_tag: resource.field(self._.blocks, 'account_tag'),
      config_src: resource.field(self._.blocks, 'config_src'),
      connections: resource.field(self._.blocks, 'connections'),
      conns_active_at: resource.field(self._.blocks, 'conns_active_at'),
      conns_inactive_at: resource.field(self._.blocks, 'conns_inactive_at'),
      created_at: resource.field(self._.blocks, 'created_at'),
      deleted_at: resource.field(self._.blocks, 'deleted_at'),
      id: resource.field(self._.blocks, 'id'),
      metadata: resource.field(self._.blocks, 'metadata'),
      name: resource.field(self._.blocks, 'name'),
      remote_config: resource.field(self._.blocks, 'remote_config'),
      status: resource.field(self._.blocks, 'status'),
      tun_type: resource.field(self._.blocks, 'tun_type'),
      tunnel_secret: resource.field(self._.blocks, 'tunnel_secret'),
    },
    zero_trust_tunnel_cloudflared_config(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_tunnel_cloudflared_config', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'config') +
        attribute(block, 'created_at') +
        attribute(block, 'id') +
        attribute(block, 'source') +
        attribute(block, 'tunnel_id', true) +
        attribute(block, 'version')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      config: resource.field(self._.blocks, 'config'),
      created_at: resource.field(self._.blocks, 'created_at'),
      id: resource.field(self._.blocks, 'id'),
      source: resource.field(self._.blocks, 'source'),
      tunnel_id: resource.field(self._.blocks, 'tunnel_id'),
      version: resource.field(self._.blocks, 'version'),
    },
    zero_trust_tunnel_cloudflared_route(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_tunnel_cloudflared_route', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'comment') +
        attribute(block, 'created_at') +
        attribute(block, 'deleted_at') +
        attribute(block, 'id') +
        attribute(block, 'network', true) +
        attribute(block, 'tunnel_id', true) +
        attribute(block, 'virtual_network_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      comment: resource.field(self._.blocks, 'comment'),
      created_at: resource.field(self._.blocks, 'created_at'),
      deleted_at: resource.field(self._.blocks, 'deleted_at'),
      id: resource.field(self._.blocks, 'id'),
      network: resource.field(self._.blocks, 'network'),
      tunnel_id: resource.field(self._.blocks, 'tunnel_id'),
      virtual_network_id: resource.field(self._.blocks, 'virtual_network_id'),
    },
    zero_trust_tunnel_cloudflared_virtual_network(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_tunnel_cloudflared_virtual_network', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'comment') +
        attribute(block, 'created_at') +
        attribute(block, 'deleted_at') +
        attribute(block, 'id') +
        attribute(block, 'is_default') +
        attribute(block, 'is_default_network') +
        attribute(block, 'name', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      comment: resource.field(self._.blocks, 'comment'),
      created_at: resource.field(self._.blocks, 'created_at'),
      deleted_at: resource.field(self._.blocks, 'deleted_at'),
      id: resource.field(self._.blocks, 'id'),
      is_default: resource.field(self._.blocks, 'is_default'),
      is_default_network: resource.field(self._.blocks, 'is_default_network'),
      name: resource.field(self._.blocks, 'name'),
    },
    zero_trust_tunnel_warp_connector(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_tunnel_warp_connector', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'account_tag') +
        attribute(block, 'connections') +
        attribute(block, 'conns_active_at') +
        attribute(block, 'conns_inactive_at') +
        attribute(block, 'created_at') +
        attribute(block, 'deleted_at') +
        attribute(block, 'ha') +
        attribute(block, 'id') +
        attribute(block, 'metadata') +
        attribute(block, 'name', true) +
        attribute(block, 'status') +
        attribute(block, 'tun_type') +
        attribute(block, 'tunnel_secret')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      account_tag: resource.field(self._.blocks, 'account_tag'),
      connections: resource.field(self._.blocks, 'connections'),
      conns_active_at: resource.field(self._.blocks, 'conns_active_at'),
      conns_inactive_at: resource.field(self._.blocks, 'conns_inactive_at'),
      created_at: resource.field(self._.blocks, 'created_at'),
      deleted_at: resource.field(self._.blocks, 'deleted_at'),
      ha: resource.field(self._.blocks, 'ha'),
      id: resource.field(self._.blocks, 'id'),
      metadata: resource.field(self._.blocks, 'metadata'),
      name: resource.field(self._.blocks, 'name'),
      status: resource.field(self._.blocks, 'status'),
      tun_type: resource.field(self._.blocks, 'tun_type'),
      tunnel_secret: resource.field(self._.blocks, 'tunnel_secret'),
    },
    zone(name, block): {
      local resource = blockType.resource('cloudflare_zone', name),
      _: resource._(
        block,
        attribute(block, 'account', true) +
        attribute(block, 'activated_on') +
        attribute(block, 'cname_suffix') +
        attribute(block, 'created_on') +
        attribute(block, 'development_mode') +
        attribute(block, 'id') +
        attribute(block, 'meta') +
        attribute(block, 'modified_on') +
        attribute(block, 'name', true) +
        attribute(block, 'name_servers') +
        attribute(block, 'original_dnshost') +
        attribute(block, 'original_name_servers') +
        attribute(block, 'original_registrar') +
        attribute(block, 'owner') +
        attribute(block, 'paused') +
        attribute(block, 'permissions') +
        attribute(block, 'plan') +
        attribute(block, 'status') +
        attribute(block, 'tenant') +
        attribute(block, 'tenant_unit') +
        attribute(block, 'type') +
        attribute(block, 'vanity_name_servers') +
        attribute(block, 'verification_key')
      ),
      account: resource.field(self._.blocks, 'account'),
      activated_on: resource.field(self._.blocks, 'activated_on'),
      cname_suffix: resource.field(self._.blocks, 'cname_suffix'),
      created_on: resource.field(self._.blocks, 'created_on'),
      development_mode: resource.field(self._.blocks, 'development_mode'),
      id: resource.field(self._.blocks, 'id'),
      meta: resource.field(self._.blocks, 'meta'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      name_servers: resource.field(self._.blocks, 'name_servers'),
      original_dnshost: resource.field(self._.blocks, 'original_dnshost'),
      original_name_servers: resource.field(self._.blocks, 'original_name_servers'),
      original_registrar: resource.field(self._.blocks, 'original_registrar'),
      owner: resource.field(self._.blocks, 'owner'),
      paused: resource.field(self._.blocks, 'paused'),
      permissions: resource.field(self._.blocks, 'permissions'),
      plan: resource.field(self._.blocks, 'plan'),
      status: resource.field(self._.blocks, 'status'),
      tenant: resource.field(self._.blocks, 'tenant'),
      tenant_unit: resource.field(self._.blocks, 'tenant_unit'),
      type: resource.field(self._.blocks, 'type'),
      vanity_name_servers: resource.field(self._.blocks, 'vanity_name_servers'),
      verification_key: resource.field(self._.blocks, 'verification_key'),
    },
    zone_cache_reserve(name, block): {
      local resource = blockType.resource('cloudflare_zone_cache_reserve', name),
      _: resource._(
        block,
        attribute(block, 'editable') +
        attribute(block, 'id') +
        attribute(block, 'modified_on') +
        attribute(block, 'value') +
        attribute(block, 'zone_id', true)
      ),
      editable: resource.field(self._.blocks, 'editable'),
      id: resource.field(self._.blocks, 'id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      value: resource.field(self._.blocks, 'value'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zone_cache_variants(name, block): {
      local resource = blockType.resource('cloudflare_zone_cache_variants', name),
      _: resource._(
        block,
        attribute(block, 'editable') +
        attribute(block, 'id') +
        attribute(block, 'modified_on') +
        attribute(block, 'value', true) +
        attribute(block, 'zone_id', true)
      ),
      editable: resource.field(self._.blocks, 'editable'),
      id: resource.field(self._.blocks, 'id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      value: resource.field(self._.blocks, 'value'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zone_dns_settings(name, block): {
      local resource = blockType.resource('cloudflare_zone_dns_settings', name),
      _: resource._(
        block,
        attribute(block, 'flatten_all_cnames') +
        attribute(block, 'foundation_dns') +
        attribute(block, 'internal_dns') +
        attribute(block, 'multi_provider') +
        attribute(block, 'nameservers') +
        attribute(block, 'ns_ttl') +
        attribute(block, 'secondary_overrides') +
        attribute(block, 'soa') +
        attribute(block, 'zone_id') +
        attribute(block, 'zone_mode')
      ),
      flatten_all_cnames: resource.field(self._.blocks, 'flatten_all_cnames'),
      foundation_dns: resource.field(self._.blocks, 'foundation_dns'),
      internal_dns: resource.field(self._.blocks, 'internal_dns'),
      multi_provider: resource.field(self._.blocks, 'multi_provider'),
      nameservers: resource.field(self._.blocks, 'nameservers'),
      ns_ttl: resource.field(self._.blocks, 'ns_ttl'),
      secondary_overrides: resource.field(self._.blocks, 'secondary_overrides'),
      soa: resource.field(self._.blocks, 'soa'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
      zone_mode: resource.field(self._.blocks, 'zone_mode'),
    },
    zone_dnssec(name, block): {
      local resource = blockType.resource('cloudflare_zone_dnssec', name),
      _: resource._(
        block,
        attribute(block, 'algorithm') +
        attribute(block, 'digest') +
        attribute(block, 'digest_algorithm') +
        attribute(block, 'digest_type') +
        attribute(block, 'dnssec_multi_signer') +
        attribute(block, 'dnssec_presigned') +
        attribute(block, 'dnssec_use_nsec3') +
        attribute(block, 'ds') +
        attribute(block, 'flags') +
        attribute(block, 'id') +
        attribute(block, 'key_tag') +
        attribute(block, 'key_type') +
        attribute(block, 'modified_on') +
        attribute(block, 'public_key') +
        attribute(block, 'status') +
        attribute(block, 'zone_id', true)
      ),
      algorithm: resource.field(self._.blocks, 'algorithm'),
      digest: resource.field(self._.blocks, 'digest'),
      digest_algorithm: resource.field(self._.blocks, 'digest_algorithm'),
      digest_type: resource.field(self._.blocks, 'digest_type'),
      dnssec_multi_signer: resource.field(self._.blocks, 'dnssec_multi_signer'),
      dnssec_presigned: resource.field(self._.blocks, 'dnssec_presigned'),
      dnssec_use_nsec3: resource.field(self._.blocks, 'dnssec_use_nsec3'),
      ds: resource.field(self._.blocks, 'ds'),
      flags: resource.field(self._.blocks, 'flags'),
      id: resource.field(self._.blocks, 'id'),
      key_tag: resource.field(self._.blocks, 'key_tag'),
      key_type: resource.field(self._.blocks, 'key_type'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      public_key: resource.field(self._.blocks, 'public_key'),
      status: resource.field(self._.blocks, 'status'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zone_hold(name, block): {
      local resource = blockType.resource('cloudflare_zone_hold', name),
      _: resource._(
        block,
        attribute(block, 'hold') +
        attribute(block, 'hold_after') +
        attribute(block, 'id') +
        attribute(block, 'include_subdomains') +
        attribute(block, 'zone_id', true)
      ),
      hold: resource.field(self._.blocks, 'hold'),
      hold_after: resource.field(self._.blocks, 'hold_after'),
      id: resource.field(self._.blocks, 'id'),
      include_subdomains: resource.field(self._.blocks, 'include_subdomains'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zone_lockdown(name, block): {
      local resource = blockType.resource('cloudflare_zone_lockdown', name),
      _: resource._(
        block,
        attribute(block, 'configurations', true) +
        attribute(block, 'created_on') +
        attribute(block, 'description') +
        attribute(block, 'id') +
        attribute(block, 'modified_on') +
        attribute(block, 'paused') +
        attribute(block, 'priority') +
        attribute(block, 'urls', true) +
        attribute(block, 'zone_id')
      ),
      configurations: resource.field(self._.blocks, 'configurations'),
      created_on: resource.field(self._.blocks, 'created_on'),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      paused: resource.field(self._.blocks, 'paused'),
      priority: resource.field(self._.blocks, 'priority'),
      urls: resource.field(self._.blocks, 'urls'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zone_setting(name, block): {
      local resource = blockType.resource('cloudflare_zone_setting', name),
      _: resource._(
        block,
        attribute(block, 'editable') +
        attribute(block, 'enabled') +
        attribute(block, 'id') +
        attribute(block, 'modified_on') +
        attribute(block, 'setting_id', true) +
        attribute(block, 'time_remaining') +
        attribute(block, 'value', true) +
        attribute(block, 'zone_id')
      ),
      editable: resource.field(self._.blocks, 'editable'),
      enabled: resource.field(self._.blocks, 'enabled'),
      id: resource.field(self._.blocks, 'id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      setting_id: resource.field(self._.blocks, 'setting_id'),
      time_remaining: resource.field(self._.blocks, 'time_remaining'),
      value: resource.field(self._.blocks, 'value'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zone_subscription(name, block): {
      local resource = blockType.resource('cloudflare_zone_subscription', name),
      _: resource._(
        block,
        attribute(block, 'currency') +
        attribute(block, 'current_period_end') +
        attribute(block, 'current_period_start') +
        attribute(block, 'frequency') +
        attribute(block, 'id') +
        attribute(block, 'price') +
        attribute(block, 'rate_plan') +
        attribute(block, 'state') +
        attribute(block, 'zone_id', true)
      ),
      currency: resource.field(self._.blocks, 'currency'),
      current_period_end: resource.field(self._.blocks, 'current_period_end'),
      current_period_start: resource.field(self._.blocks, 'current_period_start'),
      frequency: resource.field(self._.blocks, 'frequency'),
      id: resource.field(self._.blocks, 'id'),
      price: resource.field(self._.blocks, 'price'),
      rate_plan: resource.field(self._.blocks, 'rate_plan'),
      state: resource.field(self._.blocks, 'state'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
  },
  data: {
    local blockType = provider.blockType('data'),
    access_rule(name, block): {
      local resource = blockType.resource('cloudflare_access_rule', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'allowed_modes') +
        attribute(block, 'configuration') +
        attribute(block, 'created_on') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'mode') +
        attribute(block, 'modified_on') +
        attribute(block, 'notes') +
        attribute(block, 'rule_id') +
        attribute(block, 'scope') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      allowed_modes: resource.field(self._.blocks, 'allowed_modes'),
      configuration: resource.field(self._.blocks, 'configuration'),
      created_on: resource.field(self._.blocks, 'created_on'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      mode: resource.field(self._.blocks, 'mode'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      notes: resource.field(self._.blocks, 'notes'),
      rule_id: resource.field(self._.blocks, 'rule_id'),
      scope: resource.field(self._.blocks, 'scope'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    access_rules(name, block): {
      local resource = blockType.resource('cloudflare_access_rules', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'configuration') +
        attribute(block, 'direction') +
        attribute(block, 'match') +
        attribute(block, 'max_items') +
        attribute(block, 'mode') +
        attribute(block, 'notes') +
        attribute(block, 'order') +
        attribute(block, 'result') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      configuration: resource.field(self._.blocks, 'configuration'),
      direction: resource.field(self._.blocks, 'direction'),
      match: resource.field(self._.blocks, 'match'),
      max_items: resource.field(self._.blocks, 'max_items'),
      mode: resource.field(self._.blocks, 'mode'),
      notes: resource.field(self._.blocks, 'notes'),
      order: resource.field(self._.blocks, 'order'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    account(name, block): {
      local resource = blockType.resource('cloudflare_account', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_on') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'managed_by') +
        attribute(block, 'name') +
        attribute(block, 'settings') +
        attribute(block, 'type')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_on: resource.field(self._.blocks, 'created_on'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      managed_by: resource.field(self._.blocks, 'managed_by'),
      name: resource.field(self._.blocks, 'name'),
      settings: resource.field(self._.blocks, 'settings'),
      type: resource.field(self._.blocks, 'type'),
    },
    account_api_token_permission_groups(name, block): {
      local resource = blockType.resource('cloudflare_account_api_token_permission_groups', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'name') +
        attribute(block, 'permission_groups') +
        attribute(block, 'scope')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      name: resource.field(self._.blocks, 'name'),
      permission_groups: resource.field(self._.blocks, 'permission_groups'),
      scope: resource.field(self._.blocks, 'scope'),
    },
    account_api_token_permission_groups_list(name, block): {
      local resource = blockType.resource('cloudflare_account_api_token_permission_groups_list', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'name') +
        attribute(block, 'result') +
        attribute(block, 'scope')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      name: resource.field(self._.blocks, 'name'),
      result: resource.field(self._.blocks, 'result'),
      scope: resource.field(self._.blocks, 'scope'),
    },
    account_dns_settings(name, block): {
      local resource = blockType.resource('cloudflare_account_dns_settings', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'enforce_dns_only') +
        attribute(block, 'zone_defaults')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      enforce_dns_only: resource.field(self._.blocks, 'enforce_dns_only'),
      zone_defaults: resource.field(self._.blocks, 'zone_defaults'),
    },
    account_dns_settings_internal_view(name, block): {
      local resource = blockType.resource('cloudflare_account_dns_settings_internal_view', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_time') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'modified_time') +
        attribute(block, 'name') +
        attribute(block, 'view_id') +
        attribute(block, 'zones')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_time: resource.field(self._.blocks, 'created_time'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      modified_time: resource.field(self._.blocks, 'modified_time'),
      name: resource.field(self._.blocks, 'name'),
      view_id: resource.field(self._.blocks, 'view_id'),
      zones: resource.field(self._.blocks, 'zones'),
    },
    account_dns_settings_internal_views(name, block): {
      local resource = blockType.resource('cloudflare_account_dns_settings_internal_views', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'direction') +
        attribute(block, 'match') +
        attribute(block, 'max_items') +
        attribute(block, 'name') +
        attribute(block, 'order') +
        attribute(block, 'result') +
        attribute(block, 'zone_id') +
        attribute(block, 'zone_name')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      direction: resource.field(self._.blocks, 'direction'),
      match: resource.field(self._.blocks, 'match'),
      max_items: resource.field(self._.blocks, 'max_items'),
      name: resource.field(self._.blocks, 'name'),
      order: resource.field(self._.blocks, 'order'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
      zone_name: resource.field(self._.blocks, 'zone_name'),
    },
    account_member(name, block): {
      local resource = blockType.resource('cloudflare_account_member', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'email') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'member_id') +
        attribute(block, 'policies') +
        attribute(block, 'roles') +
        attribute(block, 'status') +
        attribute(block, 'user')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      email: resource.field(self._.blocks, 'email'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      member_id: resource.field(self._.blocks, 'member_id'),
      policies: resource.field(self._.blocks, 'policies'),
      roles: resource.field(self._.blocks, 'roles'),
      status: resource.field(self._.blocks, 'status'),
      user: resource.field(self._.blocks, 'user'),
    },
    account_members(name, block): {
      local resource = blockType.resource('cloudflare_account_members', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'direction') +
        attribute(block, 'max_items') +
        attribute(block, 'order') +
        attribute(block, 'result') +
        attribute(block, 'status')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      direction: resource.field(self._.blocks, 'direction'),
      max_items: resource.field(self._.blocks, 'max_items'),
      order: resource.field(self._.blocks, 'order'),
      result: resource.field(self._.blocks, 'result'),
      status: resource.field(self._.blocks, 'status'),
    },
    account_permission_group(name, block): {
      local resource = blockType.resource('cloudflare_account_permission_group', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'id') +
        attribute(block, 'meta') +
        attribute(block, 'name') +
        attribute(block, 'permission_group_id', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      id: resource.field(self._.blocks, 'id'),
      meta: resource.field(self._.blocks, 'meta'),
      name: resource.field(self._.blocks, 'name'),
      permission_group_id: resource.field(self._.blocks, 'permission_group_id'),
    },
    account_permission_groups(name, block): {
      local resource = blockType.resource('cloudflare_account_permission_groups', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'id') +
        attribute(block, 'label') +
        attribute(block, 'max_items') +
        attribute(block, 'name') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      id: resource.field(self._.blocks, 'id'),
      label: resource.field(self._.blocks, 'label'),
      max_items: resource.field(self._.blocks, 'max_items'),
      name: resource.field(self._.blocks, 'name'),
      result: resource.field(self._.blocks, 'result'),
    },
    account_role(name, block): {
      local resource = blockType.resource('cloudflare_account_role', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'description') +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'permissions') +
        attribute(block, 'role_id', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      permissions: resource.field(self._.blocks, 'permissions'),
      role_id: resource.field(self._.blocks, 'role_id'),
    },
    account_roles(name, block): {
      local resource = blockType.resource('cloudflare_account_roles', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    account_subscription(name, block): {
      local resource = blockType.resource('cloudflare_account_subscription', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'currency') +
        attribute(block, 'current_period_end') +
        attribute(block, 'current_period_start') +
        attribute(block, 'frequency') +
        attribute(block, 'id') +
        attribute(block, 'price') +
        attribute(block, 'rate_plan') +
        attribute(block, 'state')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      currency: resource.field(self._.blocks, 'currency'),
      current_period_end: resource.field(self._.blocks, 'current_period_end'),
      current_period_start: resource.field(self._.blocks, 'current_period_start'),
      frequency: resource.field(self._.blocks, 'frequency'),
      id: resource.field(self._.blocks, 'id'),
      price: resource.field(self._.blocks, 'price'),
      rate_plan: resource.field(self._.blocks, 'rate_plan'),
      state: resource.field(self._.blocks, 'state'),
    },
    account_token(name, block): {
      local resource = blockType.resource('cloudflare_account_token', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'condition') +
        attribute(block, 'expires_on') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'issued_on') +
        attribute(block, 'last_used_on') +
        attribute(block, 'modified_on') +
        attribute(block, 'name') +
        attribute(block, 'not_before') +
        attribute(block, 'policies') +
        attribute(block, 'status') +
        attribute(block, 'token_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      condition: resource.field(self._.blocks, 'condition'),
      expires_on: resource.field(self._.blocks, 'expires_on'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      issued_on: resource.field(self._.blocks, 'issued_on'),
      last_used_on: resource.field(self._.blocks, 'last_used_on'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      not_before: resource.field(self._.blocks, 'not_before'),
      policies: resource.field(self._.blocks, 'policies'),
      status: resource.field(self._.blocks, 'status'),
      token_id: resource.field(self._.blocks, 'token_id'),
    },
    account_tokens(name, block): {
      local resource = blockType.resource('cloudflare_account_tokens', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'direction') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      direction: resource.field(self._.blocks, 'direction'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    accounts(name, block): {
      local resource = blockType.resource('cloudflare_accounts', name),
      _: resource._(
        block,
        attribute(block, 'direction') +
        attribute(block, 'max_items') +
        attribute(block, 'name') +
        attribute(block, 'result')
      ),
      direction: resource.field(self._.blocks, 'direction'),
      max_items: resource.field(self._.blocks, 'max_items'),
      name: resource.field(self._.blocks, 'name'),
      result: resource.field(self._.blocks, 'result'),
    },
    address_map(name, block): {
      local resource = blockType.resource('cloudflare_address_map', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'address_map_id', true) +
        attribute(block, 'can_delete') +
        attribute(block, 'can_modify_ips') +
        attribute(block, 'created_at') +
        attribute(block, 'default_sni') +
        attribute(block, 'description') +
        attribute(block, 'enabled') +
        attribute(block, 'id') +
        attribute(block, 'ips') +
        attribute(block, 'memberships') +
        attribute(block, 'modified_at')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      address_map_id: resource.field(self._.blocks, 'address_map_id'),
      can_delete: resource.field(self._.blocks, 'can_delete'),
      can_modify_ips: resource.field(self._.blocks, 'can_modify_ips'),
      created_at: resource.field(self._.blocks, 'created_at'),
      default_sni: resource.field(self._.blocks, 'default_sni'),
      description: resource.field(self._.blocks, 'description'),
      enabled: resource.field(self._.blocks, 'enabled'),
      id: resource.field(self._.blocks, 'id'),
      ips: resource.field(self._.blocks, 'ips'),
      memberships: resource.field(self._.blocks, 'memberships'),
      modified_at: resource.field(self._.blocks, 'modified_at'),
    },
    address_maps(name, block): {
      local resource = blockType.resource('cloudflare_address_maps', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    ai_gateway(name, block): {
      local resource = blockType.resource('cloudflare_ai_gateway', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'authentication') +
        attribute(block, 'cache_invalidate_on_update') +
        attribute(block, 'cache_ttl') +
        attribute(block, 'collect_logs') +
        attribute(block, 'created_at') +
        attribute(block, 'dlp') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'is_default') +
        attribute(block, 'log_management') +
        attribute(block, 'log_management_strategy') +
        attribute(block, 'logpush') +
        attribute(block, 'logpush_public_key') +
        attribute(block, 'modified_at') +
        attribute(block, 'otel') +
        attribute(block, 'rate_limiting_interval') +
        attribute(block, 'rate_limiting_limit') +
        attribute(block, 'rate_limiting_technique') +
        attribute(block, 'retry_backoff') +
        attribute(block, 'retry_delay') +
        attribute(block, 'retry_max_attempts') +
        attribute(block, 'store_id') +
        attribute(block, 'stripe') +
        attribute(block, 'workers_ai_billing_mode') +
        attribute(block, 'zdr')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      authentication: resource.field(self._.blocks, 'authentication'),
      cache_invalidate_on_update: resource.field(self._.blocks, 'cache_invalidate_on_update'),
      cache_ttl: resource.field(self._.blocks, 'cache_ttl'),
      collect_logs: resource.field(self._.blocks, 'collect_logs'),
      created_at: resource.field(self._.blocks, 'created_at'),
      dlp: resource.field(self._.blocks, 'dlp'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      is_default: resource.field(self._.blocks, 'is_default'),
      log_management: resource.field(self._.blocks, 'log_management'),
      log_management_strategy: resource.field(self._.blocks, 'log_management_strategy'),
      logpush: resource.field(self._.blocks, 'logpush'),
      logpush_public_key: resource.field(self._.blocks, 'logpush_public_key'),
      modified_at: resource.field(self._.blocks, 'modified_at'),
      otel: resource.field(self._.blocks, 'otel'),
      rate_limiting_interval: resource.field(self._.blocks, 'rate_limiting_interval'),
      rate_limiting_limit: resource.field(self._.blocks, 'rate_limiting_limit'),
      rate_limiting_technique: resource.field(self._.blocks, 'rate_limiting_technique'),
      retry_backoff: resource.field(self._.blocks, 'retry_backoff'),
      retry_delay: resource.field(self._.blocks, 'retry_delay'),
      retry_max_attempts: resource.field(self._.blocks, 'retry_max_attempts'),
      store_id: resource.field(self._.blocks, 'store_id'),
      stripe: resource.field(self._.blocks, 'stripe'),
      workers_ai_billing_mode: resource.field(self._.blocks, 'workers_ai_billing_mode'),
      zdr: resource.field(self._.blocks, 'zdr'),
    },
    ai_gateway_dynamic_routing(name, block): {
      local resource = blockType.resource('cloudflare_ai_gateway_dynamic_routing', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_at') +
        attribute(block, 'deployment') +
        attribute(block, 'elements') +
        attribute(block, 'gateway_id', true) +
        attribute(block, 'id', true) +
        attribute(block, 'modified_at') +
        attribute(block, 'name') +
        attribute(block, 'version')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_at: resource.field(self._.blocks, 'created_at'),
      deployment: resource.field(self._.blocks, 'deployment'),
      elements: resource.field(self._.blocks, 'elements'),
      gateway_id: resource.field(self._.blocks, 'gateway_id'),
      id: resource.field(self._.blocks, 'id'),
      modified_at: resource.field(self._.blocks, 'modified_at'),
      name: resource.field(self._.blocks, 'name'),
      version: resource.field(self._.blocks, 'version'),
    },
    ai_gateways(name, block): {
      local resource = blockType.resource('cloudflare_ai_gateways', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'search')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      search: resource.field(self._.blocks, 'search'),
    },
    ai_search_instance(name, block): {
      local resource = blockType.resource('cloudflare_ai_search_instance', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'ai_gateway_id') +
        attribute(block, 'aisearch_model') +
        attribute(block, 'cache') +
        attribute(block, 'cache_threshold') +
        attribute(block, 'chunk_overlap') +
        attribute(block, 'chunk_size') +
        attribute(block, 'created_at') +
        attribute(block, 'created_by') +
        attribute(block, 'custom_metadata') +
        attribute(block, 'embedding_model') +
        attribute(block, 'enable') +
        attribute(block, 'engine_version') +
        attribute(block, 'filter') +
        attribute(block, 'fusion_method') +
        attribute(block, 'hybrid_search_enabled') +
        attribute(block, 'id') +
        attribute(block, 'index_method') +
        attribute(block, 'indexing_options') +
        attribute(block, 'last_activity') +
        attribute(block, 'max_num_results') +
        attribute(block, 'metadata') +
        attribute(block, 'modified_at') +
        attribute(block, 'modified_by') +
        attribute(block, 'namespace') +
        attribute(block, 'paused') +
        attribute(block, 'public_endpoint_id') +
        attribute(block, 'public_endpoint_params') +
        attribute(block, 'reranking') +
        attribute(block, 'reranking_model') +
        attribute(block, 'retrieval_options') +
        attribute(block, 'rewrite_model') +
        attribute(block, 'rewrite_query') +
        attribute(block, 'score_threshold') +
        attribute(block, 'source') +
        attribute(block, 'source_params') +
        attribute(block, 'status') +
        attribute(block, 'sync_interval') +
        attribute(block, 'token_id') +
        attribute(block, 'type')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      ai_gateway_id: resource.field(self._.blocks, 'ai_gateway_id'),
      aisearch_model: resource.field(self._.blocks, 'aisearch_model'),
      cache: resource.field(self._.blocks, 'cache'),
      cache_threshold: resource.field(self._.blocks, 'cache_threshold'),
      chunk_overlap: resource.field(self._.blocks, 'chunk_overlap'),
      chunk_size: resource.field(self._.blocks, 'chunk_size'),
      created_at: resource.field(self._.blocks, 'created_at'),
      created_by: resource.field(self._.blocks, 'created_by'),
      custom_metadata: resource.field(self._.blocks, 'custom_metadata'),
      embedding_model: resource.field(self._.blocks, 'embedding_model'),
      enable: resource.field(self._.blocks, 'enable'),
      engine_version: resource.field(self._.blocks, 'engine_version'),
      filter: resource.field(self._.blocks, 'filter'),
      fusion_method: resource.field(self._.blocks, 'fusion_method'),
      hybrid_search_enabled: resource.field(self._.blocks, 'hybrid_search_enabled'),
      id: resource.field(self._.blocks, 'id'),
      index_method: resource.field(self._.blocks, 'index_method'),
      indexing_options: resource.field(self._.blocks, 'indexing_options'),
      last_activity: resource.field(self._.blocks, 'last_activity'),
      max_num_results: resource.field(self._.blocks, 'max_num_results'),
      metadata: resource.field(self._.blocks, 'metadata'),
      modified_at: resource.field(self._.blocks, 'modified_at'),
      modified_by: resource.field(self._.blocks, 'modified_by'),
      namespace: resource.field(self._.blocks, 'namespace'),
      paused: resource.field(self._.blocks, 'paused'),
      public_endpoint_id: resource.field(self._.blocks, 'public_endpoint_id'),
      public_endpoint_params: resource.field(self._.blocks, 'public_endpoint_params'),
      reranking: resource.field(self._.blocks, 'reranking'),
      reranking_model: resource.field(self._.blocks, 'reranking_model'),
      retrieval_options: resource.field(self._.blocks, 'retrieval_options'),
      rewrite_model: resource.field(self._.blocks, 'rewrite_model'),
      rewrite_query: resource.field(self._.blocks, 'rewrite_query'),
      score_threshold: resource.field(self._.blocks, 'score_threshold'),
      source: resource.field(self._.blocks, 'source'),
      source_params: resource.field(self._.blocks, 'source_params'),
      status: resource.field(self._.blocks, 'status'),
      sync_interval: resource.field(self._.blocks, 'sync_interval'),
      token_id: resource.field(self._.blocks, 'token_id'),
      type: resource.field(self._.blocks, 'type'),
    },
    ai_search_instances(name, block): {
      local resource = blockType.resource('cloudflare_ai_search_instances', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'namespace') +
        attribute(block, 'order_by') +
        attribute(block, 'order_by_direction') +
        attribute(block, 'result') +
        attribute(block, 'search')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      namespace: resource.field(self._.blocks, 'namespace'),
      order_by: resource.field(self._.blocks, 'order_by'),
      order_by_direction: resource.field(self._.blocks, 'order_by_direction'),
      result: resource.field(self._.blocks, 'result'),
      search: resource.field(self._.blocks, 'search'),
    },
    ai_search_token(name, block): {
      local resource = blockType.resource('cloudflare_ai_search_token', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'cf_api_id') +
        attribute(block, 'created_at') +
        attribute(block, 'created_by') +
        attribute(block, 'enabled') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'legacy') +
        attribute(block, 'modified_at') +
        attribute(block, 'modified_by') +
        attribute(block, 'name')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      cf_api_id: resource.field(self._.blocks, 'cf_api_id'),
      created_at: resource.field(self._.blocks, 'created_at'),
      created_by: resource.field(self._.blocks, 'created_by'),
      enabled: resource.field(self._.blocks, 'enabled'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      legacy: resource.field(self._.blocks, 'legacy'),
      modified_at: resource.field(self._.blocks, 'modified_at'),
      modified_by: resource.field(self._.blocks, 'modified_by'),
      name: resource.field(self._.blocks, 'name'),
    },
    ai_search_tokens(name, block): {
      local resource = blockType.resource('cloudflare_ai_search_tokens', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'search')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      search: resource.field(self._.blocks, 'search'),
    },
    api_shield(name, block): {
      local resource = blockType.resource('cloudflare_api_shield', name),
      _: resource._(
        block,
        attribute(block, 'auth_id_characteristics') +
        attribute(block, 'id') +
        attribute(block, 'normalize') +
        attribute(block, 'zone_id')
      ),
      auth_id_characteristics: resource.field(self._.blocks, 'auth_id_characteristics'),
      id: resource.field(self._.blocks, 'id'),
      normalize: resource.field(self._.blocks, 'normalize'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    api_shield_discovery_operations(name, block): {
      local resource = blockType.resource('cloudflare_api_shield_discovery_operations', name),
      _: resource._(
        block,
        attribute(block, 'diff') +
        attribute(block, 'direction') +
        attribute(block, 'endpoint') +
        attribute(block, 'host') +
        attribute(block, 'max_items') +
        attribute(block, 'method') +
        attribute(block, 'order') +
        attribute(block, 'origin') +
        attribute(block, 'result') +
        attribute(block, 'state') +
        attribute(block, 'zone_id')
      ),
      diff: resource.field(self._.blocks, 'diff'),
      direction: resource.field(self._.blocks, 'direction'),
      endpoint: resource.field(self._.blocks, 'endpoint'),
      host: resource.field(self._.blocks, 'host'),
      max_items: resource.field(self._.blocks, 'max_items'),
      method: resource.field(self._.blocks, 'method'),
      order: resource.field(self._.blocks, 'order'),
      origin: resource.field(self._.blocks, 'origin'),
      result: resource.field(self._.blocks, 'result'),
      state: resource.field(self._.blocks, 'state'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    api_shield_operation(name, block): {
      local resource = blockType.resource('cloudflare_api_shield_operation', name),
      _: resource._(
        block,
        attribute(block, 'endpoint') +
        attribute(block, 'feature') +
        attribute(block, 'features') +
        attribute(block, 'filter') +
        attribute(block, 'host') +
        attribute(block, 'id') +
        attribute(block, 'last_updated') +
        attribute(block, 'method') +
        attribute(block, 'operation_id') +
        attribute(block, 'zone_id')
      ),
      endpoint: resource.field(self._.blocks, 'endpoint'),
      feature: resource.field(self._.blocks, 'feature'),
      features: resource.field(self._.blocks, 'features'),
      filter: resource.field(self._.blocks, 'filter'),
      host: resource.field(self._.blocks, 'host'),
      id: resource.field(self._.blocks, 'id'),
      last_updated: resource.field(self._.blocks, 'last_updated'),
      method: resource.field(self._.blocks, 'method'),
      operation_id: resource.field(self._.blocks, 'operation_id'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    api_shield_operation_schema_validation_settings(name, block): {
      local resource = blockType.resource('cloudflare_api_shield_operation_schema_validation_settings', name),
      _: resource._(
        block,
        attribute(block, 'mitigation_action') +
        attribute(block, 'operation_id', true) +
        attribute(block, 'zone_id')
      ),
      mitigation_action: resource.field(self._.blocks, 'mitigation_action'),
      operation_id: resource.field(self._.blocks, 'operation_id'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    api_shield_operations(name, block): {
      local resource = blockType.resource('cloudflare_api_shield_operations', name),
      _: resource._(
        block,
        attribute(block, 'direction') +
        attribute(block, 'endpoint') +
        attribute(block, 'feature') +
        attribute(block, 'host') +
        attribute(block, 'max_items') +
        attribute(block, 'method') +
        attribute(block, 'order') +
        attribute(block, 'result') +
        attribute(block, 'zone_id')
      ),
      direction: resource.field(self._.blocks, 'direction'),
      endpoint: resource.field(self._.blocks, 'endpoint'),
      feature: resource.field(self._.blocks, 'feature'),
      host: resource.field(self._.blocks, 'host'),
      max_items: resource.field(self._.blocks, 'max_items'),
      method: resource.field(self._.blocks, 'method'),
      order: resource.field(self._.blocks, 'order'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    api_shield_schema(name, block): {
      local resource = blockType.resource('cloudflare_api_shield_schema', name),
      _: resource._(
        block,
        attribute(block, 'created_at') +
        attribute(block, 'kind') +
        attribute(block, 'name') +
        attribute(block, 'omit_source') +
        attribute(block, 'schema_id', true) +
        attribute(block, 'source') +
        attribute(block, 'validation_enabled') +
        attribute(block, 'zone_id')
      ),
      created_at: resource.field(self._.blocks, 'created_at'),
      kind: resource.field(self._.blocks, 'kind'),
      name: resource.field(self._.blocks, 'name'),
      omit_source: resource.field(self._.blocks, 'omit_source'),
      schema_id: resource.field(self._.blocks, 'schema_id'),
      source: resource.field(self._.blocks, 'source'),
      validation_enabled: resource.field(self._.blocks, 'validation_enabled'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    api_shield_schema_validation_settings(name, block): {
      local resource = blockType.resource('cloudflare_api_shield_schema_validation_settings', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'validation_default_mitigation_action') +
        attribute(block, 'validation_override_mitigation_action') +
        attribute(block, 'zone_id')
      ),
      id: resource.field(self._.blocks, 'id'),
      validation_default_mitigation_action: resource.field(self._.blocks, 'validation_default_mitigation_action'),
      validation_override_mitigation_action: resource.field(self._.blocks, 'validation_override_mitigation_action'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    api_shield_schemas(name, block): {
      local resource = blockType.resource('cloudflare_api_shield_schemas', name),
      _: resource._(
        block,
        attribute(block, 'max_items') +
        attribute(block, 'omit_source') +
        attribute(block, 'result') +
        attribute(block, 'validation_enabled') +
        attribute(block, 'zone_id')
      ),
      max_items: resource.field(self._.blocks, 'max_items'),
      omit_source: resource.field(self._.blocks, 'omit_source'),
      result: resource.field(self._.blocks, 'result'),
      validation_enabled: resource.field(self._.blocks, 'validation_enabled'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    api_token(name, block): {
      local resource = blockType.resource('cloudflare_api_token', name),
      _: resource._(
        block,
        attribute(block, 'condition') +
        attribute(block, 'expires_on') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'issued_on') +
        attribute(block, 'last_used_on') +
        attribute(block, 'modified_on') +
        attribute(block, 'name') +
        attribute(block, 'not_before') +
        attribute(block, 'policies') +
        attribute(block, 'status') +
        attribute(block, 'token_id')
      ),
      condition: resource.field(self._.blocks, 'condition'),
      expires_on: resource.field(self._.blocks, 'expires_on'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      issued_on: resource.field(self._.blocks, 'issued_on'),
      last_used_on: resource.field(self._.blocks, 'last_used_on'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      not_before: resource.field(self._.blocks, 'not_before'),
      policies: resource.field(self._.blocks, 'policies'),
      status: resource.field(self._.blocks, 'status'),
      token_id: resource.field(self._.blocks, 'token_id'),
    },
    api_token_permission_groups_list(name, block): {
      local resource = blockType.resource('cloudflare_api_token_permission_groups_list', name),
      _: resource._(
        block,
        attribute(block, 'max_items') +
        attribute(block, 'name') +
        attribute(block, 'result') +
        attribute(block, 'scope')
      ),
      max_items: resource.field(self._.blocks, 'max_items'),
      name: resource.field(self._.blocks, 'name'),
      result: resource.field(self._.blocks, 'result'),
      scope: resource.field(self._.blocks, 'scope'),
    },
    api_tokens(name, block): {
      local resource = blockType.resource('cloudflare_api_tokens', name),
      _: resource._(
        block,
        attribute(block, 'direction') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      direction: resource.field(self._.blocks, 'direction'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    argo_smart_routing(name, block): {
      local resource = blockType.resource('cloudflare_argo_smart_routing', name),
      _: resource._(
        block,
        attribute(block, 'editable') +
        attribute(block, 'id') +
        attribute(block, 'modified_on') +
        attribute(block, 'value') +
        attribute(block, 'zone_id')
      ),
      editable: resource.field(self._.blocks, 'editable'),
      id: resource.field(self._.blocks, 'id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      value: resource.field(self._.blocks, 'value'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    argo_tiered_caching(name, block): {
      local resource = blockType.resource('cloudflare_argo_tiered_caching', name),
      _: resource._(
        block,
        attribute(block, 'editable') +
        attribute(block, 'id') +
        attribute(block, 'modified_on') +
        attribute(block, 'value') +
        attribute(block, 'zone_id')
      ),
      editable: resource.field(self._.blocks, 'editable'),
      id: resource.field(self._.blocks, 'id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      value: resource.field(self._.blocks, 'value'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    authenticated_origin_pulls(name, block): {
      local resource = blockType.resource('cloudflare_authenticated_origin_pulls', name),
      _: resource._(
        block,
        attribute(block, 'cert_id') +
        attribute(block, 'cert_status') +
        attribute(block, 'cert_updated_at') +
        attribute(block, 'cert_uploaded_on') +
        attribute(block, 'certificate') +
        attribute(block, 'created_at') +
        attribute(block, 'enabled') +
        attribute(block, 'expires_on') +
        attribute(block, 'hostname', true) +
        attribute(block, 'issuer') +
        attribute(block, 'serial_number') +
        attribute(block, 'signature') +
        attribute(block, 'status') +
        attribute(block, 'updated_at') +
        attribute(block, 'zone_id', true)
      ),
      cert_id: resource.field(self._.blocks, 'cert_id'),
      cert_status: resource.field(self._.blocks, 'cert_status'),
      cert_updated_at: resource.field(self._.blocks, 'cert_updated_at'),
      cert_uploaded_on: resource.field(self._.blocks, 'cert_uploaded_on'),
      certificate: resource.field(self._.blocks, 'certificate'),
      created_at: resource.field(self._.blocks, 'created_at'),
      enabled: resource.field(self._.blocks, 'enabled'),
      expires_on: resource.field(self._.blocks, 'expires_on'),
      hostname: resource.field(self._.blocks, 'hostname'),
      issuer: resource.field(self._.blocks, 'issuer'),
      serial_number: resource.field(self._.blocks, 'serial_number'),
      signature: resource.field(self._.blocks, 'signature'),
      status: resource.field(self._.blocks, 'status'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    authenticated_origin_pulls_certificate(name, block): {
      local resource = blockType.resource('cloudflare_authenticated_origin_pulls_certificate', name),
      _: resource._(
        block,
        attribute(block, 'certificate') +
        attribute(block, 'certificate_id', true) +
        attribute(block, 'expires_on') +
        attribute(block, 'id') +
        attribute(block, 'issuer') +
        attribute(block, 'serial_number') +
        attribute(block, 'signature') +
        attribute(block, 'status') +
        attribute(block, 'uploaded_on') +
        attribute(block, 'zone_id', true)
      ),
      certificate: resource.field(self._.blocks, 'certificate'),
      certificate_id: resource.field(self._.blocks, 'certificate_id'),
      expires_on: resource.field(self._.blocks, 'expires_on'),
      id: resource.field(self._.blocks, 'id'),
      issuer: resource.field(self._.blocks, 'issuer'),
      serial_number: resource.field(self._.blocks, 'serial_number'),
      signature: resource.field(self._.blocks, 'signature'),
      status: resource.field(self._.blocks, 'status'),
      uploaded_on: resource.field(self._.blocks, 'uploaded_on'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    authenticated_origin_pulls_certificates(name, block): {
      local resource = blockType.resource('cloudflare_authenticated_origin_pulls_certificates', name),
      _: resource._(
        block,
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'zone_id', true)
      ),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    authenticated_origin_pulls_hostname_certificate(name, block): {
      local resource = blockType.resource('cloudflare_authenticated_origin_pulls_hostname_certificate', name),
      _: resource._(
        block,
        attribute(block, 'certificate') +
        attribute(block, 'certificate_id', true) +
        attribute(block, 'expires_on') +
        attribute(block, 'id') +
        attribute(block, 'issuer') +
        attribute(block, 'serial_number') +
        attribute(block, 'signature') +
        attribute(block, 'status') +
        attribute(block, 'uploaded_on') +
        attribute(block, 'zone_id', true)
      ),
      certificate: resource.field(self._.blocks, 'certificate'),
      certificate_id: resource.field(self._.blocks, 'certificate_id'),
      expires_on: resource.field(self._.blocks, 'expires_on'),
      id: resource.field(self._.blocks, 'id'),
      issuer: resource.field(self._.blocks, 'issuer'),
      serial_number: resource.field(self._.blocks, 'serial_number'),
      signature: resource.field(self._.blocks, 'signature'),
      status: resource.field(self._.blocks, 'status'),
      uploaded_on: resource.field(self._.blocks, 'uploaded_on'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    authenticated_origin_pulls_hostname_certificates(name, block): {
      local resource = blockType.resource('cloudflare_authenticated_origin_pulls_hostname_certificates', name),
      _: resource._(
        block,
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'zone_id', true)
      ),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    authenticated_origin_pulls_settings(name, block): {
      local resource = blockType.resource('cloudflare_authenticated_origin_pulls_settings', name),
      _: resource._(
        block,
        attribute(block, 'enabled') +
        attribute(block, 'id') +
        attribute(block, 'zone_id')
      ),
      enabled: resource.field(self._.blocks, 'enabled'),
      id: resource.field(self._.blocks, 'id'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    bot_management(name, block): {
      local resource = blockType.resource('cloudflare_bot_management', name),
      _: resource._(
        block,
        attribute(block, 'ai_bots_protection') +
        attribute(block, 'auto_update_model') +
        attribute(block, 'bm_cookie_enabled') +
        attribute(block, 'cf_robots_variant') +
        attribute(block, 'content_bots_protection') +
        attribute(block, 'crawler_protection') +
        attribute(block, 'enable_js') +
        attribute(block, 'fight_mode') +
        attribute(block, 'id') +
        attribute(block, 'is_robots_txt_managed') +
        attribute(block, 'optimize_wordpress') +
        attribute(block, 'sbfm_definitely_automated') +
        attribute(block, 'sbfm_likely_automated') +
        attribute(block, 'sbfm_static_resource_protection') +
        attribute(block, 'sbfm_verified_bots') +
        attribute(block, 'stale_zone_configuration') +
        attribute(block, 'suppress_session_score') +
        attribute(block, 'using_latest_model') +
        attribute(block, 'zone_id')
      ),
      ai_bots_protection: resource.field(self._.blocks, 'ai_bots_protection'),
      auto_update_model: resource.field(self._.blocks, 'auto_update_model'),
      bm_cookie_enabled: resource.field(self._.blocks, 'bm_cookie_enabled'),
      cf_robots_variant: resource.field(self._.blocks, 'cf_robots_variant'),
      content_bots_protection: resource.field(self._.blocks, 'content_bots_protection'),
      crawler_protection: resource.field(self._.blocks, 'crawler_protection'),
      enable_js: resource.field(self._.blocks, 'enable_js'),
      fight_mode: resource.field(self._.blocks, 'fight_mode'),
      id: resource.field(self._.blocks, 'id'),
      is_robots_txt_managed: resource.field(self._.blocks, 'is_robots_txt_managed'),
      optimize_wordpress: resource.field(self._.blocks, 'optimize_wordpress'),
      sbfm_definitely_automated: resource.field(self._.blocks, 'sbfm_definitely_automated'),
      sbfm_likely_automated: resource.field(self._.blocks, 'sbfm_likely_automated'),
      sbfm_static_resource_protection: resource.field(self._.blocks, 'sbfm_static_resource_protection'),
      sbfm_verified_bots: resource.field(self._.blocks, 'sbfm_verified_bots'),
      stale_zone_configuration: resource.field(self._.blocks, 'stale_zone_configuration'),
      suppress_session_score: resource.field(self._.blocks, 'suppress_session_score'),
      using_latest_model: resource.field(self._.blocks, 'using_latest_model'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    botnet_feed_config_asn(name, block): {
      local resource = blockType.resource('cloudflare_botnet_feed_config_asn', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'asn')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      asn: resource.field(self._.blocks, 'asn'),
    },
    byo_ip_prefix(name, block): {
      local resource = blockType.resource('cloudflare_byo_ip_prefix', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'advertised') +
        attribute(block, 'advertised_modified_at') +
        attribute(block, 'approved') +
        attribute(block, 'asn') +
        attribute(block, 'cidr') +
        attribute(block, 'created_at') +
        attribute(block, 'delegate_loa_creation') +
        attribute(block, 'description') +
        attribute(block, 'id') +
        attribute(block, 'irr_validation_state') +
        attribute(block, 'loa_document_id') +
        attribute(block, 'modified_at') +
        attribute(block, 'on_demand_enabled') +
        attribute(block, 'on_demand_locked') +
        attribute(block, 'ownership_validation_state') +
        attribute(block, 'ownership_validation_token') +
        attribute(block, 'prefix_id', true) +
        attribute(block, 'rpki_validation_state')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      advertised: resource.field(self._.blocks, 'advertised'),
      advertised_modified_at: resource.field(self._.blocks, 'advertised_modified_at'),
      approved: resource.field(self._.blocks, 'approved'),
      asn: resource.field(self._.blocks, 'asn'),
      cidr: resource.field(self._.blocks, 'cidr'),
      created_at: resource.field(self._.blocks, 'created_at'),
      delegate_loa_creation: resource.field(self._.blocks, 'delegate_loa_creation'),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      irr_validation_state: resource.field(self._.blocks, 'irr_validation_state'),
      loa_document_id: resource.field(self._.blocks, 'loa_document_id'),
      modified_at: resource.field(self._.blocks, 'modified_at'),
      on_demand_enabled: resource.field(self._.blocks, 'on_demand_enabled'),
      on_demand_locked: resource.field(self._.blocks, 'on_demand_locked'),
      ownership_validation_state: resource.field(self._.blocks, 'ownership_validation_state'),
      ownership_validation_token: resource.field(self._.blocks, 'ownership_validation_token'),
      prefix_id: resource.field(self._.blocks, 'prefix_id'),
      rpki_validation_state: resource.field(self._.blocks, 'rpki_validation_state'),
    },
    byo_ip_prefixes(name, block): {
      local resource = blockType.resource('cloudflare_byo_ip_prefixes', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    calls_sfu_app(name, block): {
      local resource = blockType.resource('cloudflare_calls_sfu_app', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'app_id', true) +
        attribute(block, 'created') +
        attribute(block, 'modified') +
        attribute(block, 'name') +
        attribute(block, 'uid')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      app_id: resource.field(self._.blocks, 'app_id'),
      created: resource.field(self._.blocks, 'created'),
      modified: resource.field(self._.blocks, 'modified'),
      name: resource.field(self._.blocks, 'name'),
      uid: resource.field(self._.blocks, 'uid'),
    },
    calls_sfu_apps(name, block): {
      local resource = blockType.resource('cloudflare_calls_sfu_apps', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    calls_turn_app(name, block): {
      local resource = blockType.resource('cloudflare_calls_turn_app', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created') +
        attribute(block, 'key_id', true) +
        attribute(block, 'modified') +
        attribute(block, 'name') +
        attribute(block, 'uid')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created: resource.field(self._.blocks, 'created'),
      key_id: resource.field(self._.blocks, 'key_id'),
      modified: resource.field(self._.blocks, 'modified'),
      name: resource.field(self._.blocks, 'name'),
      uid: resource.field(self._.blocks, 'uid'),
    },
    calls_turn_apps(name, block): {
      local resource = blockType.resource('cloudflare_calls_turn_apps', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    certificate_authorities_hostname_associations(name, block): {
      local resource = blockType.resource('cloudflare_certificate_authorities_hostname_associations', name),
      _: resource._(
        block,
        attribute(block, 'hostnames') +
        attribute(block, 'id') +
        attribute(block, 'mtls_certificate_id') +
        attribute(block, 'zone_id')
      ),
      hostnames: resource.field(self._.blocks, 'hostnames'),
      id: resource.field(self._.blocks, 'id'),
      mtls_certificate_id: resource.field(self._.blocks, 'mtls_certificate_id'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    certificate_pack(name, block): {
      local resource = blockType.resource('cloudflare_certificate_pack', name),
      _: resource._(
        block,
        attribute(block, 'certificate_authority') +
        attribute(block, 'certificate_pack_id') +
        attribute(block, 'certificates') +
        attribute(block, 'cloudflare_branding') +
        attribute(block, 'dcv_delegation_records') +
        attribute(block, 'filter') +
        attribute(block, 'hosts') +
        attribute(block, 'id') +
        attribute(block, 'primary_certificate') +
        attribute(block, 'status') +
        attribute(block, 'type') +
        attribute(block, 'validation_errors') +
        attribute(block, 'validation_method') +
        attribute(block, 'validation_records') +
        attribute(block, 'validity_days') +
        attribute(block, 'zone_id')
      ),
      certificate_authority: resource.field(self._.blocks, 'certificate_authority'),
      certificate_pack_id: resource.field(self._.blocks, 'certificate_pack_id'),
      certificates: resource.field(self._.blocks, 'certificates'),
      cloudflare_branding: resource.field(self._.blocks, 'cloudflare_branding'),
      dcv_delegation_records: resource.field(self._.blocks, 'dcv_delegation_records'),
      filter: resource.field(self._.blocks, 'filter'),
      hosts: resource.field(self._.blocks, 'hosts'),
      id: resource.field(self._.blocks, 'id'),
      primary_certificate: resource.field(self._.blocks, 'primary_certificate'),
      status: resource.field(self._.blocks, 'status'),
      type: resource.field(self._.blocks, 'type'),
      validation_errors: resource.field(self._.blocks, 'validation_errors'),
      validation_method: resource.field(self._.blocks, 'validation_method'),
      validation_records: resource.field(self._.blocks, 'validation_records'),
      validity_days: resource.field(self._.blocks, 'validity_days'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    certificate_packs(name, block): {
      local resource = blockType.resource('cloudflare_certificate_packs', name),
      _: resource._(
        block,
        attribute(block, 'deploy') +
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'status') +
        attribute(block, 'zone_id')
      ),
      deploy: resource.field(self._.blocks, 'deploy'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      status: resource.field(self._.blocks, 'status'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    client_certificate(name, block): {
      local resource = blockType.resource('cloudflare_client_certificate', name),
      _: resource._(
        block,
        attribute(block, 'certificate') +
        attribute(block, 'certificate_authority') +
        attribute(block, 'client_certificate_id') +
        attribute(block, 'common_name') +
        attribute(block, 'country') +
        attribute(block, 'csr') +
        attribute(block, 'expires_on') +
        attribute(block, 'filter') +
        attribute(block, 'fingerprint_sha256') +
        attribute(block, 'id') +
        attribute(block, 'issued_on') +
        attribute(block, 'location') +
        attribute(block, 'organization') +
        attribute(block, 'organizational_unit') +
        attribute(block, 'serial_number') +
        attribute(block, 'signature') +
        attribute(block, 'ski') +
        attribute(block, 'state') +
        attribute(block, 'status') +
        attribute(block, 'validity_days') +
        attribute(block, 'zone_id')
      ),
      certificate: resource.field(self._.blocks, 'certificate'),
      certificate_authority: resource.field(self._.blocks, 'certificate_authority'),
      client_certificate_id: resource.field(self._.blocks, 'client_certificate_id'),
      common_name: resource.field(self._.blocks, 'common_name'),
      country: resource.field(self._.blocks, 'country'),
      csr: resource.field(self._.blocks, 'csr'),
      expires_on: resource.field(self._.blocks, 'expires_on'),
      filter: resource.field(self._.blocks, 'filter'),
      fingerprint_sha256: resource.field(self._.blocks, 'fingerprint_sha256'),
      id: resource.field(self._.blocks, 'id'),
      issued_on: resource.field(self._.blocks, 'issued_on'),
      location: resource.field(self._.blocks, 'location'),
      organization: resource.field(self._.blocks, 'organization'),
      organizational_unit: resource.field(self._.blocks, 'organizational_unit'),
      serial_number: resource.field(self._.blocks, 'serial_number'),
      signature: resource.field(self._.blocks, 'signature'),
      ski: resource.field(self._.blocks, 'ski'),
      state: resource.field(self._.blocks, 'state'),
      status: resource.field(self._.blocks, 'status'),
      validity_days: resource.field(self._.blocks, 'validity_days'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    client_certificates(name, block): {
      local resource = blockType.resource('cloudflare_client_certificates', name),
      _: resource._(
        block,
        attribute(block, 'limit') +
        attribute(block, 'max_items') +
        attribute(block, 'offset') +
        attribute(block, 'result') +
        attribute(block, 'status') +
        attribute(block, 'zone_id')
      ),
      limit: resource.field(self._.blocks, 'limit'),
      max_items: resource.field(self._.blocks, 'max_items'),
      offset: resource.field(self._.blocks, 'offset'),
      result: resource.field(self._.blocks, 'result'),
      status: resource.field(self._.blocks, 'status'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    cloud_connector_rules(name, block): {
      local resource = blockType.resource('cloudflare_cloud_connector_rules', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'rules') +
        attribute(block, 'zone_id')
      ),
      id: resource.field(self._.blocks, 'id'),
      rules: resource.field(self._.blocks, 'rules'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    cloudforce_one_request(name, block): {
      local resource = blockType.resource('cloudflare_cloudforce_one_request', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'completed') +
        attribute(block, 'content') +
        attribute(block, 'created') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'message_tokens') +
        attribute(block, 'priority') +
        attribute(block, 'readable_id') +
        attribute(block, 'request') +
        attribute(block, 'request_id') +
        attribute(block, 'status') +
        attribute(block, 'summary') +
        attribute(block, 'tlp') +
        attribute(block, 'tokens') +
        attribute(block, 'updated')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      completed: resource.field(self._.blocks, 'completed'),
      content: resource.field(self._.blocks, 'content'),
      created: resource.field(self._.blocks, 'created'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      message_tokens: resource.field(self._.blocks, 'message_tokens'),
      priority: resource.field(self._.blocks, 'priority'),
      readable_id: resource.field(self._.blocks, 'readable_id'),
      request: resource.field(self._.blocks, 'request'),
      request_id: resource.field(self._.blocks, 'request_id'),
      status: resource.field(self._.blocks, 'status'),
      summary: resource.field(self._.blocks, 'summary'),
      tlp: resource.field(self._.blocks, 'tlp'),
      tokens: resource.field(self._.blocks, 'tokens'),
      updated: resource.field(self._.blocks, 'updated'),
    },
    cloudforce_one_request_asset(name, block): {
      local resource = blockType.resource('cloudflare_cloudforce_one_request_asset', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'asset_id', true) +
        attribute(block, 'created') +
        attribute(block, 'description') +
        attribute(block, 'file_type') +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'request_id', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      asset_id: resource.field(self._.blocks, 'asset_id'),
      created: resource.field(self._.blocks, 'created'),
      description: resource.field(self._.blocks, 'description'),
      file_type: resource.field(self._.blocks, 'file_type'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      request_id: resource.field(self._.blocks, 'request_id'),
    },
    cloudforce_one_request_message(name, block): {
      local resource = blockType.resource('cloudflare_cloudforce_one_request_message', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'after') +
        attribute(block, 'author') +
        attribute(block, 'before') +
        attribute(block, 'content') +
        attribute(block, 'created') +
        attribute(block, 'id') +
        attribute(block, 'is_follow_on_request') +
        attribute(block, 'page', true) +
        attribute(block, 'per_page', true) +
        attribute(block, 'request_id', true) +
        attribute(block, 'sort_by') +
        attribute(block, 'sort_order') +
        attribute(block, 'updated')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      after: resource.field(self._.blocks, 'after'),
      author: resource.field(self._.blocks, 'author'),
      before: resource.field(self._.blocks, 'before'),
      content: resource.field(self._.blocks, 'content'),
      created: resource.field(self._.blocks, 'created'),
      id: resource.field(self._.blocks, 'id'),
      is_follow_on_request: resource.field(self._.blocks, 'is_follow_on_request'),
      page: resource.field(self._.blocks, 'page'),
      per_page: resource.field(self._.blocks, 'per_page'),
      request_id: resource.field(self._.blocks, 'request_id'),
      sort_by: resource.field(self._.blocks, 'sort_by'),
      sort_order: resource.field(self._.blocks, 'sort_order'),
      updated: resource.field(self._.blocks, 'updated'),
    },
    cloudforce_one_request_priority(name, block): {
      local resource = blockType.resource('cloudflare_cloudforce_one_request_priority', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'completed') +
        attribute(block, 'content') +
        attribute(block, 'created') +
        attribute(block, 'id') +
        attribute(block, 'message_tokens') +
        attribute(block, 'priority') +
        attribute(block, 'priority_id', true) +
        attribute(block, 'readable_id') +
        attribute(block, 'request') +
        attribute(block, 'status') +
        attribute(block, 'summary') +
        attribute(block, 'tlp') +
        attribute(block, 'tokens') +
        attribute(block, 'updated')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      completed: resource.field(self._.blocks, 'completed'),
      content: resource.field(self._.blocks, 'content'),
      created: resource.field(self._.blocks, 'created'),
      id: resource.field(self._.blocks, 'id'),
      message_tokens: resource.field(self._.blocks, 'message_tokens'),
      priority: resource.field(self._.blocks, 'priority'),
      priority_id: resource.field(self._.blocks, 'priority_id'),
      readable_id: resource.field(self._.blocks, 'readable_id'),
      request: resource.field(self._.blocks, 'request'),
      status: resource.field(self._.blocks, 'status'),
      summary: resource.field(self._.blocks, 'summary'),
      tlp: resource.field(self._.blocks, 'tlp'),
      tokens: resource.field(self._.blocks, 'tokens'),
      updated: resource.field(self._.blocks, 'updated'),
    },
    cloudforce_one_requests(name, block): {
      local resource = blockType.resource('cloudflare_cloudforce_one_requests', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'completed_after') +
        attribute(block, 'completed_before') +
        attribute(block, 'created_after') +
        attribute(block, 'created_before') +
        attribute(block, 'max_items') +
        attribute(block, 'page', true) +
        attribute(block, 'per_page', true) +
        attribute(block, 'request_type') +
        attribute(block, 'result') +
        attribute(block, 'sort_by') +
        attribute(block, 'sort_order') +
        attribute(block, 'status')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      completed_after: resource.field(self._.blocks, 'completed_after'),
      completed_before: resource.field(self._.blocks, 'completed_before'),
      created_after: resource.field(self._.blocks, 'created_after'),
      created_before: resource.field(self._.blocks, 'created_before'),
      max_items: resource.field(self._.blocks, 'max_items'),
      page: resource.field(self._.blocks, 'page'),
      per_page: resource.field(self._.blocks, 'per_page'),
      request_type: resource.field(self._.blocks, 'request_type'),
      result: resource.field(self._.blocks, 'result'),
      sort_by: resource.field(self._.blocks, 'sort_by'),
      sort_order: resource.field(self._.blocks, 'sort_order'),
      status: resource.field(self._.blocks, 'status'),
    },
    connectivity_directory_service(name, block): {
      local resource = blockType.resource('cloudflare_connectivity_directory_service', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'app_protocol') +
        attribute(block, 'created_at') +
        attribute(block, 'filter') +
        attribute(block, 'host') +
        attribute(block, 'http_port') +
        attribute(block, 'https_port') +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'service_id') +
        attribute(block, 'tcp_port') +
        attribute(block, 'tls_settings') +
        attribute(block, 'type') +
        attribute(block, 'updated_at')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      app_protocol: resource.field(self._.blocks, 'app_protocol'),
      created_at: resource.field(self._.blocks, 'created_at'),
      filter: resource.field(self._.blocks, 'filter'),
      host: resource.field(self._.blocks, 'host'),
      http_port: resource.field(self._.blocks, 'http_port'),
      https_port: resource.field(self._.blocks, 'https_port'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      service_id: resource.field(self._.blocks, 'service_id'),
      tcp_port: resource.field(self._.blocks, 'tcp_port'),
      tls_settings: resource.field(self._.blocks, 'tls_settings'),
      type: resource.field(self._.blocks, 'type'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
    },
    connectivity_directory_services(name, block): {
      local resource = blockType.resource('cloudflare_connectivity_directory_services', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'type')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      type: resource.field(self._.blocks, 'type'),
    },
    content_scanning(name, block): {
      local resource = blockType.resource('cloudflare_content_scanning', name),
      _: resource._(
        block,
        attribute(block, 'modified') +
        attribute(block, 'value') +
        attribute(block, 'zone_id')
      ),
      modified: resource.field(self._.blocks, 'modified'),
      value: resource.field(self._.blocks, 'value'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    content_scanning_expressions(name, block): {
      local resource = blockType.resource('cloudflare_content_scanning_expressions', name),
      _: resource._(
        block,
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'zone_id')
      ),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    custom_hostname(name, block): {
      local resource = blockType.resource('cloudflare_custom_hostname', name),
      _: resource._(
        block,
        attribute(block, 'created_at') +
        attribute(block, 'custom_hostname_id') +
        attribute(block, 'custom_metadata') +
        attribute(block, 'custom_origin_server') +
        attribute(block, 'custom_origin_sni') +
        attribute(block, 'filter') +
        attribute(block, 'hostname') +
        attribute(block, 'id') +
        attribute(block, 'ownership_verification') +
        attribute(block, 'ownership_verification_http') +
        attribute(block, 'ssl') +
        attribute(block, 'status') +
        attribute(block, 'verification_errors') +
        attribute(block, 'zone_id')
      ),
      created_at: resource.field(self._.blocks, 'created_at'),
      custom_hostname_id: resource.field(self._.blocks, 'custom_hostname_id'),
      custom_metadata: resource.field(self._.blocks, 'custom_metadata'),
      custom_origin_server: resource.field(self._.blocks, 'custom_origin_server'),
      custom_origin_sni: resource.field(self._.blocks, 'custom_origin_sni'),
      filter: resource.field(self._.blocks, 'filter'),
      hostname: resource.field(self._.blocks, 'hostname'),
      id: resource.field(self._.blocks, 'id'),
      ownership_verification: resource.field(self._.blocks, 'ownership_verification'),
      ownership_verification_http: resource.field(self._.blocks, 'ownership_verification_http'),
      ssl: resource.field(self._.blocks, 'ssl'),
      status: resource.field(self._.blocks, 'status'),
      verification_errors: resource.field(self._.blocks, 'verification_errors'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    custom_hostname_fallback_origin(name, block): {
      local resource = blockType.resource('cloudflare_custom_hostname_fallback_origin', name),
      _: resource._(
        block,
        attribute(block, 'created_at') +
        attribute(block, 'errors') +
        attribute(block, 'id') +
        attribute(block, 'origin') +
        attribute(block, 'status') +
        attribute(block, 'updated_at') +
        attribute(block, 'zone_id')
      ),
      created_at: resource.field(self._.blocks, 'created_at'),
      errors: resource.field(self._.blocks, 'errors'),
      id: resource.field(self._.blocks, 'id'),
      origin: resource.field(self._.blocks, 'origin'),
      status: resource.field(self._.blocks, 'status'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    custom_hostnames(name, block): {
      local resource = blockType.resource('cloudflare_custom_hostnames', name),
      _: resource._(
        block,
        attribute(block, 'certificate_authority') +
        attribute(block, 'custom_origin_server') +
        attribute(block, 'direction') +
        attribute(block, 'hostname') +
        attribute(block, 'hostname_status') +
        attribute(block, 'id') +
        attribute(block, 'max_items') +
        attribute(block, 'order') +
        attribute(block, 'result') +
        attribute(block, 'ssl') +
        attribute(block, 'ssl_status') +
        attribute(block, 'wildcard') +
        attribute(block, 'zone_id')
      ),
      certificate_authority: resource.field(self._.blocks, 'certificate_authority'),
      custom_origin_server: resource.field(self._.blocks, 'custom_origin_server'),
      direction: resource.field(self._.blocks, 'direction'),
      hostname: resource.field(self._.blocks, 'hostname'),
      hostname_status: resource.field(self._.blocks, 'hostname_status'),
      id: resource.field(self._.blocks, 'id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      order: resource.field(self._.blocks, 'order'),
      result: resource.field(self._.blocks, 'result'),
      ssl: resource.field(self._.blocks, 'ssl'),
      ssl_status: resource.field(self._.blocks, 'ssl_status'),
      wildcard: resource.field(self._.blocks, 'wildcard'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    custom_origin_trust_store(name, block): {
      local resource = blockType.resource('cloudflare_custom_origin_trust_store', name),
      _: resource._(
        block,
        attribute(block, 'certificate') +
        attribute(block, 'custom_origin_trust_store_id') +
        attribute(block, 'expires_on') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'issuer') +
        attribute(block, 'signature') +
        attribute(block, 'status') +
        attribute(block, 'updated_at') +
        attribute(block, 'uploaded_on') +
        attribute(block, 'zone_id')
      ),
      certificate: resource.field(self._.blocks, 'certificate'),
      custom_origin_trust_store_id: resource.field(self._.blocks, 'custom_origin_trust_store_id'),
      expires_on: resource.field(self._.blocks, 'expires_on'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      issuer: resource.field(self._.blocks, 'issuer'),
      signature: resource.field(self._.blocks, 'signature'),
      status: resource.field(self._.blocks, 'status'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      uploaded_on: resource.field(self._.blocks, 'uploaded_on'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    custom_origin_trust_stores(name, block): {
      local resource = blockType.resource('cloudflare_custom_origin_trust_stores', name),
      _: resource._(
        block,
        attribute(block, 'limit') +
        attribute(block, 'max_items') +
        attribute(block, 'offset') +
        attribute(block, 'result') +
        attribute(block, 'zone_id')
      ),
      limit: resource.field(self._.blocks, 'limit'),
      max_items: resource.field(self._.blocks, 'max_items'),
      offset: resource.field(self._.blocks, 'offset'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    custom_page_asset(name, block): {
      local resource = blockType.resource('cloudflare_custom_page_asset', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'asset_name', true) +
        attribute(block, 'description') +
        attribute(block, 'id') +
        attribute(block, 'last_updated') +
        attribute(block, 'name') +
        attribute(block, 'size_bytes') +
        attribute(block, 'url') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      asset_name: resource.field(self._.blocks, 'asset_name'),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      last_updated: resource.field(self._.blocks, 'last_updated'),
      name: resource.field(self._.blocks, 'name'),
      size_bytes: resource.field(self._.blocks, 'size_bytes'),
      url: resource.field(self._.blocks, 'url'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    custom_page_assets(name, block): {
      local resource = blockType.resource('cloudflare_custom_page_assets', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    custom_pages(name, block): {
      local resource = blockType.resource('cloudflare_custom_pages', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_on') +
        attribute(block, 'description') +
        attribute(block, 'id') +
        attribute(block, 'identifier', true) +
        attribute(block, 'modified_on') +
        attribute(block, 'preview_target') +
        attribute(block, 'required_tokens') +
        attribute(block, 'state') +
        attribute(block, 'url') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_on: resource.field(self._.blocks, 'created_on'),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      identifier: resource.field(self._.blocks, 'identifier'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      preview_target: resource.field(self._.blocks, 'preview_target'),
      required_tokens: resource.field(self._.blocks, 'required_tokens'),
      state: resource.field(self._.blocks, 'state'),
      url: resource.field(self._.blocks, 'url'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    custom_pages_list(name, block): {
      local resource = blockType.resource('cloudflare_custom_pages_list', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    custom_ssl(name, block): {
      local resource = blockType.resource('cloudflare_custom_ssl', name),
      _: resource._(
        block,
        attribute(block, 'bundle_method') +
        attribute(block, 'custom_certificate_id') +
        attribute(block, 'custom_csr_id') +
        attribute(block, 'expires_on') +
        attribute(block, 'filter') +
        attribute(block, 'geo_restrictions') +
        attribute(block, 'hosts') +
        attribute(block, 'id') +
        attribute(block, 'issuer') +
        attribute(block, 'keyless_server') +
        attribute(block, 'modified_on') +
        attribute(block, 'policy_restrictions') +
        attribute(block, 'priority') +
        attribute(block, 'signature') +
        attribute(block, 'status') +
        attribute(block, 'uploaded_on') +
        attribute(block, 'zone_id')
      ),
      bundle_method: resource.field(self._.blocks, 'bundle_method'),
      custom_certificate_id: resource.field(self._.blocks, 'custom_certificate_id'),
      custom_csr_id: resource.field(self._.blocks, 'custom_csr_id'),
      expires_on: resource.field(self._.blocks, 'expires_on'),
      filter: resource.field(self._.blocks, 'filter'),
      geo_restrictions: resource.field(self._.blocks, 'geo_restrictions'),
      hosts: resource.field(self._.blocks, 'hosts'),
      id: resource.field(self._.blocks, 'id'),
      issuer: resource.field(self._.blocks, 'issuer'),
      keyless_server: resource.field(self._.blocks, 'keyless_server'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      policy_restrictions: resource.field(self._.blocks, 'policy_restrictions'),
      priority: resource.field(self._.blocks, 'priority'),
      signature: resource.field(self._.blocks, 'signature'),
      status: resource.field(self._.blocks, 'status'),
      uploaded_on: resource.field(self._.blocks, 'uploaded_on'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    custom_ssls(name, block): {
      local resource = blockType.resource('cloudflare_custom_ssls', name),
      _: resource._(
        block,
        attribute(block, 'match') +
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'status') +
        attribute(block, 'zone_id')
      ),
      match: resource.field(self._.blocks, 'match'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      status: resource.field(self._.blocks, 'status'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    d1_database(name, block): {
      local resource = blockType.resource('cloudflare_d1_database', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_at') +
        attribute(block, 'database_id') +
        attribute(block, 'file_size') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'jurisdiction') +
        attribute(block, 'name') +
        attribute(block, 'num_tables') +
        attribute(block, 'read_replication') +
        attribute(block, 'uuid') +
        attribute(block, 'version')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_at: resource.field(self._.blocks, 'created_at'),
      database_id: resource.field(self._.blocks, 'database_id'),
      file_size: resource.field(self._.blocks, 'file_size'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      jurisdiction: resource.field(self._.blocks, 'jurisdiction'),
      name: resource.field(self._.blocks, 'name'),
      num_tables: resource.field(self._.blocks, 'num_tables'),
      read_replication: resource.field(self._.blocks, 'read_replication'),
      uuid: resource.field(self._.blocks, 'uuid'),
      version: resource.field(self._.blocks, 'version'),
    },
    d1_databases(name, block): {
      local resource = blockType.resource('cloudflare_d1_databases', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'name') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      name: resource.field(self._.blocks, 'name'),
      result: resource.field(self._.blocks, 'result'),
    },
    dcv_delegation(name, block): {
      local resource = blockType.resource('cloudflare_dcv_delegation', name),
      _: resource._(
        block,
        attribute(block, 'uuid') +
        attribute(block, 'zone_id')
      ),
      uuid: resource.field(self._.blocks, 'uuid'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    dns_firewall(name, block): {
      local resource = blockType.resource('cloudflare_dns_firewall', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'attack_mitigation') +
        attribute(block, 'deprecate_any_requests') +
        attribute(block, 'dns_firewall_id', true) +
        attribute(block, 'dns_firewall_ips') +
        attribute(block, 'ecs_fallback') +
        attribute(block, 'id') +
        attribute(block, 'maximum_cache_ttl') +
        attribute(block, 'minimum_cache_ttl') +
        attribute(block, 'modified_on') +
        attribute(block, 'name') +
        attribute(block, 'negative_cache_ttl') +
        attribute(block, 'ratelimit') +
        attribute(block, 'retries') +
        attribute(block, 'upstream_ips')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      attack_mitigation: resource.field(self._.blocks, 'attack_mitigation'),
      deprecate_any_requests: resource.field(self._.blocks, 'deprecate_any_requests'),
      dns_firewall_id: resource.field(self._.blocks, 'dns_firewall_id'),
      dns_firewall_ips: resource.field(self._.blocks, 'dns_firewall_ips'),
      ecs_fallback: resource.field(self._.blocks, 'ecs_fallback'),
      id: resource.field(self._.blocks, 'id'),
      maximum_cache_ttl: resource.field(self._.blocks, 'maximum_cache_ttl'),
      minimum_cache_ttl: resource.field(self._.blocks, 'minimum_cache_ttl'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      negative_cache_ttl: resource.field(self._.blocks, 'negative_cache_ttl'),
      ratelimit: resource.field(self._.blocks, 'ratelimit'),
      retries: resource.field(self._.blocks, 'retries'),
      upstream_ips: resource.field(self._.blocks, 'upstream_ips'),
    },
    dns_firewalls(name, block): {
      local resource = blockType.resource('cloudflare_dns_firewalls', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    dns_record(name, block): {
      local resource = blockType.resource('cloudflare_dns_record', name),
      _: resource._(
        block,
        attribute(block, 'comment') +
        attribute(block, 'comment_modified_on') +
        attribute(block, 'content') +
        attribute(block, 'created_on') +
        attribute(block, 'data') +
        attribute(block, 'dns_record_id') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'meta') +
        attribute(block, 'modified_on') +
        attribute(block, 'name') +
        attribute(block, 'priority') +
        attribute(block, 'private_routing') +
        attribute(block, 'proxiable') +
        attribute(block, 'proxied') +
        attribute(block, 'settings') +
        attribute(block, 'tags') +
        attribute(block, 'tags_modified_on') +
        attribute(block, 'ttl') +
        attribute(block, 'type') +
        attribute(block, 'zone_id')
      ),
      comment: resource.field(self._.blocks, 'comment'),
      comment_modified_on: resource.field(self._.blocks, 'comment_modified_on'),
      content: resource.field(self._.blocks, 'content'),
      created_on: resource.field(self._.blocks, 'created_on'),
      data: resource.field(self._.blocks, 'data'),
      dns_record_id: resource.field(self._.blocks, 'dns_record_id'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      meta: resource.field(self._.blocks, 'meta'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      priority: resource.field(self._.blocks, 'priority'),
      private_routing: resource.field(self._.blocks, 'private_routing'),
      proxiable: resource.field(self._.blocks, 'proxiable'),
      proxied: resource.field(self._.blocks, 'proxied'),
      settings: resource.field(self._.blocks, 'settings'),
      tags: resource.field(self._.blocks, 'tags'),
      tags_modified_on: resource.field(self._.blocks, 'tags_modified_on'),
      ttl: resource.field(self._.blocks, 'ttl'),
      type: resource.field(self._.blocks, 'type'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    dns_records(name, block): {
      local resource = blockType.resource('cloudflare_dns_records', name),
      _: resource._(
        block,
        attribute(block, 'comment') +
        attribute(block, 'content') +
        attribute(block, 'direction') +
        attribute(block, 'match') +
        attribute(block, 'max_items') +
        attribute(block, 'name') +
        attribute(block, 'order') +
        attribute(block, 'proxied') +
        attribute(block, 'result') +
        attribute(block, 'search') +
        attribute(block, 'tag') +
        attribute(block, 'tag_match') +
        attribute(block, 'type') +
        attribute(block, 'zone_id')
      ),
      comment: resource.field(self._.blocks, 'comment'),
      content: resource.field(self._.blocks, 'content'),
      direction: resource.field(self._.blocks, 'direction'),
      match: resource.field(self._.blocks, 'match'),
      max_items: resource.field(self._.blocks, 'max_items'),
      name: resource.field(self._.blocks, 'name'),
      order: resource.field(self._.blocks, 'order'),
      proxied: resource.field(self._.blocks, 'proxied'),
      result: resource.field(self._.blocks, 'result'),
      search: resource.field(self._.blocks, 'search'),
      tag: resource.field(self._.blocks, 'tag'),
      tag_match: resource.field(self._.blocks, 'tag_match'),
      type: resource.field(self._.blocks, 'type'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    dns_zone_transfers_acl(name, block): {
      local resource = blockType.resource('cloudflare_dns_zone_transfers_acl', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'acl_id', true) +
        attribute(block, 'id') +
        attribute(block, 'ip_range') +
        attribute(block, 'name')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      acl_id: resource.field(self._.blocks, 'acl_id'),
      id: resource.field(self._.blocks, 'id'),
      ip_range: resource.field(self._.blocks, 'ip_range'),
      name: resource.field(self._.blocks, 'name'),
    },
    dns_zone_transfers_acls(name, block): {
      local resource = blockType.resource('cloudflare_dns_zone_transfers_acls', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    dns_zone_transfers_incoming(name, block): {
      local resource = blockType.resource('cloudflare_dns_zone_transfers_incoming', name),
      _: resource._(
        block,
        attribute(block, 'auto_refresh_seconds') +
        attribute(block, 'checked_time') +
        attribute(block, 'created_time') +
        attribute(block, 'id') +
        attribute(block, 'modified_time') +
        attribute(block, 'name') +
        attribute(block, 'peers') +
        attribute(block, 'soa_serial') +
        attribute(block, 'zone_id')
      ),
      auto_refresh_seconds: resource.field(self._.blocks, 'auto_refresh_seconds'),
      checked_time: resource.field(self._.blocks, 'checked_time'),
      created_time: resource.field(self._.blocks, 'created_time'),
      id: resource.field(self._.blocks, 'id'),
      modified_time: resource.field(self._.blocks, 'modified_time'),
      name: resource.field(self._.blocks, 'name'),
      peers: resource.field(self._.blocks, 'peers'),
      soa_serial: resource.field(self._.blocks, 'soa_serial'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    dns_zone_transfers_outgoing(name, block): {
      local resource = blockType.resource('cloudflare_dns_zone_transfers_outgoing', name),
      _: resource._(
        block,
        attribute(block, 'checked_time') +
        attribute(block, 'created_time') +
        attribute(block, 'id') +
        attribute(block, 'last_transferred_time') +
        attribute(block, 'name') +
        attribute(block, 'peers') +
        attribute(block, 'soa_serial') +
        attribute(block, 'zone_id')
      ),
      checked_time: resource.field(self._.blocks, 'checked_time'),
      created_time: resource.field(self._.blocks, 'created_time'),
      id: resource.field(self._.blocks, 'id'),
      last_transferred_time: resource.field(self._.blocks, 'last_transferred_time'),
      name: resource.field(self._.blocks, 'name'),
      peers: resource.field(self._.blocks, 'peers'),
      soa_serial: resource.field(self._.blocks, 'soa_serial'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    dns_zone_transfers_peer(name, block): {
      local resource = blockType.resource('cloudflare_dns_zone_transfers_peer', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'id') +
        attribute(block, 'ip') +
        attribute(block, 'ixfr_enable') +
        attribute(block, 'name') +
        attribute(block, 'peer_id', true) +
        attribute(block, 'port') +
        attribute(block, 'tsig_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      id: resource.field(self._.blocks, 'id'),
      ip: resource.field(self._.blocks, 'ip'),
      ixfr_enable: resource.field(self._.blocks, 'ixfr_enable'),
      name: resource.field(self._.blocks, 'name'),
      peer_id: resource.field(self._.blocks, 'peer_id'),
      port: resource.field(self._.blocks, 'port'),
      tsig_id: resource.field(self._.blocks, 'tsig_id'),
    },
    dns_zone_transfers_peers(name, block): {
      local resource = blockType.resource('cloudflare_dns_zone_transfers_peers', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    dns_zone_transfers_tsig(name, block): {
      local resource = blockType.resource('cloudflare_dns_zone_transfers_tsig', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'algo') +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'secret') +
        attribute(block, 'tsig_id', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      algo: resource.field(self._.blocks, 'algo'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      secret: resource.field(self._.blocks, 'secret'),
      tsig_id: resource.field(self._.blocks, 'tsig_id'),
    },
    dns_zone_transfers_tsigs(name, block): {
      local resource = blockType.resource('cloudflare_dns_zone_transfers_tsigs', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    email_routing_address(name, block): {
      local resource = blockType.resource('cloudflare_email_routing_address', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created') +
        attribute(block, 'destination_address_identifier') +
        attribute(block, 'email') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'modified') +
        attribute(block, 'tag') +
        attribute(block, 'verified')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created: resource.field(self._.blocks, 'created'),
      destination_address_identifier: resource.field(self._.blocks, 'destination_address_identifier'),
      email: resource.field(self._.blocks, 'email'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      modified: resource.field(self._.blocks, 'modified'),
      tag: resource.field(self._.blocks, 'tag'),
      verified: resource.field(self._.blocks, 'verified'),
    },
    email_routing_addresses(name, block): {
      local resource = blockType.resource('cloudflare_email_routing_addresses', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'direction') +
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'verified')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      direction: resource.field(self._.blocks, 'direction'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      verified: resource.field(self._.blocks, 'verified'),
    },
    email_routing_catch_all(name, block): {
      local resource = blockType.resource('cloudflare_email_routing_catch_all', name),
      _: resource._(
        block,
        attribute(block, 'actions') +
        attribute(block, 'enabled') +
        attribute(block, 'id') +
        attribute(block, 'matchers') +
        attribute(block, 'name') +
        attribute(block, 'tag') +
        attribute(block, 'zone_id')
      ),
      actions: resource.field(self._.blocks, 'actions'),
      enabled: resource.field(self._.blocks, 'enabled'),
      id: resource.field(self._.blocks, 'id'),
      matchers: resource.field(self._.blocks, 'matchers'),
      name: resource.field(self._.blocks, 'name'),
      tag: resource.field(self._.blocks, 'tag'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    email_routing_dns(name, block): {
      local resource = blockType.resource('cloudflare_email_routing_dns', name),
      _: resource._(
        block,
        attribute(block, 'errors') +
        attribute(block, 'id') +
        attribute(block, 'messages') +
        attribute(block, 'result') +
        attribute(block, 'result_info') +
        attribute(block, 'subdomain') +
        attribute(block, 'success') +
        attribute(block, 'zone_id')
      ),
      errors: resource.field(self._.blocks, 'errors'),
      id: resource.field(self._.blocks, 'id'),
      messages: resource.field(self._.blocks, 'messages'),
      result: resource.field(self._.blocks, 'result'),
      result_info: resource.field(self._.blocks, 'result_info'),
      subdomain: resource.field(self._.blocks, 'subdomain'),
      success: resource.field(self._.blocks, 'success'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    email_routing_rule(name, block): {
      local resource = blockType.resource('cloudflare_email_routing_rule', name),
      _: resource._(
        block,
        attribute(block, 'actions') +
        attribute(block, 'enabled') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'matchers') +
        attribute(block, 'name') +
        attribute(block, 'priority') +
        attribute(block, 'rule_identifier') +
        attribute(block, 'tag') +
        attribute(block, 'zone_id')
      ),
      actions: resource.field(self._.blocks, 'actions'),
      enabled: resource.field(self._.blocks, 'enabled'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      matchers: resource.field(self._.blocks, 'matchers'),
      name: resource.field(self._.blocks, 'name'),
      priority: resource.field(self._.blocks, 'priority'),
      rule_identifier: resource.field(self._.blocks, 'rule_identifier'),
      tag: resource.field(self._.blocks, 'tag'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    email_routing_rules(name, block): {
      local resource = blockType.resource('cloudflare_email_routing_rules', name),
      _: resource._(
        block,
        attribute(block, 'enabled') +
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'zone_id')
      ),
      enabled: resource.field(self._.blocks, 'enabled'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    email_routing_settings(name, block): {
      local resource = blockType.resource('cloudflare_email_routing_settings', name),
      _: resource._(
        block,
        attribute(block, 'created') +
        attribute(block, 'enabled') +
        attribute(block, 'id') +
        attribute(block, 'modified') +
        attribute(block, 'name') +
        attribute(block, 'skip_wizard') +
        attribute(block, 'status') +
        attribute(block, 'tag') +
        attribute(block, 'zone_id')
      ),
      created: resource.field(self._.blocks, 'created'),
      enabled: resource.field(self._.blocks, 'enabled'),
      id: resource.field(self._.blocks, 'id'),
      modified: resource.field(self._.blocks, 'modified'),
      name: resource.field(self._.blocks, 'name'),
      skip_wizard: resource.field(self._.blocks, 'skip_wizard'),
      status: resource.field(self._.blocks, 'status'),
      tag: resource.field(self._.blocks, 'tag'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    email_security_block_sender(name, block): {
      local resource = blockType.resource('cloudflare_email_security_block_sender', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'comments') +
        attribute(block, 'created_at') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'is_regex') +
        attribute(block, 'last_modified') +
        attribute(block, 'pattern') +
        attribute(block, 'pattern_id') +
        attribute(block, 'pattern_type')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      comments: resource.field(self._.blocks, 'comments'),
      created_at: resource.field(self._.blocks, 'created_at'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      is_regex: resource.field(self._.blocks, 'is_regex'),
      last_modified: resource.field(self._.blocks, 'last_modified'),
      pattern: resource.field(self._.blocks, 'pattern'),
      pattern_id: resource.field(self._.blocks, 'pattern_id'),
      pattern_type: resource.field(self._.blocks, 'pattern_type'),
    },
    email_security_block_senders(name, block): {
      local resource = blockType.resource('cloudflare_email_security_block_senders', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'direction') +
        attribute(block, 'max_items') +
        attribute(block, 'order') +
        attribute(block, 'pattern') +
        attribute(block, 'pattern_type') +
        attribute(block, 'result') +
        attribute(block, 'search')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      direction: resource.field(self._.blocks, 'direction'),
      max_items: resource.field(self._.blocks, 'max_items'),
      order: resource.field(self._.blocks, 'order'),
      pattern: resource.field(self._.blocks, 'pattern'),
      pattern_type: resource.field(self._.blocks, 'pattern_type'),
      result: resource.field(self._.blocks, 'result'),
      search: resource.field(self._.blocks, 'search'),
    },
    email_security_impersonation_registries(name, block): {
      local resource = blockType.resource('cloudflare_email_security_impersonation_registries', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'direction') +
        attribute(block, 'max_items') +
        attribute(block, 'order') +
        attribute(block, 'provenance') +
        attribute(block, 'result') +
        attribute(block, 'search')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      direction: resource.field(self._.blocks, 'direction'),
      max_items: resource.field(self._.blocks, 'max_items'),
      order: resource.field(self._.blocks, 'order'),
      provenance: resource.field(self._.blocks, 'provenance'),
      result: resource.field(self._.blocks, 'result'),
      search: resource.field(self._.blocks, 'search'),
    },
    email_security_impersonation_registry(name, block): {
      local resource = blockType.resource('cloudflare_email_security_impersonation_registry', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'comments') +
        attribute(block, 'created_at') +
        attribute(block, 'directory_id') +
        attribute(block, 'directory_node_id') +
        attribute(block, 'display_name_id') +
        attribute(block, 'email') +
        attribute(block, 'external_directory_node_id') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'is_email_regex') +
        attribute(block, 'last_modified') +
        attribute(block, 'name') +
        attribute(block, 'provenance')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      comments: resource.field(self._.blocks, 'comments'),
      created_at: resource.field(self._.blocks, 'created_at'),
      directory_id: resource.field(self._.blocks, 'directory_id'),
      directory_node_id: resource.field(self._.blocks, 'directory_node_id'),
      display_name_id: resource.field(self._.blocks, 'display_name_id'),
      email: resource.field(self._.blocks, 'email'),
      external_directory_node_id: resource.field(self._.blocks, 'external_directory_node_id'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      is_email_regex: resource.field(self._.blocks, 'is_email_regex'),
      last_modified: resource.field(self._.blocks, 'last_modified'),
      name: resource.field(self._.blocks, 'name'),
      provenance: resource.field(self._.blocks, 'provenance'),
    },
    email_security_trusted_domains(name, block): {
      local resource = blockType.resource('cloudflare_email_security_trusted_domains', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'comments') +
        attribute(block, 'created_at') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'is_recent') +
        attribute(block, 'is_regex') +
        attribute(block, 'is_similarity') +
        attribute(block, 'last_modified') +
        attribute(block, 'pattern') +
        attribute(block, 'trusted_domain_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      comments: resource.field(self._.blocks, 'comments'),
      created_at: resource.field(self._.blocks, 'created_at'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      is_recent: resource.field(self._.blocks, 'is_recent'),
      is_regex: resource.field(self._.blocks, 'is_regex'),
      is_similarity: resource.field(self._.blocks, 'is_similarity'),
      last_modified: resource.field(self._.blocks, 'last_modified'),
      pattern: resource.field(self._.blocks, 'pattern'),
      trusted_domain_id: resource.field(self._.blocks, 'trusted_domain_id'),
    },
    email_security_trusted_domains_list(name, block): {
      local resource = blockType.resource('cloudflare_email_security_trusted_domains_list', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'direction') +
        attribute(block, 'is_recent') +
        attribute(block, 'is_similarity') +
        attribute(block, 'max_items') +
        attribute(block, 'order') +
        attribute(block, 'pattern') +
        attribute(block, 'result') +
        attribute(block, 'search')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      direction: resource.field(self._.blocks, 'direction'),
      is_recent: resource.field(self._.blocks, 'is_recent'),
      is_similarity: resource.field(self._.blocks, 'is_similarity'),
      max_items: resource.field(self._.blocks, 'max_items'),
      order: resource.field(self._.blocks, 'order'),
      pattern: resource.field(self._.blocks, 'pattern'),
      result: resource.field(self._.blocks, 'result'),
      search: resource.field(self._.blocks, 'search'),
    },
    filter(name, block): {
      local resource = blockType.resource('cloudflare_filter', name),
      _: resource._(
        block,
        attribute(block, 'description') +
        attribute(block, 'expression') +
        attribute(block, 'filter') +
        attribute(block, 'filter_id') +
        attribute(block, 'id') +
        attribute(block, 'paused') +
        attribute(block, 'ref') +
        attribute(block, 'zone_id')
      ),
      description: resource.field(self._.blocks, 'description'),
      expression: resource.field(self._.blocks, 'expression'),
      filter: resource.field(self._.blocks, 'filter'),
      filter_id: resource.field(self._.blocks, 'filter_id'),
      id: resource.field(self._.blocks, 'id'),
      paused: resource.field(self._.blocks, 'paused'),
      ref: resource.field(self._.blocks, 'ref'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    filters(name, block): {
      local resource = blockType.resource('cloudflare_filters', name),
      _: resource._(
        block,
        attribute(block, 'description') +
        attribute(block, 'expression') +
        attribute(block, 'id') +
        attribute(block, 'max_items') +
        attribute(block, 'paused') +
        attribute(block, 'ref') +
        attribute(block, 'result') +
        attribute(block, 'zone_id')
      ),
      description: resource.field(self._.blocks, 'description'),
      expression: resource.field(self._.blocks, 'expression'),
      id: resource.field(self._.blocks, 'id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      paused: resource.field(self._.blocks, 'paused'),
      ref: resource.field(self._.blocks, 'ref'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    firewall_rule(name, block): {
      local resource = blockType.resource('cloudflare_firewall_rule', name),
      _: resource._(
        block,
        attribute(block, 'action') +
        attribute(block, 'description') +
        attribute(block, 'id') +
        attribute(block, 'paused') +
        attribute(block, 'priority') +
        attribute(block, 'products') +
        attribute(block, 'ref') +
        attribute(block, 'rule_id') +
        attribute(block, 'zone_id')
      ),
      action: resource.field(self._.blocks, 'action'),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      paused: resource.field(self._.blocks, 'paused'),
      priority: resource.field(self._.blocks, 'priority'),
      products: resource.field(self._.blocks, 'products'),
      ref: resource.field(self._.blocks, 'ref'),
      rule_id: resource.field(self._.blocks, 'rule_id'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    firewall_rules(name, block): {
      local resource = blockType.resource('cloudflare_firewall_rules', name),
      _: resource._(
        block,
        attribute(block, 'action') +
        attribute(block, 'description') +
        attribute(block, 'id') +
        attribute(block, 'max_items') +
        attribute(block, 'paused') +
        attribute(block, 'result') +
        attribute(block, 'zone_id')
      ),
      action: resource.field(self._.blocks, 'action'),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      paused: resource.field(self._.blocks, 'paused'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    healthcheck(name, block): {
      local resource = blockType.resource('cloudflare_healthcheck', name),
      _: resource._(
        block,
        attribute(block, 'address') +
        attribute(block, 'check_regions') +
        attribute(block, 'consecutive_fails') +
        attribute(block, 'consecutive_successes') +
        attribute(block, 'created_on') +
        attribute(block, 'description') +
        attribute(block, 'failure_reason') +
        attribute(block, 'healthcheck_id', true) +
        attribute(block, 'http_config') +
        attribute(block, 'id') +
        attribute(block, 'interval') +
        attribute(block, 'modified_on') +
        attribute(block, 'name') +
        attribute(block, 'retries') +
        attribute(block, 'status') +
        attribute(block, 'suspended') +
        attribute(block, 'tcp_config') +
        attribute(block, 'timeout') +
        attribute(block, 'type') +
        attribute(block, 'zone_id')
      ),
      address: resource.field(self._.blocks, 'address'),
      check_regions: resource.field(self._.blocks, 'check_regions'),
      consecutive_fails: resource.field(self._.blocks, 'consecutive_fails'),
      consecutive_successes: resource.field(self._.blocks, 'consecutive_successes'),
      created_on: resource.field(self._.blocks, 'created_on'),
      description: resource.field(self._.blocks, 'description'),
      failure_reason: resource.field(self._.blocks, 'failure_reason'),
      healthcheck_id: resource.field(self._.blocks, 'healthcheck_id'),
      http_config: resource.field(self._.blocks, 'http_config'),
      id: resource.field(self._.blocks, 'id'),
      interval: resource.field(self._.blocks, 'interval'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      retries: resource.field(self._.blocks, 'retries'),
      status: resource.field(self._.blocks, 'status'),
      suspended: resource.field(self._.blocks, 'suspended'),
      tcp_config: resource.field(self._.blocks, 'tcp_config'),
      timeout: resource.field(self._.blocks, 'timeout'),
      type: resource.field(self._.blocks, 'type'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    healthchecks(name, block): {
      local resource = blockType.resource('cloudflare_healthchecks', name),
      _: resource._(
        block,
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'zone_id')
      ),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    hostname_tls_setting(name, block): {
      local resource = blockType.resource('cloudflare_hostname_tls_setting', name),
      _: resource._(
        block,
        attribute(block, 'created_at') +
        attribute(block, 'hostname') +
        attribute(block, 'id') +
        attribute(block, 'setting_id', true) +
        attribute(block, 'status') +
        attribute(block, 'updated_at') +
        attribute(block, 'value') +
        attribute(block, 'zone_id')
      ),
      created_at: resource.field(self._.blocks, 'created_at'),
      hostname: resource.field(self._.blocks, 'hostname'),
      id: resource.field(self._.blocks, 'id'),
      setting_id: resource.field(self._.blocks, 'setting_id'),
      status: resource.field(self._.blocks, 'status'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      value: resource.field(self._.blocks, 'value'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    hyperdrive_config(name, block): {
      local resource = blockType.resource('cloudflare_hyperdrive_config', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'caching') +
        attribute(block, 'created_on') +
        attribute(block, 'hyperdrive_id', true) +
        attribute(block, 'id') +
        attribute(block, 'modified_on') +
        attribute(block, 'mtls') +
        attribute(block, 'name') +
        attribute(block, 'origin') +
        attribute(block, 'origin_connection_limit')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      caching: resource.field(self._.blocks, 'caching'),
      created_on: resource.field(self._.blocks, 'created_on'),
      hyperdrive_id: resource.field(self._.blocks, 'hyperdrive_id'),
      id: resource.field(self._.blocks, 'id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      mtls: resource.field(self._.blocks, 'mtls'),
      name: resource.field(self._.blocks, 'name'),
      origin: resource.field(self._.blocks, 'origin'),
      origin_connection_limit: resource.field(self._.blocks, 'origin_connection_limit'),
    },
    hyperdrive_configs(name, block): {
      local resource = blockType.resource('cloudflare_hyperdrive_configs', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    image(name, block): {
      local resource = blockType.resource('cloudflare_image', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'creator') +
        attribute(block, 'filename') +
        attribute(block, 'id') +
        attribute(block, 'image_id', true) +
        attribute(block, 'meta') +
        attribute(block, 'require_signed_urls') +
        attribute(block, 'uploaded') +
        attribute(block, 'variants')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      creator: resource.field(self._.blocks, 'creator'),
      filename: resource.field(self._.blocks, 'filename'),
      id: resource.field(self._.blocks, 'id'),
      image_id: resource.field(self._.blocks, 'image_id'),
      meta: resource.field(self._.blocks, 'meta'),
      require_signed_urls: resource.field(self._.blocks, 'require_signed_urls'),
      uploaded: resource.field(self._.blocks, 'uploaded'),
      variants: resource.field(self._.blocks, 'variants'),
    },
    image_variant(name, block): {
      local resource = blockType.resource('cloudflare_image_variant', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'id') +
        attribute(block, 'variant') +
        attribute(block, 'variant_id', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      id: resource.field(self._.blocks, 'id'),
      variant: resource.field(self._.blocks, 'variant'),
      variant_id: resource.field(self._.blocks, 'variant_id'),
    },
    images(name, block): {
      local resource = blockType.resource('cloudflare_images', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'creator') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      creator: resource.field(self._.blocks, 'creator'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    ip_ranges(name, block): {
      local resource = blockType.resource('cloudflare_ip_ranges', name),
      _: resource._(
        block,
        attribute(block, 'etag') +
        attribute(block, 'ipv4_cidrs') +
        attribute(block, 'ipv6_cidrs') +
        attribute(block, 'jdcloud_cidrs') +
        attribute(block, 'networks')
      ),
      etag: resource.field(self._.blocks, 'etag'),
      ipv4_cidrs: resource.field(self._.blocks, 'ipv4_cidrs'),
      ipv6_cidrs: resource.field(self._.blocks, 'ipv6_cidrs'),
      jdcloud_cidrs: resource.field(self._.blocks, 'jdcloud_cidrs'),
      networks: resource.field(self._.blocks, 'networks'),
    },
    keyless_certificate(name, block): {
      local resource = blockType.resource('cloudflare_keyless_certificate', name),
      _: resource._(
        block,
        attribute(block, 'created_on') +
        attribute(block, 'enabled') +
        attribute(block, 'host') +
        attribute(block, 'id') +
        attribute(block, 'keyless_certificate_id', true) +
        attribute(block, 'modified_on') +
        attribute(block, 'name') +
        attribute(block, 'permissions') +
        attribute(block, 'port') +
        attribute(block, 'status') +
        attribute(block, 'tunnel') +
        attribute(block, 'zone_id')
      ),
      created_on: resource.field(self._.blocks, 'created_on'),
      enabled: resource.field(self._.blocks, 'enabled'),
      host: resource.field(self._.blocks, 'host'),
      id: resource.field(self._.blocks, 'id'),
      keyless_certificate_id: resource.field(self._.blocks, 'keyless_certificate_id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      permissions: resource.field(self._.blocks, 'permissions'),
      port: resource.field(self._.blocks, 'port'),
      status: resource.field(self._.blocks, 'status'),
      tunnel: resource.field(self._.blocks, 'tunnel'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    keyless_certificates(name, block): {
      local resource = blockType.resource('cloudflare_keyless_certificates', name),
      _: resource._(
        block,
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'zone_id')
      ),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    leaked_credential_check(name, block): {
      local resource = blockType.resource('cloudflare_leaked_credential_check', name),
      _: resource._(
        block,
        attribute(block, 'enabled') +
        attribute(block, 'zone_id')
      ),
      enabled: resource.field(self._.blocks, 'enabled'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    leaked_credential_check_rule(name, block): {
      local resource = blockType.resource('cloudflare_leaked_credential_check_rule', name),
      _: resource._(
        block,
        attribute(block, 'detection_id', true) +
        attribute(block, 'id') +
        attribute(block, 'password') +
        attribute(block, 'username') +
        attribute(block, 'zone_id')
      ),
      detection_id: resource.field(self._.blocks, 'detection_id'),
      id: resource.field(self._.blocks, 'id'),
      password: resource.field(self._.blocks, 'password'),
      username: resource.field(self._.blocks, 'username'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    leaked_credential_check_rules(name, block): {
      local resource = blockType.resource('cloudflare_leaked_credential_check_rules', name),
      _: resource._(
        block,
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'zone_id')
      ),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    list(name, block): {
      local resource = blockType.resource('cloudflare_list', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_on') +
        attribute(block, 'description') +
        attribute(block, 'id') +
        attribute(block, 'items') +
        attribute(block, 'kind') +
        attribute(block, 'list_id', true) +
        attribute(block, 'modified_on') +
        attribute(block, 'name') +
        attribute(block, 'num_items') +
        attribute(block, 'num_referencing_filters') +
        attribute(block, 'search')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_on: resource.field(self._.blocks, 'created_on'),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      items: resource.field(self._.blocks, 'items'),
      kind: resource.field(self._.blocks, 'kind'),
      list_id: resource.field(self._.blocks, 'list_id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      num_items: resource.field(self._.blocks, 'num_items'),
      num_referencing_filters: resource.field(self._.blocks, 'num_referencing_filters'),
      search: resource.field(self._.blocks, 'search'),
    },
    list_item(name, block): {
      local resource = blockType.resource('cloudflare_list_item', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'asn') +
        attribute(block, 'comment') +
        attribute(block, 'created_on') +
        attribute(block, 'hostname') +
        attribute(block, 'id') +
        attribute(block, 'ip') +
        attribute(block, 'item_id', true) +
        attribute(block, 'list_id', true) +
        attribute(block, 'modified_on') +
        attribute(block, 'redirect')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      asn: resource.field(self._.blocks, 'asn'),
      comment: resource.field(self._.blocks, 'comment'),
      created_on: resource.field(self._.blocks, 'created_on'),
      hostname: resource.field(self._.blocks, 'hostname'),
      id: resource.field(self._.blocks, 'id'),
      ip: resource.field(self._.blocks, 'ip'),
      item_id: resource.field(self._.blocks, 'item_id'),
      list_id: resource.field(self._.blocks, 'list_id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      redirect: resource.field(self._.blocks, 'redirect'),
    },
    list_items(name, block): {
      local resource = blockType.resource('cloudflare_list_items', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'list_id', true) +
        attribute(block, 'max_items') +
        attribute(block, 'per_page') +
        attribute(block, 'result') +
        attribute(block, 'search')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      list_id: resource.field(self._.blocks, 'list_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      per_page: resource.field(self._.blocks, 'per_page'),
      result: resource.field(self._.blocks, 'result'),
      search: resource.field(self._.blocks, 'search'),
    },
    lists(name, block): {
      local resource = blockType.resource('cloudflare_lists', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    load_balancer(name, block): {
      local resource = blockType.resource('cloudflare_load_balancer', name),
      _: resource._(
        block,
        attribute(block, 'adaptive_routing') +
        attribute(block, 'country_pools') +
        attribute(block, 'created_on') +
        attribute(block, 'default_pools') +
        attribute(block, 'description') +
        attribute(block, 'enabled') +
        attribute(block, 'fallback_pool') +
        attribute(block, 'id') +
        attribute(block, 'load_balancer_id', true) +
        attribute(block, 'location_strategy') +
        attribute(block, 'modified_on') +
        attribute(block, 'name') +
        attribute(block, 'networks') +
        attribute(block, 'pop_pools') +
        attribute(block, 'proxied') +
        attribute(block, 'random_steering') +
        attribute(block, 'region_pools') +
        attribute(block, 'rules') +
        attribute(block, 'session_affinity') +
        attribute(block, 'session_affinity_attributes') +
        attribute(block, 'session_affinity_ttl') +
        attribute(block, 'steering_policy') +
        attribute(block, 'ttl') +
        attribute(block, 'zone_id')
      ),
      adaptive_routing: resource.field(self._.blocks, 'adaptive_routing'),
      country_pools: resource.field(self._.blocks, 'country_pools'),
      created_on: resource.field(self._.blocks, 'created_on'),
      default_pools: resource.field(self._.blocks, 'default_pools'),
      description: resource.field(self._.blocks, 'description'),
      enabled: resource.field(self._.blocks, 'enabled'),
      fallback_pool: resource.field(self._.blocks, 'fallback_pool'),
      id: resource.field(self._.blocks, 'id'),
      load_balancer_id: resource.field(self._.blocks, 'load_balancer_id'),
      location_strategy: resource.field(self._.blocks, 'location_strategy'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      networks: resource.field(self._.blocks, 'networks'),
      pop_pools: resource.field(self._.blocks, 'pop_pools'),
      proxied: resource.field(self._.blocks, 'proxied'),
      random_steering: resource.field(self._.blocks, 'random_steering'),
      region_pools: resource.field(self._.blocks, 'region_pools'),
      rules: resource.field(self._.blocks, 'rules'),
      session_affinity: resource.field(self._.blocks, 'session_affinity'),
      session_affinity_attributes: resource.field(self._.blocks, 'session_affinity_attributes'),
      session_affinity_ttl: resource.field(self._.blocks, 'session_affinity_ttl'),
      steering_policy: resource.field(self._.blocks, 'steering_policy'),
      ttl: resource.field(self._.blocks, 'ttl'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    load_balancer_monitor(name, block): {
      local resource = blockType.resource('cloudflare_load_balancer_monitor', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'allow_insecure') +
        attribute(block, 'consecutive_down') +
        attribute(block, 'consecutive_up') +
        attribute(block, 'created_on') +
        attribute(block, 'description') +
        attribute(block, 'expected_body') +
        attribute(block, 'expected_codes') +
        attribute(block, 'follow_redirects') +
        attribute(block, 'header') +
        attribute(block, 'id') +
        attribute(block, 'interval') +
        attribute(block, 'method') +
        attribute(block, 'modified_on') +
        attribute(block, 'monitor_id', true) +
        attribute(block, 'path') +
        attribute(block, 'port') +
        attribute(block, 'probe_zone') +
        attribute(block, 'retries') +
        attribute(block, 'timeout') +
        attribute(block, 'type')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      allow_insecure: resource.field(self._.blocks, 'allow_insecure'),
      consecutive_down: resource.field(self._.blocks, 'consecutive_down'),
      consecutive_up: resource.field(self._.blocks, 'consecutive_up'),
      created_on: resource.field(self._.blocks, 'created_on'),
      description: resource.field(self._.blocks, 'description'),
      expected_body: resource.field(self._.blocks, 'expected_body'),
      expected_codes: resource.field(self._.blocks, 'expected_codes'),
      follow_redirects: resource.field(self._.blocks, 'follow_redirects'),
      header: resource.field(self._.blocks, 'header'),
      id: resource.field(self._.blocks, 'id'),
      interval: resource.field(self._.blocks, 'interval'),
      method: resource.field(self._.blocks, 'method'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      monitor_id: resource.field(self._.blocks, 'monitor_id'),
      path: resource.field(self._.blocks, 'path'),
      port: resource.field(self._.blocks, 'port'),
      probe_zone: resource.field(self._.blocks, 'probe_zone'),
      retries: resource.field(self._.blocks, 'retries'),
      timeout: resource.field(self._.blocks, 'timeout'),
      type: resource.field(self._.blocks, 'type'),
    },
    load_balancer_monitors(name, block): {
      local resource = blockType.resource('cloudflare_load_balancer_monitors', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    load_balancer_pool(name, block): {
      local resource = blockType.resource('cloudflare_load_balancer_pool', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'check_regions') +
        attribute(block, 'created_on') +
        attribute(block, 'description') +
        attribute(block, 'disabled_at') +
        attribute(block, 'enabled') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'latitude') +
        attribute(block, 'load_shedding') +
        attribute(block, 'longitude') +
        attribute(block, 'minimum_origins') +
        attribute(block, 'modified_on') +
        attribute(block, 'monitor') +
        attribute(block, 'monitor_group') +
        attribute(block, 'name') +
        attribute(block, 'networks') +
        attribute(block, 'notification_email') +
        attribute(block, 'notification_filter') +
        attribute(block, 'origin_steering') +
        attribute(block, 'origins') +
        attribute(block, 'pool_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      check_regions: resource.field(self._.blocks, 'check_regions'),
      created_on: resource.field(self._.blocks, 'created_on'),
      description: resource.field(self._.blocks, 'description'),
      disabled_at: resource.field(self._.blocks, 'disabled_at'),
      enabled: resource.field(self._.blocks, 'enabled'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      latitude: resource.field(self._.blocks, 'latitude'),
      load_shedding: resource.field(self._.blocks, 'load_shedding'),
      longitude: resource.field(self._.blocks, 'longitude'),
      minimum_origins: resource.field(self._.blocks, 'minimum_origins'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      monitor: resource.field(self._.blocks, 'monitor'),
      monitor_group: resource.field(self._.blocks, 'monitor_group'),
      name: resource.field(self._.blocks, 'name'),
      networks: resource.field(self._.blocks, 'networks'),
      notification_email: resource.field(self._.blocks, 'notification_email'),
      notification_filter: resource.field(self._.blocks, 'notification_filter'),
      origin_steering: resource.field(self._.blocks, 'origin_steering'),
      origins: resource.field(self._.blocks, 'origins'),
      pool_id: resource.field(self._.blocks, 'pool_id'),
    },
    load_balancer_pools(name, block): {
      local resource = blockType.resource('cloudflare_load_balancer_pools', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'monitor') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      monitor: resource.field(self._.blocks, 'monitor'),
      result: resource.field(self._.blocks, 'result'),
    },
    load_balancers(name, block): {
      local resource = blockType.resource('cloudflare_load_balancers', name),
      _: resource._(
        block,
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'zone_id')
      ),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    logpull_retention(name, block): {
      local resource = blockType.resource('cloudflare_logpull_retention', name),
      _: resource._(
        block,
        attribute(block, 'flag') +
        attribute(block, 'id') +
        attribute(block, 'zone_id')
      ),
      flag: resource.field(self._.blocks, 'flag'),
      id: resource.field(self._.blocks, 'id'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    logpush_dataset_field(name, block): {
      local resource = blockType.resource('cloudflare_logpush_dataset_field', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'dataset_id') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      dataset_id: resource.field(self._.blocks, 'dataset_id'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    logpush_dataset_job(name, block): {
      local resource = blockType.resource('cloudflare_logpush_dataset_job', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'dataset') +
        attribute(block, 'dataset_id') +
        attribute(block, 'destination_conf') +
        attribute(block, 'enabled') +
        attribute(block, 'error_message') +
        attribute(block, 'frequency') +
        attribute(block, 'id') +
        attribute(block, 'kind') +
        attribute(block, 'last_complete') +
        attribute(block, 'last_error') +
        attribute(block, 'logpull_options') +
        attribute(block, 'max_upload_bytes') +
        attribute(block, 'max_upload_interval_seconds') +
        attribute(block, 'max_upload_records') +
        attribute(block, 'name') +
        attribute(block, 'output_options') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      dataset: resource.field(self._.blocks, 'dataset'),
      dataset_id: resource.field(self._.blocks, 'dataset_id'),
      destination_conf: resource.field(self._.blocks, 'destination_conf'),
      enabled: resource.field(self._.blocks, 'enabled'),
      error_message: resource.field(self._.blocks, 'error_message'),
      frequency: resource.field(self._.blocks, 'frequency'),
      id: resource.field(self._.blocks, 'id'),
      kind: resource.field(self._.blocks, 'kind'),
      last_complete: resource.field(self._.blocks, 'last_complete'),
      last_error: resource.field(self._.blocks, 'last_error'),
      logpull_options: resource.field(self._.blocks, 'logpull_options'),
      max_upload_bytes: resource.field(self._.blocks, 'max_upload_bytes'),
      max_upload_interval_seconds: resource.field(self._.blocks, 'max_upload_interval_seconds'),
      max_upload_records: resource.field(self._.blocks, 'max_upload_records'),
      name: resource.field(self._.blocks, 'name'),
      output_options: resource.field(self._.blocks, 'output_options'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    logpush_job(name, block): {
      local resource = blockType.resource('cloudflare_logpush_job', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'dataset') +
        attribute(block, 'destination_conf') +
        attribute(block, 'enabled') +
        attribute(block, 'error_message') +
        attribute(block, 'frequency') +
        attribute(block, 'id') +
        attribute(block, 'job_id', true) +
        attribute(block, 'kind') +
        attribute(block, 'last_complete') +
        attribute(block, 'last_error') +
        attribute(block, 'logpull_options') +
        attribute(block, 'max_upload_bytes') +
        attribute(block, 'max_upload_interval_seconds') +
        attribute(block, 'max_upload_records') +
        attribute(block, 'name') +
        attribute(block, 'output_options') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      dataset: resource.field(self._.blocks, 'dataset'),
      destination_conf: resource.field(self._.blocks, 'destination_conf'),
      enabled: resource.field(self._.blocks, 'enabled'),
      error_message: resource.field(self._.blocks, 'error_message'),
      frequency: resource.field(self._.blocks, 'frequency'),
      id: resource.field(self._.blocks, 'id'),
      job_id: resource.field(self._.blocks, 'job_id'),
      kind: resource.field(self._.blocks, 'kind'),
      last_complete: resource.field(self._.blocks, 'last_complete'),
      last_error: resource.field(self._.blocks, 'last_error'),
      logpull_options: resource.field(self._.blocks, 'logpull_options'),
      max_upload_bytes: resource.field(self._.blocks, 'max_upload_bytes'),
      max_upload_interval_seconds: resource.field(self._.blocks, 'max_upload_interval_seconds'),
      max_upload_records: resource.field(self._.blocks, 'max_upload_records'),
      name: resource.field(self._.blocks, 'name'),
      output_options: resource.field(self._.blocks, 'output_options'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    logpush_jobs(name, block): {
      local resource = blockType.resource('cloudflare_logpush_jobs', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    magic_network_monitoring_configuration(name, block): {
      local resource = blockType.resource('cloudflare_magic_network_monitoring_configuration', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'default_sampling') +
        attribute(block, 'name') +
        attribute(block, 'router_ips') +
        attribute(block, 'warp_devices')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      default_sampling: resource.field(self._.blocks, 'default_sampling'),
      name: resource.field(self._.blocks, 'name'),
      router_ips: resource.field(self._.blocks, 'router_ips'),
      warp_devices: resource.field(self._.blocks, 'warp_devices'),
    },
    magic_network_monitoring_rule(name, block): {
      local resource = blockType.resource('cloudflare_magic_network_monitoring_rule', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'automatic_advertisement') +
        attribute(block, 'bandwidth_threshold') +
        attribute(block, 'duration') +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'packet_threshold') +
        attribute(block, 'prefix_match') +
        attribute(block, 'prefixes') +
        attribute(block, 'rule_id', true) +
        attribute(block, 'type') +
        attribute(block, 'zscore_sensitivity') +
        attribute(block, 'zscore_target')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      automatic_advertisement: resource.field(self._.blocks, 'automatic_advertisement'),
      bandwidth_threshold: resource.field(self._.blocks, 'bandwidth_threshold'),
      duration: resource.field(self._.blocks, 'duration'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      packet_threshold: resource.field(self._.blocks, 'packet_threshold'),
      prefix_match: resource.field(self._.blocks, 'prefix_match'),
      prefixes: resource.field(self._.blocks, 'prefixes'),
      rule_id: resource.field(self._.blocks, 'rule_id'),
      type: resource.field(self._.blocks, 'type'),
      zscore_sensitivity: resource.field(self._.blocks, 'zscore_sensitivity'),
      zscore_target: resource.field(self._.blocks, 'zscore_target'),
    },
    magic_network_monitoring_rules(name, block): {
      local resource = blockType.resource('cloudflare_magic_network_monitoring_rules', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    magic_transit_connector(name, block): {
      local resource = blockType.resource('cloudflare_magic_transit_connector', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'activated') +
        attribute(block, 'connector_id', true) +
        attribute(block, 'device') +
        attribute(block, 'id') +
        attribute(block, 'interrupt_window_days_of_week') +
        attribute(block, 'interrupt_window_duration_hours') +
        attribute(block, 'interrupt_window_embargo_dates') +
        attribute(block, 'interrupt_window_hour_of_day') +
        attribute(block, 'last_heartbeat') +
        attribute(block, 'last_seen_version') +
        attribute(block, 'last_updated') +
        attribute(block, 'license_key') +
        attribute(block, 'notes') +
        attribute(block, 'timezone')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      activated: resource.field(self._.blocks, 'activated'),
      connector_id: resource.field(self._.blocks, 'connector_id'),
      device: resource.field(self._.blocks, 'device'),
      id: resource.field(self._.blocks, 'id'),
      interrupt_window_days_of_week: resource.field(self._.blocks, 'interrupt_window_days_of_week'),
      interrupt_window_duration_hours: resource.field(self._.blocks, 'interrupt_window_duration_hours'),
      interrupt_window_embargo_dates: resource.field(self._.blocks, 'interrupt_window_embargo_dates'),
      interrupt_window_hour_of_day: resource.field(self._.blocks, 'interrupt_window_hour_of_day'),
      last_heartbeat: resource.field(self._.blocks, 'last_heartbeat'),
      last_seen_version: resource.field(self._.blocks, 'last_seen_version'),
      last_updated: resource.field(self._.blocks, 'last_updated'),
      license_key: resource.field(self._.blocks, 'license_key'),
      notes: resource.field(self._.blocks, 'notes'),
      timezone: resource.field(self._.blocks, 'timezone'),
    },
    magic_transit_connectors(name, block): {
      local resource = blockType.resource('cloudflare_magic_transit_connectors', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    magic_transit_site(name, block): {
      local resource = blockType.resource('cloudflare_magic_transit_site', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'connector_id') +
        attribute(block, 'description') +
        attribute(block, 'filter') +
        attribute(block, 'ha_mode') +
        attribute(block, 'id') +
        attribute(block, 'location') +
        attribute(block, 'name') +
        attribute(block, 'secondary_connector_id') +
        attribute(block, 'site_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      connector_id: resource.field(self._.blocks, 'connector_id'),
      description: resource.field(self._.blocks, 'description'),
      filter: resource.field(self._.blocks, 'filter'),
      ha_mode: resource.field(self._.blocks, 'ha_mode'),
      id: resource.field(self._.blocks, 'id'),
      location: resource.field(self._.blocks, 'location'),
      name: resource.field(self._.blocks, 'name'),
      secondary_connector_id: resource.field(self._.blocks, 'secondary_connector_id'),
      site_id: resource.field(self._.blocks, 'site_id'),
    },
    magic_transit_site_acl(name, block): {
      local resource = blockType.resource('cloudflare_magic_transit_site_acl', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'acl_id', true) +
        attribute(block, 'description') +
        attribute(block, 'forward_locally') +
        attribute(block, 'id') +
        attribute(block, 'lan_1') +
        attribute(block, 'lan_2') +
        attribute(block, 'name') +
        attribute(block, 'protocols') +
        attribute(block, 'site_id', true) +
        attribute(block, 'unidirectional')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      acl_id: resource.field(self._.blocks, 'acl_id'),
      description: resource.field(self._.blocks, 'description'),
      forward_locally: resource.field(self._.blocks, 'forward_locally'),
      id: resource.field(self._.blocks, 'id'),
      lan_1: resource.field(self._.blocks, 'lan_1'),
      lan_2: resource.field(self._.blocks, 'lan_2'),
      name: resource.field(self._.blocks, 'name'),
      protocols: resource.field(self._.blocks, 'protocols'),
      site_id: resource.field(self._.blocks, 'site_id'),
      unidirectional: resource.field(self._.blocks, 'unidirectional'),
    },
    magic_transit_site_acls(name, block): {
      local resource = blockType.resource('cloudflare_magic_transit_site_acls', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'site_id', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      site_id: resource.field(self._.blocks, 'site_id'),
    },
    magic_transit_site_lan(name, block): {
      local resource = blockType.resource('cloudflare_magic_transit_site_lan', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'bond_id') +
        attribute(block, 'ha_link') +
        attribute(block, 'id') +
        attribute(block, 'is_breakout') +
        attribute(block, 'is_prioritized') +
        attribute(block, 'lan_id', true) +
        attribute(block, 'name') +
        attribute(block, 'nat') +
        attribute(block, 'physport') +
        attribute(block, 'routed_subnets') +
        attribute(block, 'site_id', true) +
        attribute(block, 'static_addressing') +
        attribute(block, 'vlan_tag')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      bond_id: resource.field(self._.blocks, 'bond_id'),
      ha_link: resource.field(self._.blocks, 'ha_link'),
      id: resource.field(self._.blocks, 'id'),
      is_breakout: resource.field(self._.blocks, 'is_breakout'),
      is_prioritized: resource.field(self._.blocks, 'is_prioritized'),
      lan_id: resource.field(self._.blocks, 'lan_id'),
      name: resource.field(self._.blocks, 'name'),
      nat: resource.field(self._.blocks, 'nat'),
      physport: resource.field(self._.blocks, 'physport'),
      routed_subnets: resource.field(self._.blocks, 'routed_subnets'),
      site_id: resource.field(self._.blocks, 'site_id'),
      static_addressing: resource.field(self._.blocks, 'static_addressing'),
      vlan_tag: resource.field(self._.blocks, 'vlan_tag'),
    },
    magic_transit_site_lans(name, block): {
      local resource = blockType.resource('cloudflare_magic_transit_site_lans', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'site_id', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      site_id: resource.field(self._.blocks, 'site_id'),
    },
    magic_transit_site_wan(name, block): {
      local resource = blockType.resource('cloudflare_magic_transit_site_wan', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'health_check_rate') +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'physport') +
        attribute(block, 'priority') +
        attribute(block, 'site_id', true) +
        attribute(block, 'static_addressing') +
        attribute(block, 'vlan_tag') +
        attribute(block, 'wan_id', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      health_check_rate: resource.field(self._.blocks, 'health_check_rate'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      physport: resource.field(self._.blocks, 'physport'),
      priority: resource.field(self._.blocks, 'priority'),
      site_id: resource.field(self._.blocks, 'site_id'),
      static_addressing: resource.field(self._.blocks, 'static_addressing'),
      vlan_tag: resource.field(self._.blocks, 'vlan_tag'),
      wan_id: resource.field(self._.blocks, 'wan_id'),
    },
    magic_transit_site_wans(name, block): {
      local resource = blockType.resource('cloudflare_magic_transit_site_wans', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'site_id', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      site_id: resource.field(self._.blocks, 'site_id'),
    },
    magic_transit_sites(name, block): {
      local resource = blockType.resource('cloudflare_magic_transit_sites', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'connectorid') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      connectorid: resource.field(self._.blocks, 'connectorid'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    magic_wan_gre_tunnel(name, block): {
      local resource = blockType.resource('cloudflare_magic_wan_gre_tunnel', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'gre_tunnel') +
        attribute(block, 'gre_tunnel_id', true) +
        attribute(block, 'id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      gre_tunnel: resource.field(self._.blocks, 'gre_tunnel'),
      gre_tunnel_id: resource.field(self._.blocks, 'gre_tunnel_id'),
      id: resource.field(self._.blocks, 'id'),
    },
    magic_wan_ipsec_tunnel(name, block): {
      local resource = blockType.resource('cloudflare_magic_wan_ipsec_tunnel', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'id') +
        attribute(block, 'ipsec_tunnel') +
        attribute(block, 'ipsec_tunnel_id', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      id: resource.field(self._.blocks, 'id'),
      ipsec_tunnel: resource.field(self._.blocks, 'ipsec_tunnel'),
      ipsec_tunnel_id: resource.field(self._.blocks, 'ipsec_tunnel_id'),
    },
    magic_wan_static_route(name, block): {
      local resource = blockType.resource('cloudflare_magic_wan_static_route', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'id') +
        attribute(block, 'route') +
        attribute(block, 'route_id', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      id: resource.field(self._.blocks, 'id'),
      route: resource.field(self._.blocks, 'route'),
      route_id: resource.field(self._.blocks, 'route_id'),
    },
    managed_transforms(name, block): {
      local resource = blockType.resource('cloudflare_managed_transforms', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'managed_request_headers') +
        attribute(block, 'managed_response_headers') +
        attribute(block, 'zone_id')
      ),
      id: resource.field(self._.blocks, 'id'),
      managed_request_headers: resource.field(self._.blocks, 'managed_request_headers'),
      managed_response_headers: resource.field(self._.blocks, 'managed_response_headers'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    mtls_certificate(name, block): {
      local resource = blockType.resource('cloudflare_mtls_certificate', name),
      _: resource._(
        block,
        attribute(block, 'account_id', true) +
        attribute(block, 'ca') +
        attribute(block, 'certificates') +
        attribute(block, 'expires_on') +
        attribute(block, 'id') +
        attribute(block, 'issuer') +
        attribute(block, 'mtls_certificate_id', true) +
        attribute(block, 'name') +
        attribute(block, 'serial_number') +
        attribute(block, 'signature') +
        attribute(block, 'uploaded_on')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      ca: resource.field(self._.blocks, 'ca'),
      certificates: resource.field(self._.blocks, 'certificates'),
      expires_on: resource.field(self._.blocks, 'expires_on'),
      id: resource.field(self._.blocks, 'id'),
      issuer: resource.field(self._.blocks, 'issuer'),
      mtls_certificate_id: resource.field(self._.blocks, 'mtls_certificate_id'),
      name: resource.field(self._.blocks, 'name'),
      serial_number: resource.field(self._.blocks, 'serial_number'),
      signature: resource.field(self._.blocks, 'signature'),
      uploaded_on: resource.field(self._.blocks, 'uploaded_on'),
    },
    mtls_certificate_associations(name, block): {
      local resource = blockType.resource('cloudflare_mtls_certificate_associations', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'mtls_certificate_id', true) +
        attribute(block, 'service') +
        attribute(block, 'status')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      mtls_certificate_id: resource.field(self._.blocks, 'mtls_certificate_id'),
      service: resource.field(self._.blocks, 'service'),
      status: resource.field(self._.blocks, 'status'),
    },
    mtls_certificates(name, block): {
      local resource = blockType.resource('cloudflare_mtls_certificates', name),
      _: resource._(
        block,
        attribute(block, 'account_id', true) +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    notification_policies(name, block): {
      local resource = blockType.resource('cloudflare_notification_policies', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    notification_policy(name, block): {
      local resource = blockType.resource('cloudflare_notification_policy', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'alert_interval') +
        attribute(block, 'alert_type') +
        attribute(block, 'created') +
        attribute(block, 'description') +
        attribute(block, 'enabled') +
        attribute(block, 'filters') +
        attribute(block, 'id') +
        attribute(block, 'mechanisms') +
        attribute(block, 'modified') +
        attribute(block, 'name') +
        attribute(block, 'policy_id', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      alert_interval: resource.field(self._.blocks, 'alert_interval'),
      alert_type: resource.field(self._.blocks, 'alert_type'),
      created: resource.field(self._.blocks, 'created'),
      description: resource.field(self._.blocks, 'description'),
      enabled: resource.field(self._.blocks, 'enabled'),
      filters: resource.field(self._.blocks, 'filters'),
      id: resource.field(self._.blocks, 'id'),
      mechanisms: resource.field(self._.blocks, 'mechanisms'),
      modified: resource.field(self._.blocks, 'modified'),
      name: resource.field(self._.blocks, 'name'),
      policy_id: resource.field(self._.blocks, 'policy_id'),
    },
    notification_policy_webhooks(name, block): {
      local resource = blockType.resource('cloudflare_notification_policy_webhooks', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_at') +
        attribute(block, 'id') +
        attribute(block, 'last_failure') +
        attribute(block, 'last_success') +
        attribute(block, 'name') +
        attribute(block, 'secret') +
        attribute(block, 'type') +
        attribute(block, 'url') +
        attribute(block, 'webhook_id', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_at: resource.field(self._.blocks, 'created_at'),
      id: resource.field(self._.blocks, 'id'),
      last_failure: resource.field(self._.blocks, 'last_failure'),
      last_success: resource.field(self._.blocks, 'last_success'),
      name: resource.field(self._.blocks, 'name'),
      secret: resource.field(self._.blocks, 'secret'),
      type: resource.field(self._.blocks, 'type'),
      url: resource.field(self._.blocks, 'url'),
      webhook_id: resource.field(self._.blocks, 'webhook_id'),
    },
    notification_policy_webhooks_list(name, block): {
      local resource = blockType.resource('cloudflare_notification_policy_webhooks_list', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    observatory_scheduled_test(name, block): {
      local resource = blockType.resource('cloudflare_observatory_scheduled_test', name),
      _: resource._(
        block,
        attribute(block, 'frequency') +
        attribute(block, 'region') +
        attribute(block, 'url', true) +
        attribute(block, 'zone_id')
      ),
      frequency: resource.field(self._.blocks, 'frequency'),
      region: resource.field(self._.blocks, 'region'),
      url: resource.field(self._.blocks, 'url'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    organization(name, block): {
      local resource = blockType.resource('cloudflare_organization', name),
      _: resource._(
        block,
        attribute(block, 'create_time') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'meta') +
        attribute(block, 'name') +
        attribute(block, 'organization_id') +
        attribute(block, 'parent') +
        attribute(block, 'profile')
      ),
      create_time: resource.field(self._.blocks, 'create_time'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      meta: resource.field(self._.blocks, 'meta'),
      name: resource.field(self._.blocks, 'name'),
      organization_id: resource.field(self._.blocks, 'organization_id'),
      parent: resource.field(self._.blocks, 'parent'),
      profile: resource.field(self._.blocks, 'profile'),
    },
    organization_profile(name, block): {
      local resource = blockType.resource('cloudflare_organization_profile', name),
      _: resource._(
        block,
        attribute(block, 'business_address') +
        attribute(block, 'business_email') +
        attribute(block, 'business_name') +
        attribute(block, 'business_phone') +
        attribute(block, 'external_metadata') +
        attribute(block, 'organization_id', true)
      ),
      business_address: resource.field(self._.blocks, 'business_address'),
      business_email: resource.field(self._.blocks, 'business_email'),
      business_name: resource.field(self._.blocks, 'business_name'),
      business_phone: resource.field(self._.blocks, 'business_phone'),
      external_metadata: resource.field(self._.blocks, 'external_metadata'),
      organization_id: resource.field(self._.blocks, 'organization_id'),
    },
    organizations(name, block): {
      local resource = blockType.resource('cloudflare_organizations', name),
      _: resource._(
        block,
        attribute(block, 'containing') +
        attribute(block, 'id') +
        attribute(block, 'max_items') +
        attribute(block, 'name') +
        attribute(block, 'page_size') +
        attribute(block, 'page_token') +
        attribute(block, 'parent') +
        attribute(block, 'result')
      ),
      containing: resource.field(self._.blocks, 'containing'),
      id: resource.field(self._.blocks, 'id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      name: resource.field(self._.blocks, 'name'),
      page_size: resource.field(self._.blocks, 'page_size'),
      page_token: resource.field(self._.blocks, 'page_token'),
      parent: resource.field(self._.blocks, 'parent'),
      result: resource.field(self._.blocks, 'result'),
    },
    origin_ca_certificate(name, block): {
      local resource = blockType.resource('cloudflare_origin_ca_certificate', name),
      _: resource._(
        block,
        attribute(block, 'certificate') +
        attribute(block, 'certificate_id') +
        attribute(block, 'csr') +
        attribute(block, 'expires_on') +
        attribute(block, 'filter') +
        attribute(block, 'hostnames') +
        attribute(block, 'id') +
        attribute(block, 'request_type') +
        attribute(block, 'requested_validity')
      ),
      certificate: resource.field(self._.blocks, 'certificate'),
      certificate_id: resource.field(self._.blocks, 'certificate_id'),
      csr: resource.field(self._.blocks, 'csr'),
      expires_on: resource.field(self._.blocks, 'expires_on'),
      filter: resource.field(self._.blocks, 'filter'),
      hostnames: resource.field(self._.blocks, 'hostnames'),
      id: resource.field(self._.blocks, 'id'),
      request_type: resource.field(self._.blocks, 'request_type'),
      requested_validity: resource.field(self._.blocks, 'requested_validity'),
    },
    origin_ca_certificates(name, block): {
      local resource = blockType.resource('cloudflare_origin_ca_certificates', name),
      _: resource._(
        block,
        attribute(block, 'limit') +
        attribute(block, 'max_items') +
        attribute(block, 'offset') +
        attribute(block, 'result') +
        attribute(block, 'zone_id', true)
      ),
      limit: resource.field(self._.blocks, 'limit'),
      max_items: resource.field(self._.blocks, 'max_items'),
      offset: resource.field(self._.blocks, 'offset'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    page_rule(name, block): {
      local resource = blockType.resource('cloudflare_page_rule', name),
      _: resource._(
        block,
        attribute(block, 'created_on') +
        attribute(block, 'id') +
        attribute(block, 'modified_on') +
        attribute(block, 'pagerule_id', true) +
        attribute(block, 'priority') +
        attribute(block, 'status') +
        attribute(block, 'zone_id')
      ),
      created_on: resource.field(self._.blocks, 'created_on'),
      id: resource.field(self._.blocks, 'id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      pagerule_id: resource.field(self._.blocks, 'pagerule_id'),
      priority: resource.field(self._.blocks, 'priority'),
      status: resource.field(self._.blocks, 'status'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    page_shield_connections(name, block): {
      local resource = blockType.resource('cloudflare_page_shield_connections', name),
      _: resource._(
        block,
        attribute(block, 'added_at') +
        attribute(block, 'connection_id', true) +
        attribute(block, 'domain_reported_malicious') +
        attribute(block, 'first_page_url') +
        attribute(block, 'first_seen_at') +
        attribute(block, 'host') +
        attribute(block, 'id') +
        attribute(block, 'last_seen_at') +
        attribute(block, 'malicious_domain_categories') +
        attribute(block, 'malicious_url_categories') +
        attribute(block, 'page_urls') +
        attribute(block, 'url') +
        attribute(block, 'url_contains_cdn_cgi_path') +
        attribute(block, 'url_reported_malicious') +
        attribute(block, 'zone_id')
      ),
      added_at: resource.field(self._.blocks, 'added_at'),
      connection_id: resource.field(self._.blocks, 'connection_id'),
      domain_reported_malicious: resource.field(self._.blocks, 'domain_reported_malicious'),
      first_page_url: resource.field(self._.blocks, 'first_page_url'),
      first_seen_at: resource.field(self._.blocks, 'first_seen_at'),
      host: resource.field(self._.blocks, 'host'),
      id: resource.field(self._.blocks, 'id'),
      last_seen_at: resource.field(self._.blocks, 'last_seen_at'),
      malicious_domain_categories: resource.field(self._.blocks, 'malicious_domain_categories'),
      malicious_url_categories: resource.field(self._.blocks, 'malicious_url_categories'),
      page_urls: resource.field(self._.blocks, 'page_urls'),
      url: resource.field(self._.blocks, 'url'),
      url_contains_cdn_cgi_path: resource.field(self._.blocks, 'url_contains_cdn_cgi_path'),
      url_reported_malicious: resource.field(self._.blocks, 'url_reported_malicious'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    page_shield_connections_list(name, block): {
      local resource = blockType.resource('cloudflare_page_shield_connections_list', name),
      _: resource._(
        block,
        attribute(block, 'direction') +
        attribute(block, 'exclude_cdn_cgi') +
        attribute(block, 'exclude_urls') +
        attribute(block, 'export') +
        attribute(block, 'hosts') +
        attribute(block, 'max_items') +
        attribute(block, 'order_by') +
        attribute(block, 'page') +
        attribute(block, 'page_url') +
        attribute(block, 'per_page') +
        attribute(block, 'prioritize_malicious') +
        attribute(block, 'result') +
        attribute(block, 'status') +
        attribute(block, 'urls') +
        attribute(block, 'zone_id')
      ),
      direction: resource.field(self._.blocks, 'direction'),
      exclude_cdn_cgi: resource.field(self._.blocks, 'exclude_cdn_cgi'),
      exclude_urls: resource.field(self._.blocks, 'exclude_urls'),
      export: resource.field(self._.blocks, 'export'),
      hosts: resource.field(self._.blocks, 'hosts'),
      max_items: resource.field(self._.blocks, 'max_items'),
      order_by: resource.field(self._.blocks, 'order_by'),
      page: resource.field(self._.blocks, 'page'),
      page_url: resource.field(self._.blocks, 'page_url'),
      per_page: resource.field(self._.blocks, 'per_page'),
      prioritize_malicious: resource.field(self._.blocks, 'prioritize_malicious'),
      result: resource.field(self._.blocks, 'result'),
      status: resource.field(self._.blocks, 'status'),
      urls: resource.field(self._.blocks, 'urls'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    page_shield_cookies(name, block): {
      local resource = blockType.resource('cloudflare_page_shield_cookies', name),
      _: resource._(
        block,
        attribute(block, 'cookie_id', true) +
        attribute(block, 'domain_attribute') +
        attribute(block, 'expires_attribute') +
        attribute(block, 'first_seen_at') +
        attribute(block, 'host') +
        attribute(block, 'http_only_attribute') +
        attribute(block, 'id') +
        attribute(block, 'last_seen_at') +
        attribute(block, 'max_age_attribute') +
        attribute(block, 'name') +
        attribute(block, 'page_urls') +
        attribute(block, 'path_attribute') +
        attribute(block, 'same_site_attribute') +
        attribute(block, 'secure_attribute') +
        attribute(block, 'type') +
        attribute(block, 'zone_id')
      ),
      cookie_id: resource.field(self._.blocks, 'cookie_id'),
      domain_attribute: resource.field(self._.blocks, 'domain_attribute'),
      expires_attribute: resource.field(self._.blocks, 'expires_attribute'),
      first_seen_at: resource.field(self._.blocks, 'first_seen_at'),
      host: resource.field(self._.blocks, 'host'),
      http_only_attribute: resource.field(self._.blocks, 'http_only_attribute'),
      id: resource.field(self._.blocks, 'id'),
      last_seen_at: resource.field(self._.blocks, 'last_seen_at'),
      max_age_attribute: resource.field(self._.blocks, 'max_age_attribute'),
      name: resource.field(self._.blocks, 'name'),
      page_urls: resource.field(self._.blocks, 'page_urls'),
      path_attribute: resource.field(self._.blocks, 'path_attribute'),
      same_site_attribute: resource.field(self._.blocks, 'same_site_attribute'),
      secure_attribute: resource.field(self._.blocks, 'secure_attribute'),
      type: resource.field(self._.blocks, 'type'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    page_shield_cookies_list(name, block): {
      local resource = blockType.resource('cloudflare_page_shield_cookies_list', name),
      _: resource._(
        block,
        attribute(block, 'direction') +
        attribute(block, 'domain') +
        attribute(block, 'export') +
        attribute(block, 'hosts') +
        attribute(block, 'http_only') +
        attribute(block, 'max_items') +
        attribute(block, 'name') +
        attribute(block, 'order_by') +
        attribute(block, 'page') +
        attribute(block, 'page_url') +
        attribute(block, 'path') +
        attribute(block, 'per_page') +
        attribute(block, 'result') +
        attribute(block, 'same_site') +
        attribute(block, 'secure') +
        attribute(block, 'type') +
        attribute(block, 'zone_id')
      ),
      direction: resource.field(self._.blocks, 'direction'),
      domain: resource.field(self._.blocks, 'domain'),
      export: resource.field(self._.blocks, 'export'),
      hosts: resource.field(self._.blocks, 'hosts'),
      http_only: resource.field(self._.blocks, 'http_only'),
      max_items: resource.field(self._.blocks, 'max_items'),
      name: resource.field(self._.blocks, 'name'),
      order_by: resource.field(self._.blocks, 'order_by'),
      page: resource.field(self._.blocks, 'page'),
      page_url: resource.field(self._.blocks, 'page_url'),
      path: resource.field(self._.blocks, 'path'),
      per_page: resource.field(self._.blocks, 'per_page'),
      result: resource.field(self._.blocks, 'result'),
      same_site: resource.field(self._.blocks, 'same_site'),
      secure: resource.field(self._.blocks, 'secure'),
      type: resource.field(self._.blocks, 'type'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    page_shield_policies(name, block): {
      local resource = blockType.resource('cloudflare_page_shield_policies', name),
      _: resource._(
        block,
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'zone_id')
      ),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    page_shield_policy(name, block): {
      local resource = blockType.resource('cloudflare_page_shield_policy', name),
      _: resource._(
        block,
        attribute(block, 'action') +
        attribute(block, 'description') +
        attribute(block, 'enabled') +
        attribute(block, 'expression') +
        attribute(block, 'id') +
        attribute(block, 'policy_id', true) +
        attribute(block, 'value') +
        attribute(block, 'zone_id')
      ),
      action: resource.field(self._.blocks, 'action'),
      description: resource.field(self._.blocks, 'description'),
      enabled: resource.field(self._.blocks, 'enabled'),
      expression: resource.field(self._.blocks, 'expression'),
      id: resource.field(self._.blocks, 'id'),
      policy_id: resource.field(self._.blocks, 'policy_id'),
      value: resource.field(self._.blocks, 'value'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    page_shield_scripts(name, block): {
      local resource = blockType.resource('cloudflare_page_shield_scripts', name),
      _: resource._(
        block,
        attribute(block, 'added_at') +
        attribute(block, 'cryptomining_score') +
        attribute(block, 'dataflow_score') +
        attribute(block, 'domain_reported_malicious') +
        attribute(block, 'fetched_at') +
        attribute(block, 'first_page_url') +
        attribute(block, 'first_seen_at') +
        attribute(block, 'hash') +
        attribute(block, 'host') +
        attribute(block, 'id') +
        attribute(block, 'js_integrity_score') +
        attribute(block, 'last_seen_at') +
        attribute(block, 'magecart_score') +
        attribute(block, 'malicious_domain_categories') +
        attribute(block, 'malicious_url_categories') +
        attribute(block, 'malware_score') +
        attribute(block, 'obfuscation_score') +
        attribute(block, 'page_urls') +
        attribute(block, 'script_id', true) +
        attribute(block, 'url') +
        attribute(block, 'url_contains_cdn_cgi_path') +
        attribute(block, 'url_reported_malicious') +
        attribute(block, 'versions') +
        attribute(block, 'zone_id')
      ),
      added_at: resource.field(self._.blocks, 'added_at'),
      cryptomining_score: resource.field(self._.blocks, 'cryptomining_score'),
      dataflow_score: resource.field(self._.blocks, 'dataflow_score'),
      domain_reported_malicious: resource.field(self._.blocks, 'domain_reported_malicious'),
      fetched_at: resource.field(self._.blocks, 'fetched_at'),
      first_page_url: resource.field(self._.blocks, 'first_page_url'),
      first_seen_at: resource.field(self._.blocks, 'first_seen_at'),
      hash: resource.field(self._.blocks, 'hash'),
      host: resource.field(self._.blocks, 'host'),
      id: resource.field(self._.blocks, 'id'),
      js_integrity_score: resource.field(self._.blocks, 'js_integrity_score'),
      last_seen_at: resource.field(self._.blocks, 'last_seen_at'),
      magecart_score: resource.field(self._.blocks, 'magecart_score'),
      malicious_domain_categories: resource.field(self._.blocks, 'malicious_domain_categories'),
      malicious_url_categories: resource.field(self._.blocks, 'malicious_url_categories'),
      malware_score: resource.field(self._.blocks, 'malware_score'),
      obfuscation_score: resource.field(self._.blocks, 'obfuscation_score'),
      page_urls: resource.field(self._.blocks, 'page_urls'),
      script_id: resource.field(self._.blocks, 'script_id'),
      url: resource.field(self._.blocks, 'url'),
      url_contains_cdn_cgi_path: resource.field(self._.blocks, 'url_contains_cdn_cgi_path'),
      url_reported_malicious: resource.field(self._.blocks, 'url_reported_malicious'),
      versions: resource.field(self._.blocks, 'versions'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    page_shield_scripts_list(name, block): {
      local resource = blockType.resource('cloudflare_page_shield_scripts_list', name),
      _: resource._(
        block,
        attribute(block, 'direction') +
        attribute(block, 'exclude_cdn_cgi') +
        attribute(block, 'exclude_duplicates') +
        attribute(block, 'exclude_urls') +
        attribute(block, 'export') +
        attribute(block, 'hosts') +
        attribute(block, 'max_items') +
        attribute(block, 'order_by') +
        attribute(block, 'page') +
        attribute(block, 'page_url') +
        attribute(block, 'per_page') +
        attribute(block, 'prioritize_malicious') +
        attribute(block, 'result') +
        attribute(block, 'status') +
        attribute(block, 'urls') +
        attribute(block, 'zone_id')
      ),
      direction: resource.field(self._.blocks, 'direction'),
      exclude_cdn_cgi: resource.field(self._.blocks, 'exclude_cdn_cgi'),
      exclude_duplicates: resource.field(self._.blocks, 'exclude_duplicates'),
      exclude_urls: resource.field(self._.blocks, 'exclude_urls'),
      export: resource.field(self._.blocks, 'export'),
      hosts: resource.field(self._.blocks, 'hosts'),
      max_items: resource.field(self._.blocks, 'max_items'),
      order_by: resource.field(self._.blocks, 'order_by'),
      page: resource.field(self._.blocks, 'page'),
      page_url: resource.field(self._.blocks, 'page_url'),
      per_page: resource.field(self._.blocks, 'per_page'),
      prioritize_malicious: resource.field(self._.blocks, 'prioritize_malicious'),
      result: resource.field(self._.blocks, 'result'),
      status: resource.field(self._.blocks, 'status'),
      urls: resource.field(self._.blocks, 'urls'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    pages_domain(name, block): {
      local resource = blockType.resource('cloudflare_pages_domain', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'certificate_authority') +
        attribute(block, 'created_on') +
        attribute(block, 'domain_id') +
        attribute(block, 'domain_name', true) +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'project_name', true) +
        attribute(block, 'status') +
        attribute(block, 'validation_data') +
        attribute(block, 'verification_data') +
        attribute(block, 'zone_tag')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      certificate_authority: resource.field(self._.blocks, 'certificate_authority'),
      created_on: resource.field(self._.blocks, 'created_on'),
      domain_id: resource.field(self._.blocks, 'domain_id'),
      domain_name: resource.field(self._.blocks, 'domain_name'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      project_name: resource.field(self._.blocks, 'project_name'),
      status: resource.field(self._.blocks, 'status'),
      validation_data: resource.field(self._.blocks, 'validation_data'),
      verification_data: resource.field(self._.blocks, 'verification_data'),
      zone_tag: resource.field(self._.blocks, 'zone_tag'),
    },
    pages_domains(name, block): {
      local resource = blockType.resource('cloudflare_pages_domains', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'project_name', true) +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      project_name: resource.field(self._.blocks, 'project_name'),
      result: resource.field(self._.blocks, 'result'),
    },
    pages_project(name, block): {
      local resource = blockType.resource('cloudflare_pages_project', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'build_config') +
        attribute(block, 'canonical_deployment') +
        attribute(block, 'created_on') +
        attribute(block, 'deployment_configs') +
        attribute(block, 'domains') +
        attribute(block, 'framework') +
        attribute(block, 'framework_version') +
        attribute(block, 'id') +
        attribute(block, 'latest_deployment') +
        attribute(block, 'name') +
        attribute(block, 'preview_script_name') +
        attribute(block, 'production_branch') +
        attribute(block, 'production_script_name') +
        attribute(block, 'project_name', true) +
        attribute(block, 'source') +
        attribute(block, 'subdomain') +
        attribute(block, 'uses_functions')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      build_config: resource.field(self._.blocks, 'build_config'),
      canonical_deployment: resource.field(self._.blocks, 'canonical_deployment'),
      created_on: resource.field(self._.blocks, 'created_on'),
      deployment_configs: resource.field(self._.blocks, 'deployment_configs'),
      domains: resource.field(self._.blocks, 'domains'),
      framework: resource.field(self._.blocks, 'framework'),
      framework_version: resource.field(self._.blocks, 'framework_version'),
      id: resource.field(self._.blocks, 'id'),
      latest_deployment: resource.field(self._.blocks, 'latest_deployment'),
      name: resource.field(self._.blocks, 'name'),
      preview_script_name: resource.field(self._.blocks, 'preview_script_name'),
      production_branch: resource.field(self._.blocks, 'production_branch'),
      production_script_name: resource.field(self._.blocks, 'production_script_name'),
      project_name: resource.field(self._.blocks, 'project_name'),
      source: resource.field(self._.blocks, 'source'),
      subdomain: resource.field(self._.blocks, 'subdomain'),
      uses_functions: resource.field(self._.blocks, 'uses_functions'),
    },
    pages_projects(name, block): {
      local resource = blockType.resource('cloudflare_pages_projects', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    pipeline(name, block): {
      local resource = blockType.resource('cloudflare_pipeline', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_at') +
        attribute(block, 'failure_reason') +
        attribute(block, 'id') +
        attribute(block, 'modified_at') +
        attribute(block, 'name') +
        attribute(block, 'pipeline_id', true) +
        attribute(block, 'sql') +
        attribute(block, 'status') +
        attribute(block, 'tables')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_at: resource.field(self._.blocks, 'created_at'),
      failure_reason: resource.field(self._.blocks, 'failure_reason'),
      id: resource.field(self._.blocks, 'id'),
      modified_at: resource.field(self._.blocks, 'modified_at'),
      name: resource.field(self._.blocks, 'name'),
      pipeline_id: resource.field(self._.blocks, 'pipeline_id'),
      sql: resource.field(self._.blocks, 'sql'),
      status: resource.field(self._.blocks, 'status'),
      tables: resource.field(self._.blocks, 'tables'),
    },
    pipeline_sink(name, block): {
      local resource = blockType.resource('cloudflare_pipeline_sink', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'config') +
        attribute(block, 'created_at') +
        attribute(block, 'filter') +
        attribute(block, 'format') +
        attribute(block, 'id') +
        attribute(block, 'modified_at') +
        attribute(block, 'name') +
        attribute(block, 'schema') +
        attribute(block, 'sink_id') +
        attribute(block, 'type')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      config: resource.field(self._.blocks, 'config'),
      created_at: resource.field(self._.blocks, 'created_at'),
      filter: resource.field(self._.blocks, 'filter'),
      format: resource.field(self._.blocks, 'format'),
      id: resource.field(self._.blocks, 'id'),
      modified_at: resource.field(self._.blocks, 'modified_at'),
      name: resource.field(self._.blocks, 'name'),
      schema: resource.field(self._.blocks, 'schema'),
      sink_id: resource.field(self._.blocks, 'sink_id'),
      type: resource.field(self._.blocks, 'type'),
    },
    pipeline_sinks(name, block): {
      local resource = blockType.resource('cloudflare_pipeline_sinks', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'pipeline_id') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      pipeline_id: resource.field(self._.blocks, 'pipeline_id'),
      result: resource.field(self._.blocks, 'result'),
    },
    pipeline_stream(name, block): {
      local resource = blockType.resource('cloudflare_pipeline_stream', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_at') +
        attribute(block, 'endpoint') +
        attribute(block, 'filter') +
        attribute(block, 'format') +
        attribute(block, 'http') +
        attribute(block, 'id') +
        attribute(block, 'modified_at') +
        attribute(block, 'name') +
        attribute(block, 'schema') +
        attribute(block, 'stream_id') +
        attribute(block, 'version') +
        attribute(block, 'worker_binding')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_at: resource.field(self._.blocks, 'created_at'),
      endpoint: resource.field(self._.blocks, 'endpoint'),
      filter: resource.field(self._.blocks, 'filter'),
      format: resource.field(self._.blocks, 'format'),
      http: resource.field(self._.blocks, 'http'),
      id: resource.field(self._.blocks, 'id'),
      modified_at: resource.field(self._.blocks, 'modified_at'),
      name: resource.field(self._.blocks, 'name'),
      schema: resource.field(self._.blocks, 'schema'),
      stream_id: resource.field(self._.blocks, 'stream_id'),
      version: resource.field(self._.blocks, 'version'),
      worker_binding: resource.field(self._.blocks, 'worker_binding'),
    },
    pipeline_streams(name, block): {
      local resource = blockType.resource('cloudflare_pipeline_streams', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'pipeline_id') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      pipeline_id: resource.field(self._.blocks, 'pipeline_id'),
      result: resource.field(self._.blocks, 'result'),
    },
    queue(name, block): {
      local resource = blockType.resource('cloudflare_queue', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'consumers') +
        attribute(block, 'consumers_total_count') +
        attribute(block, 'created_on') +
        attribute(block, 'id') +
        attribute(block, 'modified_on') +
        attribute(block, 'producers') +
        attribute(block, 'producers_total_count') +
        attribute(block, 'queue_id', true) +
        attribute(block, 'queue_name') +
        attribute(block, 'settings')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      consumers: resource.field(self._.blocks, 'consumers'),
      consumers_total_count: resource.field(self._.blocks, 'consumers_total_count'),
      created_on: resource.field(self._.blocks, 'created_on'),
      id: resource.field(self._.blocks, 'id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      producers: resource.field(self._.blocks, 'producers'),
      producers_total_count: resource.field(self._.blocks, 'producers_total_count'),
      queue_id: resource.field(self._.blocks, 'queue_id'),
      queue_name: resource.field(self._.blocks, 'queue_name'),
      settings: resource.field(self._.blocks, 'settings'),
    },
    queue_consumer(name, block): {
      local resource = blockType.resource('cloudflare_queue_consumer', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'consumer_id') +
        attribute(block, 'created_on') +
        attribute(block, 'dead_letter_queue') +
        attribute(block, 'queue_id', true) +
        attribute(block, 'queue_name') +
        attribute(block, 'script_name') +
        attribute(block, 'settings') +
        attribute(block, 'type')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      consumer_id: resource.field(self._.blocks, 'consumer_id'),
      created_on: resource.field(self._.blocks, 'created_on'),
      dead_letter_queue: resource.field(self._.blocks, 'dead_letter_queue'),
      queue_id: resource.field(self._.blocks, 'queue_id'),
      queue_name: resource.field(self._.blocks, 'queue_name'),
      script_name: resource.field(self._.blocks, 'script_name'),
      settings: resource.field(self._.blocks, 'settings'),
      type: resource.field(self._.blocks, 'type'),
    },
    queue_consumers(name, block): {
      local resource = blockType.resource('cloudflare_queue_consumers', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'queue_id', true) +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      queue_id: resource.field(self._.blocks, 'queue_id'),
      result: resource.field(self._.blocks, 'result'),
    },
    queues(name, block): {
      local resource = blockType.resource('cloudflare_queues', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    r2_bucket(name, block): {
      local resource = blockType.resource('cloudflare_r2_bucket', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'bucket_name', true) +
        attribute(block, 'creation_date') +
        attribute(block, 'id') +
        attribute(block, 'jurisdiction') +
        attribute(block, 'location') +
        attribute(block, 'name') +
        attribute(block, 'storage_class')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      bucket_name: resource.field(self._.blocks, 'bucket_name'),
      creation_date: resource.field(self._.blocks, 'creation_date'),
      id: resource.field(self._.blocks, 'id'),
      jurisdiction: resource.field(self._.blocks, 'jurisdiction'),
      location: resource.field(self._.blocks, 'location'),
      name: resource.field(self._.blocks, 'name'),
      storage_class: resource.field(self._.blocks, 'storage_class'),
    },
    r2_bucket_cors(name, block): {
      local resource = blockType.resource('cloudflare_r2_bucket_cors', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'bucket_name', true) +
        attribute(block, 'rules')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      bucket_name: resource.field(self._.blocks, 'bucket_name'),
      rules: resource.field(self._.blocks, 'rules'),
    },
    r2_bucket_event_notification(name, block): {
      local resource = blockType.resource('cloudflare_r2_bucket_event_notification', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'bucket_name', true) +
        attribute(block, 'queue_id', true) +
        attribute(block, 'queue_name') +
        attribute(block, 'rules')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      bucket_name: resource.field(self._.blocks, 'bucket_name'),
      queue_id: resource.field(self._.blocks, 'queue_id'),
      queue_name: resource.field(self._.blocks, 'queue_name'),
      rules: resource.field(self._.blocks, 'rules'),
    },
    r2_bucket_lifecycle(name, block): {
      local resource = blockType.resource('cloudflare_r2_bucket_lifecycle', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'bucket_name', true) +
        attribute(block, 'rules')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      bucket_name: resource.field(self._.blocks, 'bucket_name'),
      rules: resource.field(self._.blocks, 'rules'),
    },
    r2_bucket_lock(name, block): {
      local resource = blockType.resource('cloudflare_r2_bucket_lock', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'bucket_name', true) +
        attribute(block, 'rules')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      bucket_name: resource.field(self._.blocks, 'bucket_name'),
      rules: resource.field(self._.blocks, 'rules'),
    },
    r2_bucket_sippy(name, block): {
      local resource = blockType.resource('cloudflare_r2_bucket_sippy', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'bucket_name', true) +
        attribute(block, 'destination') +
        attribute(block, 'enabled') +
        attribute(block, 'source')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      bucket_name: resource.field(self._.blocks, 'bucket_name'),
      destination: resource.field(self._.blocks, 'destination'),
      enabled: resource.field(self._.blocks, 'enabled'),
      source: resource.field(self._.blocks, 'source'),
    },
    r2_custom_domain(name, block): {
      local resource = blockType.resource('cloudflare_r2_custom_domain', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'bucket_name', true) +
        attribute(block, 'ciphers') +
        attribute(block, 'domain', true) +
        attribute(block, 'enabled') +
        attribute(block, 'min_tls') +
        attribute(block, 'status') +
        attribute(block, 'zone_id') +
        attribute(block, 'zone_name')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      bucket_name: resource.field(self._.blocks, 'bucket_name'),
      ciphers: resource.field(self._.blocks, 'ciphers'),
      domain: resource.field(self._.blocks, 'domain'),
      enabled: resource.field(self._.blocks, 'enabled'),
      min_tls: resource.field(self._.blocks, 'min_tls'),
      status: resource.field(self._.blocks, 'status'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
      zone_name: resource.field(self._.blocks, 'zone_name'),
    },
    r2_data_catalog(name, block): {
      local resource = blockType.resource('cloudflare_r2_data_catalog', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'bucket') +
        attribute(block, 'bucket_name', true) +
        attribute(block, 'credential_status') +
        attribute(block, 'id') +
        attribute(block, 'maintenance_config') +
        attribute(block, 'name') +
        attribute(block, 'status')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      bucket: resource.field(self._.blocks, 'bucket'),
      bucket_name: resource.field(self._.blocks, 'bucket_name'),
      credential_status: resource.field(self._.blocks, 'credential_status'),
      id: resource.field(self._.blocks, 'id'),
      maintenance_config: resource.field(self._.blocks, 'maintenance_config'),
      name: resource.field(self._.blocks, 'name'),
      status: resource.field(self._.blocks, 'status'),
    },
    rate_limit(name, block): {
      local resource = blockType.resource('cloudflare_rate_limit', name),
      _: resource._(
        block,
        attribute(block, 'action') +
        attribute(block, 'bypass') +
        attribute(block, 'description') +
        attribute(block, 'disabled') +
        attribute(block, 'id') +
        attribute(block, 'match') +
        attribute(block, 'period') +
        attribute(block, 'rate_limit_id', true) +
        attribute(block, 'threshold') +
        attribute(block, 'zone_id')
      ),
      action: resource.field(self._.blocks, 'action'),
      bypass: resource.field(self._.blocks, 'bypass'),
      description: resource.field(self._.blocks, 'description'),
      disabled: resource.field(self._.blocks, 'disabled'),
      id: resource.field(self._.blocks, 'id'),
      match: resource.field(self._.blocks, 'match'),
      period: resource.field(self._.blocks, 'period'),
      rate_limit_id: resource.field(self._.blocks, 'rate_limit_id'),
      threshold: resource.field(self._.blocks, 'threshold'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    rate_limits(name, block): {
      local resource = blockType.resource('cloudflare_rate_limits', name),
      _: resource._(
        block,
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'zone_id')
      ),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    regional_hostname(name, block): {
      local resource = blockType.resource('cloudflare_regional_hostname', name),
      _: resource._(
        block,
        attribute(block, 'created_on') +
        attribute(block, 'hostname', true) +
        attribute(block, 'id') +
        attribute(block, 'region_key') +
        attribute(block, 'routing') +
        attribute(block, 'zone_id')
      ),
      created_on: resource.field(self._.blocks, 'created_on'),
      hostname: resource.field(self._.blocks, 'hostname'),
      id: resource.field(self._.blocks, 'id'),
      region_key: resource.field(self._.blocks, 'region_key'),
      routing: resource.field(self._.blocks, 'routing'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    regional_hostnames(name, block): {
      local resource = blockType.resource('cloudflare_regional_hostnames', name),
      _: resource._(
        block,
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'zone_id')
      ),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    regional_tiered_cache(name, block): {
      local resource = blockType.resource('cloudflare_regional_tiered_cache', name),
      _: resource._(
        block,
        attribute(block, 'editable') +
        attribute(block, 'id') +
        attribute(block, 'modified_on') +
        attribute(block, 'value') +
        attribute(block, 'zone_id')
      ),
      editable: resource.field(self._.blocks, 'editable'),
      id: resource.field(self._.blocks, 'id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      value: resource.field(self._.blocks, 'value'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    registrar_domain(name, block): {
      local resource = blockType.resource('cloudflare_registrar_domain', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'domain_name', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      domain_name: resource.field(self._.blocks, 'domain_name'),
    },
    registrar_domains(name, block): {
      local resource = blockType.resource('cloudflare_registrar_domains', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    resource_group(name, block): {
      local resource = blockType.resource('cloudflare_resource_group', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'id') +
        attribute(block, 'meta') +
        attribute(block, 'name') +
        attribute(block, 'resource_group_id', true) +
        attribute(block, 'scope')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      id: resource.field(self._.blocks, 'id'),
      meta: resource.field(self._.blocks, 'meta'),
      name: resource.field(self._.blocks, 'name'),
      resource_group_id: resource.field(self._.blocks, 'resource_group_id'),
      scope: resource.field(self._.blocks, 'scope'),
    },
    resource_groups(name, block): {
      local resource = blockType.resource('cloudflare_resource_groups', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'id') +
        attribute(block, 'max_items') +
        attribute(block, 'name') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      id: resource.field(self._.blocks, 'id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      name: resource.field(self._.blocks, 'name'),
      result: resource.field(self._.blocks, 'result'),
    },
    ruleset(name, block): {
      local resource = blockType.resource('cloudflare_ruleset', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'description') +
        attribute(block, 'id') +
        attribute(block, 'kind') +
        attribute(block, 'last_updated') +
        attribute(block, 'name') +
        attribute(block, 'phase') +
        attribute(block, 'rules') +
        attribute(block, 'ruleset_id') +
        attribute(block, 'version') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      kind: resource.field(self._.blocks, 'kind'),
      last_updated: resource.field(self._.blocks, 'last_updated'),
      name: resource.field(self._.blocks, 'name'),
      phase: resource.field(self._.blocks, 'phase'),
      rules: resource.field(self._.blocks, 'rules'),
      ruleset_id: resource.field(self._.blocks, 'ruleset_id'),
      version: resource.field(self._.blocks, 'version'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    rulesets(name, block): {
      local resource = blockType.resource('cloudflare_rulesets', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'rulesets') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      rulesets: resource.field(self._.blocks, 'rulesets'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    schema_validation_operation_settings(name, block): {
      local resource = blockType.resource('cloudflare_schema_validation_operation_settings', name),
      _: resource._(
        block,
        attribute(block, 'mitigation_action') +
        attribute(block, 'operation_id', true) +
        attribute(block, 'zone_id')
      ),
      mitigation_action: resource.field(self._.blocks, 'mitigation_action'),
      operation_id: resource.field(self._.blocks, 'operation_id'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    schema_validation_operation_settings_list(name, block): {
      local resource = blockType.resource('cloudflare_schema_validation_operation_settings_list', name),
      _: resource._(
        block,
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'zone_id')
      ),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    schema_validation_schemas(name, block): {
      local resource = blockType.resource('cloudflare_schema_validation_schemas', name),
      _: resource._(
        block,
        attribute(block, 'created_at') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'kind') +
        attribute(block, 'name') +
        attribute(block, 'omit_source') +
        attribute(block, 'schema_id') +
        attribute(block, 'source') +
        attribute(block, 'validation_enabled') +
        attribute(block, 'zone_id')
      ),
      created_at: resource.field(self._.blocks, 'created_at'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      kind: resource.field(self._.blocks, 'kind'),
      name: resource.field(self._.blocks, 'name'),
      omit_source: resource.field(self._.blocks, 'omit_source'),
      schema_id: resource.field(self._.blocks, 'schema_id'),
      source: resource.field(self._.blocks, 'source'),
      validation_enabled: resource.field(self._.blocks, 'validation_enabled'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    schema_validation_schemas_list(name, block): {
      local resource = blockType.resource('cloudflare_schema_validation_schemas_list', name),
      _: resource._(
        block,
        attribute(block, 'max_items') +
        attribute(block, 'omit_source') +
        attribute(block, 'result') +
        attribute(block, 'validation_enabled') +
        attribute(block, 'zone_id')
      ),
      max_items: resource.field(self._.blocks, 'max_items'),
      omit_source: resource.field(self._.blocks, 'omit_source'),
      result: resource.field(self._.blocks, 'result'),
      validation_enabled: resource.field(self._.blocks, 'validation_enabled'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    schema_validation_settings(name, block): {
      local resource = blockType.resource('cloudflare_schema_validation_settings', name),
      _: resource._(
        block,
        attribute(block, 'validation_default_mitigation_action') +
        attribute(block, 'validation_override_mitigation_action') +
        attribute(block, 'zone_id')
      ),
      validation_default_mitigation_action: resource.field(self._.blocks, 'validation_default_mitigation_action'),
      validation_override_mitigation_action: resource.field(self._.blocks, 'validation_override_mitigation_action'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    snippet(name, block): {
      local resource = blockType.resource('cloudflare_snippet', name),
      _: resource._(
        block,
        attribute(block, 'created_on') +
        attribute(block, 'modified_on') +
        attribute(block, 'snippet_name', true) +
        attribute(block, 'zone_id')
      ),
      created_on: resource.field(self._.blocks, 'created_on'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      snippet_name: resource.field(self._.blocks, 'snippet_name'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    snippet_list(name, block): {
      local resource = blockType.resource('cloudflare_snippet_list', name),
      _: resource._(
        block,
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'zone_id')
      ),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    snippet_rules_list(name, block): {
      local resource = blockType.resource('cloudflare_snippet_rules_list', name),
      _: resource._(
        block,
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'zone_id', true)
      ),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    snippets(name, block): {
      local resource = blockType.resource('cloudflare_snippets', name),
      _: resource._(
        block,
        attribute(block, 'created_on') +
        attribute(block, 'modified_on') +
        attribute(block, 'snippet_name', true) +
        attribute(block, 'zone_id', true)
      ),
      created_on: resource.field(self._.blocks, 'created_on'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      snippet_name: resource.field(self._.blocks, 'snippet_name'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    snippets_list(name, block): {
      local resource = blockType.resource('cloudflare_snippets_list', name),
      _: resource._(
        block,
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'zone_id', true)
      ),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    spectrum_application(name, block): {
      local resource = blockType.resource('cloudflare_spectrum_application', name),
      _: resource._(
        block,
        attribute(block, 'app_id') +
        attribute(block, 'argo_smart_routing') +
        attribute(block, 'created_on') +
        attribute(block, 'dns') +
        attribute(block, 'edge_ips') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'ip_firewall') +
        attribute(block, 'modified_on') +
        attribute(block, 'origin_direct') +
        attribute(block, 'origin_dns') +
        attribute(block, 'origin_port') +
        attribute(block, 'protocol') +
        attribute(block, 'proxy_protocol') +
        attribute(block, 'tls') +
        attribute(block, 'traffic_type') +
        attribute(block, 'zone_id')
      ),
      app_id: resource.field(self._.blocks, 'app_id'),
      argo_smart_routing: resource.field(self._.blocks, 'argo_smart_routing'),
      created_on: resource.field(self._.blocks, 'created_on'),
      dns: resource.field(self._.blocks, 'dns'),
      edge_ips: resource.field(self._.blocks, 'edge_ips'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      ip_firewall: resource.field(self._.blocks, 'ip_firewall'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      origin_direct: resource.field(self._.blocks, 'origin_direct'),
      origin_dns: resource.field(self._.blocks, 'origin_dns'),
      origin_port: resource.field(self._.blocks, 'origin_port'),
      protocol: resource.field(self._.blocks, 'protocol'),
      proxy_protocol: resource.field(self._.blocks, 'proxy_protocol'),
      tls: resource.field(self._.blocks, 'tls'),
      traffic_type: resource.field(self._.blocks, 'traffic_type'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    spectrum_applications(name, block): {
      local resource = blockType.resource('cloudflare_spectrum_applications', name),
      _: resource._(
        block,
        attribute(block, 'direction') +
        attribute(block, 'max_items') +
        attribute(block, 'order') +
        attribute(block, 'result') +
        attribute(block, 'zone_id')
      ),
      direction: resource.field(self._.blocks, 'direction'),
      max_items: resource.field(self._.blocks, 'max_items'),
      order: resource.field(self._.blocks, 'order'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    sso_connector(name, block): {
      local resource = blockType.resource('cloudflare_sso_connector', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_on') +
        attribute(block, 'email_domain') +
        attribute(block, 'enabled') +
        attribute(block, 'id') +
        attribute(block, 'sso_connector_id', true) +
        attribute(block, 'updated_on') +
        attribute(block, 'use_fedramp_language') +
        attribute(block, 'verification')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_on: resource.field(self._.blocks, 'created_on'),
      email_domain: resource.field(self._.blocks, 'email_domain'),
      enabled: resource.field(self._.blocks, 'enabled'),
      id: resource.field(self._.blocks, 'id'),
      sso_connector_id: resource.field(self._.blocks, 'sso_connector_id'),
      updated_on: resource.field(self._.blocks, 'updated_on'),
      use_fedramp_language: resource.field(self._.blocks, 'use_fedramp_language'),
      verification: resource.field(self._.blocks, 'verification'),
    },
    sso_connectors(name, block): {
      local resource = blockType.resource('cloudflare_sso_connectors', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    stream(name, block): {
      local resource = blockType.resource('cloudflare_stream', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'allowed_origins') +
        attribute(block, 'clipped_from') +
        attribute(block, 'created') +
        attribute(block, 'creator') +
        attribute(block, 'duration') +
        attribute(block, 'identifier', true) +
        attribute(block, 'input') +
        attribute(block, 'live_input') +
        attribute(block, 'max_duration_seconds') +
        attribute(block, 'max_size_bytes') +
        attribute(block, 'meta') +
        attribute(block, 'modified') +
        attribute(block, 'playback') +
        attribute(block, 'preview') +
        attribute(block, 'public_details') +
        attribute(block, 'ready_to_stream') +
        attribute(block, 'ready_to_stream_at') +
        attribute(block, 'require_signed_urls') +
        attribute(block, 'scheduled_deletion') +
        attribute(block, 'size') +
        attribute(block, 'status') +
        attribute(block, 'thumbnail') +
        attribute(block, 'thumbnail_timestamp_pct') +
        attribute(block, 'uid') +
        attribute(block, 'upload_expiry') +
        attribute(block, 'uploaded') +
        attribute(block, 'watermark')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      allowed_origins: resource.field(self._.blocks, 'allowed_origins'),
      clipped_from: resource.field(self._.blocks, 'clipped_from'),
      created: resource.field(self._.blocks, 'created'),
      creator: resource.field(self._.blocks, 'creator'),
      duration: resource.field(self._.blocks, 'duration'),
      identifier: resource.field(self._.blocks, 'identifier'),
      input: resource.field(self._.blocks, 'input'),
      live_input: resource.field(self._.blocks, 'live_input'),
      max_duration_seconds: resource.field(self._.blocks, 'max_duration_seconds'),
      max_size_bytes: resource.field(self._.blocks, 'max_size_bytes'),
      meta: resource.field(self._.blocks, 'meta'),
      modified: resource.field(self._.blocks, 'modified'),
      playback: resource.field(self._.blocks, 'playback'),
      preview: resource.field(self._.blocks, 'preview'),
      public_details: resource.field(self._.blocks, 'public_details'),
      ready_to_stream: resource.field(self._.blocks, 'ready_to_stream'),
      ready_to_stream_at: resource.field(self._.blocks, 'ready_to_stream_at'),
      require_signed_urls: resource.field(self._.blocks, 'require_signed_urls'),
      scheduled_deletion: resource.field(self._.blocks, 'scheduled_deletion'),
      size: resource.field(self._.blocks, 'size'),
      status: resource.field(self._.blocks, 'status'),
      thumbnail: resource.field(self._.blocks, 'thumbnail'),
      thumbnail_timestamp_pct: resource.field(self._.blocks, 'thumbnail_timestamp_pct'),
      uid: resource.field(self._.blocks, 'uid'),
      upload_expiry: resource.field(self._.blocks, 'upload_expiry'),
      uploaded: resource.field(self._.blocks, 'uploaded'),
      watermark: resource.field(self._.blocks, 'watermark'),
    },
    stream_audio_track(name, block): {
      local resource = blockType.resource('cloudflare_stream_audio_track', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'audio') +
        attribute(block, 'identifier', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      audio: resource.field(self._.blocks, 'audio'),
      identifier: resource.field(self._.blocks, 'identifier'),
    },
    stream_caption_language(name, block): {
      local resource = blockType.resource('cloudflare_stream_caption_language', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'generated') +
        attribute(block, 'identifier', true) +
        attribute(block, 'label') +
        attribute(block, 'language', true) +
        attribute(block, 'status')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      generated: resource.field(self._.blocks, 'generated'),
      identifier: resource.field(self._.blocks, 'identifier'),
      label: resource.field(self._.blocks, 'label'),
      language: resource.field(self._.blocks, 'language'),
      status: resource.field(self._.blocks, 'status'),
    },
    stream_download(name, block): {
      local resource = blockType.resource('cloudflare_stream_download', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'identifier', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      identifier: resource.field(self._.blocks, 'identifier'),
    },
    stream_key(name, block): {
      local resource = blockType.resource('cloudflare_stream_key', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created') +
        attribute(block, 'id') +
        attribute(block, 'key_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created: resource.field(self._.blocks, 'created'),
      id: resource.field(self._.blocks, 'id'),
      key_id: resource.field(self._.blocks, 'key_id'),
    },
    stream_live_input(name, block): {
      local resource = blockType.resource('cloudflare_stream_live_input', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created') +
        attribute(block, 'delete_recording_after_days') +
        attribute(block, 'enabled') +
        attribute(block, 'live_input_identifier', true) +
        attribute(block, 'meta') +
        attribute(block, 'modified') +
        attribute(block, 'recording') +
        attribute(block, 'rtmps') +
        attribute(block, 'rtmps_playback') +
        attribute(block, 'srt') +
        attribute(block, 'srt_playback') +
        attribute(block, 'status') +
        attribute(block, 'uid') +
        attribute(block, 'web_rtc') +
        attribute(block, 'web_rtc_playback')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created: resource.field(self._.blocks, 'created'),
      delete_recording_after_days: resource.field(self._.blocks, 'delete_recording_after_days'),
      enabled: resource.field(self._.blocks, 'enabled'),
      live_input_identifier: resource.field(self._.blocks, 'live_input_identifier'),
      meta: resource.field(self._.blocks, 'meta'),
      modified: resource.field(self._.blocks, 'modified'),
      recording: resource.field(self._.blocks, 'recording'),
      rtmps: resource.field(self._.blocks, 'rtmps'),
      rtmps_playback: resource.field(self._.blocks, 'rtmps_playback'),
      srt: resource.field(self._.blocks, 'srt'),
      srt_playback: resource.field(self._.blocks, 'srt_playback'),
      status: resource.field(self._.blocks, 'status'),
      uid: resource.field(self._.blocks, 'uid'),
      web_rtc: resource.field(self._.blocks, 'web_rtc'),
      web_rtc_playback: resource.field(self._.blocks, 'web_rtc_playback'),
    },
    stream_watermark(name, block): {
      local resource = blockType.resource('cloudflare_stream_watermark', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created') +
        attribute(block, 'downloaded_from') +
        attribute(block, 'height') +
        attribute(block, 'identifier', true) +
        attribute(block, 'name') +
        attribute(block, 'opacity') +
        attribute(block, 'padding') +
        attribute(block, 'position') +
        attribute(block, 'scale') +
        attribute(block, 'size') +
        attribute(block, 'uid') +
        attribute(block, 'width')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created: resource.field(self._.blocks, 'created'),
      downloaded_from: resource.field(self._.blocks, 'downloaded_from'),
      height: resource.field(self._.blocks, 'height'),
      identifier: resource.field(self._.blocks, 'identifier'),
      name: resource.field(self._.blocks, 'name'),
      opacity: resource.field(self._.blocks, 'opacity'),
      padding: resource.field(self._.blocks, 'padding'),
      position: resource.field(self._.blocks, 'position'),
      scale: resource.field(self._.blocks, 'scale'),
      size: resource.field(self._.blocks, 'size'),
      uid: resource.field(self._.blocks, 'uid'),
      width: resource.field(self._.blocks, 'width'),
    },
    stream_watermarks(name, block): {
      local resource = blockType.resource('cloudflare_stream_watermarks', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    stream_webhook(name, block): {
      local resource = blockType.resource('cloudflare_stream_webhook', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'modified') +
        attribute(block, 'notification_url') +
        attribute(block, 'secret')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      modified: resource.field(self._.blocks, 'modified'),
      notification_url: resource.field(self._.blocks, 'notification_url'),
      secret: resource.field(self._.blocks, 'secret'),
    },
    streams(name, block): {
      local resource = blockType.resource('cloudflare_streams', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'after') +
        attribute(block, 'asc') +
        attribute(block, 'before') +
        attribute(block, 'creator') +
        attribute(block, 'end') +
        attribute(block, 'id') +
        attribute(block, 'include_counts') +
        attribute(block, 'limit') +
        attribute(block, 'live_input_id') +
        attribute(block, 'max_items') +
        attribute(block, 'name') +
        attribute(block, 'result') +
        attribute(block, 'search') +
        attribute(block, 'start') +
        attribute(block, 'status') +
        attribute(block, 'type') +
        attribute(block, 'video_name')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      after: resource.field(self._.blocks, 'after'),
      asc: resource.field(self._.blocks, 'asc'),
      before: resource.field(self._.blocks, 'before'),
      creator: resource.field(self._.blocks, 'creator'),
      end: resource.field(self._.blocks, 'end'),
      id: resource.field(self._.blocks, 'id'),
      include_counts: resource.field(self._.blocks, 'include_counts'),
      limit: resource.field(self._.blocks, 'limit'),
      live_input_id: resource.field(self._.blocks, 'live_input_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      name: resource.field(self._.blocks, 'name'),
      result: resource.field(self._.blocks, 'result'),
      search: resource.field(self._.blocks, 'search'),
      start: resource.field(self._.blocks, 'start'),
      status: resource.field(self._.blocks, 'status'),
      type: resource.field(self._.blocks, 'type'),
      video_name: resource.field(self._.blocks, 'video_name'),
    },
    tiered_cache(name, block): {
      local resource = blockType.resource('cloudflare_tiered_cache', name),
      _: resource._(
        block,
        attribute(block, 'editable') +
        attribute(block, 'id') +
        attribute(block, 'modified_on') +
        attribute(block, 'value') +
        attribute(block, 'zone_id')
      ),
      editable: resource.field(self._.blocks, 'editable'),
      id: resource.field(self._.blocks, 'id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      value: resource.field(self._.blocks, 'value'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    token_validation_config(name, block): {
      local resource = blockType.resource('cloudflare_token_validation_config', name),
      _: resource._(
        block,
        attribute(block, 'config_id', true) +
        attribute(block, 'created_at') +
        attribute(block, 'credentials') +
        attribute(block, 'description') +
        attribute(block, 'id') +
        attribute(block, 'last_updated') +
        attribute(block, 'title') +
        attribute(block, 'token_sources') +
        attribute(block, 'token_type') +
        attribute(block, 'zone_id')
      ),
      config_id: resource.field(self._.blocks, 'config_id'),
      created_at: resource.field(self._.blocks, 'created_at'),
      credentials: resource.field(self._.blocks, 'credentials'),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      last_updated: resource.field(self._.blocks, 'last_updated'),
      title: resource.field(self._.blocks, 'title'),
      token_sources: resource.field(self._.blocks, 'token_sources'),
      token_type: resource.field(self._.blocks, 'token_type'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    token_validation_configs(name, block): {
      local resource = blockType.resource('cloudflare_token_validation_configs', name),
      _: resource._(
        block,
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'zone_id')
      ),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    token_validation_rules(name, block): {
      local resource = blockType.resource('cloudflare_token_validation_rules', name),
      _: resource._(
        block,
        attribute(block, 'action') +
        attribute(block, 'created_at') +
        attribute(block, 'description') +
        attribute(block, 'enabled') +
        attribute(block, 'expression') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'last_updated') +
        attribute(block, 'rule_id') +
        attribute(block, 'selector') +
        attribute(block, 'title') +
        attribute(block, 'zone_id')
      ),
      action: resource.field(self._.blocks, 'action'),
      created_at: resource.field(self._.blocks, 'created_at'),
      description: resource.field(self._.blocks, 'description'),
      enabled: resource.field(self._.blocks, 'enabled'),
      expression: resource.field(self._.blocks, 'expression'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      last_updated: resource.field(self._.blocks, 'last_updated'),
      rule_id: resource.field(self._.blocks, 'rule_id'),
      selector: resource.field(self._.blocks, 'selector'),
      title: resource.field(self._.blocks, 'title'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    token_validation_rules_list(name, block): {
      local resource = blockType.resource('cloudflare_token_validation_rules_list', name),
      _: resource._(
        block,
        attribute(block, 'action') +
        attribute(block, 'enabled') +
        attribute(block, 'host') +
        attribute(block, 'hostname') +
        attribute(block, 'id') +
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'rule_id') +
        attribute(block, 'token_configuration') +
        attribute(block, 'zone_id')
      ),
      action: resource.field(self._.blocks, 'action'),
      enabled: resource.field(self._.blocks, 'enabled'),
      host: resource.field(self._.blocks, 'host'),
      hostname: resource.field(self._.blocks, 'hostname'),
      id: resource.field(self._.blocks, 'id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      rule_id: resource.field(self._.blocks, 'rule_id'),
      token_configuration: resource.field(self._.blocks, 'token_configuration'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    total_tls(name, block): {
      local resource = blockType.resource('cloudflare_total_tls', name),
      _: resource._(
        block,
        attribute(block, 'certificate_authority') +
        attribute(block, 'enabled') +
        attribute(block, 'id') +
        attribute(block, 'validity_period') +
        attribute(block, 'zone_id')
      ),
      certificate_authority: resource.field(self._.blocks, 'certificate_authority'),
      enabled: resource.field(self._.blocks, 'enabled'),
      id: resource.field(self._.blocks, 'id'),
      validity_period: resource.field(self._.blocks, 'validity_period'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    turnstile_widget(name, block): {
      local resource = blockType.resource('cloudflare_turnstile_widget', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'bot_fight_mode') +
        attribute(block, 'clearance_level') +
        attribute(block, 'created_on') +
        attribute(block, 'domains') +
        attribute(block, 'ephemeral_id') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'mode') +
        attribute(block, 'modified_on') +
        attribute(block, 'name') +
        attribute(block, 'offlabel') +
        attribute(block, 'region') +
        attribute(block, 'secret') +
        attribute(block, 'sitekey')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      bot_fight_mode: resource.field(self._.blocks, 'bot_fight_mode'),
      clearance_level: resource.field(self._.blocks, 'clearance_level'),
      created_on: resource.field(self._.blocks, 'created_on'),
      domains: resource.field(self._.blocks, 'domains'),
      ephemeral_id: resource.field(self._.blocks, 'ephemeral_id'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      mode: resource.field(self._.blocks, 'mode'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      offlabel: resource.field(self._.blocks, 'offlabel'),
      region: resource.field(self._.blocks, 'region'),
      secret: resource.field(self._.blocks, 'secret'),
      sitekey: resource.field(self._.blocks, 'sitekey'),
    },
    turnstile_widgets(name, block): {
      local resource = blockType.resource('cloudflare_turnstile_widgets', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'direction') +
        attribute(block, 'filter') +
        attribute(block, 'max_items') +
        attribute(block, 'order') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      direction: resource.field(self._.blocks, 'direction'),
      filter: resource.field(self._.blocks, 'filter'),
      max_items: resource.field(self._.blocks, 'max_items'),
      order: resource.field(self._.blocks, 'order'),
      result: resource.field(self._.blocks, 'result'),
    },
    universal_ssl_setting(name, block): {
      local resource = blockType.resource('cloudflare_universal_ssl_setting', name),
      _: resource._(
        block,
        attribute(block, 'enabled') +
        attribute(block, 'id') +
        attribute(block, 'zone_id')
      ),
      enabled: resource.field(self._.blocks, 'enabled'),
      id: resource.field(self._.blocks, 'id'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    url_normalization_settings(name, block): {
      local resource = blockType.resource('cloudflare_url_normalization_settings', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'scope') +
        attribute(block, 'type') +
        attribute(block, 'zone_id')
      ),
      id: resource.field(self._.blocks, 'id'),
      scope: resource.field(self._.blocks, 'scope'),
      type: resource.field(self._.blocks, 'type'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    user(name, block): {
      local resource = blockType.resource('cloudflare_user', name),
      _: resource._(
        block,
        attribute(block, 'betas') +
        attribute(block, 'country') +
        attribute(block, 'first_name') +
        attribute(block, 'has_business_zones') +
        attribute(block, 'has_enterprise_zones') +
        attribute(block, 'has_pro_zones') +
        attribute(block, 'id') +
        attribute(block, 'last_name') +
        attribute(block, 'organizations') +
        attribute(block, 'suspended') +
        attribute(block, 'telephone') +
        attribute(block, 'two_factor_authentication_enabled') +
        attribute(block, 'two_factor_authentication_locked') +
        attribute(block, 'zipcode')
      ),
      betas: resource.field(self._.blocks, 'betas'),
      country: resource.field(self._.blocks, 'country'),
      first_name: resource.field(self._.blocks, 'first_name'),
      has_business_zones: resource.field(self._.blocks, 'has_business_zones'),
      has_enterprise_zones: resource.field(self._.blocks, 'has_enterprise_zones'),
      has_pro_zones: resource.field(self._.blocks, 'has_pro_zones'),
      id: resource.field(self._.blocks, 'id'),
      last_name: resource.field(self._.blocks, 'last_name'),
      organizations: resource.field(self._.blocks, 'organizations'),
      suspended: resource.field(self._.blocks, 'suspended'),
      telephone: resource.field(self._.blocks, 'telephone'),
      two_factor_authentication_enabled: resource.field(self._.blocks, 'two_factor_authentication_enabled'),
      two_factor_authentication_locked: resource.field(self._.blocks, 'two_factor_authentication_locked'),
      zipcode: resource.field(self._.blocks, 'zipcode'),
    },
    user_agent_blocking_rule(name, block): {
      local resource = blockType.resource('cloudflare_user_agent_blocking_rule', name),
      _: resource._(
        block,
        attribute(block, 'configuration') +
        attribute(block, 'description') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'mode') +
        attribute(block, 'paused') +
        attribute(block, 'ua_rule_id') +
        attribute(block, 'zone_id')
      ),
      configuration: resource.field(self._.blocks, 'configuration'),
      description: resource.field(self._.blocks, 'description'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      mode: resource.field(self._.blocks, 'mode'),
      paused: resource.field(self._.blocks, 'paused'),
      ua_rule_id: resource.field(self._.blocks, 'ua_rule_id'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    user_agent_blocking_rules(name, block): {
      local resource = blockType.resource('cloudflare_user_agent_blocking_rules', name),
      _: resource._(
        block,
        attribute(block, 'description') +
        attribute(block, 'max_items') +
        attribute(block, 'paused') +
        attribute(block, 'result') +
        attribute(block, 'user_agent') +
        attribute(block, 'zone_id')
      ),
      description: resource.field(self._.blocks, 'description'),
      max_items: resource.field(self._.blocks, 'max_items'),
      paused: resource.field(self._.blocks, 'paused'),
      result: resource.field(self._.blocks, 'result'),
      user_agent: resource.field(self._.blocks, 'user_agent'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    user_group(name, block): {
      local resource = blockType.resource('cloudflare_user_group', name),
      _: resource._(
        block,
        attribute(block, 'account_id', true) +
        attribute(block, 'created_on') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'modified_on') +
        attribute(block, 'name') +
        attribute(block, 'policies') +
        attribute(block, 'user_group_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_on: resource.field(self._.blocks, 'created_on'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      policies: resource.field(self._.blocks, 'policies'),
      user_group_id: resource.field(self._.blocks, 'user_group_id'),
    },
    user_group_members(name, block): {
      local resource = blockType.resource('cloudflare_user_group_members', name),
      _: resource._(
        block,
        attribute(block, 'account_id', true) +
        attribute(block, 'direction') +
        attribute(block, 'fuzzy_email') +
        attribute(block, 'id') +
        attribute(block, 'members') +
        attribute(block, 'user_group_id', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      direction: resource.field(self._.blocks, 'direction'),
      fuzzy_email: resource.field(self._.blocks, 'fuzzy_email'),
      id: resource.field(self._.blocks, 'id'),
      members: resource.field(self._.blocks, 'members'),
      user_group_id: resource.field(self._.blocks, 'user_group_id'),
    },
    user_groups(name, block): {
      local resource = blockType.resource('cloudflare_user_groups', name),
      _: resource._(
        block,
        attribute(block, 'account_id', true) +
        attribute(block, 'direction') +
        attribute(block, 'fuzzy_name') +
        attribute(block, 'id') +
        attribute(block, 'max_items') +
        attribute(block, 'name') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      direction: resource.field(self._.blocks, 'direction'),
      fuzzy_name: resource.field(self._.blocks, 'fuzzy_name'),
      id: resource.field(self._.blocks, 'id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      name: resource.field(self._.blocks, 'name'),
      result: resource.field(self._.blocks, 'result'),
    },
    vulnerability_scanner_credential(name, block): {
      local resource = blockType.resource('cloudflare_vulnerability_scanner_credential', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'credential_id', true) +
        attribute(block, 'credential_set_id', true) +
        attribute(block, 'id') +
        attribute(block, 'location') +
        attribute(block, 'location_name') +
        attribute(block, 'name')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      credential_id: resource.field(self._.blocks, 'credential_id'),
      credential_set_id: resource.field(self._.blocks, 'credential_set_id'),
      id: resource.field(self._.blocks, 'id'),
      location: resource.field(self._.blocks, 'location'),
      location_name: resource.field(self._.blocks, 'location_name'),
      name: resource.field(self._.blocks, 'name'),
    },
    vulnerability_scanner_credential_set(name, block): {
      local resource = blockType.resource('cloudflare_vulnerability_scanner_credential_set', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'credential_set_id', true) +
        attribute(block, 'id') +
        attribute(block, 'name')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      credential_set_id: resource.field(self._.blocks, 'credential_set_id'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
    },
    vulnerability_scanner_credential_sets(name, block): {
      local resource = blockType.resource('cloudflare_vulnerability_scanner_credential_sets', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    vulnerability_scanner_credentials(name, block): {
      local resource = blockType.resource('cloudflare_vulnerability_scanner_credentials', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'credential_set_id', true) +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      credential_set_id: resource.field(self._.blocks, 'credential_set_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    vulnerability_scanner_target_environment(name, block): {
      local resource = blockType.resource('cloudflare_vulnerability_scanner_target_environment', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'description') +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'target') +
        attribute(block, 'target_environment_id', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      target: resource.field(self._.blocks, 'target'),
      target_environment_id: resource.field(self._.blocks, 'target_environment_id'),
    },
    vulnerability_scanner_target_environments(name, block): {
      local resource = blockType.resource('cloudflare_vulnerability_scanner_target_environments', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    waiting_room(name, block): {
      local resource = blockType.resource('cloudflare_waiting_room', name),
      _: resource._(
        block,
        attribute(block, 'additional_routes') +
        attribute(block, 'cookie_attributes') +
        attribute(block, 'cookie_suffix') +
        attribute(block, 'created_on') +
        attribute(block, 'custom_page_html') +
        attribute(block, 'default_template_language') +
        attribute(block, 'description') +
        attribute(block, 'disable_session_renewal') +
        attribute(block, 'enabled_origin_commands') +
        attribute(block, 'host') +
        attribute(block, 'id') +
        attribute(block, 'json_response_enabled') +
        attribute(block, 'modified_on') +
        attribute(block, 'name') +
        attribute(block, 'new_users_per_minute') +
        attribute(block, 'next_event_prequeue_start_time') +
        attribute(block, 'next_event_start_time') +
        attribute(block, 'path') +
        attribute(block, 'queue_all') +
        attribute(block, 'queueing_method') +
        attribute(block, 'queueing_status_code') +
        attribute(block, 'session_duration') +
        attribute(block, 'suspended') +
        attribute(block, 'total_active_users') +
        attribute(block, 'turnstile_action') +
        attribute(block, 'turnstile_mode') +
        attribute(block, 'waiting_room_id', true) +
        attribute(block, 'zone_id')
      ),
      additional_routes: resource.field(self._.blocks, 'additional_routes'),
      cookie_attributes: resource.field(self._.blocks, 'cookie_attributes'),
      cookie_suffix: resource.field(self._.blocks, 'cookie_suffix'),
      created_on: resource.field(self._.blocks, 'created_on'),
      custom_page_html: resource.field(self._.blocks, 'custom_page_html'),
      default_template_language: resource.field(self._.blocks, 'default_template_language'),
      description: resource.field(self._.blocks, 'description'),
      disable_session_renewal: resource.field(self._.blocks, 'disable_session_renewal'),
      enabled_origin_commands: resource.field(self._.blocks, 'enabled_origin_commands'),
      host: resource.field(self._.blocks, 'host'),
      id: resource.field(self._.blocks, 'id'),
      json_response_enabled: resource.field(self._.blocks, 'json_response_enabled'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      new_users_per_minute: resource.field(self._.blocks, 'new_users_per_minute'),
      next_event_prequeue_start_time: resource.field(self._.blocks, 'next_event_prequeue_start_time'),
      next_event_start_time: resource.field(self._.blocks, 'next_event_start_time'),
      path: resource.field(self._.blocks, 'path'),
      queue_all: resource.field(self._.blocks, 'queue_all'),
      queueing_method: resource.field(self._.blocks, 'queueing_method'),
      queueing_status_code: resource.field(self._.blocks, 'queueing_status_code'),
      session_duration: resource.field(self._.blocks, 'session_duration'),
      suspended: resource.field(self._.blocks, 'suspended'),
      total_active_users: resource.field(self._.blocks, 'total_active_users'),
      turnstile_action: resource.field(self._.blocks, 'turnstile_action'),
      turnstile_mode: resource.field(self._.blocks, 'turnstile_mode'),
      waiting_room_id: resource.field(self._.blocks, 'waiting_room_id'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    waiting_room_event(name, block): {
      local resource = blockType.resource('cloudflare_waiting_room_event', name),
      _: resource._(
        block,
        attribute(block, 'created_on') +
        attribute(block, 'custom_page_html') +
        attribute(block, 'description') +
        attribute(block, 'disable_session_renewal') +
        attribute(block, 'event_end_time') +
        attribute(block, 'event_id', true) +
        attribute(block, 'event_start_time') +
        attribute(block, 'id') +
        attribute(block, 'modified_on') +
        attribute(block, 'name') +
        attribute(block, 'new_users_per_minute') +
        attribute(block, 'prequeue_start_time') +
        attribute(block, 'queueing_method') +
        attribute(block, 'session_duration') +
        attribute(block, 'shuffle_at_event_start') +
        attribute(block, 'suspended') +
        attribute(block, 'total_active_users') +
        attribute(block, 'turnstile_action') +
        attribute(block, 'turnstile_mode') +
        attribute(block, 'waiting_room_id', true) +
        attribute(block, 'zone_id')
      ),
      created_on: resource.field(self._.blocks, 'created_on'),
      custom_page_html: resource.field(self._.blocks, 'custom_page_html'),
      description: resource.field(self._.blocks, 'description'),
      disable_session_renewal: resource.field(self._.blocks, 'disable_session_renewal'),
      event_end_time: resource.field(self._.blocks, 'event_end_time'),
      event_id: resource.field(self._.blocks, 'event_id'),
      event_start_time: resource.field(self._.blocks, 'event_start_time'),
      id: resource.field(self._.blocks, 'id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      new_users_per_minute: resource.field(self._.blocks, 'new_users_per_minute'),
      prequeue_start_time: resource.field(self._.blocks, 'prequeue_start_time'),
      queueing_method: resource.field(self._.blocks, 'queueing_method'),
      session_duration: resource.field(self._.blocks, 'session_duration'),
      shuffle_at_event_start: resource.field(self._.blocks, 'shuffle_at_event_start'),
      suspended: resource.field(self._.blocks, 'suspended'),
      total_active_users: resource.field(self._.blocks, 'total_active_users'),
      turnstile_action: resource.field(self._.blocks, 'turnstile_action'),
      turnstile_mode: resource.field(self._.blocks, 'turnstile_mode'),
      waiting_room_id: resource.field(self._.blocks, 'waiting_room_id'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    waiting_room_events(name, block): {
      local resource = blockType.resource('cloudflare_waiting_room_events', name),
      _: resource._(
        block,
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'waiting_room_id', true) +
        attribute(block, 'zone_id')
      ),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      waiting_room_id: resource.field(self._.blocks, 'waiting_room_id'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    waiting_room_rules(name, block): {
      local resource = blockType.resource('cloudflare_waiting_room_rules', name),
      _: resource._(
        block,
        attribute(block, 'action') +
        attribute(block, 'description') +
        attribute(block, 'enabled') +
        attribute(block, 'expression') +
        attribute(block, 'id') +
        attribute(block, 'last_updated') +
        attribute(block, 'version') +
        attribute(block, 'waiting_room_id', true) +
        attribute(block, 'zone_id')
      ),
      action: resource.field(self._.blocks, 'action'),
      description: resource.field(self._.blocks, 'description'),
      enabled: resource.field(self._.blocks, 'enabled'),
      expression: resource.field(self._.blocks, 'expression'),
      id: resource.field(self._.blocks, 'id'),
      last_updated: resource.field(self._.blocks, 'last_updated'),
      version: resource.field(self._.blocks, 'version'),
      waiting_room_id: resource.field(self._.blocks, 'waiting_room_id'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    waiting_room_settings(name, block): {
      local resource = blockType.resource('cloudflare_waiting_room_settings', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'search_engine_crawler_bypass') +
        attribute(block, 'zone_id')
      ),
      id: resource.field(self._.blocks, 'id'),
      search_engine_crawler_bypass: resource.field(self._.blocks, 'search_engine_crawler_bypass'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    waiting_rooms(name, block): {
      local resource = blockType.resource('cloudflare_waiting_rooms', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    web3_hostname(name, block): {
      local resource = blockType.resource('cloudflare_web3_hostname', name),
      _: resource._(
        block,
        attribute(block, 'created_on') +
        attribute(block, 'description') +
        attribute(block, 'dnslink') +
        attribute(block, 'id') +
        attribute(block, 'identifier', true) +
        attribute(block, 'modified_on') +
        attribute(block, 'name') +
        attribute(block, 'status') +
        attribute(block, 'target') +
        attribute(block, 'zone_id')
      ),
      created_on: resource.field(self._.blocks, 'created_on'),
      description: resource.field(self._.blocks, 'description'),
      dnslink: resource.field(self._.blocks, 'dnslink'),
      id: resource.field(self._.blocks, 'id'),
      identifier: resource.field(self._.blocks, 'identifier'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      status: resource.field(self._.blocks, 'status'),
      target: resource.field(self._.blocks, 'target'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    web3_hostnames(name, block): {
      local resource = blockType.resource('cloudflare_web3_hostnames', name),
      _: resource._(
        block,
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'zone_id')
      ),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    web_analytics_site(name, block): {
      local resource = blockType.resource('cloudflare_web_analytics_site', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'auto_install') +
        attribute(block, 'created') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'rules') +
        attribute(block, 'ruleset') +
        attribute(block, 'site_id') +
        attribute(block, 'site_tag') +
        attribute(block, 'site_token') +
        attribute(block, 'snippet')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      auto_install: resource.field(self._.blocks, 'auto_install'),
      created: resource.field(self._.blocks, 'created'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      rules: resource.field(self._.blocks, 'rules'),
      ruleset: resource.field(self._.blocks, 'ruleset'),
      site_id: resource.field(self._.blocks, 'site_id'),
      site_tag: resource.field(self._.blocks, 'site_tag'),
      site_token: resource.field(self._.blocks, 'site_token'),
      snippet: resource.field(self._.blocks, 'snippet'),
    },
    web_analytics_sites(name, block): {
      local resource = blockType.resource('cloudflare_web_analytics_sites', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'order_by') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      order_by: resource.field(self._.blocks, 'order_by'),
      result: resource.field(self._.blocks, 'result'),
    },
    worker(name, block): {
      local resource = blockType.resource('cloudflare_worker', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_on') +
        attribute(block, 'deployed_on') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'logpush') +
        attribute(block, 'name') +
        attribute(block, 'observability') +
        attribute(block, 'references') +
        attribute(block, 'subdomain') +
        attribute(block, 'tags') +
        attribute(block, 'tail_consumers') +
        attribute(block, 'updated_on') +
        attribute(block, 'worker_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_on: resource.field(self._.blocks, 'created_on'),
      deployed_on: resource.field(self._.blocks, 'deployed_on'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      logpush: resource.field(self._.blocks, 'logpush'),
      name: resource.field(self._.blocks, 'name'),
      observability: resource.field(self._.blocks, 'observability'),
      references: resource.field(self._.blocks, 'references'),
      subdomain: resource.field(self._.blocks, 'subdomain'),
      tags: resource.field(self._.blocks, 'tags'),
      tail_consumers: resource.field(self._.blocks, 'tail_consumers'),
      updated_on: resource.field(self._.blocks, 'updated_on'),
      worker_id: resource.field(self._.blocks, 'worker_id'),
    },
    worker_version(name, block): {
      local resource = blockType.resource('cloudflare_worker_version', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'annotations') +
        attribute(block, 'assets') +
        attribute(block, 'bindings') +
        attribute(block, 'compatibility_date') +
        attribute(block, 'compatibility_flags') +
        attribute(block, 'containers') +
        attribute(block, 'created_on') +
        attribute(block, 'id') +
        attribute(block, 'include') +
        attribute(block, 'limits') +
        attribute(block, 'main_module') +
        attribute(block, 'main_script_base64') +
        attribute(block, 'migration_tag') +
        attribute(block, 'migrations') +
        attribute(block, 'modules') +
        attribute(block, 'number') +
        attribute(block, 'placement') +
        attribute(block, 'source') +
        attribute(block, 'startup_time_ms') +
        attribute(block, 'urls') +
        attribute(block, 'usage_model') +
        attribute(block, 'version_id', true) +
        attribute(block, 'worker_id', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      annotations: resource.field(self._.blocks, 'annotations'),
      assets: resource.field(self._.blocks, 'assets'),
      bindings: resource.field(self._.blocks, 'bindings'),
      compatibility_date: resource.field(self._.blocks, 'compatibility_date'),
      compatibility_flags: resource.field(self._.blocks, 'compatibility_flags'),
      containers: resource.field(self._.blocks, 'containers'),
      created_on: resource.field(self._.blocks, 'created_on'),
      id: resource.field(self._.blocks, 'id'),
      include: resource.field(self._.blocks, 'include'),
      limits: resource.field(self._.blocks, 'limits'),
      main_module: resource.field(self._.blocks, 'main_module'),
      main_script_base64: resource.field(self._.blocks, 'main_script_base64'),
      migration_tag: resource.field(self._.blocks, 'migration_tag'),
      migrations: resource.field(self._.blocks, 'migrations'),
      modules: resource.field(self._.blocks, 'modules'),
      number: resource.field(self._.blocks, 'number'),
      placement: resource.field(self._.blocks, 'placement'),
      source: resource.field(self._.blocks, 'source'),
      startup_time_ms: resource.field(self._.blocks, 'startup_time_ms'),
      urls: resource.field(self._.blocks, 'urls'),
      usage_model: resource.field(self._.blocks, 'usage_model'),
      version_id: resource.field(self._.blocks, 'version_id'),
      worker_id: resource.field(self._.blocks, 'worker_id'),
    },
    worker_versions(name, block): {
      local resource = blockType.resource('cloudflare_worker_versions', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'worker_id', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      worker_id: resource.field(self._.blocks, 'worker_id'),
    },
    workers(name, block): {
      local resource = blockType.resource('cloudflare_workers', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'order') +
        attribute(block, 'order_by') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      order: resource.field(self._.blocks, 'order'),
      order_by: resource.field(self._.blocks, 'order_by'),
      result: resource.field(self._.blocks, 'result'),
    },
    workers_cron_trigger(name, block): {
      local resource = blockType.resource('cloudflare_workers_cron_trigger', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'id') +
        attribute(block, 'schedules') +
        attribute(block, 'script_name', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      id: resource.field(self._.blocks, 'id'),
      schedules: resource.field(self._.blocks, 'schedules'),
      script_name: resource.field(self._.blocks, 'script_name'),
    },
    workers_custom_domain(name, block): {
      local resource = blockType.resource('cloudflare_workers_custom_domain', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'cert_id') +
        attribute(block, 'domain_id') +
        attribute(block, 'environment') +
        attribute(block, 'filter') +
        attribute(block, 'hostname') +
        attribute(block, 'id') +
        attribute(block, 'service') +
        attribute(block, 'zone_id') +
        attribute(block, 'zone_name')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      cert_id: resource.field(self._.blocks, 'cert_id'),
      domain_id: resource.field(self._.blocks, 'domain_id'),
      environment: resource.field(self._.blocks, 'environment'),
      filter: resource.field(self._.blocks, 'filter'),
      hostname: resource.field(self._.blocks, 'hostname'),
      id: resource.field(self._.blocks, 'id'),
      service: resource.field(self._.blocks, 'service'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
      zone_name: resource.field(self._.blocks, 'zone_name'),
    },
    workers_custom_domains(name, block): {
      local resource = blockType.resource('cloudflare_workers_custom_domains', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'environment') +
        attribute(block, 'hostname') +
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'service') +
        attribute(block, 'zone_id') +
        attribute(block, 'zone_name')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      environment: resource.field(self._.blocks, 'environment'),
      hostname: resource.field(self._.blocks, 'hostname'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      service: resource.field(self._.blocks, 'service'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
      zone_name: resource.field(self._.blocks, 'zone_name'),
    },
    workers_deployment(name, block): {
      local resource = blockType.resource('cloudflare_workers_deployment', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'annotations') +
        attribute(block, 'author_email') +
        attribute(block, 'created_on') +
        attribute(block, 'deployment_id', true) +
        attribute(block, 'id') +
        attribute(block, 'script_name', true) +
        attribute(block, 'source') +
        attribute(block, 'strategy') +
        attribute(block, 'versions')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      annotations: resource.field(self._.blocks, 'annotations'),
      author_email: resource.field(self._.blocks, 'author_email'),
      created_on: resource.field(self._.blocks, 'created_on'),
      deployment_id: resource.field(self._.blocks, 'deployment_id'),
      id: resource.field(self._.blocks, 'id'),
      script_name: resource.field(self._.blocks, 'script_name'),
      source: resource.field(self._.blocks, 'source'),
      strategy: resource.field(self._.blocks, 'strategy'),
      versions: resource.field(self._.blocks, 'versions'),
    },
    workers_for_platforms_dispatch_namespace(name, block): {
      local resource = blockType.resource('cloudflare_workers_for_platforms_dispatch_namespace', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_by') +
        attribute(block, 'created_on') +
        attribute(block, 'dispatch_namespace', true) +
        attribute(block, 'id') +
        attribute(block, 'modified_by') +
        attribute(block, 'modified_on') +
        attribute(block, 'namespace_id') +
        attribute(block, 'namespace_name') +
        attribute(block, 'script_count') +
        attribute(block, 'trusted_workers')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_by: resource.field(self._.blocks, 'created_by'),
      created_on: resource.field(self._.blocks, 'created_on'),
      dispatch_namespace: resource.field(self._.blocks, 'dispatch_namespace'),
      id: resource.field(self._.blocks, 'id'),
      modified_by: resource.field(self._.blocks, 'modified_by'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      namespace_id: resource.field(self._.blocks, 'namespace_id'),
      namespace_name: resource.field(self._.blocks, 'namespace_name'),
      script_count: resource.field(self._.blocks, 'script_count'),
      trusted_workers: resource.field(self._.blocks, 'trusted_workers'),
    },
    workers_for_platforms_dispatch_namespaces(name, block): {
      local resource = blockType.resource('cloudflare_workers_for_platforms_dispatch_namespaces', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    workers_kv(name, block): {
      local resource = blockType.resource('cloudflare_workers_kv', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'id') +
        attribute(block, 'key_name', true) +
        attribute(block, 'namespace_id', true) +
        attribute(block, 'value')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      id: resource.field(self._.blocks, 'id'),
      key_name: resource.field(self._.blocks, 'key_name'),
      namespace_id: resource.field(self._.blocks, 'namespace_id'),
      value: resource.field(self._.blocks, 'value'),
    },
    workers_kv_namespace(name, block): {
      local resource = blockType.resource('cloudflare_workers_kv_namespace', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'namespace_id') +
        attribute(block, 'supports_url_encoding') +
        attribute(block, 'title')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      namespace_id: resource.field(self._.blocks, 'namespace_id'),
      supports_url_encoding: resource.field(self._.blocks, 'supports_url_encoding'),
      title: resource.field(self._.blocks, 'title'),
    },
    workers_kv_namespaces(name, block): {
      local resource = blockType.resource('cloudflare_workers_kv_namespaces', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'direction') +
        attribute(block, 'max_items') +
        attribute(block, 'order') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      direction: resource.field(self._.blocks, 'direction'),
      max_items: resource.field(self._.blocks, 'max_items'),
      order: resource.field(self._.blocks, 'order'),
      result: resource.field(self._.blocks, 'result'),
    },
    workers_route(name, block): {
      local resource = blockType.resource('cloudflare_workers_route', name),
      _: resource._(
        block,
        attribute(block, 'id') +
        attribute(block, 'pattern') +
        attribute(block, 'route_id', true) +
        attribute(block, 'script') +
        attribute(block, 'zone_id')
      ),
      id: resource.field(self._.blocks, 'id'),
      pattern: resource.field(self._.blocks, 'pattern'),
      route_id: resource.field(self._.blocks, 'route_id'),
      script: resource.field(self._.blocks, 'script'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    workers_routes(name, block): {
      local resource = blockType.resource('cloudflare_workers_routes', name),
      _: resource._(
        block,
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'zone_id')
      ),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    workers_script(name, block): {
      local resource = blockType.resource('cloudflare_workers_script', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'script') +
        attribute(block, 'script_name')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      script: resource.field(self._.blocks, 'script'),
      script_name: resource.field(self._.blocks, 'script_name'),
    },
    workers_script_subdomain(name, block): {
      local resource = blockType.resource('cloudflare_workers_script_subdomain', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'enabled') +
        attribute(block, 'previews_enabled') +
        attribute(block, 'script_name', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      enabled: resource.field(self._.blocks, 'enabled'),
      previews_enabled: resource.field(self._.blocks, 'previews_enabled'),
      script_name: resource.field(self._.blocks, 'script_name'),
    },
    workers_scripts(name, block): {
      local resource = blockType.resource('cloudflare_workers_scripts', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'tags')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      tags: resource.field(self._.blocks, 'tags'),
    },
    workflow(name, block): {
      local resource = blockType.resource('cloudflare_workflow', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'class_name') +
        attribute(block, 'created_on') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'instances') +
        attribute(block, 'modified_on') +
        attribute(block, 'name') +
        attribute(block, 'script_name') +
        attribute(block, 'triggered_on') +
        attribute(block, 'workflow_name')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      class_name: resource.field(self._.blocks, 'class_name'),
      created_on: resource.field(self._.blocks, 'created_on'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      instances: resource.field(self._.blocks, 'instances'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      script_name: resource.field(self._.blocks, 'script_name'),
      triggered_on: resource.field(self._.blocks, 'triggered_on'),
      workflow_name: resource.field(self._.blocks, 'workflow_name'),
    },
    workflows(name, block): {
      local resource = blockType.resource('cloudflare_workflows', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'search')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      search: resource.field(self._.blocks, 'search'),
    },
    zero_trust_access_ai_controls_mcp_portal(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_ai_controls_mcp_portal', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'allow_code_mode') +
        attribute(block, 'created_at') +
        attribute(block, 'created_by') +
        attribute(block, 'description') +
        attribute(block, 'filter') +
        attribute(block, 'hostname') +
        attribute(block, 'id') +
        attribute(block, 'modified_at') +
        attribute(block, 'modified_by') +
        attribute(block, 'name') +
        attribute(block, 'secure_web_gateway') +
        attribute(block, 'servers')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      allow_code_mode: resource.field(self._.blocks, 'allow_code_mode'),
      created_at: resource.field(self._.blocks, 'created_at'),
      created_by: resource.field(self._.blocks, 'created_by'),
      description: resource.field(self._.blocks, 'description'),
      filter: resource.field(self._.blocks, 'filter'),
      hostname: resource.field(self._.blocks, 'hostname'),
      id: resource.field(self._.blocks, 'id'),
      modified_at: resource.field(self._.blocks, 'modified_at'),
      modified_by: resource.field(self._.blocks, 'modified_by'),
      name: resource.field(self._.blocks, 'name'),
      secure_web_gateway: resource.field(self._.blocks, 'secure_web_gateway'),
      servers: resource.field(self._.blocks, 'servers'),
    },
    zero_trust_access_ai_controls_mcp_portals(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_ai_controls_mcp_portals', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'search')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      search: resource.field(self._.blocks, 'search'),
    },
    zero_trust_access_ai_controls_mcp_server(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_ai_controls_mcp_server', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'auth_type') +
        attribute(block, 'created_at') +
        attribute(block, 'created_by') +
        attribute(block, 'description') +
        attribute(block, 'error') +
        attribute(block, 'filter') +
        attribute(block, 'hostname') +
        attribute(block, 'id') +
        attribute(block, 'last_successful_sync') +
        attribute(block, 'last_synced') +
        attribute(block, 'modified_at') +
        attribute(block, 'modified_by') +
        attribute(block, 'name') +
        attribute(block, 'prompts') +
        attribute(block, 'status') +
        attribute(block, 'tools') +
        attribute(block, 'updated_prompts') +
        attribute(block, 'updated_tools')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      auth_type: resource.field(self._.blocks, 'auth_type'),
      created_at: resource.field(self._.blocks, 'created_at'),
      created_by: resource.field(self._.blocks, 'created_by'),
      description: resource.field(self._.blocks, 'description'),
      'error': resource.field(self._.blocks, 'error'),
      filter: resource.field(self._.blocks, 'filter'),
      hostname: resource.field(self._.blocks, 'hostname'),
      id: resource.field(self._.blocks, 'id'),
      last_successful_sync: resource.field(self._.blocks, 'last_successful_sync'),
      last_synced: resource.field(self._.blocks, 'last_synced'),
      modified_at: resource.field(self._.blocks, 'modified_at'),
      modified_by: resource.field(self._.blocks, 'modified_by'),
      name: resource.field(self._.blocks, 'name'),
      prompts: resource.field(self._.blocks, 'prompts'),
      status: resource.field(self._.blocks, 'status'),
      tools: resource.field(self._.blocks, 'tools'),
      updated_prompts: resource.field(self._.blocks, 'updated_prompts'),
      updated_tools: resource.field(self._.blocks, 'updated_tools'),
    },
    zero_trust_access_ai_controls_mcp_servers(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_ai_controls_mcp_servers', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'search')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      search: resource.field(self._.blocks, 'search'),
    },
    zero_trust_access_application(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_application', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'allow_authenticate_via_warp') +
        attribute(block, 'allow_iframe') +
        attribute(block, 'allowed_idps') +
        attribute(block, 'app_id') +
        attribute(block, 'app_launcher_logo_url') +
        attribute(block, 'app_launcher_visible') +
        attribute(block, 'aud') +
        attribute(block, 'auto_redirect_to_identity') +
        attribute(block, 'bg_color') +
        attribute(block, 'cors_headers') +
        attribute(block, 'custom_deny_message') +
        attribute(block, 'custom_deny_url') +
        attribute(block, 'custom_non_identity_deny_url') +
        attribute(block, 'custom_pages') +
        attribute(block, 'destinations') +
        attribute(block, 'domain') +
        attribute(block, 'enable_binding_cookie') +
        attribute(block, 'filter') +
        attribute(block, 'footer_links') +
        attribute(block, 'header_bg_color') +
        attribute(block, 'http_only_cookie_attribute') +
        attribute(block, 'id') +
        attribute(block, 'landing_page_design') +
        attribute(block, 'logo_url') +
        attribute(block, 'mfa_config') +
        attribute(block, 'name') +
        attribute(block, 'options_preflight_bypass') +
        attribute(block, 'path_cookie_attribute') +
        attribute(block, 'policies') +
        attribute(block, 'read_service_tokens_from_header') +
        attribute(block, 'saas_app') +
        attribute(block, 'same_site_cookie_attribute') +
        attribute(block, 'scim_config') +
        attribute(block, 'self_hosted_domains') +
        attribute(block, 'service_auth_401_redirect') +
        attribute(block, 'session_duration') +
        attribute(block, 'skip_app_launcher_login_page') +
        attribute(block, 'skip_interstitial') +
        attribute(block, 'tags') +
        attribute(block, 'target_criteria') +
        attribute(block, 'type') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      allow_authenticate_via_warp: resource.field(self._.blocks, 'allow_authenticate_via_warp'),
      allow_iframe: resource.field(self._.blocks, 'allow_iframe'),
      allowed_idps: resource.field(self._.blocks, 'allowed_idps'),
      app_id: resource.field(self._.blocks, 'app_id'),
      app_launcher_logo_url: resource.field(self._.blocks, 'app_launcher_logo_url'),
      app_launcher_visible: resource.field(self._.blocks, 'app_launcher_visible'),
      aud: resource.field(self._.blocks, 'aud'),
      auto_redirect_to_identity: resource.field(self._.blocks, 'auto_redirect_to_identity'),
      bg_color: resource.field(self._.blocks, 'bg_color'),
      cors_headers: resource.field(self._.blocks, 'cors_headers'),
      custom_deny_message: resource.field(self._.blocks, 'custom_deny_message'),
      custom_deny_url: resource.field(self._.blocks, 'custom_deny_url'),
      custom_non_identity_deny_url: resource.field(self._.blocks, 'custom_non_identity_deny_url'),
      custom_pages: resource.field(self._.blocks, 'custom_pages'),
      destinations: resource.field(self._.blocks, 'destinations'),
      domain: resource.field(self._.blocks, 'domain'),
      enable_binding_cookie: resource.field(self._.blocks, 'enable_binding_cookie'),
      filter: resource.field(self._.blocks, 'filter'),
      footer_links: resource.field(self._.blocks, 'footer_links'),
      header_bg_color: resource.field(self._.blocks, 'header_bg_color'),
      http_only_cookie_attribute: resource.field(self._.blocks, 'http_only_cookie_attribute'),
      id: resource.field(self._.blocks, 'id'),
      landing_page_design: resource.field(self._.blocks, 'landing_page_design'),
      logo_url: resource.field(self._.blocks, 'logo_url'),
      mfa_config: resource.field(self._.blocks, 'mfa_config'),
      name: resource.field(self._.blocks, 'name'),
      options_preflight_bypass: resource.field(self._.blocks, 'options_preflight_bypass'),
      path_cookie_attribute: resource.field(self._.blocks, 'path_cookie_attribute'),
      policies: resource.field(self._.blocks, 'policies'),
      read_service_tokens_from_header: resource.field(self._.blocks, 'read_service_tokens_from_header'),
      saas_app: resource.field(self._.blocks, 'saas_app'),
      same_site_cookie_attribute: resource.field(self._.blocks, 'same_site_cookie_attribute'),
      scim_config: resource.field(self._.blocks, 'scim_config'),
      self_hosted_domains: resource.field(self._.blocks, 'self_hosted_domains'),
      service_auth_401_redirect: resource.field(self._.blocks, 'service_auth_401_redirect'),
      session_duration: resource.field(self._.blocks, 'session_duration'),
      skip_app_launcher_login_page: resource.field(self._.blocks, 'skip_app_launcher_login_page'),
      skip_interstitial: resource.field(self._.blocks, 'skip_interstitial'),
      tags: resource.field(self._.blocks, 'tags'),
      target_criteria: resource.field(self._.blocks, 'target_criteria'),
      type: resource.field(self._.blocks, 'type'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zero_trust_access_applications(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_applications', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'aud') +
        attribute(block, 'domain') +
        attribute(block, 'exact') +
        attribute(block, 'max_items') +
        attribute(block, 'name') +
        attribute(block, 'result') +
        attribute(block, 'search') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      aud: resource.field(self._.blocks, 'aud'),
      domain: resource.field(self._.blocks, 'domain'),
      exact: resource.field(self._.blocks, 'exact'),
      max_items: resource.field(self._.blocks, 'max_items'),
      name: resource.field(self._.blocks, 'name'),
      result: resource.field(self._.blocks, 'result'),
      search: resource.field(self._.blocks, 'search'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zero_trust_access_custom_page(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_custom_page', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'custom_html') +
        attribute(block, 'custom_page_id', true) +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'type') +
        attribute(block, 'uid')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      custom_html: resource.field(self._.blocks, 'custom_html'),
      custom_page_id: resource.field(self._.blocks, 'custom_page_id'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      type: resource.field(self._.blocks, 'type'),
      uid: resource.field(self._.blocks, 'uid'),
    },
    zero_trust_access_custom_pages(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_custom_pages', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    zero_trust_access_group(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_group', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'exclude') +
        attribute(block, 'filter') +
        attribute(block, 'group_id') +
        attribute(block, 'id') +
        attribute(block, 'include') +
        attribute(block, 'is_default') +
        attribute(block, 'name') +
        attribute(block, 'require') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      exclude: resource.field(self._.blocks, 'exclude'),
      filter: resource.field(self._.blocks, 'filter'),
      group_id: resource.field(self._.blocks, 'group_id'),
      id: resource.field(self._.blocks, 'id'),
      include: resource.field(self._.blocks, 'include'),
      is_default: resource.field(self._.blocks, 'is_default'),
      name: resource.field(self._.blocks, 'name'),
      require: resource.field(self._.blocks, 'require'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zero_trust_access_groups(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_groups', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'name') +
        attribute(block, 'result') +
        attribute(block, 'search') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      name: resource.field(self._.blocks, 'name'),
      result: resource.field(self._.blocks, 'result'),
      search: resource.field(self._.blocks, 'search'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zero_trust_access_identity_provider(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_identity_provider', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'config') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'identity_provider_id') +
        attribute(block, 'name') +
        attribute(block, 'scim_config') +
        attribute(block, 'type') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      config: resource.field(self._.blocks, 'config'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      identity_provider_id: resource.field(self._.blocks, 'identity_provider_id'),
      name: resource.field(self._.blocks, 'name'),
      scim_config: resource.field(self._.blocks, 'scim_config'),
      type: resource.field(self._.blocks, 'type'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zero_trust_access_identity_providers(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_identity_providers', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'scim_enabled') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      scim_enabled: resource.field(self._.blocks, 'scim_enabled'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zero_trust_access_infrastructure_target(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_infrastructure_target', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_at') +
        attribute(block, 'filter') +
        attribute(block, 'hostname') +
        attribute(block, 'id') +
        attribute(block, 'ip') +
        attribute(block, 'modified_at') +
        attribute(block, 'target_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_at: resource.field(self._.blocks, 'created_at'),
      filter: resource.field(self._.blocks, 'filter'),
      hostname: resource.field(self._.blocks, 'hostname'),
      id: resource.field(self._.blocks, 'id'),
      ip: resource.field(self._.blocks, 'ip'),
      modified_at: resource.field(self._.blocks, 'modified_at'),
      target_id: resource.field(self._.blocks, 'target_id'),
    },
    zero_trust_access_infrastructure_targets(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_infrastructure_targets', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_after') +
        attribute(block, 'created_before') +
        attribute(block, 'direction') +
        attribute(block, 'hostname') +
        attribute(block, 'hostname_contains') +
        attribute(block, 'ip_like') +
        attribute(block, 'ip_v4') +
        attribute(block, 'ip_v6') +
        attribute(block, 'ips') +
        attribute(block, 'ipv4_end') +
        attribute(block, 'ipv4_start') +
        attribute(block, 'ipv6_end') +
        attribute(block, 'ipv6_start') +
        attribute(block, 'max_items') +
        attribute(block, 'modified_after') +
        attribute(block, 'modified_before') +
        attribute(block, 'order') +
        attribute(block, 'result') +
        attribute(block, 'target_ids') +
        attribute(block, 'virtual_network_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_after: resource.field(self._.blocks, 'created_after'),
      created_before: resource.field(self._.blocks, 'created_before'),
      direction: resource.field(self._.blocks, 'direction'),
      hostname: resource.field(self._.blocks, 'hostname'),
      hostname_contains: resource.field(self._.blocks, 'hostname_contains'),
      ip_like: resource.field(self._.blocks, 'ip_like'),
      ip_v4: resource.field(self._.blocks, 'ip_v4'),
      ip_v6: resource.field(self._.blocks, 'ip_v6'),
      ips: resource.field(self._.blocks, 'ips'),
      ipv4_end: resource.field(self._.blocks, 'ipv4_end'),
      ipv4_start: resource.field(self._.blocks, 'ipv4_start'),
      ipv6_end: resource.field(self._.blocks, 'ipv6_end'),
      ipv6_start: resource.field(self._.blocks, 'ipv6_start'),
      max_items: resource.field(self._.blocks, 'max_items'),
      modified_after: resource.field(self._.blocks, 'modified_after'),
      modified_before: resource.field(self._.blocks, 'modified_before'),
      order: resource.field(self._.blocks, 'order'),
      result: resource.field(self._.blocks, 'result'),
      target_ids: resource.field(self._.blocks, 'target_ids'),
      virtual_network_id: resource.field(self._.blocks, 'virtual_network_id'),
    },
    zero_trust_access_key_configuration(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_key_configuration', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'days_until_next_rotation') +
        attribute(block, 'id') +
        attribute(block, 'key_rotation_interval_days') +
        attribute(block, 'last_key_rotation_at')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      days_until_next_rotation: resource.field(self._.blocks, 'days_until_next_rotation'),
      id: resource.field(self._.blocks, 'id'),
      key_rotation_interval_days: resource.field(self._.blocks, 'key_rotation_interval_days'),
      last_key_rotation_at: resource.field(self._.blocks, 'last_key_rotation_at'),
    },
    zero_trust_access_mtls_certificate(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_mtls_certificate', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'associated_hostnames') +
        attribute(block, 'certificate_id', true) +
        attribute(block, 'expires_on') +
        attribute(block, 'fingerprint') +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      associated_hostnames: resource.field(self._.blocks, 'associated_hostnames'),
      certificate_id: resource.field(self._.blocks, 'certificate_id'),
      expires_on: resource.field(self._.blocks, 'expires_on'),
      fingerprint: resource.field(self._.blocks, 'fingerprint'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zero_trust_access_mtls_certificates(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_mtls_certificates', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zero_trust_access_mtls_hostname_settings(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_mtls_hostname_settings', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'china_network') +
        attribute(block, 'client_certificate_forwarding') +
        attribute(block, 'hostname') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      china_network: resource.field(self._.blocks, 'china_network'),
      client_certificate_forwarding: resource.field(self._.blocks, 'client_certificate_forwarding'),
      hostname: resource.field(self._.blocks, 'hostname'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zero_trust_access_policies(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_policies', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    zero_trust_access_policy(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_policy', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'app_count') +
        attribute(block, 'approval_groups') +
        attribute(block, 'approval_required') +
        attribute(block, 'connection_rules') +
        attribute(block, 'created_at') +
        attribute(block, 'decision') +
        attribute(block, 'exclude') +
        attribute(block, 'id') +
        attribute(block, 'include') +
        attribute(block, 'isolation_required') +
        attribute(block, 'mfa_config') +
        attribute(block, 'name') +
        attribute(block, 'policy_id', true) +
        attribute(block, 'purpose_justification_prompt') +
        attribute(block, 'purpose_justification_required') +
        attribute(block, 'require') +
        attribute(block, 'reusable') +
        attribute(block, 'session_duration') +
        attribute(block, 'updated_at')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      app_count: resource.field(self._.blocks, 'app_count'),
      approval_groups: resource.field(self._.blocks, 'approval_groups'),
      approval_required: resource.field(self._.blocks, 'approval_required'),
      connection_rules: resource.field(self._.blocks, 'connection_rules'),
      created_at: resource.field(self._.blocks, 'created_at'),
      decision: resource.field(self._.blocks, 'decision'),
      exclude: resource.field(self._.blocks, 'exclude'),
      id: resource.field(self._.blocks, 'id'),
      include: resource.field(self._.blocks, 'include'),
      isolation_required: resource.field(self._.blocks, 'isolation_required'),
      mfa_config: resource.field(self._.blocks, 'mfa_config'),
      name: resource.field(self._.blocks, 'name'),
      policy_id: resource.field(self._.blocks, 'policy_id'),
      purpose_justification_prompt: resource.field(self._.blocks, 'purpose_justification_prompt'),
      purpose_justification_required: resource.field(self._.blocks, 'purpose_justification_required'),
      require: resource.field(self._.blocks, 'require'),
      reusable: resource.field(self._.blocks, 'reusable'),
      session_duration: resource.field(self._.blocks, 'session_duration'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
    },
    zero_trust_access_service_token(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_service_token', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'client_id') +
        attribute(block, 'duration') +
        attribute(block, 'expires_at') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'service_token_id') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      client_id: resource.field(self._.blocks, 'client_id'),
      duration: resource.field(self._.blocks, 'duration'),
      expires_at: resource.field(self._.blocks, 'expires_at'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      service_token_id: resource.field(self._.blocks, 'service_token_id'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zero_trust_access_service_tokens(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_service_tokens', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'name') +
        attribute(block, 'result') +
        attribute(block, 'search') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      name: resource.field(self._.blocks, 'name'),
      result: resource.field(self._.blocks, 'result'),
      search: resource.field(self._.blocks, 'search'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zero_trust_access_short_lived_certificate(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_short_lived_certificate', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'app_id', true) +
        attribute(block, 'aud') +
        attribute(block, 'id') +
        attribute(block, 'public_key') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      app_id: resource.field(self._.blocks, 'app_id'),
      aud: resource.field(self._.blocks, 'aud'),
      id: resource.field(self._.blocks, 'id'),
      public_key: resource.field(self._.blocks, 'public_key'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zero_trust_access_short_lived_certificates(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_short_lived_certificates', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zero_trust_access_tag(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_tag', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'tag_name', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      tag_name: resource.field(self._.blocks, 'tag_name'),
    },
    zero_trust_access_tags(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_access_tags', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    zero_trust_device_custom_profile(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_device_custom_profile', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'allow_mode_switch') +
        attribute(block, 'allow_updates') +
        attribute(block, 'allowed_to_leave') +
        attribute(block, 'auto_connect') +
        attribute(block, 'captive_portal') +
        attribute(block, 'default') +
        attribute(block, 'description') +
        attribute(block, 'disable_auto_fallback') +
        attribute(block, 'enabled') +
        attribute(block, 'exclude') +
        attribute(block, 'exclude_office_ips') +
        attribute(block, 'fallback_domains') +
        attribute(block, 'gateway_unique_id') +
        attribute(block, 'id') +
        attribute(block, 'include') +
        attribute(block, 'lan_allow_minutes') +
        attribute(block, 'lan_allow_subnet_size') +
        attribute(block, 'match') +
        attribute(block, 'name') +
        attribute(block, 'policy_id', true) +
        attribute(block, 'precedence') +
        attribute(block, 'register_interface_ip_with_dns') +
        attribute(block, 'sccm_vpn_boundary_support') +
        attribute(block, 'service_mode_v2') +
        attribute(block, 'support_url') +
        attribute(block, 'switch_locked') +
        attribute(block, 'target_tests') +
        attribute(block, 'tunnel_protocol')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      allow_mode_switch: resource.field(self._.blocks, 'allow_mode_switch'),
      allow_updates: resource.field(self._.blocks, 'allow_updates'),
      allowed_to_leave: resource.field(self._.blocks, 'allowed_to_leave'),
      auto_connect: resource.field(self._.blocks, 'auto_connect'),
      captive_portal: resource.field(self._.blocks, 'captive_portal'),
      default: resource.field(self._.blocks, 'default'),
      description: resource.field(self._.blocks, 'description'),
      disable_auto_fallback: resource.field(self._.blocks, 'disable_auto_fallback'),
      enabled: resource.field(self._.blocks, 'enabled'),
      exclude: resource.field(self._.blocks, 'exclude'),
      exclude_office_ips: resource.field(self._.blocks, 'exclude_office_ips'),
      fallback_domains: resource.field(self._.blocks, 'fallback_domains'),
      gateway_unique_id: resource.field(self._.blocks, 'gateway_unique_id'),
      id: resource.field(self._.blocks, 'id'),
      include: resource.field(self._.blocks, 'include'),
      lan_allow_minutes: resource.field(self._.blocks, 'lan_allow_minutes'),
      lan_allow_subnet_size: resource.field(self._.blocks, 'lan_allow_subnet_size'),
      match: resource.field(self._.blocks, 'match'),
      name: resource.field(self._.blocks, 'name'),
      policy_id: resource.field(self._.blocks, 'policy_id'),
      precedence: resource.field(self._.blocks, 'precedence'),
      register_interface_ip_with_dns: resource.field(self._.blocks, 'register_interface_ip_with_dns'),
      sccm_vpn_boundary_support: resource.field(self._.blocks, 'sccm_vpn_boundary_support'),
      service_mode_v2: resource.field(self._.blocks, 'service_mode_v2'),
      support_url: resource.field(self._.blocks, 'support_url'),
      switch_locked: resource.field(self._.blocks, 'switch_locked'),
      target_tests: resource.field(self._.blocks, 'target_tests'),
      tunnel_protocol: resource.field(self._.blocks, 'tunnel_protocol'),
    },
    zero_trust_device_custom_profile_local_domain_fallback(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_device_custom_profile_local_domain_fallback', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'description') +
        attribute(block, 'dns_server') +
        attribute(block, 'id') +
        attribute(block, 'policy_id', true) +
        attribute(block, 'suffix')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      description: resource.field(self._.blocks, 'description'),
      dns_server: resource.field(self._.blocks, 'dns_server'),
      id: resource.field(self._.blocks, 'id'),
      policy_id: resource.field(self._.blocks, 'policy_id'),
      suffix: resource.field(self._.blocks, 'suffix'),
    },
    zero_trust_device_custom_profiles(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_device_custom_profiles', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    zero_trust_device_default_profile(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_device_default_profile', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'allow_mode_switch') +
        attribute(block, 'allow_updates') +
        attribute(block, 'allowed_to_leave') +
        attribute(block, 'auto_connect') +
        attribute(block, 'captive_portal') +
        attribute(block, 'default') +
        attribute(block, 'disable_auto_fallback') +
        attribute(block, 'enabled') +
        attribute(block, 'exclude') +
        attribute(block, 'exclude_office_ips') +
        attribute(block, 'fallback_domains') +
        attribute(block, 'gateway_unique_id') +
        attribute(block, 'id') +
        attribute(block, 'include') +
        attribute(block, 'policy_id') +
        attribute(block, 'register_interface_ip_with_dns') +
        attribute(block, 'sccm_vpn_boundary_support') +
        attribute(block, 'service_mode_v2') +
        attribute(block, 'support_url') +
        attribute(block, 'switch_locked') +
        attribute(block, 'tunnel_protocol')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      allow_mode_switch: resource.field(self._.blocks, 'allow_mode_switch'),
      allow_updates: resource.field(self._.blocks, 'allow_updates'),
      allowed_to_leave: resource.field(self._.blocks, 'allowed_to_leave'),
      auto_connect: resource.field(self._.blocks, 'auto_connect'),
      captive_portal: resource.field(self._.blocks, 'captive_portal'),
      default: resource.field(self._.blocks, 'default'),
      disable_auto_fallback: resource.field(self._.blocks, 'disable_auto_fallback'),
      enabled: resource.field(self._.blocks, 'enabled'),
      exclude: resource.field(self._.blocks, 'exclude'),
      exclude_office_ips: resource.field(self._.blocks, 'exclude_office_ips'),
      fallback_domains: resource.field(self._.blocks, 'fallback_domains'),
      gateway_unique_id: resource.field(self._.blocks, 'gateway_unique_id'),
      id: resource.field(self._.blocks, 'id'),
      include: resource.field(self._.blocks, 'include'),
      policy_id: resource.field(self._.blocks, 'policy_id'),
      register_interface_ip_with_dns: resource.field(self._.blocks, 'register_interface_ip_with_dns'),
      sccm_vpn_boundary_support: resource.field(self._.blocks, 'sccm_vpn_boundary_support'),
      service_mode_v2: resource.field(self._.blocks, 'service_mode_v2'),
      support_url: resource.field(self._.blocks, 'support_url'),
      switch_locked: resource.field(self._.blocks, 'switch_locked'),
      tunnel_protocol: resource.field(self._.blocks, 'tunnel_protocol'),
    },
    zero_trust_device_default_profile_certificates(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_device_default_profile_certificates', name),
      _: resource._(
        block,
        attribute(block, 'enabled') +
        attribute(block, 'zone_id')
      ),
      enabled: resource.field(self._.blocks, 'enabled'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zero_trust_device_default_profile_local_domain_fallback(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_device_default_profile_local_domain_fallback', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'description') +
        attribute(block, 'dns_server') +
        attribute(block, 'id') +
        attribute(block, 'suffix')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      description: resource.field(self._.blocks, 'description'),
      dns_server: resource.field(self._.blocks, 'dns_server'),
      id: resource.field(self._.blocks, 'id'),
      suffix: resource.field(self._.blocks, 'suffix'),
    },
    zero_trust_device_ip_profile(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_device_ip_profile', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_at') +
        attribute(block, 'description') +
        attribute(block, 'enabled') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'match') +
        attribute(block, 'name') +
        attribute(block, 'precedence') +
        attribute(block, 'profile_id') +
        attribute(block, 'subnet_id') +
        attribute(block, 'updated_at')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_at: resource.field(self._.blocks, 'created_at'),
      description: resource.field(self._.blocks, 'description'),
      enabled: resource.field(self._.blocks, 'enabled'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      match: resource.field(self._.blocks, 'match'),
      name: resource.field(self._.blocks, 'name'),
      precedence: resource.field(self._.blocks, 'precedence'),
      profile_id: resource.field(self._.blocks, 'profile_id'),
      subnet_id: resource.field(self._.blocks, 'subnet_id'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
    },
    zero_trust_device_ip_profiles(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_device_ip_profiles', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'per_page') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      per_page: resource.field(self._.blocks, 'per_page'),
      result: resource.field(self._.blocks, 'result'),
    },
    zero_trust_device_managed_networks(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_device_managed_networks', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'config') +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'network_id', true) +
        attribute(block, 'type')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      config: resource.field(self._.blocks, 'config'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      network_id: resource.field(self._.blocks, 'network_id'),
      type: resource.field(self._.blocks, 'type'),
    },
    zero_trust_device_managed_networks_list(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_device_managed_networks_list', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    zero_trust_device_posture_integration(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_device_posture_integration', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'config') +
        attribute(block, 'id') +
        attribute(block, 'integration_id', true) +
        attribute(block, 'interval') +
        attribute(block, 'name') +
        attribute(block, 'type')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      config: resource.field(self._.blocks, 'config'),
      id: resource.field(self._.blocks, 'id'),
      integration_id: resource.field(self._.blocks, 'integration_id'),
      interval: resource.field(self._.blocks, 'interval'),
      name: resource.field(self._.blocks, 'name'),
      type: resource.field(self._.blocks, 'type'),
    },
    zero_trust_device_posture_integrations(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_device_posture_integrations', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    zero_trust_device_posture_rule(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_device_posture_rule', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'description') +
        attribute(block, 'expiration') +
        attribute(block, 'id') +
        attribute(block, 'input') +
        attribute(block, 'match') +
        attribute(block, 'name') +
        attribute(block, 'rule_id', true) +
        attribute(block, 'schedule') +
        attribute(block, 'type')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      description: resource.field(self._.blocks, 'description'),
      expiration: resource.field(self._.blocks, 'expiration'),
      id: resource.field(self._.blocks, 'id'),
      input: resource.field(self._.blocks, 'input'),
      match: resource.field(self._.blocks, 'match'),
      name: resource.field(self._.blocks, 'name'),
      rule_id: resource.field(self._.blocks, 'rule_id'),
      schedule: resource.field(self._.blocks, 'schedule'),
      type: resource.field(self._.blocks, 'type'),
    },
    zero_trust_device_posture_rules(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_device_posture_rules', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    zero_trust_device_settings(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_device_settings', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'disable_for_time') +
        attribute(block, 'external_emergency_signal_enabled') +
        attribute(block, 'external_emergency_signal_fingerprint') +
        attribute(block, 'external_emergency_signal_interval') +
        attribute(block, 'external_emergency_signal_url') +
        attribute(block, 'gateway_proxy_enabled') +
        attribute(block, 'gateway_udp_proxy_enabled') +
        attribute(block, 'root_certificate_installation_enabled') +
        attribute(block, 'use_zt_virtual_ip')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      disable_for_time: resource.field(self._.blocks, 'disable_for_time'),
      external_emergency_signal_enabled: resource.field(self._.blocks, 'external_emergency_signal_enabled'),
      external_emergency_signal_fingerprint: resource.field(self._.blocks, 'external_emergency_signal_fingerprint'),
      external_emergency_signal_interval: resource.field(self._.blocks, 'external_emergency_signal_interval'),
      external_emergency_signal_url: resource.field(self._.blocks, 'external_emergency_signal_url'),
      gateway_proxy_enabled: resource.field(self._.blocks, 'gateway_proxy_enabled'),
      gateway_udp_proxy_enabled: resource.field(self._.blocks, 'gateway_udp_proxy_enabled'),
      root_certificate_installation_enabled: resource.field(self._.blocks, 'root_certificate_installation_enabled'),
      use_zt_virtual_ip: resource.field(self._.blocks, 'use_zt_virtual_ip'),
    },
    zero_trust_device_subnet(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_device_subnet', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'comment') +
        attribute(block, 'created_at') +
        attribute(block, 'deleted_at') +
        attribute(block, 'id') +
        attribute(block, 'is_default_network') +
        attribute(block, 'name') +
        attribute(block, 'network') +
        attribute(block, 'subnet_id', true) +
        attribute(block, 'subnet_type')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      comment: resource.field(self._.blocks, 'comment'),
      created_at: resource.field(self._.blocks, 'created_at'),
      deleted_at: resource.field(self._.blocks, 'deleted_at'),
      id: resource.field(self._.blocks, 'id'),
      is_default_network: resource.field(self._.blocks, 'is_default_network'),
      name: resource.field(self._.blocks, 'name'),
      network: resource.field(self._.blocks, 'network'),
      subnet_id: resource.field(self._.blocks, 'subnet_id'),
      subnet_type: resource.field(self._.blocks, 'subnet_type'),
    },
    zero_trust_dex_rule(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dex_rule', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_at') +
        attribute(block, 'description') +
        attribute(block, 'id') +
        attribute(block, 'match') +
        attribute(block, 'name') +
        attribute(block, 'rule_id', true) +
        attribute(block, 'targeted_tests') +
        attribute(block, 'updated_at')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_at: resource.field(self._.blocks, 'created_at'),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      match: resource.field(self._.blocks, 'match'),
      name: resource.field(self._.blocks, 'name'),
      rule_id: resource.field(self._.blocks, 'rule_id'),
      targeted_tests: resource.field(self._.blocks, 'targeted_tests'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
    },
    zero_trust_dex_rules(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dex_rules', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'name') +
        attribute(block, 'result') +
        attribute(block, 'sort_by') +
        attribute(block, 'sort_order')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      name: resource.field(self._.blocks, 'name'),
      result: resource.field(self._.blocks, 'result'),
      sort_by: resource.field(self._.blocks, 'sort_by'),
      sort_order: resource.field(self._.blocks, 'sort_order'),
    },
    zero_trust_dex_test(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dex_test', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'data') +
        attribute(block, 'description') +
        attribute(block, 'dex_test_id') +
        attribute(block, 'enabled') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'interval') +
        attribute(block, 'name') +
        attribute(block, 'target_policies') +
        attribute(block, 'targeted') +
        attribute(block, 'test_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      data: resource.field(self._.blocks, 'data'),
      description: resource.field(self._.blocks, 'description'),
      dex_test_id: resource.field(self._.blocks, 'dex_test_id'),
      enabled: resource.field(self._.blocks, 'enabled'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      interval: resource.field(self._.blocks, 'interval'),
      name: resource.field(self._.blocks, 'name'),
      target_policies: resource.field(self._.blocks, 'target_policies'),
      targeted: resource.field(self._.blocks, 'targeted'),
      test_id: resource.field(self._.blocks, 'test_id'),
    },
    zero_trust_dex_tests(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dex_tests', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'kind') +
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'test_name')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      kind: resource.field(self._.blocks, 'kind'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      test_name: resource.field(self._.blocks, 'test_name'),
    },
    zero_trust_dlp_custom_entries(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dlp_custom_entries', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    zero_trust_dlp_custom_entry(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dlp_custom_entry', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'case_sensitive') +
        attribute(block, 'confidence') +
        attribute(block, 'created_at') +
        attribute(block, 'description') +
        attribute(block, 'enabled') +
        attribute(block, 'entry_id', true) +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'pattern') +
        attribute(block, 'profile_id') +
        attribute(block, 'profiles') +
        attribute(block, 'secret') +
        attribute(block, 'type') +
        attribute(block, 'updated_at') +
        attribute(block, 'upload_status') +
        attribute(block, 'variant') +
        attribute(block, 'word_list')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      case_sensitive: resource.field(self._.blocks, 'case_sensitive'),
      confidence: resource.field(self._.blocks, 'confidence'),
      created_at: resource.field(self._.blocks, 'created_at'),
      description: resource.field(self._.blocks, 'description'),
      enabled: resource.field(self._.blocks, 'enabled'),
      entry_id: resource.field(self._.blocks, 'entry_id'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      pattern: resource.field(self._.blocks, 'pattern'),
      profile_id: resource.field(self._.blocks, 'profile_id'),
      profiles: resource.field(self._.blocks, 'profiles'),
      secret: resource.field(self._.blocks, 'secret'),
      type: resource.field(self._.blocks, 'type'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      upload_status: resource.field(self._.blocks, 'upload_status'),
      variant: resource.field(self._.blocks, 'variant'),
      word_list: resource.field(self._.blocks, 'word_list'),
    },
    zero_trust_dlp_custom_profile(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dlp_custom_profile', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'ai_context_enabled') +
        attribute(block, 'allowed_match_count') +
        attribute(block, 'confidence_threshold') +
        attribute(block, 'context_awareness') +
        attribute(block, 'created_at') +
        attribute(block, 'data_classes') +
        attribute(block, 'data_tags') +
        attribute(block, 'description') +
        attribute(block, 'entries') +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'ocr_enabled') +
        attribute(block, 'open_access') +
        attribute(block, 'profile_id', true) +
        attribute(block, 'sensitivity_levels') +
        attribute(block, 'shared_entries') +
        attribute(block, 'type') +
        attribute(block, 'updated_at')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      ai_context_enabled: resource.field(self._.blocks, 'ai_context_enabled'),
      allowed_match_count: resource.field(self._.blocks, 'allowed_match_count'),
      confidence_threshold: resource.field(self._.blocks, 'confidence_threshold'),
      context_awareness: resource.field(self._.blocks, 'context_awareness'),
      created_at: resource.field(self._.blocks, 'created_at'),
      data_classes: resource.field(self._.blocks, 'data_classes'),
      data_tags: resource.field(self._.blocks, 'data_tags'),
      description: resource.field(self._.blocks, 'description'),
      entries: resource.field(self._.blocks, 'entries'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      ocr_enabled: resource.field(self._.blocks, 'ocr_enabled'),
      open_access: resource.field(self._.blocks, 'open_access'),
      profile_id: resource.field(self._.blocks, 'profile_id'),
      sensitivity_levels: resource.field(self._.blocks, 'sensitivity_levels'),
      shared_entries: resource.field(self._.blocks, 'shared_entries'),
      type: resource.field(self._.blocks, 'type'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
    },
    zero_trust_dlp_dataset(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dlp_dataset', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'case_sensitive') +
        attribute(block, 'columns') +
        attribute(block, 'created_at') +
        attribute(block, 'dataset_id', true) +
        attribute(block, 'description') +
        attribute(block, 'encoding_version') +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'num_cells') +
        attribute(block, 'secret') +
        attribute(block, 'status') +
        attribute(block, 'updated_at') +
        attribute(block, 'uploads')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      case_sensitive: resource.field(self._.blocks, 'case_sensitive'),
      columns: resource.field(self._.blocks, 'columns'),
      created_at: resource.field(self._.blocks, 'created_at'),
      dataset_id: resource.field(self._.blocks, 'dataset_id'),
      description: resource.field(self._.blocks, 'description'),
      encoding_version: resource.field(self._.blocks, 'encoding_version'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      num_cells: resource.field(self._.blocks, 'num_cells'),
      secret: resource.field(self._.blocks, 'secret'),
      status: resource.field(self._.blocks, 'status'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      uploads: resource.field(self._.blocks, 'uploads'),
    },
    zero_trust_dlp_datasets(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dlp_datasets', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    zero_trust_dlp_entries(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dlp_entries', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    zero_trust_dlp_entry(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dlp_entry', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'case_sensitive') +
        attribute(block, 'confidence') +
        attribute(block, 'created_at') +
        attribute(block, 'description') +
        attribute(block, 'enabled') +
        attribute(block, 'entry_id', true) +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'pattern') +
        attribute(block, 'profile_id') +
        attribute(block, 'profiles') +
        attribute(block, 'secret') +
        attribute(block, 'type') +
        attribute(block, 'updated_at') +
        attribute(block, 'upload_status') +
        attribute(block, 'variant') +
        attribute(block, 'word_list')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      case_sensitive: resource.field(self._.blocks, 'case_sensitive'),
      confidence: resource.field(self._.blocks, 'confidence'),
      created_at: resource.field(self._.blocks, 'created_at'),
      description: resource.field(self._.blocks, 'description'),
      enabled: resource.field(self._.blocks, 'enabled'),
      entry_id: resource.field(self._.blocks, 'entry_id'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      pattern: resource.field(self._.blocks, 'pattern'),
      profile_id: resource.field(self._.blocks, 'profile_id'),
      profiles: resource.field(self._.blocks, 'profiles'),
      secret: resource.field(self._.blocks, 'secret'),
      type: resource.field(self._.blocks, 'type'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      upload_status: resource.field(self._.blocks, 'upload_status'),
      variant: resource.field(self._.blocks, 'variant'),
      word_list: resource.field(self._.blocks, 'word_list'),
    },
    zero_trust_dlp_integration_entries(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dlp_integration_entries', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    zero_trust_dlp_integration_entry(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dlp_integration_entry', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'case_sensitive') +
        attribute(block, 'confidence') +
        attribute(block, 'created_at') +
        attribute(block, 'description') +
        attribute(block, 'enabled') +
        attribute(block, 'entry_id', true) +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'pattern') +
        attribute(block, 'profile_id') +
        attribute(block, 'profiles') +
        attribute(block, 'secret') +
        attribute(block, 'type') +
        attribute(block, 'updated_at') +
        attribute(block, 'upload_status') +
        attribute(block, 'variant') +
        attribute(block, 'word_list')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      case_sensitive: resource.field(self._.blocks, 'case_sensitive'),
      confidence: resource.field(self._.blocks, 'confidence'),
      created_at: resource.field(self._.blocks, 'created_at'),
      description: resource.field(self._.blocks, 'description'),
      enabled: resource.field(self._.blocks, 'enabled'),
      entry_id: resource.field(self._.blocks, 'entry_id'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      pattern: resource.field(self._.blocks, 'pattern'),
      profile_id: resource.field(self._.blocks, 'profile_id'),
      profiles: resource.field(self._.blocks, 'profiles'),
      secret: resource.field(self._.blocks, 'secret'),
      type: resource.field(self._.blocks, 'type'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      upload_status: resource.field(self._.blocks, 'upload_status'),
      variant: resource.field(self._.blocks, 'variant'),
      word_list: resource.field(self._.blocks, 'word_list'),
    },
    zero_trust_dlp_predefined_entries(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dlp_predefined_entries', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    zero_trust_dlp_predefined_entry(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dlp_predefined_entry', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'case_sensitive') +
        attribute(block, 'confidence') +
        attribute(block, 'created_at') +
        attribute(block, 'description') +
        attribute(block, 'enabled') +
        attribute(block, 'entry_id', true) +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'pattern') +
        attribute(block, 'profile_id') +
        attribute(block, 'profiles') +
        attribute(block, 'secret') +
        attribute(block, 'type') +
        attribute(block, 'updated_at') +
        attribute(block, 'upload_status') +
        attribute(block, 'variant') +
        attribute(block, 'word_list')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      case_sensitive: resource.field(self._.blocks, 'case_sensitive'),
      confidence: resource.field(self._.blocks, 'confidence'),
      created_at: resource.field(self._.blocks, 'created_at'),
      description: resource.field(self._.blocks, 'description'),
      enabled: resource.field(self._.blocks, 'enabled'),
      entry_id: resource.field(self._.blocks, 'entry_id'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      pattern: resource.field(self._.blocks, 'pattern'),
      profile_id: resource.field(self._.blocks, 'profile_id'),
      profiles: resource.field(self._.blocks, 'profiles'),
      secret: resource.field(self._.blocks, 'secret'),
      type: resource.field(self._.blocks, 'type'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      upload_status: resource.field(self._.blocks, 'upload_status'),
      variant: resource.field(self._.blocks, 'variant'),
      word_list: resource.field(self._.blocks, 'word_list'),
    },
    zero_trust_dlp_predefined_profile(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dlp_predefined_profile', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'ai_context_enabled') +
        attribute(block, 'allowed_match_count') +
        attribute(block, 'confidence_threshold') +
        attribute(block, 'enabled_entries') +
        attribute(block, 'entries') +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'ocr_enabled') +
        attribute(block, 'open_access') +
        attribute(block, 'profile_id', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      ai_context_enabled: resource.field(self._.blocks, 'ai_context_enabled'),
      allowed_match_count: resource.field(self._.blocks, 'allowed_match_count'),
      confidence_threshold: resource.field(self._.blocks, 'confidence_threshold'),
      enabled_entries: resource.field(self._.blocks, 'enabled_entries'),
      entries: resource.field(self._.blocks, 'entries'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      ocr_enabled: resource.field(self._.blocks, 'ocr_enabled'),
      open_access: resource.field(self._.blocks, 'open_access'),
      profile_id: resource.field(self._.blocks, 'profile_id'),
    },
    zero_trust_dlp_settings(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dlp_settings', name),
      _: resource._(
        block,
        attribute(block, 'account_id', true) +
        attribute(block, 'ai_context_analysis') +
        attribute(block, 'id') +
        attribute(block, 'ocr') +
        attribute(block, 'payload_logging')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      ai_context_analysis: resource.field(self._.blocks, 'ai_context_analysis'),
      id: resource.field(self._.blocks, 'id'),
      ocr: resource.field(self._.blocks, 'ocr'),
      payload_logging: resource.field(self._.blocks, 'payload_logging'),
    },
    zero_trust_dns_location(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dns_location', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'client_default') +
        attribute(block, 'created_at') +
        attribute(block, 'dns_destination_ips_id') +
        attribute(block, 'dns_destination_ipv6_block_id') +
        attribute(block, 'doh_subdomain') +
        attribute(block, 'ecs_support') +
        attribute(block, 'endpoints') +
        attribute(block, 'id') +
        attribute(block, 'ip') +
        attribute(block, 'ipv4_destination') +
        attribute(block, 'ipv4_destination_backup') +
        attribute(block, 'location_id', true) +
        attribute(block, 'name') +
        attribute(block, 'networks') +
        attribute(block, 'updated_at')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      client_default: resource.field(self._.blocks, 'client_default'),
      created_at: resource.field(self._.blocks, 'created_at'),
      dns_destination_ips_id: resource.field(self._.blocks, 'dns_destination_ips_id'),
      dns_destination_ipv6_block_id: resource.field(self._.blocks, 'dns_destination_ipv6_block_id'),
      doh_subdomain: resource.field(self._.blocks, 'doh_subdomain'),
      ecs_support: resource.field(self._.blocks, 'ecs_support'),
      endpoints: resource.field(self._.blocks, 'endpoints'),
      id: resource.field(self._.blocks, 'id'),
      ip: resource.field(self._.blocks, 'ip'),
      ipv4_destination: resource.field(self._.blocks, 'ipv4_destination'),
      ipv4_destination_backup: resource.field(self._.blocks, 'ipv4_destination_backup'),
      location_id: resource.field(self._.blocks, 'location_id'),
      name: resource.field(self._.blocks, 'name'),
      networks: resource.field(self._.blocks, 'networks'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
    },
    zero_trust_dns_locations(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_dns_locations', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    zero_trust_gateway_app_types_list(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_gateway_app_types_list', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    zero_trust_gateway_categories_list(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_gateway_categories_list', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    zero_trust_gateway_certificate(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_gateway_certificate', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'binding_status') +
        attribute(block, 'certificate') +
        attribute(block, 'certificate_id', true) +
        attribute(block, 'created_at') +
        attribute(block, 'expires_on') +
        attribute(block, 'fingerprint') +
        attribute(block, 'id') +
        attribute(block, 'in_use') +
        attribute(block, 'issuer_org') +
        attribute(block, 'issuer_raw') +
        attribute(block, 'type') +
        attribute(block, 'updated_at') +
        attribute(block, 'uploaded_on')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      binding_status: resource.field(self._.blocks, 'binding_status'),
      certificate: resource.field(self._.blocks, 'certificate'),
      certificate_id: resource.field(self._.blocks, 'certificate_id'),
      created_at: resource.field(self._.blocks, 'created_at'),
      expires_on: resource.field(self._.blocks, 'expires_on'),
      fingerprint: resource.field(self._.blocks, 'fingerprint'),
      id: resource.field(self._.blocks, 'id'),
      in_use: resource.field(self._.blocks, 'in_use'),
      issuer_org: resource.field(self._.blocks, 'issuer_org'),
      issuer_raw: resource.field(self._.blocks, 'issuer_raw'),
      type: resource.field(self._.blocks, 'type'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      uploaded_on: resource.field(self._.blocks, 'uploaded_on'),
    },
    zero_trust_gateway_certificates(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_gateway_certificates', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    zero_trust_gateway_logging(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_gateway_logging', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'id') +
        attribute(block, 'redact_pii') +
        attribute(block, 'settings_by_rule_type')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      id: resource.field(self._.blocks, 'id'),
      redact_pii: resource.field(self._.blocks, 'redact_pii'),
      settings_by_rule_type: resource.field(self._.blocks, 'settings_by_rule_type'),
    },
    zero_trust_gateway_pacfile(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_gateway_pacfile', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'contents') +
        attribute(block, 'created_at') +
        attribute(block, 'description') +
        attribute(block, 'id') +
        attribute(block, 'name') +
        attribute(block, 'pacfile_id', true) +
        attribute(block, 'slug') +
        attribute(block, 'updated_at') +
        attribute(block, 'url')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      contents: resource.field(self._.blocks, 'contents'),
      created_at: resource.field(self._.blocks, 'created_at'),
      description: resource.field(self._.blocks, 'description'),
      id: resource.field(self._.blocks, 'id'),
      name: resource.field(self._.blocks, 'name'),
      pacfile_id: resource.field(self._.blocks, 'pacfile_id'),
      slug: resource.field(self._.blocks, 'slug'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      url: resource.field(self._.blocks, 'url'),
    },
    zero_trust_gateway_pacfiles(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_gateway_pacfiles', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    zero_trust_gateway_policies(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_gateway_policies', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    zero_trust_gateway_policy(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_gateway_policy', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'action') +
        attribute(block, 'created_at') +
        attribute(block, 'deleted_at') +
        attribute(block, 'description') +
        attribute(block, 'device_posture') +
        attribute(block, 'enabled') +
        attribute(block, 'expiration') +
        attribute(block, 'filters') +
        attribute(block, 'id') +
        attribute(block, 'identity') +
        attribute(block, 'name') +
        attribute(block, 'precedence') +
        attribute(block, 'read_only') +
        attribute(block, 'rule_id', true) +
        attribute(block, 'rule_settings') +
        attribute(block, 'schedule') +
        attribute(block, 'sharable') +
        attribute(block, 'source_account') +
        attribute(block, 'traffic') +
        attribute(block, 'updated_at') +
        attribute(block, 'version') +
        attribute(block, 'warning_status')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      action: resource.field(self._.blocks, 'action'),
      created_at: resource.field(self._.blocks, 'created_at'),
      deleted_at: resource.field(self._.blocks, 'deleted_at'),
      description: resource.field(self._.blocks, 'description'),
      device_posture: resource.field(self._.blocks, 'device_posture'),
      enabled: resource.field(self._.blocks, 'enabled'),
      expiration: resource.field(self._.blocks, 'expiration'),
      filters: resource.field(self._.blocks, 'filters'),
      id: resource.field(self._.blocks, 'id'),
      identity: resource.field(self._.blocks, 'identity'),
      name: resource.field(self._.blocks, 'name'),
      precedence: resource.field(self._.blocks, 'precedence'),
      read_only: resource.field(self._.blocks, 'read_only'),
      rule_id: resource.field(self._.blocks, 'rule_id'),
      rule_settings: resource.field(self._.blocks, 'rule_settings'),
      schedule: resource.field(self._.blocks, 'schedule'),
      sharable: resource.field(self._.blocks, 'sharable'),
      source_account: resource.field(self._.blocks, 'source_account'),
      traffic: resource.field(self._.blocks, 'traffic'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
      version: resource.field(self._.blocks, 'version'),
      warning_status: resource.field(self._.blocks, 'warning_status'),
    },
    zero_trust_gateway_proxy_endpoint(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_gateway_proxy_endpoint', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_at') +
        attribute(block, 'id') +
        attribute(block, 'ips') +
        attribute(block, 'kind') +
        attribute(block, 'name') +
        attribute(block, 'proxy_endpoint_id', true) +
        attribute(block, 'subdomain') +
        attribute(block, 'updated_at')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_at: resource.field(self._.blocks, 'created_at'),
      id: resource.field(self._.blocks, 'id'),
      ips: resource.field(self._.blocks, 'ips'),
      kind: resource.field(self._.blocks, 'kind'),
      name: resource.field(self._.blocks, 'name'),
      proxy_endpoint_id: resource.field(self._.blocks, 'proxy_endpoint_id'),
      subdomain: resource.field(self._.blocks, 'subdomain'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
    },
    zero_trust_gateway_proxy_endpoints(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_gateway_proxy_endpoints', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    zero_trust_gateway_settings(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_gateway_settings', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_at') +
        attribute(block, 'id') +
        attribute(block, 'settings') +
        attribute(block, 'updated_at')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_at: resource.field(self._.blocks, 'created_at'),
      id: resource.field(self._.blocks, 'id'),
      settings: resource.field(self._.blocks, 'settings'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
    },
    zero_trust_list(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_list', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'created_at') +
        attribute(block, 'description') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'items') +
        attribute(block, 'list_count') +
        attribute(block, 'list_id') +
        attribute(block, 'name') +
        attribute(block, 'type') +
        attribute(block, 'updated_at')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      created_at: resource.field(self._.blocks, 'created_at'),
      description: resource.field(self._.blocks, 'description'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      items: resource.field(self._.blocks, 'items'),
      list_count: resource.field(self._.blocks, 'list_count'),
      list_id: resource.field(self._.blocks, 'list_id'),
      name: resource.field(self._.blocks, 'name'),
      type: resource.field(self._.blocks, 'type'),
      updated_at: resource.field(self._.blocks, 'updated_at'),
    },
    zero_trust_lists(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_lists', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'type')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      type: resource.field(self._.blocks, 'type'),
    },
    zero_trust_network_hostname_route(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_network_hostname_route', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'comment') +
        attribute(block, 'created_at') +
        attribute(block, 'deleted_at') +
        attribute(block, 'filter') +
        attribute(block, 'hostname') +
        attribute(block, 'hostname_route_id') +
        attribute(block, 'id') +
        attribute(block, 'tunnel_id') +
        attribute(block, 'tunnel_name')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      comment: resource.field(self._.blocks, 'comment'),
      created_at: resource.field(self._.blocks, 'created_at'),
      deleted_at: resource.field(self._.blocks, 'deleted_at'),
      filter: resource.field(self._.blocks, 'filter'),
      hostname: resource.field(self._.blocks, 'hostname'),
      hostname_route_id: resource.field(self._.blocks, 'hostname_route_id'),
      id: resource.field(self._.blocks, 'id'),
      tunnel_id: resource.field(self._.blocks, 'tunnel_id'),
      tunnel_name: resource.field(self._.blocks, 'tunnel_name'),
    },
    zero_trust_network_hostname_routes(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_network_hostname_routes', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'comment') +
        attribute(block, 'existed_at') +
        attribute(block, 'hostname') +
        attribute(block, 'id') +
        attribute(block, 'is_deleted') +
        attribute(block, 'max_items') +
        attribute(block, 'result') +
        attribute(block, 'tunnel_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      comment: resource.field(self._.blocks, 'comment'),
      existed_at: resource.field(self._.blocks, 'existed_at'),
      hostname: resource.field(self._.blocks, 'hostname'),
      id: resource.field(self._.blocks, 'id'),
      is_deleted: resource.field(self._.blocks, 'is_deleted'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
      tunnel_id: resource.field(self._.blocks, 'tunnel_id'),
    },
    zero_trust_organization(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_organization', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'allow_authenticate_via_warp') +
        attribute(block, 'auth_domain') +
        attribute(block, 'auto_redirect_to_identity') +
        attribute(block, 'custom_pages') +
        attribute(block, 'deny_unmatched_requests') +
        attribute(block, 'deny_unmatched_requests_exempted_zone_names') +
        attribute(block, 'is_ui_read_only') +
        attribute(block, 'login_design') +
        attribute(block, 'mfa_config') +
        attribute(block, 'mfa_required_for_all_apps') +
        attribute(block, 'mfa_ssh_piv_key_requirements') +
        attribute(block, 'name') +
        attribute(block, 'session_duration') +
        attribute(block, 'ui_read_only_toggle_reason') +
        attribute(block, 'user_seat_expiration_inactive_time') +
        attribute(block, 'warp_auth_session_duration') +
        attribute(block, 'zone_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      allow_authenticate_via_warp: resource.field(self._.blocks, 'allow_authenticate_via_warp'),
      auth_domain: resource.field(self._.blocks, 'auth_domain'),
      auto_redirect_to_identity: resource.field(self._.blocks, 'auto_redirect_to_identity'),
      custom_pages: resource.field(self._.blocks, 'custom_pages'),
      deny_unmatched_requests: resource.field(self._.blocks, 'deny_unmatched_requests'),
      deny_unmatched_requests_exempted_zone_names: resource.field(self._.blocks, 'deny_unmatched_requests_exempted_zone_names'),
      is_ui_read_only: resource.field(self._.blocks, 'is_ui_read_only'),
      login_design: resource.field(self._.blocks, 'login_design'),
      mfa_config: resource.field(self._.blocks, 'mfa_config'),
      mfa_required_for_all_apps: resource.field(self._.blocks, 'mfa_required_for_all_apps'),
      mfa_ssh_piv_key_requirements: resource.field(self._.blocks, 'mfa_ssh_piv_key_requirements'),
      name: resource.field(self._.blocks, 'name'),
      session_duration: resource.field(self._.blocks, 'session_duration'),
      ui_read_only_toggle_reason: resource.field(self._.blocks, 'ui_read_only_toggle_reason'),
      user_seat_expiration_inactive_time: resource.field(self._.blocks, 'user_seat_expiration_inactive_time'),
      warp_auth_session_duration: resource.field(self._.blocks, 'warp_auth_session_duration'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zero_trust_risk_behavior(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_risk_behavior', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'behaviors')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      behaviors: resource.field(self._.blocks, 'behaviors'),
    },
    zero_trust_risk_scoring_integration(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_risk_scoring_integration', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'account_tag') +
        attribute(block, 'active') +
        attribute(block, 'created_at') +
        attribute(block, 'id') +
        attribute(block, 'integration_id', true) +
        attribute(block, 'integration_type') +
        attribute(block, 'reference_id') +
        attribute(block, 'tenant_url') +
        attribute(block, 'well_known_url')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      account_tag: resource.field(self._.blocks, 'account_tag'),
      active: resource.field(self._.blocks, 'active'),
      created_at: resource.field(self._.blocks, 'created_at'),
      id: resource.field(self._.blocks, 'id'),
      integration_id: resource.field(self._.blocks, 'integration_id'),
      integration_type: resource.field(self._.blocks, 'integration_type'),
      reference_id: resource.field(self._.blocks, 'reference_id'),
      tenant_url: resource.field(self._.blocks, 'tenant_url'),
      well_known_url: resource.field(self._.blocks, 'well_known_url'),
    },
    zero_trust_risk_scoring_integrations(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_risk_scoring_integrations', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'max_items') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      max_items: resource.field(self._.blocks, 'max_items'),
      result: resource.field(self._.blocks, 'result'),
    },
    zero_trust_tunnel_cloudflared(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_tunnel_cloudflared', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'account_tag') +
        attribute(block, 'config_src') +
        attribute(block, 'connections') +
        attribute(block, 'conns_active_at') +
        attribute(block, 'conns_inactive_at') +
        attribute(block, 'created_at') +
        attribute(block, 'deleted_at') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'metadata') +
        attribute(block, 'name') +
        attribute(block, 'remote_config') +
        attribute(block, 'status') +
        attribute(block, 'tun_type') +
        attribute(block, 'tunnel_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      account_tag: resource.field(self._.blocks, 'account_tag'),
      config_src: resource.field(self._.blocks, 'config_src'),
      connections: resource.field(self._.blocks, 'connections'),
      conns_active_at: resource.field(self._.blocks, 'conns_active_at'),
      conns_inactive_at: resource.field(self._.blocks, 'conns_inactive_at'),
      created_at: resource.field(self._.blocks, 'created_at'),
      deleted_at: resource.field(self._.blocks, 'deleted_at'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      metadata: resource.field(self._.blocks, 'metadata'),
      name: resource.field(self._.blocks, 'name'),
      remote_config: resource.field(self._.blocks, 'remote_config'),
      status: resource.field(self._.blocks, 'status'),
      tun_type: resource.field(self._.blocks, 'tun_type'),
      tunnel_id: resource.field(self._.blocks, 'tunnel_id'),
    },
    zero_trust_tunnel_cloudflared_config(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_tunnel_cloudflared_config', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'config') +
        attribute(block, 'created_at') +
        attribute(block, 'source') +
        attribute(block, 'tunnel_id', true) +
        attribute(block, 'version')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      config: resource.field(self._.blocks, 'config'),
      created_at: resource.field(self._.blocks, 'created_at'),
      source: resource.field(self._.blocks, 'source'),
      tunnel_id: resource.field(self._.blocks, 'tunnel_id'),
      version: resource.field(self._.blocks, 'version'),
    },
    zero_trust_tunnel_cloudflared_route(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_tunnel_cloudflared_route', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'comment') +
        attribute(block, 'created_at') +
        attribute(block, 'deleted_at') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'network') +
        attribute(block, 'route_id') +
        attribute(block, 'tunnel_id') +
        attribute(block, 'virtual_network_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      comment: resource.field(self._.blocks, 'comment'),
      created_at: resource.field(self._.blocks, 'created_at'),
      deleted_at: resource.field(self._.blocks, 'deleted_at'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      network: resource.field(self._.blocks, 'network'),
      route_id: resource.field(self._.blocks, 'route_id'),
      tunnel_id: resource.field(self._.blocks, 'tunnel_id'),
      virtual_network_id: resource.field(self._.blocks, 'virtual_network_id'),
    },
    zero_trust_tunnel_cloudflared_routes(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_tunnel_cloudflared_routes', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'comment') +
        attribute(block, 'existed_at') +
        attribute(block, 'is_deleted') +
        attribute(block, 'max_items') +
        attribute(block, 'network_subset') +
        attribute(block, 'network_superset') +
        attribute(block, 'result') +
        attribute(block, 'route_id') +
        attribute(block, 'tun_types') +
        attribute(block, 'tunnel_id') +
        attribute(block, 'virtual_network_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      comment: resource.field(self._.blocks, 'comment'),
      existed_at: resource.field(self._.blocks, 'existed_at'),
      is_deleted: resource.field(self._.blocks, 'is_deleted'),
      max_items: resource.field(self._.blocks, 'max_items'),
      network_subset: resource.field(self._.blocks, 'network_subset'),
      network_superset: resource.field(self._.blocks, 'network_superset'),
      result: resource.field(self._.blocks, 'result'),
      route_id: resource.field(self._.blocks, 'route_id'),
      tun_types: resource.field(self._.blocks, 'tun_types'),
      tunnel_id: resource.field(self._.blocks, 'tunnel_id'),
      virtual_network_id: resource.field(self._.blocks, 'virtual_network_id'),
    },
    zero_trust_tunnel_cloudflared_token(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_tunnel_cloudflared_token', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'token') +
        attribute(block, 'tunnel_id', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      token: resource.field(self._.blocks, 'token'),
      tunnel_id: resource.field(self._.blocks, 'tunnel_id'),
    },
    zero_trust_tunnel_cloudflared_virtual_network(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_tunnel_cloudflared_virtual_network', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'comment') +
        attribute(block, 'created_at') +
        attribute(block, 'deleted_at') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'is_default_network') +
        attribute(block, 'name') +
        attribute(block, 'virtual_network_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      comment: resource.field(self._.blocks, 'comment'),
      created_at: resource.field(self._.blocks, 'created_at'),
      deleted_at: resource.field(self._.blocks, 'deleted_at'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      is_default_network: resource.field(self._.blocks, 'is_default_network'),
      name: resource.field(self._.blocks, 'name'),
      virtual_network_id: resource.field(self._.blocks, 'virtual_network_id'),
    },
    zero_trust_tunnel_cloudflared_virtual_networks(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_tunnel_cloudflared_virtual_networks', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'id') +
        attribute(block, 'is_default') +
        attribute(block, 'is_default_network') +
        attribute(block, 'is_deleted') +
        attribute(block, 'max_items') +
        attribute(block, 'name') +
        attribute(block, 'result')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      id: resource.field(self._.blocks, 'id'),
      is_default: resource.field(self._.blocks, 'is_default'),
      is_default_network: resource.field(self._.blocks, 'is_default_network'),
      is_deleted: resource.field(self._.blocks, 'is_deleted'),
      max_items: resource.field(self._.blocks, 'max_items'),
      name: resource.field(self._.blocks, 'name'),
      result: resource.field(self._.blocks, 'result'),
    },
    zero_trust_tunnel_cloudflareds(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_tunnel_cloudflareds', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'exclude_prefix') +
        attribute(block, 'existed_at') +
        attribute(block, 'include_prefix') +
        attribute(block, 'is_deleted') +
        attribute(block, 'max_items') +
        attribute(block, 'name') +
        attribute(block, 'result') +
        attribute(block, 'status') +
        attribute(block, 'uuid') +
        attribute(block, 'was_active_at') +
        attribute(block, 'was_inactive_at')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      exclude_prefix: resource.field(self._.blocks, 'exclude_prefix'),
      existed_at: resource.field(self._.blocks, 'existed_at'),
      include_prefix: resource.field(self._.blocks, 'include_prefix'),
      is_deleted: resource.field(self._.blocks, 'is_deleted'),
      max_items: resource.field(self._.blocks, 'max_items'),
      name: resource.field(self._.blocks, 'name'),
      result: resource.field(self._.blocks, 'result'),
      status: resource.field(self._.blocks, 'status'),
      uuid: resource.field(self._.blocks, 'uuid'),
      was_active_at: resource.field(self._.blocks, 'was_active_at'),
      was_inactive_at: resource.field(self._.blocks, 'was_inactive_at'),
    },
    zero_trust_tunnel_warp_connector(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_tunnel_warp_connector', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'account_tag') +
        attribute(block, 'connections') +
        attribute(block, 'conns_active_at') +
        attribute(block, 'conns_inactive_at') +
        attribute(block, 'created_at') +
        attribute(block, 'deleted_at') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'metadata') +
        attribute(block, 'name') +
        attribute(block, 'status') +
        attribute(block, 'tun_type') +
        attribute(block, 'tunnel_id')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      account_tag: resource.field(self._.blocks, 'account_tag'),
      connections: resource.field(self._.blocks, 'connections'),
      conns_active_at: resource.field(self._.blocks, 'conns_active_at'),
      conns_inactive_at: resource.field(self._.blocks, 'conns_inactive_at'),
      created_at: resource.field(self._.blocks, 'created_at'),
      deleted_at: resource.field(self._.blocks, 'deleted_at'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      metadata: resource.field(self._.blocks, 'metadata'),
      name: resource.field(self._.blocks, 'name'),
      status: resource.field(self._.blocks, 'status'),
      tun_type: resource.field(self._.blocks, 'tun_type'),
      tunnel_id: resource.field(self._.blocks, 'tunnel_id'),
    },
    zero_trust_tunnel_warp_connector_token(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_tunnel_warp_connector_token', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'token') +
        attribute(block, 'tunnel_id', true)
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      token: resource.field(self._.blocks, 'token'),
      tunnel_id: resource.field(self._.blocks, 'tunnel_id'),
    },
    zero_trust_tunnel_warp_connectors(name, block): {
      local resource = blockType.resource('cloudflare_zero_trust_tunnel_warp_connectors', name),
      _: resource._(
        block,
        attribute(block, 'account_id') +
        attribute(block, 'exclude_prefix') +
        attribute(block, 'existed_at') +
        attribute(block, 'include_prefix') +
        attribute(block, 'is_deleted') +
        attribute(block, 'max_items') +
        attribute(block, 'name') +
        attribute(block, 'result') +
        attribute(block, 'status') +
        attribute(block, 'uuid') +
        attribute(block, 'was_active_at') +
        attribute(block, 'was_inactive_at')
      ),
      account_id: resource.field(self._.blocks, 'account_id'),
      exclude_prefix: resource.field(self._.blocks, 'exclude_prefix'),
      existed_at: resource.field(self._.blocks, 'existed_at'),
      include_prefix: resource.field(self._.blocks, 'include_prefix'),
      is_deleted: resource.field(self._.blocks, 'is_deleted'),
      max_items: resource.field(self._.blocks, 'max_items'),
      name: resource.field(self._.blocks, 'name'),
      result: resource.field(self._.blocks, 'result'),
      status: resource.field(self._.blocks, 'status'),
      uuid: resource.field(self._.blocks, 'uuid'),
      was_active_at: resource.field(self._.blocks, 'was_active_at'),
      was_inactive_at: resource.field(self._.blocks, 'was_inactive_at'),
    },
    zone(name, block): {
      local resource = blockType.resource('cloudflare_zone', name),
      _: resource._(
        block,
        attribute(block, 'account') +
        attribute(block, 'activated_on') +
        attribute(block, 'cname_suffix') +
        attribute(block, 'created_on') +
        attribute(block, 'development_mode') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'meta') +
        attribute(block, 'modified_on') +
        attribute(block, 'name') +
        attribute(block, 'name_servers') +
        attribute(block, 'original_dnshost') +
        attribute(block, 'original_name_servers') +
        attribute(block, 'original_registrar') +
        attribute(block, 'owner') +
        attribute(block, 'paused') +
        attribute(block, 'permissions') +
        attribute(block, 'plan') +
        attribute(block, 'status') +
        attribute(block, 'tenant') +
        attribute(block, 'tenant_unit') +
        attribute(block, 'type') +
        attribute(block, 'vanity_name_servers') +
        attribute(block, 'verification_key') +
        attribute(block, 'zone_id')
      ),
      account: resource.field(self._.blocks, 'account'),
      activated_on: resource.field(self._.blocks, 'activated_on'),
      cname_suffix: resource.field(self._.blocks, 'cname_suffix'),
      created_on: resource.field(self._.blocks, 'created_on'),
      development_mode: resource.field(self._.blocks, 'development_mode'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      meta: resource.field(self._.blocks, 'meta'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      name: resource.field(self._.blocks, 'name'),
      name_servers: resource.field(self._.blocks, 'name_servers'),
      original_dnshost: resource.field(self._.blocks, 'original_dnshost'),
      original_name_servers: resource.field(self._.blocks, 'original_name_servers'),
      original_registrar: resource.field(self._.blocks, 'original_registrar'),
      owner: resource.field(self._.blocks, 'owner'),
      paused: resource.field(self._.blocks, 'paused'),
      permissions: resource.field(self._.blocks, 'permissions'),
      plan: resource.field(self._.blocks, 'plan'),
      status: resource.field(self._.blocks, 'status'),
      tenant: resource.field(self._.blocks, 'tenant'),
      tenant_unit: resource.field(self._.blocks, 'tenant_unit'),
      type: resource.field(self._.blocks, 'type'),
      vanity_name_servers: resource.field(self._.blocks, 'vanity_name_servers'),
      verification_key: resource.field(self._.blocks, 'verification_key'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zone_cache_reserve(name, block): {
      local resource = blockType.resource('cloudflare_zone_cache_reserve', name),
      _: resource._(
        block,
        attribute(block, 'editable') +
        attribute(block, 'id') +
        attribute(block, 'modified_on') +
        attribute(block, 'value') +
        attribute(block, 'zone_id')
      ),
      editable: resource.field(self._.blocks, 'editable'),
      id: resource.field(self._.blocks, 'id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      value: resource.field(self._.blocks, 'value'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zone_cache_variants(name, block): {
      local resource = blockType.resource('cloudflare_zone_cache_variants', name),
      _: resource._(
        block,
        attribute(block, 'editable') +
        attribute(block, 'id') +
        attribute(block, 'modified_on') +
        attribute(block, 'value') +
        attribute(block, 'zone_id')
      ),
      editable: resource.field(self._.blocks, 'editable'),
      id: resource.field(self._.blocks, 'id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      value: resource.field(self._.blocks, 'value'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zone_dns_settings(name, block): {
      local resource = blockType.resource('cloudflare_zone_dns_settings', name),
      _: resource._(
        block,
        attribute(block, 'flatten_all_cnames') +
        attribute(block, 'foundation_dns') +
        attribute(block, 'internal_dns') +
        attribute(block, 'multi_provider') +
        attribute(block, 'nameservers') +
        attribute(block, 'ns_ttl') +
        attribute(block, 'secondary_overrides') +
        attribute(block, 'soa') +
        attribute(block, 'zone_id') +
        attribute(block, 'zone_mode')
      ),
      flatten_all_cnames: resource.field(self._.blocks, 'flatten_all_cnames'),
      foundation_dns: resource.field(self._.blocks, 'foundation_dns'),
      internal_dns: resource.field(self._.blocks, 'internal_dns'),
      multi_provider: resource.field(self._.blocks, 'multi_provider'),
      nameservers: resource.field(self._.blocks, 'nameservers'),
      ns_ttl: resource.field(self._.blocks, 'ns_ttl'),
      secondary_overrides: resource.field(self._.blocks, 'secondary_overrides'),
      soa: resource.field(self._.blocks, 'soa'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
      zone_mode: resource.field(self._.blocks, 'zone_mode'),
    },
    zone_dnssec(name, block): {
      local resource = blockType.resource('cloudflare_zone_dnssec', name),
      _: resource._(
        block,
        attribute(block, 'algorithm') +
        attribute(block, 'digest') +
        attribute(block, 'digest_algorithm') +
        attribute(block, 'digest_type') +
        attribute(block, 'dnssec_multi_signer') +
        attribute(block, 'dnssec_presigned') +
        attribute(block, 'dnssec_use_nsec3') +
        attribute(block, 'ds') +
        attribute(block, 'flags') +
        attribute(block, 'id') +
        attribute(block, 'key_tag') +
        attribute(block, 'key_type') +
        attribute(block, 'modified_on') +
        attribute(block, 'public_key') +
        attribute(block, 'status') +
        attribute(block, 'zone_id')
      ),
      algorithm: resource.field(self._.blocks, 'algorithm'),
      digest: resource.field(self._.blocks, 'digest'),
      digest_algorithm: resource.field(self._.blocks, 'digest_algorithm'),
      digest_type: resource.field(self._.blocks, 'digest_type'),
      dnssec_multi_signer: resource.field(self._.blocks, 'dnssec_multi_signer'),
      dnssec_presigned: resource.field(self._.blocks, 'dnssec_presigned'),
      dnssec_use_nsec3: resource.field(self._.blocks, 'dnssec_use_nsec3'),
      ds: resource.field(self._.blocks, 'ds'),
      flags: resource.field(self._.blocks, 'flags'),
      id: resource.field(self._.blocks, 'id'),
      key_tag: resource.field(self._.blocks, 'key_tag'),
      key_type: resource.field(self._.blocks, 'key_type'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      public_key: resource.field(self._.blocks, 'public_key'),
      status: resource.field(self._.blocks, 'status'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zone_hold(name, block): {
      local resource = blockType.resource('cloudflare_zone_hold', name),
      _: resource._(
        block,
        attribute(block, 'hold') +
        attribute(block, 'hold_after') +
        attribute(block, 'id') +
        attribute(block, 'include_subdomains') +
        attribute(block, 'zone_id')
      ),
      hold: resource.field(self._.blocks, 'hold'),
      hold_after: resource.field(self._.blocks, 'hold_after'),
      id: resource.field(self._.blocks, 'id'),
      include_subdomains: resource.field(self._.blocks, 'include_subdomains'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zone_lockdown(name, block): {
      local resource = blockType.resource('cloudflare_zone_lockdown', name),
      _: resource._(
        block,
        attribute(block, 'configurations') +
        attribute(block, 'created_on') +
        attribute(block, 'description') +
        attribute(block, 'filter') +
        attribute(block, 'id') +
        attribute(block, 'lock_downs_id') +
        attribute(block, 'modified_on') +
        attribute(block, 'paused') +
        attribute(block, 'urls') +
        attribute(block, 'zone_id')
      ),
      configurations: resource.field(self._.blocks, 'configurations'),
      created_on: resource.field(self._.blocks, 'created_on'),
      description: resource.field(self._.blocks, 'description'),
      filter: resource.field(self._.blocks, 'filter'),
      id: resource.field(self._.blocks, 'id'),
      lock_downs_id: resource.field(self._.blocks, 'lock_downs_id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      paused: resource.field(self._.blocks, 'paused'),
      urls: resource.field(self._.blocks, 'urls'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zone_lockdowns(name, block): {
      local resource = blockType.resource('cloudflare_zone_lockdowns', name),
      _: resource._(
        block,
        attribute(block, 'created_on') +
        attribute(block, 'description') +
        attribute(block, 'description_search') +
        attribute(block, 'ip') +
        attribute(block, 'ip_range_search') +
        attribute(block, 'ip_search') +
        attribute(block, 'max_items') +
        attribute(block, 'modified_on') +
        attribute(block, 'priority') +
        attribute(block, 'result') +
        attribute(block, 'uri_search') +
        attribute(block, 'zone_id')
      ),
      created_on: resource.field(self._.blocks, 'created_on'),
      description: resource.field(self._.blocks, 'description'),
      description_search: resource.field(self._.blocks, 'description_search'),
      ip: resource.field(self._.blocks, 'ip'),
      ip_range_search: resource.field(self._.blocks, 'ip_range_search'),
      ip_search: resource.field(self._.blocks, 'ip_search'),
      max_items: resource.field(self._.blocks, 'max_items'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      priority: resource.field(self._.blocks, 'priority'),
      result: resource.field(self._.blocks, 'result'),
      uri_search: resource.field(self._.blocks, 'uri_search'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zone_setting(name, block): {
      local resource = blockType.resource('cloudflare_zone_setting', name),
      _: resource._(
        block,
        attribute(block, 'editable') +
        attribute(block, 'enabled') +
        attribute(block, 'id') +
        attribute(block, 'modified_on') +
        attribute(block, 'setting_id', true) +
        attribute(block, 'time_remaining') +
        attribute(block, 'value') +
        attribute(block, 'zone_id')
      ),
      editable: resource.field(self._.blocks, 'editable'),
      enabled: resource.field(self._.blocks, 'enabled'),
      id: resource.field(self._.blocks, 'id'),
      modified_on: resource.field(self._.blocks, 'modified_on'),
      setting_id: resource.field(self._.blocks, 'setting_id'),
      time_remaining: resource.field(self._.blocks, 'time_remaining'),
      value: resource.field(self._.blocks, 'value'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zone_subscription(name, block): {
      local resource = blockType.resource('cloudflare_zone_subscription', name),
      _: resource._(
        block,
        attribute(block, 'currency') +
        attribute(block, 'current_period_end') +
        attribute(block, 'current_period_start') +
        attribute(block, 'frequency') +
        attribute(block, 'id') +
        attribute(block, 'price') +
        attribute(block, 'rate_plan') +
        attribute(block, 'state') +
        attribute(block, 'zone_id')
      ),
      currency: resource.field(self._.blocks, 'currency'),
      current_period_end: resource.field(self._.blocks, 'current_period_end'),
      current_period_start: resource.field(self._.blocks, 'current_period_start'),
      frequency: resource.field(self._.blocks, 'frequency'),
      id: resource.field(self._.blocks, 'id'),
      price: resource.field(self._.blocks, 'price'),
      rate_plan: resource.field(self._.blocks, 'rate_plan'),
      state: resource.field(self._.blocks, 'state'),
      zone_id: resource.field(self._.blocks, 'zone_id'),
    },
    zones(name, block): {
      local resource = blockType.resource('cloudflare_zones', name),
      _: resource._(
        block,
        attribute(block, 'account') +
        attribute(block, 'direction') +
        attribute(block, 'match') +
        attribute(block, 'max_items') +
        attribute(block, 'name') +
        attribute(block, 'order') +
        attribute(block, 'result') +
        attribute(block, 'status')
      ),
      account: resource.field(self._.blocks, 'account'),
      direction: resource.field(self._.blocks, 'direction'),
      match: resource.field(self._.blocks, 'match'),
      max_items: resource.field(self._.blocks, 'max_items'),
      name: resource.field(self._.blocks, 'name'),
      order: resource.field(self._.blocks, 'order'),
      result: resource.field(self._.blocks, 'result'),
      status: resource.field(self._.blocks, 'status'),
    },
  },
};
local providerWithConfiguration = provider(null, null) + {
  withConfiguration(alias, block): provider(block, {
    alias: alias,
    api_key: build.template(std.get(block, 'api_key', null)),
    api_token: build.template(std.get(block, 'api_token', null)),
    api_user_service_key: build.template(std.get(block, 'api_user_service_key', null)),
    base_url: build.template(std.get(block, 'base_url', null)),
    email: build.template(std.get(block, 'email', null)),
    user_agent_operator_suffix: build.template(std.get(block, 'user_agent_operator_suffix', null)),
  }),
};
providerWithConfiguration
