module Delayed
  module NewRelic
    module Samplers
      
      class QueueSizeSampler < ::NewRelic::Agent::Sampler
        def initialize
          super :delayed_job_queue_size
        end
        
        def stats
          stats_engine.get_stats("Jobs/Queue Size")
        end
        
        def queue_size
          Delayed::Job.count
        end
        
        def poll
          stats.record_data_point queue_size
        end
      end
      
      class FailedJobsSampler < ::NewRelic::Agent::Sampler
        def initialize
          super :delayed_job_failed_jobs
        end
        
        def stats
          stats_engine.get_stats("Jobs/Failed Jobs")
        end
        
        def failed_jobs
          Delayed::Job.count({:conditions => '`failed_at` IS NOT NULL'})
        end
        
        def poll
          stats.record_data_point failed_jobs
        end
      end
      
    end
  end
end

::NewRelic::Agent.instance.stats_engine.add_sampler Delayed::NewRelic::Samplers::QueueSizeSampler.new

::NewRelic::Agent.instance.stats_engine.add_sampler Delayed::NewRelic::Samplers::FailedJobsSampler.new
