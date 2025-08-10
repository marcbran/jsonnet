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
              [name]: std.prune(providerConfiguration._.refBlock + metaBlock + block),
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
local provider(rawConfiguration, configuration) = {
  local requirements = {
    source: 'registry.terraform.io/hashicorp/assert',
    version: '0.16.0',
  },
  local provider = providerTemplate('assert', requirements, rawConfiguration, configuration),
  Function: {
    between(begin, end, number): provider.Function('between', [begin, end, number]),
    cidr(prefix): provider.Function('cidr', [prefix]),
    cidrv4(prefix): provider.Function('cidrv4', [prefix]),
    cidrv6(prefix): provider.Function('cidrv6', [prefix]),
    contains(list, element): provider.Function('contains', [list, element]),
    empty(s): provider.Function('empty', [s]),
    ends_with(suffix, string): provider.Function('ends_with', [suffix, string]),
    equal(compare_against, number): provider.Function('equal', [compare_against, number]),
    expired(timestamp): provider.Function('expired', [timestamp]),
    'false'(bool): provider.Function('false', [bool]),
    greater(compare_against, number): provider.Function('greater', [compare_against, number]),
    greater_or_equal(compare_against, number): provider.Function('greater_or_equal', [compare_against, number]),
    http_client_error(status_code): provider.Function('http_client_error', [status_code]),
    http_redirect(status_code): provider.Function('http_redirect', [status_code]),
    http_server_error(status_code): provider.Function('http_server_error', [status_code]),
    http_success(status_code): provider.Function('http_success', [status_code]),
    ip(ip_address): provider.Function('ip', [ip_address]),
    ipv4(ip_address): provider.Function('ipv4', [ip_address]),
    ipv6(ip_address): provider.Function('ipv6', [ip_address]),
    key(key, map): provider.Function('key', [key, map]),
    less(compare_against, number): provider.Function('less', [compare_against, number]),
    less_or_equal(compare_against, number): provider.Function('less_or_equal', [compare_against, number]),
    lowercased(string): provider.Function('lowercased', [string]),
    negative(number): provider.Function('negative', [number]),
    not_empty(s): provider.Function('not_empty', [s]),
    not_equal(compare_against, number): provider.Function('not_equal', [compare_against, number]),
    not_null(argument): provider.Function('not_null', [argument]),
    'null'(argument): provider.Function('null', [argument]),
    positive(number): provider.Function('positive', [number]),
    regex(pattern, s): provider.Function('regex', [pattern, s]),
    starts_with(prefix, string): provider.Function('starts_with', [prefix, string]),
    'true'(bool): provider.Function('true', [bool]),
    uppercased(string): provider.Function('uppercased', [string]),
    valid_json(json): provider.Function('valid_json', [json]),
    valid_yaml(yaml): provider.Function('valid_yaml', [yaml]),
    value(value, map): provider.Function('value', [value, map]),
  },
};
local providerWithConfiguration = provider(null, null) + {
  withConfiguration(alias, block): provider(block, {
    alias: alias,
  }),
};
providerWithConfiguration
