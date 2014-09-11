module Messenger
  class << self

    def send_chunk_to_clients(hash)
      users = hash[:user_ids].map(&:to_i)
      data  = MultiJson.dump(hash[:data])

      users.each { |uid|
        env = EnvRegistry[uid]
        EM.next_tick { send_chunk_to(env, data) } if env
      }
    end


    def send_ping(env)
      ts   = (Time.now.utc.to_f * 1000).to_i
      data = {servertime: ts}.to_json
      send_chunk_to(env, data, :ping)
    end


    def send_chunk_to(env, payload, type=:data)
      env.stream_send  "data:#{payload}\n\n"
      env.logger.debug "Sent #{type} to user ##{env[:user_id]}."
    rescue
      env.logger.warn 'Sending data to closed socket failed.'
    end
  end
end
