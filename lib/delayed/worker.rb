module Delayed
  class Worker < ActiveRecord::Base
    set_table_name :delayed_workers
    
    # Every worker has a unique name which by default is the pid of the process.
    # There are some advantages to overriding this with something which survives worker retarts:
    # Workers can safely resume working on tasks which are locked by themselves. The worker will assume that it crashed before.
    def self.default_name
      "host:#{Socket.gethostname} pid:#{Process.pid}" rescue "pid:#{Process.pid}"
    end
    
    def self.start(options={})
      create!(options).start
    end
    
    @@sleep_delay = 5
    
    cattr_accessor :sleep_delay
    
    cattr_accessor :instance

    cattr_accessor :logger
    self.logger = if defined?(Merb::Logger)
      Merb.logger
    elsif defined?(RAILS_DEFAULT_LOGGER)
      RAILS_DEFAULT_LOGGER
    end
    
    after_save :set_worker_instance

    def job_max_run_time
      Delayed::Job.max_run_time
    end

    def initialize(options={})
      @quiet = options.delete(:quiet)
      
      Delayed::Job.min_priority = options.delete(:min_priority) if options.has_key?(:min_priority)
      Delayed::Job.max_priority = options.delete(:max_priority) if options.has_key?(:max_priority)
      
      options[:name] ||= self.class.default_name
      options[:name] = "#{options.delete(:name_prefix)}#{options[:name]}" if options.has_key?(:name_prefix)
      
      super(options)  
    end

    def start
      say "*** Starting job worker #{self.name}"

      trap('TERM') { say 'Exiting...'; $exit = true }
      trap('INT')  { say 'Exiting...'; $exit = true }

      loop do
        result = nil

        realtime = Benchmark.realtime do
          result = work_off
        end

        count = result.sum

        break if $exit

        if count.zero?
          sleep(@@sleep_delay)
        else
          say "#{count} jobs processed at %.4f j/s, %d failed ..." % [count / realtime, result.last]
        end

        break if $exit
      end

    ensure
      Delayed::Job.clear_locks!(self.name)
    end

    def say(text, level = Logger::INFO)
      puts text unless @quiet
      logger.add level, text if logger
    end
    
    def start_job(job)
      return if new_record?
      self.job_id = job.id
      self.job_name = job.name
      self.job_attempt = job.attempts
      self.job_priority = job.priority
      self.job_started_at = Delayed::Job.db_time_now
      save!
    end
    
    def fail_job(job)
      return if new_record?
      self.failed_jobs += 1
      set_longest_job
      clear_state_fields
      save!
    end
    
    def end_job(job, runtime = nil)
      return if new_record?
      self.completed_jobs += 1
      set_longest_job(runtime)
      clear_state_fields
      save!
    end
    
    def clear_state_fields
      self.job_id = nil
      self.job_name = nil
      self.job_attempt = nil
      self.job_priority = nil
      self.job_started_at = nil
    end
    
    def set_longest_job(duration = nil)
      duration ||= job_started_at ? Delayed::Job.db_time_now - job_started_at : 0
      self.longest_job = duration if duration > self.longest_job
    end

    protected

    # Run the next job we can get an exclusive lock on.
    # If no jobs are left we return nil
    def reserve_and_run_one_job(max_run_time = job_max_run_time)

      # We get up to 5 jobs from the db. In case we cannot get exclusive access to a job we try the next.
      # this leads to a more even distribution of jobs across the worker processes
      job = Delayed::Job.find_available(name, 5, max_run_time).detect do |job|
        if job.lock_exclusively!(max_run_time, name)
          say "* [Worker(#{self.name})] acquired lock on #{job.name}"
          true
        else
          say "* [Worker(#{self.name})] failed to acquire exclusive lock for #{job.name}", Logger::WARN
          false
        end
      end

      if job.nil?
        nil # we didn't do any work, all 5 were not lockable
      else
        job.run(max_run_time)
      end
    end

    # Do num jobs and return stats on success/failure.
    # Exit early if interrupted.
    def work_off(num = 100)
      success, failure = 0, 0

      num.times do
        case reserve_and_run_one_job
        when true
            success += 1
        when false
            failure += 1
        else
          break  # leave if no work could be done
        end
        break if $exit # leave if we're exiting
      end

      return [success, failure]
    end
    
    def set_worker_instance
      self.class.instance = self
    end
    
  end
end
