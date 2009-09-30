module Delayed
  class Worker < ActiveRecord::Base
    set_table_name :delayed_workers
    SLEEP = 5

    cattr_accessor :logger
    self.logger = if defined?(Merb::Logger)
      Merb.logger
    elsif defined?(RAILS_DEFAULT_LOGGER)
      RAILS_DEFAULT_LOGGER
    end

    def self.default_name
      "host:#{Socket.gethostname} pid:#{Process.pid}" rescue "pid:#{Process.pid}"
    end

    def self.start(options = {})
      Delayed::Job.worker = create!(options)
      Delayed::Job.worker.start
    end

    def initialize(options={})
      @quiet = options.delete(:quiet)
      Delayed::Job.min_priority = options.delete(:min_priority) if options.has_key?(:min_priority)
      Delayed::Job.max_priority = options.delete(:max_priority) if options.has_key?(:max_priority)
      options[:name] = self.class.default_name if !options[:name]
      super
    end

    def start_job(job)
      return if new_record?
      self.job_id         = job.id
      self.job_started_at = Delayed::Job.db_time_now
      save!
    end

    def end_job(job)
      return if new_record?
      duration    = job_started_at ? Delayed::Job.db_time_now - job_started_at : 0
      self.longest_job     = duration if duration > self.longest_job
      self.job_id          = nil
      self.completed_jobs += 1
      save!
    end

    def start
      say "*** Starting job worker #{name}"

      trap('TERM') { say 'Exiting...'; $exit = true }
      trap('INT')  { say 'Exiting...'; $exit = true }

      loop do
        result = nil

        realtime = Benchmark.realtime do
          result = Delayed::Job.work_off
        end

        count = result.sum

        break if $exit

        if count.zero?
          sleep(SLEEP)
        else
          say "#{count} jobs processed at %.4f j/s, %d failed ..." % [count / realtime, result.last]
        end

        break if $exit
      end

    ensure
      Delayed::Job.clear_locks!
    end

    def say(text)
      puts text unless @quiet
      logger.info text if logger
    end

  end
end
