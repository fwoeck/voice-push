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
RabbitHost = conf['rabbithost']
RabbitUser = conf['rabbituser']
RabbitPass = conf['rabbitpass']


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
