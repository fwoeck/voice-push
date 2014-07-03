require 'bunny'

module AmqpManager
  class << self

    def shutdown
      @connection.close
    end


    def push_channel
      Thread.current[:push_channel] ||= @connection.create_channel
    end


    def push_xchange
      Thread.current[:push_xchange] ||= push_channel.topic('voice.push', auto_delete: false)
    end


    def push_queue
      Thread.current[:push_queue] ||= push_channel.queue('voice.push', auto_delete: false)
    end


    def establish_connection
      @connection = Bunny.new(
        host:     WimConfig['rabbit_host'],
        user:     WimConfig['rabbit_user'],
        password: WimConfig['rabbit_pass'],
        automatic_recovery: false
      ).tap { |c| c.start }
    end


    def start
      establish_connection
      push_queue.bind(push_xchange, routing_key: 'voice.push')

      push_queue.subscribe do |delivery_info, metadata, payload|
        Messenger.send_chunk_to_client(payload)
      end
    end
  end
end
