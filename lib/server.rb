class Server < Goliath::API
  use Goliath::Rack::Params

  def response(env)
    if user_token_is_valid?(env)
      EM.synchrony {
        clear_old(env)
        store_env_in_registry(env)
        setup_ping_timer(env)
      }
      streaming_response(200, {'Content-Type' => 'text/event-stream'})
    else
      env[:skip_cleanup] = true
      return [400, {}, []]
    end
  end


  def clear_old(env)
    old_env = EnvRegistry[env[:user_id]]
    old_env.stream_close if old_env
  end


  def user_token_is_valid?(env)
    env[:user_id] = params['user_id'].to_i
    client_token  = params['token'] || ""
    server_token  = Redis.current.get(token_keyname)

    token_is_valid?(env, client_token, server_token)
  end


  def token_is_valid?(env, client_token, server_token)
    env[:user_id] > 0 &&
      client_token.length > 0 &&
      client_token == server_token
  end


  def token_keyname
    "#{params['rails_env']}.token.#{params['user_id']}"
  end


  def store_env_in_registry(env)
    uid   = env[:user_id]
    agent = Agent.new.tap { |a| a.id = uid; a.visibility = :online }
    EnvRegistry[uid] = env

    EM.next_tick {
      AmqpManager.ahn_publish(agent)
    }
    env.logger.info "Queue for user ##{uid} opened."
  end


  def setup_ping_timer(env)
    env[:ping] = EM.add_periodic_timer(10) { Messenger.send_ping(env) }
    EM.next_tick { Messenger.send_ping(env) }
  end


  def clear_ping_timer(env)
    if env[:ping]
      EM.cancel_timer env[:ping]
      env.delete :ping
    end
  end


  def remove_connection(env)
    uid   = env[:user_id]
    agent = Agent.new.tap { |a| a.id = uid; a.visibility = :offline }
    EnvRegistry.delete uid

    EM.next_tick {
      AmqpManager.ahn_publish(agent)
    }
    env.logger.info "Queue for user ##{uid} closed."
  end


  def on_close(env)
    return if env[:skip_cleanup]

    clear_ping_timer(env)
    remove_connection(env)
  end
end
