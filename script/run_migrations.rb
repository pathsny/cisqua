require File.expand_path('../lib/libs', __dir__)

module Cisqua
  class RunMigrations
    def run
      LifeCycle.instance.setup_registry
      LifeCycle.instance.run_migrations
    end
  end
end

Cisqua::RunMigrations.new.run
