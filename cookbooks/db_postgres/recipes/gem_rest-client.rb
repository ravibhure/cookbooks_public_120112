#
# Cookbook Name:: db_postgres
# Definition:: gem_rest-client
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


# == Install rest-client gem
#
# Also installs in compile phase
#

r = execute "install rest-client gem" do
  command "/opt/rightscale/sandbox/bin/gem install rest-client --no-rdoc --no-ri"
end
r.run_action(:run)

# Remove existing version of rest-client
# Upgrade for gem does not seem to work so using two step - removal and install.
#u = execute "uninstall rest-client gem" do
#  command "/opt/rightscale/sandbox/bin/gem uninstall rest-client -v 1.6.3"
#end
#u.run_action(:run)

#t = execute "install taps gem" do
#  command "/opt/rightscale/sandbox/bin/gem install taps --no-rdoc --no-ri"
#end
#t.run_action(:run)

Gem.clear_paths
log "Gem reload forced with Gem.clear_paths"

rs_utils_marker :end
