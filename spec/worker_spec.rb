require File.dirname(__FILE__) + '/database'
require File.dirname(__FILE__) + '/sample_jobs'

describe Delayed::Worker do
  def job_create(opts = {})
    Delayed::Job.create(opts.merge(:payload_object => SimpleJob.new))
  end

  before do
    Delayed::Worker.class_eval('public :work_off')
    Delayed::Worker.delete_all
  end

  before(:each) do
    @worker = Delayed::Worker.new(:max_priority => nil, :min_priority => nil)
    @worker.save!

    Delayed::Job.delete_all
    
    SimpleJob.runs = 0
  end
  
  context "starting up" do
    it "sets the worker instance" do
      Delayed::Worker.instance.should == @worker
    end
    
    it "sets name" do
      @worker.name.should == Delayed::Worker.default_name
    end
    
    it "sets created_at" do
      @worker.created_at.should_not == nil
    end
  end
  
  context "starting a job" do
    before(:each) do
      @worker = Delayed::Worker.new
      @worker.save!
      @job = job_create
      @worker.start_job(@job)
    end
    
    it "sets job_id" do
      @worker.job_id.should == @job.id
    end
    
    it "sets job_name" do
      @worker.job_name.should == @job.name
    end
    
    it "sets job_attempt" do
      @worker.job_attempt.should == @job.attempts
    end
    
    it "sets job_priority" do
      @worker.job_priority.should == @job.priority
    end
    
    it "sets job_started_at" do
      @worker.job_started_at.should_not == nil
    end
  end
  
  context "ending a job" do
    before(:each) do
      @worker = Delayed::Worker.create!({})
      @job = job_create
      @worker.start_job(@job)
      @worker.update_attribute :job_started_at, 5.minutes.ago
      @worker.end_job(@job)
    end
    
    it "increments completed jobs" do
      @worker.completed_jobs.should == 1
    end
    
    it "records longest running job" do
      @worker.longest_job.should == 300
    end
    
    it "unsets job_id" do
      @worker.job_id.should == nil
    end
    
    it "unsets job_name" do
      @worker.job_name.should == nil
    end
    
    it "unsets job_started_at" do
      @worker.job_started_at.should == nil
    end
  end
  
  context "failing a job" do
    before(:each) do
      @worker = Delayed::Worker.create!({})
      @job = job_create
      @worker.start_job(@job)
      @worker.fail_job(@job)
    end
    
    it "increments failed jobs" do
      @worker.failed_jobs.should == 1
    end
  end

  context "worker prioritization" do
    before(:each) do
      @worker = Delayed::Worker.new(:max_priority => 5, :min_priority => -5)
      @worker.save!
    end

    it "should only work_off jobs that are >= min_priority" do
      SimpleJob.runs.should == 0

      job_create(:priority => -10)
      job_create(:priority => 0)
      @worker.work_off

      SimpleJob.runs.should == 1
    end

    it "should only work_off jobs that are <= max_priority" do
      SimpleJob.runs.should == 0

      job_create(:priority => 10)
      job_create(:priority => 0)

      @worker.work_off

      SimpleJob.runs.should == 1
    end
  end

  context "while running alongside other workers that locked jobs, it" do
    before(:each) do
      @worker.name = 'worker1'
      job_create(:locked_by => 'worker1', :locked_at => (Delayed::Job.db_time_now - 1.minutes))
      job_create(:locked_by => 'worker2', :locked_at => (Delayed::Job.db_time_now - 1.minutes))
      job_create
      job_create(:locked_by => 'worker1', :locked_at => (Delayed::Job.db_time_now - 1.minutes))
    end

    it "should ingore locked jobs from other workers" do
      @worker.name = 'worker3'
      SimpleJob.runs.should == 0
      @worker.work_off
      SimpleJob.runs.should == 1 # runs the one open job
    end

    it "should find our own jobs regardless of locks" do
      @worker.name = 'worker1'
      SimpleJob.runs.should == 0
      @worker.work_off
      SimpleJob.runs.should == 3 # runs open job plus worker1 jobs that were already locked
    end
  end

  context "while running with locked and expired jobs, it" do
    before(:each) do
      @worker.name = 'worker1'
      exp_time = Delayed::Job.db_time_now - (1.minutes + Delayed::Job::max_run_time)
      job_create(:locked_by => 'worker1', :locked_at => exp_time)
      job_create(:locked_by => 'worker2', :locked_at => (Delayed::Job.db_time_now - 1.minutes))
      job_create
      job_create(:locked_by => 'worker1', :locked_at => (Delayed::Job.db_time_now - 1.minutes))
    end

    it "should only find unlocked and expired jobs" do
      @worker.name = 'worker3'
      SimpleJob.runs.should == 0
      @worker.work_off
      SimpleJob.runs.should == 2 # runs the one open job and one expired job
    end

    it "should ignore locks when finding our own jobs" do
      @worker.name = 'worker1'
      SimpleJob.runs.should == 0
      @worker.work_off
      SimpleJob.runs.should == 3 # runs open job plus worker1 jobs
      # This is useful in the case of a crash/restart on worker1, but make sure multiple workers on the same host have unique names!
    end

  end

end
