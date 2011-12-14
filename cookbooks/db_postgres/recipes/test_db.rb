# Cookbook Name:: db_postgres
# Recipe:: test_db
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


#
# Script to download and restore sample database 'booktown' db in to postgres
# Ravi Bhure
# 
log "download and restore sample database 'booktown' db"

dumpfile = /tmp/baooktown.sql

bash "download and restore sample database" download  do
    code <<-EOF
      # Downloading #{dumpfile}
      log "Downloading #{dumpfile}......"
      wget http://www.commandprompt.com/ppbook/booktown.sql  -O #{dumpfile}
      set -e
      if [ ! -f #{dumpfile} ]
      then
        echo "ERROR: PostgreSQL sample database file not found! File: '#{dumpfile}'"
        exit 1
      fi
      psql -h /var/run/postgresql -U postgres < #{dumpfile}
    EOF
end
