require_relative 'model'

class ScheduledTaskValidator 
  include Veto.validator
end

class ScheduledTaskInstance < Model::Base

  configure_model(
    :type => :scheduled_task,
    :version => 1, 
    :validator => ScheduledTaskValidator,
    :fields => [{
      :name => :id,
      :serialize_to_ui => true,
      :description => 'unique name for each task',
      :mutable => false,
    },{
      :name => :frequency_sec,
      :description => 'how often task should be run',
      :serialize_to_ui => true,
      :mutable => true,
    },{
      :name => :last_run_at,
      :description => 'time at which task last completed',
      :serialize_to_ui => true,
      :mutable => true,
      :default => nil,
    },{
      :name => :running,
      :description => 'currently running task',
      :serialize_to_ui => true,
      :mutable => true,
      :default => false,
    }]
  )

  def initialize(id, frequency_sec)
    super()
    @id = id
    @frequency_sec = frequency_sec
  end
end

ScheduledTask = Model.get_collection(:scheduled_task, 'scheduled_tasks')  