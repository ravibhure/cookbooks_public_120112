# Cookbook Name:: db_postgres
#
# Copyright 2011, RightScale, Inc.
#
# All rights reserved - Do Not Redistribute
#

set_unless[:db_postgres][:backup][:slave][:max_allowed_lag] = 60

