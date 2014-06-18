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

PushConf = YAML.load(File.read(File.join('./config/app.yml')))
require 'lib/amqp_manager'


class Server < Goliath::API

  def response(env)
    EM.synchrony do
      @queue = AmqpManager.channel.queue(env.object_id.to_s, auto_delete: true)

      @queue.bind(AmqpManager.xchange).subscribe do |info, meta, payload|
        env.stream_send converted(payload)
        env.logger.info payload
      end
    end

    streaming_response(200, {'Content-Type' => 'text/event-stream'})
  end

  def on_close(env)
    @queue.delete
  end

  def converted(payload)
    "id: #{Time.now}\n" + "data: #{payload}" + "\n\n"
  end
end
