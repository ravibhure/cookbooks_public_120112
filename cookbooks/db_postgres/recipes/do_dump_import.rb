#
# Cookbook Name:: db_postgres
# Definition:: do_dump_import
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

skip, reason = true, "DB schema name not provided"           if node[:db_postgres][:dump][:schema_name] == ""
skip, reason = true, "Prefix not provided"                   if node[:db_postgres][:dump][:prefix] == ""
skip, reason = true, "Storage account provider not provided" if node[:db_postgres][:dump][:storage_account_provider] == ""
skip, reason = true, "Container not provided"                if node[:db_postgres][:dump][:container] == ""

if skip
  log "Skipping import: #{reason}"
else

  temp_dir = node[:db_postgres][:tmpdir]
  schema_name = node[:db_postgres][:dump][:schema_name]

  cloud = node[:db_postgres][:dump][:storage_account_provider] unless node[:db_postgres][:dump][:storage_account_provider] == ""
  cloud ||= node[:cloud][:provider]

  container = node[:db_postgres][:dump][:container]
  prefix = node[:db_postgres][:dump][:prefix]
  dumpfile = "#{temp_dir}/#{prefix}.gz"

  execute "Download PostgreSQL dumpfile from Remote Object Store" do
    command "/opt/rightscale/sandbox/bin/mc_sync.rb get --cloud #{cloud} " +
            "--container #{container} --source #{prefix} " +
            "--latest --dest #{dumpfile}"
    creates dumpfile
    environment ({
      'STORAGE_ACCOUNT_ID' => node[:db_postgres][:dump][:storage_account_id],
      'STORAGE_ACCOUNT_SECRET' => node[:db_postgres][:dump][:storage_account_secret],
    })

  end

#TODO Log if import skipped
  bash "Import PostgreSQL dump file: #{dumpfile}" do
    not_if "echo \"select datname from pg_database\" | psql | grep -q  \"^#{schema_name}$\""
    user "postgres"
    cwd temp_dir
    code <<-EOH
      set -e
      if [ ! -f #{dumpfile} ]
      then
        echo "ERROR: PostgreSQL dumpfile not found! File: '#{dumpfile}'"
        exit 1
      fi
      createdb #{schema_name}
      gunzip < #{dumpfile} | psql #{schema_name}
    EOH
  end

end
rs_utils_marker :end
