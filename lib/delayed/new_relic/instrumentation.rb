Delayed::Job.class_eval do
  include NewRelic::Agent::Instrumentation::ControllerInstrumentation
  add_transaction_tracer "invoke_job", :category => :task, :force => true
end
