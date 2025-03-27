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
    source: 'registry.terraform.io/hashicorp/time',
    version: '0.13.0',
  },
  local provider = providerTemplate('time', requirements, rawConfiguration, configuration),
  resource: {
    local blockType = provider.blockType('resource'),
    offset(name, block): {
      local resource = blockType.resource('time_offset', name),
      _: resource._(block, {
        base_rfc3339: build.template(std.get(block, 'base_rfc3339', null)),
        day: build.template(std.get(block, 'day', null)),
        hour: build.template(std.get(block, 'hour', null)),
        id: build.template(std.get(block, 'id', null)),
        minute: build.template(std.get(block, 'minute', null)),
        month: build.template(std.get(block, 'month', null)),
        offset_days: build.template(std.get(block, 'offset_days', null)),
        offset_hours: build.template(std.get(block, 'offset_hours', null)),
        offset_minutes: build.template(std.get(block, 'offset_minutes', null)),
        offset_months: build.template(std.get(block, 'offset_months', null)),
        offset_seconds: build.template(std.get(block, 'offset_seconds', null)),
        offset_years: build.template(std.get(block, 'offset_years', null)),
        rfc3339: build.template(std.get(block, 'rfc3339', null)),
        second: build.template(std.get(block, 'second', null)),
        triggers: build.template(std.get(block, 'triggers', null)),
        unix: build.template(std.get(block, 'unix', null)),
        year: build.template(std.get(block, 'year', null)),
      }),
      base_rfc3339: resource.field(self._.blocks, 'base_rfc3339'),
      day: resource.field(self._.blocks, 'day'),
      hour: resource.field(self._.blocks, 'hour'),
      id: resource.field(self._.blocks, 'id'),
      minute: resource.field(self._.blocks, 'minute'),
      month: resource.field(self._.blocks, 'month'),
      offset_days: resource.field(self._.blocks, 'offset_days'),
      offset_hours: resource.field(self._.blocks, 'offset_hours'),
      offset_minutes: resource.field(self._.blocks, 'offset_minutes'),
      offset_months: resource.field(self._.blocks, 'offset_months'),
      offset_seconds: resource.field(self._.blocks, 'offset_seconds'),
      offset_years: resource.field(self._.blocks, 'offset_years'),
      rfc3339: resource.field(self._.blocks, 'rfc3339'),
      second: resource.field(self._.blocks, 'second'),
      triggers: resource.field(self._.blocks, 'triggers'),
      unix: resource.field(self._.blocks, 'unix'),
      year: resource.field(self._.blocks, 'year'),
    },
    rotating(name, block): {
      local resource = blockType.resource('time_rotating', name),
      _: resource._(block, {
        day: build.template(std.get(block, 'day', null)),
        hour: build.template(std.get(block, 'hour', null)),
        id: build.template(std.get(block, 'id', null)),
        minute: build.template(std.get(block, 'minute', null)),
        month: build.template(std.get(block, 'month', null)),
        rfc3339: build.template(std.get(block, 'rfc3339', null)),
        rotation_days: build.template(std.get(block, 'rotation_days', null)),
        rotation_hours: build.template(std.get(block, 'rotation_hours', null)),
        rotation_minutes: build.template(std.get(block, 'rotation_minutes', null)),
        rotation_months: build.template(std.get(block, 'rotation_months', null)),
        rotation_rfc3339: build.template(std.get(block, 'rotation_rfc3339', null)),
        rotation_years: build.template(std.get(block, 'rotation_years', null)),
        second: build.template(std.get(block, 'second', null)),
        triggers: build.template(std.get(block, 'triggers', null)),
        unix: build.template(std.get(block, 'unix', null)),
        year: build.template(std.get(block, 'year', null)),
      }),
      day: resource.field(self._.blocks, 'day'),
      hour: resource.field(self._.blocks, 'hour'),
      id: resource.field(self._.blocks, 'id'),
      minute: resource.field(self._.blocks, 'minute'),
      month: resource.field(self._.blocks, 'month'),
      rfc3339: resource.field(self._.blocks, 'rfc3339'),
      rotation_days: resource.field(self._.blocks, 'rotation_days'),
      rotation_hours: resource.field(self._.blocks, 'rotation_hours'),
      rotation_minutes: resource.field(self._.blocks, 'rotation_minutes'),
      rotation_months: resource.field(self._.blocks, 'rotation_months'),
      rotation_rfc3339: resource.field(self._.blocks, 'rotation_rfc3339'),
      rotation_years: resource.field(self._.blocks, 'rotation_years'),
      second: resource.field(self._.blocks, 'second'),
      triggers: resource.field(self._.blocks, 'triggers'),
      unix: resource.field(self._.blocks, 'unix'),
      year: resource.field(self._.blocks, 'year'),
    },
    sleep(name, block): {
      local resource = blockType.resource('time_sleep', name),
      _: resource._(block, {
        create_duration: build.template(std.get(block, 'create_duration', null)),
        destroy_duration: build.template(std.get(block, 'destroy_duration', null)),
        id: build.template(std.get(block, 'id', null)),
        triggers: build.template(std.get(block, 'triggers', null)),
      }),
      create_duration: resource.field(self._.blocks, 'create_duration'),
      destroy_duration: resource.field(self._.blocks, 'destroy_duration'),
      id: resource.field(self._.blocks, 'id'),
      triggers: resource.field(self._.blocks, 'triggers'),
    },
    static(name, block): {
      local resource = blockType.resource('time_static', name),
      _: resource._(block, {
        day: build.template(std.get(block, 'day', null)),
        hour: build.template(std.get(block, 'hour', null)),
        id: build.template(std.get(block, 'id', null)),
        minute: build.template(std.get(block, 'minute', null)),
        month: build.template(std.get(block, 'month', null)),
        rfc3339: build.template(std.get(block, 'rfc3339', null)),
        second: build.template(std.get(block, 'second', null)),
        triggers: build.template(std.get(block, 'triggers', null)),
        unix: build.template(std.get(block, 'unix', null)),
        year: build.template(std.get(block, 'year', null)),
      }),
      day: resource.field(self._.blocks, 'day'),
      hour: resource.field(self._.blocks, 'hour'),
      id: resource.field(self._.blocks, 'id'),
      minute: resource.field(self._.blocks, 'minute'),
      month: resource.field(self._.blocks, 'month'),
      rfc3339: resource.field(self._.blocks, 'rfc3339'),
      second: resource.field(self._.blocks, 'second'),
      triggers: resource.field(self._.blocks, 'triggers'),
      unix: resource.field(self._.blocks, 'unix'),
      year: resource.field(self._.blocks, 'year'),
    },
  },
  func: {
    duration_parse(duration): provider.func('duration_parse', [duration]),
    rfc3339_parse(timestamp): provider.func('rfc3339_parse', [timestamp]),
    unix_timestamp_parse(unix_timestamp): provider.func('unix_timestamp_parse', [unix_timestamp]),
  },
};

local providerWithConfiguration = provider(null, null) + {
  withConfiguration(alias, block): provider(block, {
    alias: alias,
  }),
};

providerWithConfiguration
