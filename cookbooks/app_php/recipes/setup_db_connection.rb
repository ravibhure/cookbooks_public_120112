# Cookbook Name:: app_php
# Recipe:: setup_db_connection
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

rs_utils_marker :begin

# == Setup PHP Database Connection
#
# Make sure config dir exists
directory File.join(node[:web_apache][:docroot], "config") do
  recursive true 
  owner node[:php][:app_user]
  group node[:php][:app_user]
end

db_adapter = node[:php][:db_adapter]
# runs only on db_adapter selection
if db_adapter == "mysql"
  # Tell MySQL to fill in our connection template
  db_mysql_connect_app File.join(node[:web_apache][:docroot], "config", "db.php") do
    template "db.php.erb"
    cookbook "app_php"
    database node[:php][:db_schema_name]
    owner node[:php][:app_user]
    group node[:php][:app_user]
  end
else
  # Tell PostgreSQL to fill in our connection template
  db_postgres_connect_app File.join(node[:web_apache][:docroot], "config", "db.php") do
    template "db.php.erb"
    cookbook "app_php"
    database node[:php][:db_schema_name]
    owner node[:php][:app_user]
    group node[:php][:app_user]
  end
end 

rs_utils_marker :end
