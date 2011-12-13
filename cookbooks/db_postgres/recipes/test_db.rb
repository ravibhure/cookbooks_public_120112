#
# Script to download and restore sample database 'booktown' db in to postgres
# Ravi Bhure
# 
log "download and restore sample database 'booktown' db"

dumpfile = /tmp/baooktown.sql

bash "download and restore sample database" download  do
    code <<-EOF
      wget http://www.commandprompt.com/ppbook/booktown.sql  -O #{dumpfile}
      set -e
      if [ ! -f #{dumpfile} ]
      then
        echo "ERROR: PostgreSQL sample database file not found! File: '#{dumpfile}'"
        exit 1
      fi
      psql -h /var/run/postgres -U postgres < #{dumpfile}
    EOF
end
