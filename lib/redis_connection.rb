RPool = ConnectionPool.new(size: 5, timeout: 3) {
  Redis.new(host: PushConfig['redis_host'], port: PushConfig['redis_port'], db: PushConfig['redis_db'])
}
