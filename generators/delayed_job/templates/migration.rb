class CreateDelayedJobs < ActiveRecord::Migration
  def self.up
    create_table :delayed_jobs, :force => true do |table|
      table.integer  :priority, :default => 0      # Allows some jobs to jump to the front of the queue
      table.integer  :attempts, :default => 0      # Provides for retries, but still fail eventually.
      table.text     :handler                      # YAML-encoded string of the object that will do work
      table.text     :last_error                   # reason for last failure (See Note below)
      table.datetime :run_at                       # When to run. Could be Time.zone.now for immediately, or sometime in the future.
      table.datetime :locked_at                    # Set when a client is working on this object
      table.datetime :failed_at                    # Set when all retries have failed (actually, by default, the record is deleted instead)
      table.string   :locked_by                    # Who is working on this object (if locked)
      table.timestamps
    end
    
    create_table :delayed_workers, :force => true do |table|
      table.string :name
      table.integer :job_id
      table.string :job_name
      table.integer :job_attempt
      table.integer :job_priority
      table.integer :completed_jobs, :default => 0
      table.integer :failed_jobs, :default => 0
      table.integer :longest_job, :default => 0
      table.datetime :job_started_at
      table.timestamps
    end

  end
  
  def self.down
    drop_table :delayed_jobs  
  end
end