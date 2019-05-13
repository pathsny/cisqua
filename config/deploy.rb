# config valid only for current version of Capistrano
lock '3.11.0'

set :application, 'anidb'
set :repo_url, '.'

# Default branch is :master
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp
set :branch, 'develop'

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to, '/anidb_ruby'

set :rbenv_type, :user
set :rbenv_ruby, File.read('.ruby-version').strip

# Default value for :scm is :git
set :scm, :rsync
set :rsync_options, %w[
  --recursive --delete --delete-excluded
  --include /web/public/build/
  --include /web/public/index.html
  --include /web/public/favicon.production.ico
  --exclude .git*
  --exclude /data
  --exclude /config
  --exclude /web/public/*
  --exclude .gitignore
  --exclude .rspec
]

namespace :rsync do
    # Create an empty task to hook with. Implementation will be come next
    task :stage_done

    # Then add your hook
    after :stage_done, :precompile do
      public_dir = File.expand_path(File.join(fetch(:rsync_stage), 'web/public'))
      shared_node_modules_dir = File.expand_path(File.join(fetch(:rsync_stage), '../node_modules'))
      current_node_modules_dir = File.expand_path(File.join(public_dir, 'node_modules'))

      Dir.chdir public_dir do
        FileUtils.mkdir_p shared_node_modules_dir
        File.symlink(shared_node_modules_dir, current_node_modules_dir) unless File.symlink?(current_node_modules_dir)
        system("npm install && npm run build")
      end
    end
end

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: 'log/capistrano.log', color: :auto, truncate: :auto

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
# set :linked_files, fetch(:linked_files, []).push('config/database.yml', 'config/secrets.yml')

# Default value for linked_dirs is []
set :linked_dirs, fetch(:linked_dirs, []).push('data', 'tmp/pids', 'tmp/sockets', 'log')

set :puma_rackup, -> { File.join(current_path, 'web', 'config.ru') }

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5

namespace :deploy do

  def ensure_dir(dir_path)
    unless test(dir_path)
      execute "mkdir -p #{dir_path}"
    end
  end


  after :check, :create_directories do
    on roles(:app) do
      ensure_dir File.join(shared_path, "data/db")
      ensure_dir File.join(shared_path, "data/http_anime_info_cache")
      ensure_dir File.join(shared_path, "data/udp_anime_info_cache/lock")
    end
  end

  after :restart, :clear_cache do
    on roles(:app), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end

end


desc "Check that we can access everything"
task :check_write_permissions do
  on roles(:all) do |host|
    if test("[ -w #{fetch(:deploy_to)} ]")
      info "#{fetch(:deploy_to)} is writable on #{host}"
    else
      error "#{fetch(:deploy_to)} is not writable on #{host}"
    end
  end
end

# lib/capistrano/tasks/agent_forwarding.rake
desc "Check if agent forwarding is working"
task :forwarding do
  on roles(:all) do |h|
    if test("env | grep SSH_AUTH_SOCK")
      info "Agent forwarding is up to #{h}"
    else
      error "Agent forwarding is NOT up to #{h}"
    end
  end
end
