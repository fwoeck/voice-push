class Server < Goliath::API
  use Goliath::Rack::Params

  def response(env)
    if user_token_is_valid?(env)
      EM.synchrony {
        store_env_in_registry(env)
        setup_ping_timer(env)
      }
      streaming_response(200, {'Content-Type' => 'text/event-stream'})
    else
      return [400, {}, []]
    end
  end


  def user_token_is_valid?(env)
    env[:user_id] = params['user_id'].to_i
    client_token  = params['token'] || ""
    server_token  = $redis.get(redis_namespaced_key)

    token_is_valid?(env, client_token, server_token)
  end


  def token_is_valid?(env, client_token, server_token)
    env[:user_id] > 0 &&
      client_token.length > 0 &&
      client_token == server_token
  end


  def redis_namespaced_key
    "#{params['rails_env']}.token.#{params['user_id']}"
  end


  def store_env_in_registry(env)
    if (old_env = EnvRegistry[env[:user_id]])
      on_close(old_env)
    end

    EnvRegistry[env[:user_id]] = env
    env.logger.info "Queue for #{env[:user_id]} opened."
  end


  def setup_ping_timer(env)
    env[:ping] = EM.add_periodic_timer(10) { Messenger.send_ping(env) }
    EM.next_tick { Messenger.send_ping(env) }
  end


  def on_close(env)
    if env[:ping]
      env[:ping].cancel
      env.delete :ping
    end
    env.logger.info "Queue for #{env[:user_id]} closed."
  end
end
