#!/bin/sh

. /etc/rc.subr

name="webserver"

extra_commands="status"

start_cmd="${name}_start"
stop_cmd="${name}_stop"
restart_cmd="${name}_restart"
status_cmd="${name}_status"

webserver_start()
{
  cd /anidb/current
  /usr/local/bin/bundle exec ruby script/daemon.rb start
}

webserver_stop()
{
  cd /anidb/current
  /usr/local/bin/bundle exec ruby script/daemon.rb stop
}

webserver_restart()
{
  cd /anidb/current
  /usr/local/bin/bundle exec ruby script/daemon.rb restart
}

webserver_status()
{
  cd /anidb/current
  /usr/local/bin/bundle exec ruby script/daemon.rb status
}


run_rc_command "$1"