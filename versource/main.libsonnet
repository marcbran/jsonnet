local dolt = import 'terraform-provider-dolt/main.libsonnet';
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

local resourceRowset(name, block) =
  local resourceGroups = [
    terraformResourceGroup(resource)
    for resource in std.get(block, 'terraformResources', [])
  ] + std.get(block, 'resourceGroups', []);
  local values =
    tf.jsondecode(jsonnet.func.evaluate(
      tf.Format(
        "local main = import 'versource/main.libsonnet'; local resourceGroups = %s; local mappers = import 'mappers.libsonnet'; main.resourceGroupsValues(resourceGroups, mappers)",
        [tf.jsonencode(resourceGroups)]
      ),
      {
        jpaths: ['vendor'],
      }
    ));
  dolt.resource.rowset(name, {
    repository_path: block.table.repository_path,
    author_name: block.table.author_name,
    author_email: block.table.author_email,
    table_name: block.table.name,

    columns: ['uuid', 'provider', 'provider_alias', 'resource_type', 'namespace', 'name', 'data'],
    unique_column: 'uuid',
    values: values,
  });

local groups = {
  virtualResources(name, resources): {
    provider: 'versource',
    providerAlias: '',
    resourceType: 'VirtualResource',
    namespace: '',
    name: name,
    resources: resources,
  },
};

local cfg(block) =
  local repo = dolt.resource.repository('repository', {
    path: '../data',
    name: block.name,
    email: block.email,
  });
  local table = dolt.resource.table('table', {
    repository_path: repo.path,
    author_name: repo.name,
    author_email: repo.email,

    name: 'resources',
    query: |||
      CREATE TABLE resources (
        uuid CHAR(36) PRIMARY KEY,
        provider VARCHAR(100) NOT NULL,
        provider_alias VARCHAR(100) NOT NULL,
        resource_type VARCHAR(100) NOT NULL,
        namespace VARCHAR(100) NOT NULL,
        name VARCHAR(100) NOT NULL,
        data JSON,
        CONSTRAINT unique_resource UNIQUE (provider, provider_alias, resource_type, namespace, name)
      );
    |||,
  });
  local rowset = resourceRowset('resources', {
    table: table,
    terraformResources: block.terraformResources,
    resourceGroups: block.resourceGroups,
  });
  local doltResources = [
    repo,
    table,
    rowset,
  ];
  tf.Cfg(block.supportingTerraformResources + block.terraformResources + doltResources);

{
  resourceGroupsValues: resourceGroupsValues,
  cfg: cfg,
  groups: groups,
}
