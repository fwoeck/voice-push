class Agent

  attr_accessor :id, :name, :languages, :skills, :activity, :visibility, :call_id,
                :locked, :availability, :idle_since, :mutex, :unlock_scheduled


  def self.set_agent_visibility(uid, state, env=nil)
    agent = Agent.new.tap { |a| a.id = uid; a.visibility = state }
    EM.defer { AmqpManager.ahn_publish(agent) }
    env.logger.info "Client for user ##{uid} went #{state}." if env
  end


  def self.set_agents_offline
    Thread.new {
      sleep 5

      while !Server.shutdown do
        orphaned_agents.each { |uid| set_agent_visibility(uid, :offline) }
        sleep 1
      end
    }
  end


  def self.orphaned_agents
    RPool.with { |con|
      con.smembers(online_keyname)
    }.map(&:to_i) - EnvRegistry.keys
  end


  def self.online_keyname
    "#{ENV['RAILS_ENV']}.online-users"
  end
end
