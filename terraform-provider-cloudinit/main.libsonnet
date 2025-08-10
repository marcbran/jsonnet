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
    source: 'registry.terraform.io/hashicorp/cloudinit',
    version: '2.3.7',
  },
  local provider = providerTemplate('cloudinit', requirements, rawConfiguration, configuration),
  resource: {
    local blockType = provider.blockType('resource'),
    config(name, block): {
      local resource = blockType.resource('cloudinit_config', name),
      _: resource._(block, {
        base64_encode: build.template(std.get(block, 'base64_encode', null)),
        boundary: build.template(std.get(block, 'boundary', null)),
        gzip: build.template(std.get(block, 'gzip', null)),
        id: build.template(std.get(block, 'id', null)),
        rendered: build.template(std.get(block, 'rendered', null)),
      }),
      base64_encode: resource.field(self._.blocks, 'base64_encode'),
      boundary: resource.field(self._.blocks, 'boundary'),
      gzip: resource.field(self._.blocks, 'gzip'),
      id: resource.field(self._.blocks, 'id'),
      rendered: resource.field(self._.blocks, 'rendered'),
    },
  },
  data: {
    local blockType = provider.blockType('data'),
    config(name, block): {
      local resource = blockType.resource('cloudinit_config', name),
      _: resource._(block, {
        base64_encode: build.template(std.get(block, 'base64_encode', null)),
        boundary: build.template(std.get(block, 'boundary', null)),
        gzip: build.template(std.get(block, 'gzip', null)),
        id: build.template(std.get(block, 'id', null)),
        rendered: build.template(std.get(block, 'rendered', null)),
      }),
      base64_encode: resource.field(self._.blocks, 'base64_encode'),
      boundary: resource.field(self._.blocks, 'boundary'),
      gzip: resource.field(self._.blocks, 'gzip'),
      id: resource.field(self._.blocks, 'id'),
      rendered: resource.field(self._.blocks, 'rendered'),
    },
  },
};
local providerWithConfiguration = provider(null, null) + {
  withConfiguration(alias, block): provider(block, {
    alias: alias,
  }),
};
providerWithConfiguration
