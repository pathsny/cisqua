# config valid only for current version of Capistrano
lock '3.11.2'

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
        # system("npm install && npm run build")
      end
    end
end

set :linked_dirs, fetch(:linked_dirs, []).push('data', 'tmp/pids', 'tmp/sockets', 'log')

set :puma_rackup, -> { File.join(current_path, 'web', 'config.ru') }

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5

namespace :deploy do

  def ensure_dir(dir_path)
    unless test("[ -d #{dir_path} ]")
      execute "mkdir -p #{dir_path}"
    end
  end

  namespace :check do
    after :directories, :setup_shared_infra  do
      on roles(:all) do
        data_path = File.join(shared_path, "data")
        ensure_dir File.join(data_path, "db")
        ensure_dir File.join(data_path, "http_anime_info_cache")
        ensure_dir File.join(data_path, "udp_anime_info_cache/lock")


        options_path = File.join(data_path, "options.yml")
        unless test("[ -f #{options_path} ]")
          local_options_bak = File.expand_path('../../script/helpers/options.yml.bak', __FILE__)          puts "coping options #{local_options_bak}"
          upload! local_options_bak, options_path
        end
      end
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
