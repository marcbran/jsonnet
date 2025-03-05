{
  adapters: {
    resources(resource): [
      resource {
        resourceType: std.asciiLower(object.kind),
        namespace: std.get(object.metadata, 'namespace', ''),
        name: object.metadata.name,
        data: object {
          metadata: object.metadata {
            annotations: std.get(object.metadata, 'annotations', {}) {
              'kubectl.kubernetes.io/last-applied-configuration':: null,
            },
            managedFields:: null,
          },
        },
      }
      for object in std.prune(resource.data.objects)
    ],
  },
  views: {
    k9s: |||
      SELECT
          CONCAT('k9s-', uuid) as uid,
          CONCAT_WS('/', NULLIF(namespace, ''), name) as title,
          CONCAT('k9s://mikrok8s/', `data`->>"$.metadata.name") as arg
      FROM `resources`
      WHERE provider = "kubernetes"
      AND resource_type = "namespace"
      LIMIT 1000
    |||,
  },
}
