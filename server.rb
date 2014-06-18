#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler'
Bundler.require

require 'yaml'
require 'json'
require 'time'
require 'bunny'
require 'redis'
require 'goliath'
require 'thread_safe'
require 'connection_pool'


conf       = YAML.load(File.read(File.join("./config/app.yml")))

RedisPool  = {}
RedisPort  = conf['redisport']
RedisHost  = conf['redishost']
RedisDbs   = conf['redisaccess']

RabbitHost = conf['rabbithost']
RabbitUser = conf['rabbituser']
RabbitPass = conf['rabbitpass']


RedisDbs.each do |db|
  RedisPool[db] = ConnectionPool.new(size: 5, timeout: 5) {
    Redis.new(host: RedisHost, port: RedisPort, db: db)
  }
end

class SSE < Goliath::API

  def response(env)
    streaming_response(200, {
      'Connection'   => 'keep-alive',
      'Content-Type' => 'text/event-stream'
    })
  end

  def on_close(env)
  end
end
