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

define :db_postgres_set_privileges, :preset => "administrator", :username => nil, :password => nil, :db_name => nil, :admin_name => "admins", :user_name => "user" do 


  priv_preset = params[:preset]
  username = params[:username]
  password = params[:password]
  db_name = "*.*"
  db_name = "#{params[:db_name]}.*" if params[:db_name]
  admin_name = params[:admin_name]
  user_name = params[:user_name]

  ruby_block "set admin credentials" do
    block do
      require 'rubygems'
      require 'pg'

	con = PGconn.open("localhost", nil, nil, nil, nil, "postgres", nil)

      # Now that we have a Postgresql object, let's santize our inputs
      username = con.escape_string(username)
      password = con.escape_string(password)

      case priv_preset
      when 'administrator'
      # Create group roles, don't error out if already created.  Users don't inherit "special" attribs
      # from group role, see: http://www.postgresql.org/docs/9.1/static/role-membership.html
        con.exec("CREATE ROLE #{admin_role} SUPERUSER CREATEDB CREATEROLE INHERIT LOGIN")
      
      # Enable admin/replication user
        con.exec("CREATE USER #{username} ENCRYPTED PASSWORD '#{password}'}")
        
      # Grant role previleges to admin/replication user
        con.exec("GRANT #{admin_role} TO #{username}")

      when 'user'
      # Create group roles, don't error out if already created.  Users don't inherit "special" attribs
      # from group role, see: http://www.postgresql.org/docs/9.1/static/role-membership.html
        con.exec("CREATE ROLE #{user_role} NOSUPERUSER CREATEDB NOCREATEROLE INHERIT LOGIN")
      
      # Set default privileges for any future tables, sequences, or functions created.
        con.exec("ALTER DEFAULT PRIVILEGES FOR ROLE #{user_role} GRANT ALL ON TABLES to #{user_role}")
        con.exec("ALTER DEFAULT PRIVILEGES FOR ROLE #{user_role} GRANT ALL ON SEQUENCES to #{user_role}")
        con.exec("ALTER DEFAULT PRIVILEGES FOR ROLE #{user_role} GRANT ALL ON FUNCTIONS to #{user_role}")
      
      # Enable application user  
        con.exec("CREATE USER #{username} ENCRYPTED PASSWORD '#{password}' #{user_role} ; GRANT #{user_role} TO #{username}")
      else
        raise "only 'administrator' and 'user' type presets are supported!"
      end

      con.close
    end
  end

end
