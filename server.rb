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

WimConfig = YAML.load File.read(File.join './config/app.yml')
require './lib/redis_connection'
require './lib/amqp_manager'
require './lib/messenger'


EnvRegistry = ThreadSafe::Cache.new

class Server < Goliath::API
  use Goliath::Rack::Params

  def response(env)
    if user_token_is_valid?(env)
      EM.synchrony {
        store_env_in_registry(env)
        setup_ping_timer(env)
      }
      streaming_response(200, {'Content-Type' => 'text/event-stream'})
    else
      return [400, {}, []]
    end
  end


  def user_token_is_valid?(env)
    env[:user_id] = params['user_id'].to_i
    token         = params['token'] || ""

    token.length > 0 && token == $redis.get(redis_namespaced_key)
  end


  def redis_namespaced_key
    "#{params['rails_env']}.token.#{params['user_id']}"
  end


  def store_env_in_registry(env)
    EnvRegistry[env[:user_id]] = env
    env.logger.info "Queue for #{env[:user_id]} opened."
  end


  def setup_ping_timer(env)
    env[:ping] = EM.add_periodic_timer(10) { Messenger.send_ping(env) }
    EM.next_tick { Messenger.send_ping(env) }
  end


  def on_close(env)
    env[:ping].cancel
    env.delete :ping
    env.logger.info "Queue for #{env[:user_id]} closed."
  end
end


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
