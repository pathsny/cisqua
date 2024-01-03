require 'net/scp'
require 'net/ssh'
require 'optparse'
require 'yaml'
require 'solid_assert'
require 'amazing_print'
require 'open3'

# Read settings from file
CONFIG = YAML.load_file(File.expand_path('../data/deploy.yml', __dir__))

class Deploy
  def build_image
    run_command(
      'Building Docker image ...',
      "docker build --platform=linux/amd64 . -t #{CONFIG[:dockerhub_repo]}:#{CONFIG[:image_tag]}",
    )
  end

  def push
    run_command(
      'Pushing Docker image to Docker Hub...',
      "docker push #{CONFIG[:dockerhub_repo]}:#{CONFIG[:image_tag]}",
    )
  end

  def comment(str)
    puts AmazingPrint::Colors.gray(str)
  end

  def local_input(str)
    puts AmazingPrint::Colors.blue(str)
  end

  def remote_output(str)
    puts AmazingPrint::Colors.yellow(str)
  end

  def remote_input(str)
    puts AmazingPrint::Colors.cyan(str)
  end

  def run_remote_command(session, command)
    channel = session.open_channel do |ch|
      ch.on_extended_data do |_c, type, data|
        puts "Error -- type: #{type} data: #{data}\n".red
      end
      ch.on_data do |_c, data|
        if data =~ /password for #{CONFIG[:remote_user]}/
          comment "\tpassword requested ... Sending!"
          channel.send_data("#{CONFIG[:remote_password]}\n")
        else
          yield(channel, data)
        end
      end

      ch.request_pty do |_c, success_pty|
        raise 'could not request pty' unless success_pty

        remote_input(command)
        ch.exec(command) do |_ch, success_exec|
          raise "could not run #{command}" unless success_exec
        end
      end
    end
    channel.wait
  end

  def exec_remote_command(session, command)
    result = nil
    run_remote_command(session, command) do |_channel, data|
      result = data unless data.strip.empty?
    end
    result
  end

  def remote(cmd_types)
    comment 'creating SSH session'
    Net::SSH.start(CONFIG[:remote_host], CONFIG[:remote_user]) do |session|
      run_remote_commands(session, cmd_types)
      session.loop
    end
  end

  def run_remote_commands(session, cmd_types_and_data)
    cmd_types_and_data.each do |cmd_type_and_data|
      cmd_type, *data = cmd_type_and_data.is_a?(Array) ? cmd_type_and_data : [cmd_type_and_data, nil]

      case cmd_type
      when :pull
        comment 'pulling latest docker image'
        exec_remote_command(
          session,
          "sudo docker pull #{CONFIG[:dockerhub_repo]}:#{CONFIG[:image_tag]}",
        )
      when :stop
        comment 'stopping the remote application'
        exec_remote_command(
          session,
          "sudo ~/bin/heavyscript app -x #{CONFIG[:remote_app]}",
        )
      when :start
        comment 'starting the remote application'
        exec_remote_command(
          session,
          "sudo ~/bin/heavyscript app -s #{CONFIG[:remote_app]}",
        )
      when :backup_db
        comment 'backing up the remote db'
        remote_db_file = File.join(CONFIG[:remote_db_location], 'dump.rdb')
        backup_db_file = File.join(CONFIG[:remote_db_location], 'dump.rdb.autobackup')
        exec_remote_command(
          session,
          "cp #{remote_db_file} #{backup_db_file}",
        )
      when :copy_db
        remote_db_file = File.join(CONFIG[:remote_db_location], 'dump.rdb')
        local_db_file = File.expand_path(data.first)
        comment "have to upload #{local_db_file} to #{remote_db_file}"
        Net::SCP.start(CONFIG[:remote_host], CONFIG[:remote_user]) do |scp|
          scp.upload!(local_db_file, remote_db_file)
        end
      when :restart
        comment 'finding deployments'
        result = exec_remote_command(
          session,
          'sudo k3s kubectl get deployments ' \
          "-n #{CONFIG[:remote_namespace]} " \
          '-o custom-columns=:metadata.name --no-headers',
        )
        deployments = result.split("\n")
        assert(deployments.size == 1, 'expecting only one instance')
        deployment = deployments.first.strip
        comment "restarting deployments #{deployment}"
        start_time = Time.now
        exec_remote_command(
          session,
          "sudo k3s kubectl rollout restart deployment/#{deployment} -n #{CONFIG[:remote_namespace]}",
        )
        deployment_succeeded = nil
        run_remote_command(
          session,
          "sudo k3s kubectl rollout status deployment/#{deployment} -n #{CONFIG[:remote_namespace]} --timeout=30s",
        ) do |_rollout_ch, rollout_data|
          if rollout_data =~ /deployment "#{deployment}" successfully rolled out/
            deployment_succeeded = true
            puts rollout_data.green
          elsif rollout_data =~ /error: timed out waiting for the condition/
            puts rollout_data.red
          else
            puts rollout_data.yellowish
          end
        end
        comment 'Printing Logs from container'
        cur_time = Time.now
        run_remote_command(
          session,
          "sudo k3s kubectl logs --since #{cur_time - start_time}s " \
          "-l release=cisqua -n #{CONFIG[:remote_namespace]} --tail=100",
        ) do |_logs_ch, log_data|
          puts log_data
        end
        unless deployment_succeeded
          abort
        end
      when :logs
        run_remote_command(
          session,
          'sudo k3s kubectl logs ' \
          "-l release=cisqua -n #{CONFIG[:remote_namespace]} --tail=100",
        ) do |_logs_ch, log_data|
          puts log_data
        end
      else
        raise "unknown remote command #{cmd_type}"
      end
    end
  end

  def strip_ansi_codes(str)
    str.gsub(/\e\[([;\d]+)?m/, '')
  end

  def run_command(desc, command)
    comment desc
    local_input command
    system("tput setaf 2; #{command}; tput sgr0")
  end
end

options = {
  remote: {},
}
OptionParser.new do |opts|
  opts.banner = 'Usage: deploy.rb [options]'

  opts.on('-b', '--build', 'Build Docker image') do
    options[:build] = true
  end

  opts.on('-p', '--push', 'Push Latest Docker image to Docker Hub') do
    options[:push] = true
  end

  opts.on('-r', '--remote_pull', 'Pull Docker image on remote system') do
    options[:remote][:pull] = true
  end

  opts.on('-t', '--remote_stop', 'Stop deployments in namespace') do
    options[:remote][:stop] = true
  end

  opts.on('-s', '--remote_start', 'Restart deployments in namespace') do
    options[:remote][:start] = true
  end

  opts.on('-a', '--all', 'Entire end to end deployment') do
    options[:all] = true
  end

  opts.on('-l', '--logs', 'Logs from last deployment') do
    options[:remote][:logs] = true
  end

  opts.on('-d', '--push_db DB', 'Shuts down deployment and updates remote db') do |db|
    options[:push_db] = db
  end
end.parse!

if (options.keys.count > 1 || options[:remote].count > 1) && options[:remote][:logs]
  raise 'do not run logs alongside other commands'
end

d = Deploy.new

if options.empty?
  puts 'No command listed'
else
  if options[:all]
    d.build_image
    d.push
    d.remote(%i[pull start])
    exit
  end
  if options[:build]
    d.build_image
  end
  if options[:push]
    d.push
  end
  if options[:push_db]
    d.remote([:stop, :backup_db, [:copy_db, options[:push_db]]])
  end
  unless options[:remote].empty?
    d.remote(options[:remote].keys)
  end
end
