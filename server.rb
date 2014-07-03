#!/usr/bin/env ruby
# encoding: utf-8

STDOUT.sync = true
STDERR.sync = true

require 'bundler'
Bundler.require

require 'yaml'
require 'time'
require 'json'
require 'goliath'
require 'thread_safe'

EnvRegistry = ThreadSafe::Cache.new
WimConfig   = YAML.load File.read(File.join './config/app.yml')

require './lib/redis_connection'
require './lib/amqp_manager'
require './lib/messenger'
require './lib/server'

at_exit do
  puts 'Shutting down..'
  AmqpManager.shutdown
  exit!
end

puts 'Starting up..'
AmqpManager.start

gr     = Goliath::Runner.new(ARGV, nil)
gr.api = Server.new
gr.app = Goliath::Rack::Builder.build(Server, gr.api)
gr.run
