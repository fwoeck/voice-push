class AmqpManager
  include Celluloid

  USE_JRB = RUBY_PLATFORM =~ /java/
  TOPICS  = [:ahn, :push]


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
    return if Server.shutdown

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
    USE_JRB ? establish_marchhare_connection : establish_bunny_connection
  end


  def establish_marchhare_connection
    @@connection = MarchHare.connect(amqp_config)
  rescue MarchHare::ConnectionRefused
    sleep 1
    retry
  end


  def establish_bunny_connection
    @@connection = Bunny.new(amqp_config).tap { |c| c.start }
  rescue Bunny::TCPConnectionFailed
    sleep 1
    retry
  end


  def amqp_config
    { host:     PushConfig['rabbit_host'],
      user:     PushConfig['rabbit_user'],
      password: PushConfig['rabbit_pass']
    }
  end


  def start
    establish_connection
    push_queue.bind(push_xchange, routing_key: 'voice.push')

    push_queue.subscribe(blocking: false) do |*args|
      hash = MultiJson.load(USE_JRB ? args[0] : args[2], symbolize_keys: true)
      Messenger.send_chunk_to_clients(hash)
    end
  end


  class << self

    def start
      Celluloid.logger.level = 3
      Celluloid::Actor[:amqp] = AmqpManager.pool(size: 32)
      @@manager ||= new.tap { |m| m.start }
    end


    def shutdown
      @@manager.shutdown
      Celluloid.shutdown
    end


    def ahn_publish(*args)
      return if Server.shutdown
      Celluloid::Actor[:amqp].async.ahn_publish(*args)
    end
  end
end
