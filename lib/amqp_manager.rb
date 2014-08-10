require 'bunny'

module AmqpManager
  class << self


    def ahn_channel
      Thread.current[:ahn_channel] ||= connection.create_channel
    end

    def ahn_xchange
      Thread.current[:ahn_xchange] ||= ahn_channel.topic('voice.ahn', auto_delete: false)
    end

    def ahn_queue
      Thread.current[:ahn_queue] ||= ahn_channel.queue('voice.ahn', auto_delete: false)
    end

    def ahn_publish(payload)
      ahn_xchange.publish(payload.to_json, routing_key: 'voice.ahn')
      true
    end


    def push_channel
      Thread.current[:push_channel] ||= connection.create_channel
    end

    def push_xchange
      Thread.current[:push_xchange] ||= push_channel.topic('voice.push', auto_delete: false)
    end

    def push_queue
      Thread.current[:push_queue] ||= push_channel.queue('voice.push', auto_delete: false)
    end


    def shutdown
      connection.close
    end

    def connection
      establish_connection unless @connection
      @connection
    end


    def establish_connection
      @connection = Bunny.new(
        host:     WimConfig['rabbit_host'],
        user:     WimConfig['rabbit_user'],
        password: WimConfig['rabbit_pass'],
        automatic_recovery: false
      ).tap { |c| c.start }
    rescue Bunny::TCPConnectionFailed
      sleep 1
      retry
    end


    def start
      establish_connection
      push_queue.bind(push_xchange, routing_key: 'voice.push')

      push_queue.subscribe do |delivery_info, metadata, payload|
        Messenger.send_chunk_to_clients(payload)
      end
    end
  end
end
