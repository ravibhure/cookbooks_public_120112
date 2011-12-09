# Copyright (c) 2011 RightScale, Inc, All Rights Reserved Worldwide.
#
# THIS PROGRAM IS CONFIDENTIAL AND PROPRIETARY TO RIGHTSCALE
# AND CONSTITUTES A VALUABLE TRADE SECRET.  Any unauthorized use,
# reproduction, modification, or disclosure of this program is
# strictly prohibited.  Any use of this program by an authorized
# licensee is strictly subject to the terms and conditions,
# including confidentiality obligations, set forth in the applicable
# License Agreement between RightScale.com, Inc. and
# the licensee.
#
# Common class of utils for DB operations
# Ravi Bhure


require 'rubygems'
require 'pg'
require 'system_timer'

require File.dirname(__FILE__) +  '/../common/d_b_utils.rb'

module RightScale
  class DBUtilsPostgresql
    include RightScale::DBUtils

    DBMountPoint = "/mnt/mysql"
    # Filename (from the root of the mysql datafile) where the tools will save the file/position of the master at the point of the backup
    SAVED_MASTER_POS_FILE="rs_snapshot_position.yaml"
    attr_reader :rep_user, :rep_pass, :mycnf_filename, :binlog_prefix

    def initialize(params = {})
      ### Variables
      # MySQL user and password to use at the slave DB to perform replication
      # This needs to match the deltaset that configure the master DB...
      # This user just needs replication access
      @rep_user=params[:rep_user]
      @rep_pass=params[:rep_pass]

      # if running outside runrightscripts.rb, this variable is unset.
      ENV['RS_DISTRO'] = `lsb_release -is`.chomp.downcase unless ENV['RS_DISTRO']

      # Default position of the my.cnf configuration file

