class AmqpManager
  include Celluloid

  TOPICS = [:ahn, :push]


  TOPICS.each { |name|
    class_eval %Q"
      def #{name}_channel
        @#{name}_channel ||= connection.create_channel
      end
    "

    class_eval %Q"
      def #{name}_xchange
        @#{name}_xchange ||= #{name}_channel.topic('voice.#{name}', auto_delete: false)
      end
    "

    class_eval %Q"
      def #{name}_queue
        @#{name}_queue ||= #{name}_channel.queue('voice.#{name}', auto_delete: false)
      end
    "
  }


  def ahn_publish(payload)
    data = Marshal.dump(payload)
    ahn_xchange.publish(data, routing_key: 'voice.ahn')
  end


  def connection
    establish_connection unless @@connection
    @@connection
  end


  def shutdown
    connection.close
  end


  def establish_connection
    @@connection = Bunny.new(
      host:     PushConfig['rabbit_host'],
      user:     PushConfig['rabbit_user'],
      password: PushConfig['rabbit_pass']
    ).tap { |c| c.start }
  rescue Bunny::TCPConnectionFailed
    sleep 1
    retry
  end


  def start
    establish_connection
    push_queue.bind(push_xchange, routing_key: 'voice.push')

    push_queue.subscribe do |delivery_info, metadata, payload|
      hash = MultiJson.load(payload, symbolize_keys: true)
      Messenger.send_chunk_to_clients(hash)
    end
  end


  class << self

    def start
      # TODO This will suppress warnings at exit, but could also
      #       mask potential problems. Try to remove after a while:
      #
      Celluloid.logger = nil

      Celluloid::Actor[:amqp] = AmqpManager.pool(size: 32)
      @@manager ||= new.tap { |m| m.start }
    end


    def shutdown
      @@manager.shutdown
    end


    def ahn_publish(*args)
      Celluloid::Actor[:amqp].async.ahn_publish(*args)
    end
  end
end
