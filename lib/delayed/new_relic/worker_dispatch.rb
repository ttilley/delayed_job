module Delayed
  module NewRelic
    module WorkerDispatch
      
      def self.included(worker)
        worker.class_eval do
          alias start_without_newrelic start
          alias start start_with_newrelic
        end
      end
      
      def start_with_newrelic
        started = new_relic_started?
        enabled = new_relic_enabled?
        
        unless started or enabled
          setup_new_relic_dispatcher
          enabled = new_relic_enabled?
        end
        
        if started
          say "*** NewRelic Agent already started"
        elsif enabled
          say "*** Starting NewRelic Agent"
          start_new_relic_agent
        else
          say "*** NewRelic Agent not enabled"
        end
        
        start_without_newrelic
      end
      
      protected
      
      def new_relic_control
        ::NewRelic::Control.instance
      end
      
      def new_relic_agent
        ::NewRelic::Agent.instance
      end
      
      def new_relic_app_name
        new_relic_control['app_name']
      end
      
      def new_relic_started?
        new_relic_agent.started?
      end
      
      def new_relic_enabled?
        new_relic_control.agent_enabled?
      end
      
      def new_relic_local_env
        new_relic_control.local_env
      end
      
      def setup_new_relic_dispatcher
        new_relic_local_env.dispatcher = :delayed_worker
        new_relic_local_env.dispatcher_instance_id = self.name
      end
      
      def start_new_relic_agent
        ::NewRelic::Agent.manual_start({
          :app_name => "Jobs: #{new_relic_app_name}"
        })
      end
      
    end
  end
end

Delayed::Worker.send(:include, Delayed::NewRelic::WorkerDispatch)
