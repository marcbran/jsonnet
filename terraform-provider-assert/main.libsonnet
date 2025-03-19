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

local providerTemplate(provider, requirements, configuration) = {
  local providerRequirements = { ['terraform.required_providers.%s' % [provider]]: requirements },
  local providerAlias = if configuration == null then null else configuration.alias,
  local providerRef = if configuration == null then null else '%s.%s' % [provider, providerAlias],
  local providerConfiguration = if configuration == null then {} else { [providerRef]: { provider: { [provider]: configuration } } },
  local providerRefBlock = if configuration == null then {} else { provider: providerRef },
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
              [name]: std.prune(metaBlock + block + providerRefBlock),
            },
          },
        },
        blocks: build.blocks(rawBlock) + providerRequirements + providerConfiguration + {
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
      blocks: build.blocks(parameters) + providerRequirements + providerConfiguration,
    },
  },
};

local provider(configuration) = {
  local requirements = {
    source: 'registry.terraform.io/hashicorp/assert',
    version: '0.15.0',
  },
  local provider = providerTemplate('assert', requirements, configuration),
  func: {
    between(begin, end, number): provider.func('between', [begin, end, number]),
    cidr(prefix): provider.func('cidr', [prefix]),
    cidrv4(prefix): provider.func('cidrv4', [prefix]),
    cidrv6(prefix): provider.func('cidrv6', [prefix]),
    contains(list, element): provider.func('contains', [list, element]),
    empty(s): provider.func('empty', [s]),
    ends_with(suffix, string): provider.func('ends_with', [suffix, string]),
    equal(compare_against, number): provider.func('equal', [compare_against, number]),
    expired(timestamp): provider.func('expired', [timestamp]),
    'false'(bool): provider.func('false', [bool]),
    greater(compare_against, number): provider.func('greater', [compare_against, number]),
    greater_or_equal(compare_against, number): provider.func('greater_or_equal', [compare_against, number]),
    http_client_error(status_code): provider.func('http_client_error', [status_code]),
    http_redirect(status_code): provider.func('http_redirect', [status_code]),
    http_server_error(status_code): provider.func('http_server_error', [status_code]),
    http_success(status_code): provider.func('http_success', [status_code]),
    ip(ip_address): provider.func('ip', [ip_address]),
    ipv4(ip_address): provider.func('ipv4', [ip_address]),
    ipv6(ip_address): provider.func('ipv6', [ip_address]),
    key(key, map): provider.func('key', [key, map]),
    less(compare_against, number): provider.func('less', [compare_against, number]),
    less_or_equal(compare_against, number): provider.func('less_or_equal', [compare_against, number]),
    lowercased(string): provider.func('lowercased', [string]),
    negative(number): provider.func('negative', [number]),
    not_empty(s): provider.func('not_empty', [s]),
    not_equal(compare_against, number): provider.func('not_equal', [compare_against, number]),
    not_null(argument): provider.func('not_null', [argument]),
    'null'(argument): provider.func('null', [argument]),
    positive(number): provider.func('positive', [number]),
    regex(pattern, s): provider.func('regex', [pattern, s]),
    starts_with(prefix, string): provider.func('starts_with', [prefix, string]),
    'true'(bool): provider.func('true', [bool]),
    uppercased(string): provider.func('uppercased', [string]),
    valid_json(json): provider.func('valid_json', [json]),
    valid_yaml(yaml): provider.func('valid_yaml', [yaml]),
    value(value, map): provider.func('value', [value, map]),
  },
};

local providerWithConfiguration = provider(null) + {
  withConfiguration(alias, block): provider(std.prune({
    alias: alias,
  })),
};

providerWithConfiguration
