#
# Cookbook Name:: db_postgres
# Definition:: do_dump_export
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


temp_dir = node[:db_postgres][:tmpdir]
schema_name = node[:db_postgres][:dump][:schema_name]

cloud = node[:db_postgres][:dump][:storage_account_provider] unless node[:db_postgres][:dump][:storage_account_provider] == ""
cloud ||= node[:cloud][:provider]

container = node[:db_postgres][:dump][:container]
prefix = node[:db_postgres][:dump][:prefix]
dumpfile = "#{temp_dir}/#{prefix}.gz"

bash "Write the postgres DB backup file" do
  user 'postgres'
      code <<-EOH
      pg_dump #{schema_name} | gzip -c > #{dumpfile}
      EOH
end

key = "#{prefix}-#{Time.now.strftime("%Y%m%d%H%M")}.gz"

execute "Upload PostgreSQL dumpfile to Remote Object Store" do
  command "/opt/rightscale/sandbox/bin/mc_sync.rb put --cloud #{cloud} " +
          "--container #{container} --dest #{key} --source #{dumpfile}"
  environment ({
    'STORAGE_ACCOUNT_ID' => node[:db_postgres][:dump][:storage_account_id],
    'STORAGE_ACCOUNT_SECRET' => node[:db_postgres][:dump][:storage_account_secret],
  })

end
