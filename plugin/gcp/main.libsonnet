{
  call(ctx, service, method, params={}): std.native('invoke:gcp')('call', [ctx, service, method, params]),
}
