require File.dirname(__FILE__) + '/database'

describe Delayed::Worker do

  before :all do
    Delayed::Worker.delete_all
    @worker = Delayed::Worker.create!(:quiet => true)
    Delayed::Job.worker = @worker
  end

  describe "Starting up" do
    it "sets name" do
      @worker.name.should == Delayed::Worker.default_name
    end

    it "sets created_at" do
      @worker.created_at.should_not == nil
    end
  end

  describe "Starting a job" do
    before :all do
      @job = Delayed::Job.new
      @job.id = 5
      @worker.start_job(@job)
    end

    it "resets job_id" do
      @worker.job_id.should == @job.id
    end

    it "resets start time" do
      @worker.job_started_at.should_not == nil
    end
  end

  describe "Ending a job" do
    before :all do
      @job = Delayed::Job.new
      @job.id = 5
      @worker.start_job(@job)
      @worker.update_attribute :job_started_at, 5.minutes.ago
      @worker.end_job(@job)
    end

    it "clears job_id" do
      @worker.job_id.should == nil
    end

    it "increments #completed_jobs" do
      @worker.completed_jobs.should == 1
    end

    it "sets #longest_job" do
      @worker.longest_job.should == 300
    end
  end

  describe "Running a job" do
    before :all do
      $ASS = true
      @story  = Story.create :text => "Once upon a time..."
    end

    before do
      Delayed::Job.delete_all
    end

    it "logs job stats for a successful job" do
      @story.send_later(:tell)
      completed = @worker.completed_jobs
      Delayed::Job.work_off
      @worker.completed_jobs.should > completed
    end

    it "logs job stats for a failed job" do
      @story.text = nil
      @story.whatever(1, 2)
      completed = @worker.completed_jobs
      Delayed::Job.work_off
      @worker.completed_jobs.should > completed
    end

    it "starts and ends job for a successful job" do
      job = @story.send_later(:tell)
      @worker.should_receive(:start_job).with(job)
      @worker.should_receive(:end_job).with(job)
      Delayed::Job.work_off
    end

    it "starts and ends job for a failed job" do
      @story.text = nil
      job = @story.whatever(1, 2)
      @worker.should_receive(:start_job).with(job)
      @worker.should_receive(:end_job).with(job)
      Delayed::Job.work_off
    end
  end
end