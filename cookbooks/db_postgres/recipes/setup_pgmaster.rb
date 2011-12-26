#
# Cookbook Name:: db_postgres
#
# Copyright RightScale, Inc. All rights reserved.  All access and use subject to the
# RightScale Terms of Service available at http://www.rightscale.com/terms.php and,
# if applicable, other agreements such as a RightScale Master Subscription Agreement.

# == Request postgresql.conf updated
#
db_postgres node[:db_postgres][:datadir] do
  # updates postgresql.conf for replication
  RightScale::Database::PostgreSQL::Helper.configure_postgres_conf(node)

  # Reload postgresql to read new updated postgresql.conf
  RightScale::Database::PostgreSQL::Helper.do_query('select pg_reload_conf()')
end
