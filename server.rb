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
require 'goliath'

PushConf = YAML.load(File.read(File.join('./config/app.yml')))
require 'lib/amqp_manager'


class Server < Goliath::API


  def response(env)
    EM.synchrony {
      setup_queue(env)
      setup_ping_timer(env)
      subscribe_to_queue(env)
    }

    streaming_response(200, {'Content-Type' => 'text/event-stream'})
  end


  def setup_queue(env)
    env[:queue] = AmqpManager.channel.queue(env.object_id.to_s, auto_delete: true)
    env.logger.info "Queue #{env.object_id} opened."
  end


  def subscribe_to_queue(env)
    env[:queue].bind(AmqpManager.xchange).subscribe do |info, meta, payload|
      EM.next_tick {
        begin
          send_chunk_to(env, payload)
        rescue => e
          env.logger.error "Queue #{env.object_id} error: #{e.message}"
          on_close(env)
        end
      }
    end
  end


  def setup_ping_timer(env)
    env[:ping] = EM.add_periodic_timer(10) { send_ping(env) }
    EM.next_tick { send_ping(env) }
  end


  def send_ping(env)
    ts   = (Time.now.utc.to_f * 1000).to_i
    data = {timestamp: ts}.to_json
    send_chunk_to(env, data)
  end


  def send_chunk_to(env, payload)
    env.stream_send "data:#{payload}\n\n"
    env.logger.info "Send to #{env.object_id}: #{payload}"
  end


  def on_close(env)
    if env[:ping]
      env[:ping].cancel
      env.delete :ping
    end

    if env[:queue]
      env[:queue].delete
      env.delete :queue
    end

    env.logger.info "Queue #{env.object_id} closed."
  end
end
