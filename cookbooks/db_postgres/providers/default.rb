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


action :install_client do

  # Install PostgreSQL 9.1.1 package(s)
  if node[:platform] == "centos"
  arch = node[:kernel][:machine]
  arch = "x86_64" if arch == "i386"

  # Install PostgreSQL GPG Key (http://yum.postgresql.org/9.1/redhat/rhel-5-(arch)/pgdg-centos91-9.1-4.noarch.rpm)
    pgreporpm = ::File.join(::File.dirname(__FILE__), "..", "files", "centos", "pgdg-centos91-9.1-4.noarch.rpm")
    `rpm -ihv #{pgreporpm}`

  # Packages from cookbook files as attachment for PostgreSQL 9.1.1
  # Install PostgreSQL client rpm
    pgdevelrpm = ::File.join(::File.dirname(__FILE__), "..", "files", "centos", "postgresql91-devel-9.1.1-1PGDG.rhel5.#{arch}.rpm")
    `yum -y localinstall #{pgdevelrpm}`

  else

    # Currently supports CentOS in future will support others
    
  end

  # == Install PostgreSQL client gem
  #
  # Also installs in compile phase
  #
  r = execute "install pg gem" do
    command "/opt/rightscale/sandbox/bin/gem install pg -- --with-pg-config=/usr/pgsql-9.1/bin/pg_config"
  end
  r.run_action(:run)

  Gem.clear_paths
  log "Gem reload forced with Gem.clear_paths"
end

action :install_server do

  # PostgreSQL server depends on PostgreSQL client
  action_install_client

  arch = node[:kernel][:machine]
  arch = "x86_64" if arch == "i386"

  # Install PostgreSQL 9.1 server rpm
    pgserverrpm = ::File.join(::File.dirname(__FILE__), "..", "files", "centos", "postgresql91-server-9.1.1-1PGDG.rhel5.#{arch}.rpm")
    `yum -y localinstall #{pgserverrpm}`

  # Install PostgreSQL contrib rpm
     pgcontribpkg =  ::File.join(::File.dirname(__FILE__), "..", "files", "centos", "postgresql91-contrib-9.1.1-1PGDG.rhel5.#{arch}.rpm")
    `yum -y localinstall #{pgcontribpkg}`


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


  # Create the Socket directory
  # directory "/var/run/postgresql" do
  directory "#{node[:db_postgres][:socket]}" do
    owner "postgres"
    group "postgres"
    mode 0770
    recursive true
  end


  # Setup postgresql.conf
  template_source = "postgresql.conf.erb"

  template value_for_platform([ "centos", "redhat", "suse" ] => {"default" => "#{node[:db_postgres][:confdir]}/postgresql.conf"}, "default" => "#{node[:db_postgres][:confdir]}/postgresql.conf") do
    source template_source
    owner "postgres"
    group "postgres"
    mode "0644"
    cookbook 'db_postgres'
  end

  # Setup pg_hba.conf
  pg_hba_source = "pg_hba.conf.erb"

  template value_for_platform([ "centos", "redhat", "suse" ] => {"default" => "#{node[:db_postgres][:confdir]}/pg_hba.conf"}, "default" => "#{node[:db_postgres][:confdir]}/pg_hba.conf") do
    source pg_hba_source
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
