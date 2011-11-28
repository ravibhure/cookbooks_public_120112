# Copyright (c) 2011 RightScale Inc
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

include RightScale::Database::PostgreSQL::Helper

action :stop do
  @db = init(new_resource)
  @db.stop
end

action :start do
  @db = init(new_resource)
  @db.start
end

action :status do
  @db = init(new_resource)
  status = @db.status
  log "Database Status:\n#{status}"
end

action :lock do
  @db = init(new_resource)
  @db.lock
end

action :unlock do
  @db = init(new_resource)
  @db.unlock
end

action :move_data_dir do
  @db = init(new_resource)
  @db.move_datadir
end

action :reset do
  @db = init(new_resource)
  @db.reset
end

action :firewall_update_request do
  sys_firewall "Request database open port 5432 (PostgreSQL) to this server" do
    machine_tag new_resource.machine_tag
    port 5432 
    enable new_resource.enable
    ip_addr new_resource.ip_addr
    action :update_request
  end
end

action :firewall_update do
  sys_firewall "Request database open port 5432 (PostgreSQL) to this server" do
    machine_tag new_resource.machine_tag
    port 5432 
    enable new_resource.enable
    action :update
  end
end

action :write_backup_info do
  masterstatus = Hash.new
  masterstatus = RightScale::Database::PostgreSQL::Helper.do_query(node, 'select pg_last_xlog_receive_location()')
  masterstatus['Master_IP'] = node[:db][:current_master_ip]
  masterstatus['Master_instance_uuid'] = node[:db][:current_master_uuid]
  slavestatus = RightScale::Database::PostgreSQL::Helper.do_query(node, 'select pg_last_xlog_receive_location()')
  slavestatus ||= Hash.new
  if node[:db][:this_is_master]
    Chef::Log.info "Backing up Master info"
  else
    Chef::Log.info "Backing up slave replication status"
    masterstatus['File'] = slavestatus['Relay_Master_Log_File']
    masterstatus['Position'] = slavestatus['Exec_Master_Log_Pos']
  end
  Chef::Log.info "Saving master info...:\n#{masterstatus.to_yaml}"
  ::File.open(::File.join(node[:db][:data_dir], RightScale::Database::PostgreSQL::Helper::SNAPSHOT_POSITION_FILENAME), ::File::CREAT|::File::TRUNC|::File::RDWR) do |out|
    YAML.dump(masterstatus, out)
  end
end

action :pre_restore_check do
  @db = init(new_resource)
  @db.pre_restore_sanity_check
end

action :post_restore_cleanup do
  @db = init(new_resource)
  @db.symlink_datadir("/var/lib/pgsql/9.1/data", node[:db][:data_dir])
  # TODO: used for replication
  # @db.post_restore_sanity_check
  @db.post_restore_cleanup
end

action :pre_backup_check do
  @db = init(new_resource)
  @db.pre_backup_check
end

action :post_backup_cleanup do
  @db = init(new_resource)
  @db.post_backup_steps
end

action :set_privileges do
  priv = new_resource.privilege
  priv_username = new_resource.privilege_username
  priv_password = new_resource.privilege_password
  priv_database = new_resource.privilege_database
  db_mysql_set_privileges "setup db privileges" do
    preset priv
    username priv_username
    password priv_password
    database priv_database
  end
end

action :install_client do

  # Install PostgreSQL 9.1.1 package(s)
  if node[:platform] == "centos"
  
  # Install PostgreSQL GPG Key (http://yum.postgresql.org/9.1/redhat/rhel-5-(arch)/pgdg-centos91-9.1-4.noarch.rpm)
    reporpm = ::File.join(::File.dirname(__FILE__), "..", "files", "centos", "pgdg-centos91-9.1-4.noarch.rpm")
    `rpm --install #{reporpm}`

    # Packages from cookbook files as attachment for PostgreSQL 9.1.1
    packages = ["postgresql91-devel", "postgresql91-libs", "postgresql91", "postgresql91-contrib"  ]
    #packages = ::File.join(::File.dirname(__FILE__), "..", "files", "centos", "#{packages}")
    Chef::Log.info("Packages to install: #{packages.join(",")}")
    packages.each do |p|
      r = package p do
        action :nothing
      end
      r.run_action(:install)
    end

  else

    # Install development library in compile phase
    p = package "postgresql-client-9" do
      package_name value_for_platform(
        "ubuntu" => {
          "9.04" => "postgresql-client-9.1",
          "10.04" => "postgresql-client-9.1"
        },
        "default" => 'postgresql-client-9.1'
      )
      action :nothing
    end
    p.run_action(:install)

    # install client in converge phase
    package "postgresql191-devel" do
      package_name value_for_platform(
        [ "centos", "redhat", "suse" ] => { "default" => "postgresql191-devel" },
        "default" => "postgresql191-devel"
      )
      action :install
    end

  end


  # == Install PostgreSQL client gem
  #
  # Also installs in compile phase
  #
  r = execute "install postgresql gem" do
    command "/opt/rightscale/sandbox/bin/gem install pg --no-rdoc --no-ri -- --build-flags --with-pg-config=/usr/pgsql-9.1/bin/pg_config"
  end
  r.run_action(:run)

  Gem.clear_paths
  log "Gem reload forced with Gem.clear_paths"
end

action :install_server do

  # PostgreSQL server depends on PostgreSQL client
  action_install_client

  # == Install PostgreSQL 9.1 and other packages
  #
  node[:db_postgres][:packages_install].each do |p|
    package p
  end unless node[:db_postgres][:packages_install] == ""

  # Uninstall other packages we don't
  node[:db_postgres][:packages_uninstall].each do |p|
     package p do
       action :remove
     end
  end unless node[:db_postgres][:packages_uninstall] == ""

  service "postgresql-9.1" do
    #service_name value_for_platform([ "centos", "redhat", "suse" ] => {"default" => "postgresql-9.1"}, "default" => "postgresql-9.1")
    supports :status => true, :restart => true, :reload => true
    action :stop
  end

  # Initialize PostgreSQL server and create system tables
  touchfile = ::File.expand_path "~/.postgresql_installed"
  execute "/etc/init.d/postgresql-9.1 initdb" do
    creates touchfile
  end

  # == Configure system for PostgreSQL
  #

  # Stop PostgreSQL
  service "postgresql-9.1" do
    supports :status => true, :restart => true, :reload => true
    action :stop
  end


  # moves postgresql default db to storage location
  touchfile = ::File.expand_path "~/.postgresql_dbmoved"
  ruby_block "clean innodb logfiles" do
    not_if { ::File.exists?(touchfile) }
    block do
      require 'fileutils'
     # remove_files = ::Dir.glob(::File.join(node[:db_postgres][:basedir], 'pgstartup.log*')) + ::Dir.glob(::File.join(node[:db_postgres][:basedir], 'ibdata*'))
      remove_files = ::Dir.glob(::File.join(node[:db_postgres][:basedir], 'pgstartup.log*')) 
      FileUtils.rm_rf(remove_files)
      ::File.open(touchfile,'a'){}
    end
  end


  # Create the archive directory
  directory "/mnt/archive" do
    owner "postgresql"
    group "postgresql"
    mode 0770
    recursive true
  end

  # Setup postgresql.conf
  template_source = "postgresql.conf.erb"

  template value_for_platform([ "centos", "redhat", "suse" ] => {"default" => "{[:db_postgres][:datadir]}/postgresql.conf"}, "default" => "{[:db_postgres][:datadir]}/postgresql.conf") do
    source template_source
    owner "postgres"
    group "postgres"
    mode "0644"
    variables(
      :server_id => mycnf_uuid
    )
    cookbook 'db_postgres'
  end
  
  # Setup pg_hba.conf
  pg_template_source = "pg_hba.conf.erb"  
  
    template value_for_platform([ "centos", "redhat", "suse" ] => {"default" => "#{node[:db_postgres][:datadir]}/pg_hba.conf"}, "default" => "#{node[:db_postgres][:datadir]}/pg_hba.conf") do
    source pg_template_source
    owner "postgres"
    group "postgres"
    mode "0644"
    variables(
      :server_id => mycnf_uuid
    )
    cookbook 'db_postgres'
  end

  # == Setup PostgreSQL user limits
  #
  # Set the postgres and root users max open files to a really large number.
  # 1/3 of the overall system file max should be large enough.  The percentage can be
  # adjusted if necessary.
  #
  postgres_file_ulimit = `sysctl -n fs.file-max`.to_i/33

  template "/etc/security/limits.d/postgres.limits.conf" do
    source "postgres.limits.conf.erb"
    variables({
      :ulimit => postgres_file_ulimit
    })
    cookbook 'db_postgres'
  end

  # Change root's limitations for THIS shell.  The entry in the limits.d will be
  # used for future logins.
  # The setting needs to be in place before postgresql-9 is started.
  #
  execute "ulimit -n #{postgres_file_ulimit}"

  # == Start PostgreSQL
  #
  service "postgresql-9.1" do
    supports :status => true, :restart => true, :reload => true
    action :start
  end

end 

action :setup_monitoring do
  service "collectd" do
    action :nothing
  end

  arch = node[:kernel][:machine]
  arch = "i386" if arch == "i686"

  if node[:platform] == 'centos'

    TMP_FILE = "/tmp/collectd.rpm"

    remote_file TMP_FILE do
      source "collectd-postgresql-4.10.0-4.el5.#{arch}.rpm"
      cookbook 'db_postgres'
    end

    package TMP_FILE do
      source TMP_FILE
    end

    template ::File.join(node[:rs_utils][:collectd_plugin_dir], 'postgresql.conf') do
      backup false
      source "postgresql_collectd_plugin.conf.erb"
      notifies :restart, resources(:service => "collectd")
      cookbook 'db_postgres'
    end

  else

    log "WARNING: attempting to install collectd-postgresql on unsupported platform #{node[:platform]}, continuing.." do
      level :warn
    end

  end
end

action :grant_replication_slave do
  require 'mysql'

  Chef::Log.info "GRANT REPLICATION SLAVE to #{node[:db][:replication][:user]}"
  con = Mysql.new('localhost', 'root')
  con.query("GRANT REPLICATION SLAVE ON *.* TO '#{node[:db][:replication][:user]}'@'%' IDENTIFIED BY '#{node[:db][:replication][:password]}'")
  con.query("FLUSH PRIVILEGES")
  con.close
end

action :promote do
  
  x = node[:db_mysql][:log_bin]
  logbin_dir = x.gsub(/#{::File.basename(x)}$/, "")
  directory logbin_dir do
    action :create
    recursive true
    owner 'mysql'
    group 'mysql'
  end

  # Set read/write in my.cnf
  node[:db_mysql][:tunable][:read_only] = 0
  # Enable binary logging in my.cnf
  node[:db_mysql][:log_bin_enabled] = true

  template value_for_platform([ "centos", "redhat", "suse" ] => {"default" => "/etc/my.cnf"}, "default" => "/etc/mysql/my.cnf") do
    source "my.cnf.erb"
    owner "root"
    group "root"
    mode "0644"
    variables(
      :server_id => mycnf_uuid
    )
    cookbook 'db_mysql'
  end
  
  service "mysql" do
    action :start
    only_if do
      log_bin = RightScale::Database::MySQL::Helper.do_query(node, "show variables like 'log_bin'", 'localhost', RightScale::Database::MySQL::Helper::DEFAULT_CRITICAL_TIMEOUT)
      if log_bin['Value'] == 'OFF'
	Chef::Log.info "Detected binlogs were disabled, restarting service to enable them for Master takeover."
	true
      else
	false
      end
    end
  end

  RightScale::Database::MySQL::Helper.do_query(node, "SET GLOBAL READ_ONLY=0", 'localhost', RightScale::Database::MySQL::Helper::DEFAULT_CRITICAL_TIMEOUT)
  newmasterstatus = RightScale::Database::MySQL::Helper.do_query(node, 'SHOW SLAVE STATUS', 'localhost', RightScale::Database::MySQL::Helper::DEFAULT_CRITICAL_TIMEOUT)
  previous_master = node[:db][:current_master_ip]
  raise "FATAL: could not determine master host from slave status" if previous_master.nil?
  Chef::Log.info "host: #{previous_master}}"
  #Chef::Log.info "host: #{previous_master} user: #{node[:db][:admin][:user]}, pass: #{node[:db][:admin][:password]}"

  # PHASE1: contains non-critical old master operations, if a timeout or
  # error occurs we continue promotion assuming the old master is dead.
  begin
    # OLDMASTER: query with terminate (STOP SLAVE)
    RightScale::Database::MySQL::Helper.do_query(node, 'STOP SLAVE', previous_master, RightScale::Database::MySQL::Helper::DEFAULT_CRITICAL_TIMEOUT, 2)

    # OLDMASTER: flush_and_lock_db
    RightScale::Database::MySQL::Helper.do_query(node, 'FLUSH TABLES WITH READ LOCK', previous_master, 5, 12)


    # OLDMASTER:
    masterstatus = RightScale::Database::MySQL::Helper.do_query(node, 'SHOW MASTER STATUS', previous_master, RightScale::Database::MySQL::Helper::DEFAULT_CRITICAL_TIMEOUT)

    # OLDMASTER: unconfigure source of replication
    RightScale::Database::MySQL::Helper.do_query(node, "CHANGE MASTER TO MASTER_HOST=''", previous_master, RightScale::Database::MySQL::Helper::DEFAULT_CRITICAL_TIMEOUT)

    master_file=masterstatus['File']
    master_position=masterstatus['Position']
    Chef::Log.info "Retrieved master info...File: " + master_file + " position: " + master_position

    Chef::Log.info "Waiting for slave to catch up with OLDMASTER (if alive).."
    # NEWMASTER localhost:
    RightScale::Database::MySQL::Helper.do_query(node, "SELECT MASTER_POS_WAIT('#{master_file}',#{master_position})")
  rescue => e
    Chef::Log.info "WARNING: caught exception #{e} during non-critical operations on the OLD MASTER"
  end

  # PHASE2: reset and promote this slave to master
  # Critical operations on newmaster, if a failure occurs here we allow it to halt promote operations
  Chef::Log.info "Promoting slave.."
  RightScale::Database::MySQL::Helper.do_query(node, 'RESET MASTER')

  newmasterstatus = RightScale::Database::MySQL::Helper.do_query(node, 'SHOW MASTER STATUS')
  newmaster_file=newmasterstatus['File']
  newmaster_position=newmasterstatus['Position']
  Chef::Log.info "Retrieved new master info...File: " + newmaster_file + " position: " + newmaster_position

  Chef::Log.info "Stopping slave and misconfiguring master"
  RightScale::Database::MySQL::Helper.do_query(node, "STOP SLAVE")
  RightScale::Database::MySQL::Helper.do_query(node, "CHANGE MASTER TO MASTER_HOST=''")
  action_grant_replication_slave
  RightScale::Database::MySQL::Helper.do_query(node, 'SET GLOBAL READ_ONLY=0')

  # PHASE3: more non-critical operations, have already made assumption oldmaster is dead
  begin
    unless previous_master.nil?
      #unlocking oldmaster
      RightScale::Database::MySQL::Helper.do_query(node, 'UNLOCK TABLES', previous_master)
      SystemTimer.timeout_after(RightScale::Database::MySQL::Helper::DEFAULT_CRITICAL_TIMEOUT) do
	#demote oldmaster
        Chef::Log.info "Calling reconfigure replication with host: #{previous_master} ip: #{node[:cloud][:private_ips][0]} file: #{newmaster_file} position: #{newmaster_position}"
	RightScale::Database::MySQL::Helper.reconfigure_replication(node, previous_master, node[:cloud][:private_ips][0], newmaster_file, newmaster_position)
      end
    end
  rescue Timeout::Error => e
    Chef::Log.info("WARNING: rescuing SystemTimer exception #{e}, continuing with promote")
  rescue => e
    Chef::Log.info("WARNING: rescuing exception #{e}, continuing with promote")
  end
end


action :enable_replication do

  ruby_block "wipe_existing_runtime_config" do
    block do
      Chef::Log.info "Wiping existing runtime config files"
      data_dir = ::File.join(node[:db][:data_dir], 'mysql')
      files_to_delete = [ "master.info","relay-log.info","mysql-bin.*","*relay-bin.*"]
      files_to_delete.each do |file|
        expand = Dir.glob(::File.join(data_dir,file))
        unless expand.empty?
        	expand.each do |exp_file|
        	  FileUtils.rm_rf(exp_file)
        	end
        end
      end
    end
  end

  # disable binary logging
  node[:db_mysql][:log_bin_enabled] = false

  # we refactored setup_my_cnf into db::install_server, we might want to break that out again?
  # Setup my.cnf
  template_source = "my.cnf.erb"

  template value_for_platform([ "centos", "redhat", "suse" ] => {"default" => "/etc/my.cnf"}, "default" => "/etc/mysql/my.cnf") do
    source template_source
    owner "root"
    group "root"
    mode "0644"
    variables(
      :server_id => mycnf_uuid
    )
    cookbook 'db_mysql'
  end

  # empty out the binary log dir
  directory ::File.dirname(node[:db_mysql][:log_bin]) do
    action [:delete, :create]
    recursive true
    owner 'mysql'
    group 'mysql'
  end

  # ensure_db_started
  # service provider uses the status command to decide if it
  # has to run the start command again.
  10.times do
    service "mysql" do
      action :start
    end
  end

  # checks for valid backup and that current master matches backup
  ruby_block "validate_backup" do
    block do
      master_info = RightScale::Database::MySQL::Helper.load_replication_info(node)
      raise "Position and file not saved!" unless master_info['Master_instance_uuid']
      # Check that the snapshot is from the current master or a slave associated with the current master
      if master_info['Master_instance_uuid'] != node[:db][:current_master_uuid]
        raise "FATAL: snapshot was taken from a different master! snap_master was:#{master_info['Master_instance_uuid']} != current master: #{node[:db][:current_master_uuid]}"
      end
    end
  end

  ruby_block "reconfigure_replication" do
    block do
      master_info = RightScale::Database::MySQL::Helper.load_replication_info(node)
      newmaster_host = master_info['Master_IP']
      newmaster_logfile = master_info['File']
      newmaster_position = master_info['Position'] 
      RightScale::Database::MySQL::Helper.reconfigure_replication(node, 'localhost', newmaster_host, newmaster_logfile, newmaster_position)
    end
  end

  ruby_block "do_query" do
    block do
      RightScale::Database::MySQL::Helper.do_query(node, "SET GLOBAL READ_ONLY=1")
    end
  end

  node[:db_mysql][:tunable][:read_only] = 1
  template value_for_platform([ "centos", "redhat", "suse" ] => {"default" => "/etc/my.cnf"}, "default" => "/etc/mysql/my.cnf") do
    source template_source
    owner "root"
    group "root"
    mode "0644"
    variables(
      :server_id => mycnf_uuid
    )
    cookbook 'db_mysql'
  end
end
