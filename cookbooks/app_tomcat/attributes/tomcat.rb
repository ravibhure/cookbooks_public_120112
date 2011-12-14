# == Recommended attributes
#
set_unless[:tomcat][:server_name] = "myserver"  
set_unless[:tomcat][:application_name] = "myapp"

# == Optional attributes
#
set_unless[:tomcat][:code][:url] = ""
set_unless[:tomcat][:code][:credentials] = ""
set_unless[:tomcat][:code][:branch] = "master"  
set_unless[:tomcat][:db_adapter] = ""

# this docroot is currently symlinked from /usr/share/tomcat6/webapps
set[:tomcat][:docroot] = "/srv/tomcat6/webapps"

# == Calculated attributes
#

case platform
when "ubuntu", "debian"
  if("#{tomcat[:db_adapter]}" = "mysql")
    set[:db_mysql][:socket] = "/var/run/mysqld/mysqld.sock"
  else
    set[:db_postgres][:socket] = "/var/run/postgresql"
when "centos","fedora","suse","redhat"
  if("#{tomcat[:db_adapter]}" = "mysql")
    set[:tomcat][:package_dependencies] = ["eclipse-ecj",\
                                         "tomcat6",\
                                         "tomcat6-admin-webapps",\
                                         "tomcat6-webapps",\
                                         "tomcat-native",\
                                         "mysql-connector-java"]
  else
    set[:tomcat][:package_dependencies] = ["eclipse-ecj",\
                                         "tomcat6",\
                                         "tomcat6-admin-webapps",\
                                         "tomcat6-webapps",\
                                         "tomcat-native",\
                                         "postgresql-9.1-901.jdbc4"]
  end
  set[:tomcat][:module_dependencies] = [ "proxy", "proxy_http" ]
  set_unless[:tomcat][:app_user] = "tomcat"
  if("#{tomcat[:db_adapter]}" = "mysql")
    set[:tomcat][:socket] = "/var/lib/mysql/mysql.sock"
  else
    set[:tomcat][:socket] = "/var/run/postgresql"
  end	
end
