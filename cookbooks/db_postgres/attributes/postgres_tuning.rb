# Cookbook Name:: db_postgres
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

if platform == "centos"
  set_unless[:db_postgres][:tunable][:shared_buffers] = "32MB"
  set_unless[:db_postgres][:tunable][:max_connections] = "800"
else
  set_unless[:db_postgres][:tunable][:shared_buffers] = "27MB"
  set_unless[:db_postgres][:tunable][:max_connections] = "100"
end

if !attribute?("ec2")
  #set_unless[:db_postgres][:tunable][:shared_buffers] = "64M"
else
  # tune the database for dedicated vs. shared and instance type
  case ec2[:instance_type]
  # TODO: The settings for t1.micro may be excessively conservative, but we're going to be okay with it for now
  when "t1.micro"
     if(db_postgres[:server_usage] == :dedicated)
#      set_unless[:db_postgres][:tunable][:shared_buffers] = "48M"
     else
#      set_unless[:db_postgres][:tunable][:shared_buffers] = "24M"
      set_unless[:db_postgres][:tunable][:max_connections] = "100"
     end
#  when "m1.small", "c1.medium"
#     if (db_postgres[:server_usage] == :dedicated) 
#      set_unless[:db_postgres][:tunable][:shared_buffers] = "128M"
#     else
#      set_unless[:db_postgres][:tunable][:shared_buffers] = "64M"
#     end
#  when "m1.large", "c1.xlarge"    
#     if (db_postgres[:server_usage] == :dedicated) 
#      set_unless[:db_postgres][:tunable][:shared_buffers] = "192M"
#     else
#      set_unless[:db_postgres][:tunable][:shared_buffers] = "128M"
#     end 
#  when "m1.xlarge"
#     if (db_postgres[:server_usage] == :dedicated) 
#      set_unless[:db_postgres][:tunable][:shared_buffers] = "265M"
#     else
#      set_unless[:db_postgres][:tunable][:shared_buffers] = "192M"
#     end
  end 
end 
