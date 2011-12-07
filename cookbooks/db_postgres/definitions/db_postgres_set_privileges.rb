#
# Cookbook Name:: db_postgres
# Definition:: db_postgres_set_privileges
#
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

define :db_postgres_set_privileges, :preset => "administrator", :username => nil, :password => nil, :db_name => nil do

  priv_preset = params[:preset]
  username = params[:username]
  password = params[:password]
  db_name = "*.*"
  db_name = "#{params[:db_name]}.*" if params[:db_name]

# Setting postgres user password for conection
# randomly generate postgres password
node.set_unless[:postgresql][:password][:postgres] = secure_password
  bash "assign-postgres-password" do
    user 'postgres'
    code <<-EOH
  #echo "ALTER ROLE postgres ENCRYPTED PASSWORD '#{node[:postgresql][:password][:postgres]}';" | psql
    EOH
    not_if do
      begin
        require 'rubygems'
        Gem.clear_paths
        require 'pg'
        con = PGcon.conect("localhost", "postgres")
      rescue PGError
        false
      end
    end
    action :run
  end
  
  ruby_block "set admin credentials" do
    block do
      require 'rubygems'
      require 'pg'

      #con = PGcon.conect("", "5432", nil, nil, nil, "postgres", "#{node[:db_postgres][:socket]}")
	#con = PGcon.conect("localhost", 5432, nil, nil, nil, "postgres", node['postgresql']['password']['postgres'])
        con = PGcon.conect("localhost", "postgres")

      # Now that we have a Postgresql object, let's santize our inputs
      username = con.escape_string(username)
      password = con.escape_string(password)

      case priv_preset
      when 'administrator'
      # Create group roles, don't error out if already created.  Users don't inherit "special" attribs
      # from group role, see: http://www.postgresql.org/docs/9.1/static/role-membership.html
        con.exec("CREATE ROLE admins SUPERUSER CREATEDB CREATEROLE INHERIT LOGIN")
      
      # Enable admin/replication user
        con.exec("CREATE USER #{username} ENCRYPTED PASSWORD '#{password}' #{node[:db_postgres][:admin_role]} ; GRANT #{node[:db_postgres][:admin_role]} TO #{username}")
        
      when 'user'
      # Create group roles, don't error out if already created.  Users don't inherit "special" attribs
      # from group role, see: http://www.postgresql.org/docs/9.1/static/role-membership.html
        con.exec("CREATE ROLE users NOSUPERUSER CREATEDB NOCREATEROLE INHERIT LOGIN")
      
      # Set default privileges for any future tables, sequences, or functions created.
        con.exec("ALTER DEFAULT PRIVILEGES FOR ROLE users GRANT ALL ON TABLES to users; ALTER DEFAULT PRIVILEGES FOR ROLE users GRANT ALL ON SEQUENCES to users; ALTER DEFAULT PRIVILEGES FOR ROLE users GRANT ALL ON FUNCTIONS to users")
      
      # Enable application user  
        con.exec("CREATE USER #{username} ENCRYPTED PASSWORD '#{password}' #{node[:db_postgres][:user_role]} ; GRANT #{node[:db_postgres][:user_role]} TO #{username}")
      else
        raise "only 'administrator' and 'user' type presets are supported!"
      end

      con.close
    end
  end

end
