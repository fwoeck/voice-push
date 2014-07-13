module Messenger
  class << self

    def send_chunk_to_client(payload)
      hash    = JSON.parse payload
      user_id = hash['user_id'].to_i
      data    = hash['data'].to_json
      env     = EnvRegistry[user_id]

      EM.next_tick { send_chunk_to(env, data) } if env
    end


    def send_ping(env)
      ts   = (Time.now.utc.to_f * 1000).to_i
      data = {servertime: ts}.to_json
      send_chunk_to(env, data)
    end


    def send_chunk_to(env, payload)
      env.stream_send "data:#{payload}\n\n"
      env.logger.info "Send to #{env[:user_id]}: #{payload}"
    rescue
      env.logger.info 'Sending data to closed socket failed.'
    end
  end
end
