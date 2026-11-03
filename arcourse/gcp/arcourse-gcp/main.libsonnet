local a = import 'arcourse-ui/main.libsonnet';
local root = import 'root';

{
  projects:: {},

  local projects = self.projects,

  nodeList:: [
    [['gcp'], a.list.node {
      links: {
        ['%s (%s)' % [projects[id].name, id]]: root.gcp.project(id)
        for id in std.objectFields(projects)
      },
    }],
    [['gcp', '$project'], a.list.node],
  ],
}
