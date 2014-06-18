module AmqpManager

  class << self

    def shutdown
      @connection.close
    end

    def channel
      Thread.current[:channel] ||= @connection.create_channel
    end

    def xchange
      Thread.current[:xchange] ||= channel.fanout('voice.push', auto_delete: false)
    end

    def establish_connection
      @connection = Bunny.new(
        host:     PushConf['rabbit_host'],
        user:     PushConf['rabbit_user'],
        password: PushConf['rabbit_pass']
      ).tap { |c| c.start }
    end

    def start
      establish_connection
    end
  end
end

AmqpManager.start
