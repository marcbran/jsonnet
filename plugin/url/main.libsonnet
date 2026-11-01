{
  pathEscape(s): std.native('invoke:url')('pathEscape', [s]),
  pathUnescape(s): std.native('invoke:url')('pathUnescape', [s]),
  queryEscape(s): std.native('invoke:url')('queryEscape', [s]),
  queryUnescape(s): std.native('invoke:url')('queryUnescape', [s]),
  encodeQuery(params): std.native('invoke:url')('encodeQuery', [params]),
  parseQuery(query): std.native('invoke:url')('parseQuery', [query]),
  format(u): std.native('invoke:url')('format', [u]),
  parse(s): std.native('invoke:url')('parse', [s]),
}
