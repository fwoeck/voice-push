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
      Thread.current[:push_xchange] ||= push_channel.fanout('voice.push', auto_delete: false)
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
    end
  end
end
