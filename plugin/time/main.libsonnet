{
  now(): std.native('invoke:time')('now', []),
  addDuration(epochMs, spec): std.native('invoke:time')('addDuration', [epochMs, spec]),
}
