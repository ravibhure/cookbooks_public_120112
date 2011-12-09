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

action :write_backup_info do
  masterstatus = Hash.new
  masterstatus = RightScale::Database::PostgreSQL::Helper.do_query(node, 'SHOW MASTER STATUS')
  masterstatus['Master_IP'] = node[:db][:current_master_ip]
  masterstatus['Master_instance_uuid'] = node[:db][:current_master_uuid]
  slavestatus = RightScale::Database::PostgreSQL::Helper.do_query(node, 'SHOW SLAVE STATUS')
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
  @db.symlink_datadir("/var/lib/pgsql", node[:db][:data_dir])
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
  db_postgres_set_privileges "setup db privileges" do
    preset priv
    username priv_username
    password priv_password
    database priv_database
  end
end

action :install_client do

  # Install PostgreSQL 9.1.1 package(s)
  if node[:platform] == "centos"
  arch = node[:kernel][:machine]
  arch = "x86_64" if arch == "i386" 

  # Install PostgreSQL GPG Key (http://yum.postgresql.org/9.1/redhat/rhel-5-(arch)/pgdg-centos91-9.1-4.noarch.rpm)
    pgreporpm = ::File.join(::File.dirname(__FILE__), "..", "files", "centos", "pgdg-centos91-9.1-4.noarch.rpm")
    `rpm -ihv #{pgreporpm}`

    #Installing Libxslt package for postgresql-9.1 dependancy
    package "libxslt" do
      action :install
    end

  # Packages from cookbook files as attachment for PostgreSQL 9.1.1
  # Install PostgreSQL client rpm
    pgdevelrpm = ::File.join(::File.dirname(__FILE__), "..", "files", "centos", "postgresql91-devel-9.1.1-1PGDG.rhel5.#{arch}.rpm")
    pglibrpm = ::File.join(::File.dirname(__FILE__), "..", "files", "centos", "postgresql91-libs-9.1.1-1PGDG.rhel5.#{arch}.rpm")
    pgrpm = ::File.join(::File.dirname(__FILE__), "..", "files", "centos", "postgresql91-9.1.1-1PGDG.rhel5.#{arch}.rpm")
	`rpm -ivh --nodeps #{pgrpm}`

  package "#{pglibrpm}" do
    action :install
    source "#{pglibrpm}"
    provider Chef::Provider::Package::Rpm
  end

  package "#{pgdevelrpm}" do
    action :install
    source "#{pgdevelrpm}"
    provider Chef::Provider::Package::Rpm
  end

  else

    # Currently supports CentOS in future will support others
    
  end

  # == Install PostgreSQL client gem
  #
  # Also installs in compile phase
  #
  #r = execute "install pg gem" do
  #  command "/opt/rightscale/sandbox/bin/gem install pg -- --with-pg-config=/usr/pgsql-9.1/bin/pg_config"
  #end
  #r.run_action(:run)
  execute "install pg gem" do
    command "/opt/rightscale/sandbox/bin/gem install pg -- --with-pg-config=/usr/pgsql-9.1/bin/pg_config"
  end

end

action :install_server do

  # PostgreSQL server depends on PostgreSQL client
  action_install_client

  arch = node[:kernel][:machine]
  arch = "x86_64" if arch == "i386"

  # Install PostgreSQL 9.1 server rpm
    pgserverrpm = ::File.join(::File.dirname(__FILE__), "..", "files", "centos", "postgresql91-server-9.1.1-1PGDG.rhel5.#{arch}.rpm")
  # Install PostgreSQL contrib rpm
     pgcontribpkg =  ::File.join(::File.dirname(__FILE__), "..", "files", "centos", "postgresql91-contrib-9.1.1-1PGDG.rhel5.#{arch}.rpm")
  # Install uuid package to resolve postgresql-contrib package  
  uuidrpm = ::File.join(::File.dirname(__FILE__), "..", "files", "centos", "uuid-1.5.1-4.rhel5.#{arch}.rpm")

  package "#{pgserverrpm}" do
    action :install
    source "#{pgserverrpm}"
    provider Chef::Provider::Package::Rpm
  end

  package "#{uuidrpm}" do
    action :install
    source "#{uuidrpm}"
    provider Chef::Provider::Package::Rpm
  end

  package "#{pgcontribpkg}" do
    action :install
    source "#{pgcontribpkg}"
    provider Chef::Provider::Package::Rpm
  end  


  service "postgresql-9.1" do
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


  # Create the Socket directory
  # directory "/var/run/postgresql" do
  directory "#{node[:db_postgres][:socket]}" do
    owner "postgres"
    group "postgres"
    mode 0770
    recursive true
  end


  # Setup postgresql.conf
  template "#{node[:db_postgres][:confdir]}/postgresql.conf" do
    source "postgresql.conf.erb"
    owner "postgres"
    group "postgres"
    mode "0644"
    cookbook 'db_postgres'
  end

  # Setup pg_hba.conf
  template "#{node[:db_postgres][:confdir]}/pg_hba.conf" do
    source "pg_hba.conf.erb"
    owner "postgres"
    group "postgres"
    mode "0644"
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

action :grant_replication_slave do
  require 'rubygems'
  Gem.clear_paths
  require 'pg'
  admin_role = node[:db_postgres][:admin_role]
  
  Chef::Log.info "GRANT REPLICATION SLAVE to #{node[:db][:replication][:user]}"
  # Opening connection for pg operation
  conn = PGconn.open("localhost", nil, nil, nil, nil, "postgres", nil)
  
  # Enable admin/replication user
  conn.exec("CREATE USER #{node[:db][:replication][:user]} ENCRYPTED PASSWORD '#{node[:db][:replication][:password]}'")
  # Grant role previleges to admin/replication user
  conn.exec("GRANT #{admin_role} TO #{node[:db][:replication][:user]}")
  conn.close
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

    # install the postgres_ps collectd script into the collectd library plugins directory
    remote_file ::File.join(node[:rs_utils][:collectd_lib], "plugins", 'postgres_ps') do
      source "postgres_ps"
      mode "0755"
      cookbook 'db_postgres'
    end

    # add a collectd config file for the postgres_ps script with the exec plugin and restart collectd if necessary
    template ::File.join(node[:rs_utils][:collectd_plugin_dir], 'postgres_ps.conf') do
      source "postgres_collectd_exec.erb"
      notifies :restart, resources(:service => "collectd")
      cookbook 'db_postgres'
    end

  else

    log "WARNING: attempting to install collectd-postgresql on unsupported platform #{node[:platform]}, continuing.." do
      level :warn
    end

  end
end

action :generate_dump_file do

  db_name     = new_resource.db_name
  dumpfile    = new_resource.dumpfile
  
  bash "Write the postgres DB backup file" do
      user 'postgres'
      code <<-EOH
      pg_dump -h /var/run/postgresql #{db_name} | gzip -c > #{dumpfile}
      EOH
  end


end

action :restore_from_dump_file do

  db_name     = new_resource.db_name
  dumpfile    = new_resource.dumpfile

  log "  Check if DB already exists"
  ruby_block "checking existing db" do
    block do
      db_check = `echo "select datname from pg_database" | psql -U postgres -h /var/run/postgresql | grep -q  "#{db_name}"`
      if ! db_check.empty?
        raise "ERROR: database '#{db_name}' already exists"
      end
    end
  end

  bash "Import MySQL dump file: #{dumpfile}" do
    user "postgres"
    code <<-EOH
      set -e
      if [ ! -f #{dumpfile} ]
      then
        echo "ERROR: PostgreSQL dumpfile not found! File: '#{dumpfile}'"
        exit 1
      fi
      createdb -U postgres -h /var/run/postgresql #{db_name}
      gunzip < #{dumpfile} | psql -U postgres -h /var/run/postgresql #{db_name}
    EOH
  end
  
end
