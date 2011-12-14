# Cookbook Name:: app_php
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

# == Recommended attributes
#
set_unless[:php][:application_name] = "myapp"

# == Optional attributes
#
set_unless[:php][:db_schema_name] = ""     

set_unless[:php][:code][:url] = ""
set_unless[:php][:code][:credentials] = ""
set_unless[:php][:code][:branch] = "master"  
set_unless[:php][:modules_list] = [] 
set_unless[:php][:db_adapter] = ""

# == Calculated attributes
#
#set[:php][:code][:destination] = "/home/webapp/#{php[:application_name]}"

case platform
when "ubuntu", "debian"
  set[:php][:package_dependencies] = ["php5", "php5-mysql", "php5-pgsql", "php-pear", "libapache2-mod-php5"] 
  set[:php][:module_dependencies] = [ "proxy_http", "php5"]
  set_unless[:php][:app_user] = "www-data"
  if("#{php[:db_adapter]}" = "mysql")
    set[:db_mysql][:socket] = "/var/run/mysqld/mysqld.sock"
  else
    set[:db_postgres][:socket] = "/var/run/postgresql"
  end
when "centos","fedora","suse","redhat"
  set[:php][:package_dependencies] = ["php53u", "php53u-mysql", "php53u-pgsql", "php53u-pear", "php53u-zts"]
  set[:php][:module_dependencies] = [ "proxy", "proxy_http" ]
  set_unless[:php][:app_user] = "apache"
  if("#{php[:db_adapter]}" = "mysql")
    set[:db_mysql][:socket] = "/var/lib/mysql/mysql.sock"
  else
    set[:db_postgres][:socket] = "/var/run/postgresql"
  end
end
