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
  providerRequirements(val):
    if std.type(val) == 'object'
    then
      if std.objectHas(val, '_')
      then std.get(val._, 'providerRequirements', {})
      else std.foldl(function(acc, val) std.mergePatch(acc, val), std.map(function(key) build.providerRequirements(val[key]), std.objectFields(val)), {})
    else if std.type(val) == 'array'
    then std.foldl(function(acc, val) std.mergePatch(acc, val), std.map(function(element) build.providerRequirements(element), val), {})
    else {},
};

local providerTemplate(provider, requirements, configuration) = {
  local providerRequirements = { [provider]: requirements },
  local providerAlias = if configuration == null then null else configuration.alias,
  local providerWithAlias = if configuration == null then null else '%s.%s' % [provider, providerAlias],
  local providerConfiguration = if configuration == null then {} else { [providerWithAlias]: { provider: { [provider]: configuration } } },
  local providerReference = if configuration == null then {} else { provider: providerWithAlias },
  blockType(blockType): {
    local blockTypePath = if blockType == 'resource' then [] else ['data'],
    resource(type, name): {
      local resourceType = std.substr(type, std.length(provider) + 1, std.length(type)),
      local resourcePath = blockTypePath + [type, name],
      _(rawBlock, block): {
        local metaBlock = {
          depends_on: build.template(std.get(rawBlock, 'depends_on', null)),
          count: build.template(std.get(rawBlock, 'count', null)),
          for_each: build.template(std.get(rawBlock, 'for_each', null)),
        },
        type: if std.objectHas(rawBlock, 'for_each') then 'map' else if std.objectHas(rawBlock, 'count') then 'list' else 'object',
        providerRequirements: build.providerRequirements(rawBlock) + providerRequirements,
        providerConfiguration: providerConfiguration,
        provider: provider,
        providerAlias: providerAlias,
        resourceType: resourceType,
        name: name,
        ref: std.join('.', resourcePath),
        block: {
          [blockType]: {
            [type]: {
              [name]: std.prune(metaBlock + block + providerReference),
            },
          },
        },
      },
      field(fieldName): {
        local fieldPath = resourcePath + [fieldName],
        _: {
          ref: std.join('.', fieldPath),
        },
      },
    },
  },
  func(name, parameters=[]): {
    local parameterString = std.join(', ', [build.expression(parameter) for parameter in parameters]),
    _: {
      providerRequirements: build.providerRequirements(parameters) + providerRequirements,
      providerConfiguration: providerConfiguration,
      ref: 'provider::%s::%s(%s)' % [provider, name, parameterString],
    },
  },
};

local provider(configuration) = {
  local requirements = {
    source: 'registry.terraform.io/hashicorp/time',
    version: '0.12.1',
  },
  local provider = providerTemplate('time', requirements, configuration),
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
      base_rfc3339: resource.field('base_rfc3339'),
      day: resource.field('day'),
      hour: resource.field('hour'),
      id: resource.field('id'),
      minute: resource.field('minute'),
      month: resource.field('month'),
      offset_days: resource.field('offset_days'),
      offset_hours: resource.field('offset_hours'),
      offset_minutes: resource.field('offset_minutes'),
      offset_months: resource.field('offset_months'),
      offset_seconds: resource.field('offset_seconds'),
      offset_years: resource.field('offset_years'),
      rfc3339: resource.field('rfc3339'),
      second: resource.field('second'),
      triggers: resource.field('triggers'),
      unix: resource.field('unix'),
      year: resource.field('year'),
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
      day: resource.field('day'),
      hour: resource.field('hour'),
      id: resource.field('id'),
      minute: resource.field('minute'),
      month: resource.field('month'),
      rfc3339: resource.field('rfc3339'),
      rotation_days: resource.field('rotation_days'),
      rotation_hours: resource.field('rotation_hours'),
      rotation_minutes: resource.field('rotation_minutes'),
      rotation_months: resource.field('rotation_months'),
      rotation_rfc3339: resource.field('rotation_rfc3339'),
      rotation_years: resource.field('rotation_years'),
      second: resource.field('second'),
      triggers: resource.field('triggers'),
      unix: resource.field('unix'),
      year: resource.field('year'),
    },
    sleep(name, block): {
      local resource = blockType.resource('time_sleep', name),
      _: resource._(block, {
        create_duration: build.template(std.get(block, 'create_duration', null)),
        destroy_duration: build.template(std.get(block, 'destroy_duration', null)),
        id: build.template(std.get(block, 'id', null)),
        triggers: build.template(std.get(block, 'triggers', null)),
      }),
      create_duration: resource.field('create_duration'),
      destroy_duration: resource.field('destroy_duration'),
      id: resource.field('id'),
      triggers: resource.field('triggers'),
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
      day: resource.field('day'),
      hour: resource.field('hour'),
      id: resource.field('id'),
      minute: resource.field('minute'),
      month: resource.field('month'),
      rfc3339: resource.field('rfc3339'),
      second: resource.field('second'),
      triggers: resource.field('triggers'),
      unix: resource.field('unix'),
      year: resource.field('year'),
    },
  },
  func: {
    rfc3339_parse(timestamp): provider.func('rfc3339_parse', [timestamp]),
  },
};

local providerWithConfiguration = provider(null) + {
  withConfiguration(alias, block): provider(std.prune({
    alias: alias,
  })),
};

providerWithConfiguration
