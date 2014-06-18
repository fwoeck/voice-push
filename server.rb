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
      AmqpManager.queue.subscribe do |delivery_info, metadata, payload|
        env.stream_send payload(payload)
      end
    end

    streaming_response(200, {'Content-Type' => 'text/event-stream'})
  end

  def on_close(env)
    # AmqpManager.channel.close
  end

  def payload(message)
    "id: #{Time.now}\n" + "data: #{message}" + "\r\n\n"
  end
end
