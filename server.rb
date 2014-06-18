#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler'
Bundler.require

require 'yaml'
require 'json'
require 'bunny'
require 'goliath'

PushConf = YAML.load(File.read(File.join('./config/app.yml')))
require 'lib/amqp_manager'


class Server < Goliath::API

  def response(env)
    EM.synchrony do
      @queue = AmqpManager.channel.queue(env.object_id.to_s, auto_delete: true)

      @queue.bind(AmqpManager.xchange).subscribe do |info, meta, payload|
        EM.next_tick do
          env.stream_send "data:#{payload}\n\n"
          env.logger.info payload
        end
      end
    end

    streaming_response(200, {'Content-Type' => 'text/event-stream'})
  end

  def on_close(env)
    @queue.delete
  end
end
