module Messenger
  class << self

    def send_chunk_to_clients(hash)
      users = hash[:user_ids].map(&:to_i)

      users.each { |uid|
        env = EnvRegistry[uid]
        EM.next_tick { send_chunk_to(env, hash[:data]) } if env
      }
    end


    def send_ping(env)
      ts   = (Time.now.utc.to_f * 1000).to_i
      data = {servertime: ts}.to_json
      send_chunk_to(env, data)
    end


    def send_chunk_to(env, payload)
      env.stream_send  "data:#{payload}\n\n"
      env.logger.debug "Send to #{env[:user_id]}: #{payload}"
    rescue
      env.logger.warn 'Sending data to closed socket failed.'
    end
  end
end
