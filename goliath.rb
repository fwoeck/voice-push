#!/usr/bin/env ruby
# encoding: utf-8

STDOUT.sync = true
STDERR.sync = true

require 'bundler'
Bundler.require

require 'yaml'
require 'time'
require 'json'
require 'bunny'
require 'redis'
require 'goliath'
require 'thread_safe'
require 'connection_pool'

EnvRegistry = ThreadSafe::Cache.new
WimConfig   = YAML.load File.read(File.join './config/app.yml')

require './lib/redis_connection'
require './lib/amqp_manager'
require './lib/messenger'
require './lib/server'
require './lib/agent'

at_exit do
  puts 'Shutting down..'
  Server.shutdown = true
  AmqpManager.shutdown
end

puts 'Starting up..'
Server.shutdown = false
Agent.set_agents_offline
AmqpManager.start

gr     = Goliath::Runner.new(ARGV, nil)
gr.api = Server.new
gr.app = Goliath::Rack::Builder.build(Server, gr.api)
gr.run
