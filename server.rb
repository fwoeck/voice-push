#!/usr/bin/env ruby
# encoding: utf-8

STDOUT.sync = true
STDERR.sync = true

require 'bundler'
Bundler.require

require 'yaml'
require 'bunny'
require 'goliath'

PushConf = YAML.load(File.read(File.join('./config/app.yml')))
require 'lib/amqp_manager'


class Server < Goliath::API

  def response(env)
    @queue = AmqpManager.channel.queue(env.object_id.to_s, auto_delete: true)
    env.logger.info "Queue #{env.object_id} opened."

    @queue.bind(AmqpManager.xchange).subscribe do |info, meta, payload|
      EM.next_tick {
        env.stream_send "data:#{payload}\n\n"
        env.logger.info "Send to #{env.object_id}: #{payload}"
      }
    end

    streaming_response(200, {'Content-Type' => 'text/event-stream'})
  end

  def on_close(env)
    @queue.delete
    env.logger.info "Queue #{env.object_id} closed."
  end
end
