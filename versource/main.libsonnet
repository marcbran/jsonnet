local doltProvider = import 'terraform-provider-dolt/main.libsonnet';
local jsonnet = import 'terraform-provider-jsonnet/main.libsonnet';
local tf = import 'terraform/main.libsonnet';

local terraformResourceGroup(resource) = {
  provider: resource._.provider,
  providerAlias: if resource._.providerAlias == null then '' else resource._.providerAlias,
  resourceType: resource._.resourceType,
  namespace: '',
  name: resource._.name,
  resources:
    if resource._.type == 'object' then [resource] else
      if resource._.type == 'map' then tf.values(resource) else
        if resource._.type == 'list' then resource else [],
};

local resourceGroupResources(resourceGroup) = [
  {
    provider: resourceGroup.provider,
    providerAlias: resourceGroup.providerAlias,
    resourceType: resourceGroup.resourceType,
    namespace: resourceGroup.namespace,
    name: resourceGroup.name,
    data: resource,
  }
  for resource in resourceGroup.resources
];
local resourceGroupsResources(resourceGroups) = std.flattenArrays([
  resourceGroupResources(resourceGroup)
  for resourceGroup in resourceGroups
]);

local resourceMapper(resource, mappers) = std.get(std.get(mappers, resource.provider, {}), resource.resourceType, function(resource) resource);
local mappedResources(resources, mappers) = std.flattenArrays([
  local mapper = resourceMapper(resource, mappers);
  local result = mapper(resource);
  if std.type(result) == 'array' then result else [result]
  for resource in resources
]);

local namespace = '5b1f7a3f-c85e-4d97-8f55-491a2feb413c';
local resourceValues(resource) = [
  std.native('uuidv5')(namespace, std.join('/', [
    resource.provider,
    resource.providerAlias,
    resource.resourceType,
    resource.namespace,
    resource.name,
  ])),
  resource.provider,
  resource.providerAlias,
  resource.resourceType,
  resource.namespace,
  resource.name,
  std.manifestJsonMinified(resource.data),
];
local resourcesValues(resources) = [
  resourceValues(resource)
  for resource in resources
];

local resourceGroupsValues(resourceGroups, mappers) =
  local resources = resourceGroupsResources(resourceGroups);
  local mapResources = mappedResources(resources, mappers);
  local values = resourcesValues(mapResources);
  { [value[0]]: value for value in values };

local resourceRowset(dolt, name, block) =
  local resourceGroups =
    [terraformResourceGroup(resource) for resource in block.terraformResources] +
    block.resourceGroups;
  local values =
    tf.jsondecode(jsonnet.func.evaluate(
      tf.Format(
        std.strReplace(|||
          local main = import 'versource/main.libsonnet';
          local resourceGroups = %s;
          local mappers = import 'mappers.libsonnet';
          main.resourceGroupsValues(resourceGroups, mappers)
        |||, '\n', ' '),
        [tf.jsonencode(resourceGroups)]
      ),
      {
        jpaths: ['vendor'],
      }
    ));
  dolt.resource.rowset(name, {
    database: block.database.name,
    table: block.table.name,
    columns: ['uuid', 'provider', 'provider_alias', 'resource_type', 'namespace', 'name', 'data'],
    unique_column: 'uuid',
    values: values,
  });

local flattenObject(value) =
  if std.type(value) == 'object' then
    std.foldl(function(acc, curr) acc + curr, [
      {
        [std.join('_', std.filter(function(key) key != '', [child.key, childChild.key]))]: childChild.value
        for childChild in std.objectKeysValues(flattenObject(child.value))
      }
      for child in std.objectKeysValues(value)
    ], {})
  else { '': value };

local tfCfg(block) =
  local dolt = doltProvider.withConfiguration('default', {
    path: '../db',
    name: block.name,
    email: block.email,
  });
  local database = dolt.resource.database('database', {
    name: 'versource',
  });
  local table = dolt.resource.table('table', {
    database: database.name,
    name: 'resources',
    query: std.strReplace(|||
      CREATE TABLE resources (
        uuid CHAR(36) PRIMARY KEY,
        provider VARCHAR(100) NOT NULL,
        provider_alias VARCHAR(100) NOT NULL,
        resource_type VARCHAR(100) NOT NULL,
        namespace VARCHAR(100) NOT NULL,
        name VARCHAR(100) NOT NULL,
        data JSON,
        CONSTRAINT unique_resource UNIQUE (provider, provider_alias, resource_type, namespace, name)
      )
    |||, '\n', ' '),
  });
  local viewItemsView = dolt.resource.view('view_items_view', {
    database: database.name,
    name: 'view_items',
    query: std.strReplace(|||
      SELECT
        CONCAT('view-', REPLACE(table_name, "_", "-")) as uid,
        REPLACE(table_name, "_", "-") as title,
        '' as arg
      FROM information_schema.views
      WHERE table_name LIKE '%_items'
      AND table_name <> 'view_items'
      AND table_schema = DATABASE()
    |||, '\n', ' '),
  });
  local rowset = resourceRowset(dolt, 'resources', {
    database: database,
    table: table,
    terraformResources: std.get(block, 'terraformResources', []),
    resourceGroups: std.get(block, 'resourceGroups', []),
  });
  local views = [dolt.resource.view('%s_items_view' % view.key, {
    database: database.name,
    name: '%s_items' % view.key,
    query: std.strReplace(view.value, '\n', ' '),
  }) for view in std.objectKeysValues(flattenObject(std.get(block, 'views', {})))];
  local doltResources = [
    database,
    table,
    viewItemsView,
    rowset,
  ] + views;
  tf.Cfg(block.supportingTerraformResources + block.terraformResources + doltResources);

local cfg(block) = {
  'sync/main.tf.json': std.manifestJson(tfCfg(block)),
  'sync/mappers.libsonnet': std.get(block, 'mappers', '{}'),
};

{
  resourceGroupsValues: resourceGroupsValues,
  cfg: cfg,
}
