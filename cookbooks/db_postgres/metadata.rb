maintainer       "RightScale, Inc."
maintainer_email "support@rightscale.com"
license          IO.read(File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'LICENSE')))
description      "Installs/configures a PostgreSQL database server with automated backups."
long_description IO.read(File.join(File.dirname(__FILE__), 'README.rdoc'))
version          "0.0.1"

depends "sys_dns"
depends "db"
depends "rs_utils"
depends "block_device"

provides "db_postgres_restore(url, branch, user, credentials, file_path, schema_name, tmp_dir)"
provides "db_postgres_gzipfile_backup(db_name, file_path)"
provides "db_postgres_gzipfile_restore(db_name, file_path)"

recipe  "db_postgres::default", "Runs the client 'db::install_server' recipes."

attribute "db_postgres",
  :display_name => "General Database Options",
  :type => "hash"
  
# == Default attributes
#
attribute "db_postgres/server_usage",
  :display_name => "Server Usage",
  :description => "Use 'dedicated' if the postgresql config file allocates all existing resources of the machine.  Use 'shared' if the PostgreSQL config file is configured to use less resources so that it can be run concurrently with other apps like Apache and Rails for example.",
  :recipes => [
    "db_postgres::default"
  ],
  :choice => ["shared", "dedicated"],
  :default => "dedicated"

# == Import/export attributes
# TODO: these are used by the LAPP template and should be moved into the LAPP cookbook
#
attribute "db_postgres/dump",
  :display_name => "Import/Export settings for PostgreSQL dump file management.",
  :type => "hash"

attribute "db_postgres/dump/schema_name",
  :display_name => "Schema Name",
  :description => "Enter the name of the PostgreSQL database schema to which applications will connect.  The database schema was created when the initial database was first set up.  This input will be used to set the application server's database config file so that applications can connect to the correct schema within the database.  This input is also used for PostgreSQL dump backups in order to determine which schema is getting backed up.  Ex: mydbschema",
  :required => false,
  :recipes => [ "db_postgres::do_dump_import", "db_postgres::do_dump_export", "db_postgres::setup_continuous_export"  ]

attribute "db_postgres/dump/storage_account_provider",
  :display_name => "Storage Account Provider",
  :description => "Select the cloud infrastructure where the backup will be saved. For Amazon S3, use ec2.  For Rackspace Cloud Files, use rackspace.",
  :choice => ["ec2", "rackspace"],
  :required => false,
  :recipes => [ "db_postgres::do_dump_import", "db_postgres::do_dump_export", "db_postgres::setup_continuous_export"  ]

attribute "db_postgres/dump/storage_account_id",
  :display_name => "Storage Account Id",
  :description => "In order to write the dump file to the specified cloud storage location, you will need to provide cloud authentication credentials. For Amazon S3, use AWS_ACCESS_KEY_ID. For Rackspace Cloud Files, use your Rackspace login Username.",
  :required => false,
  :recipes => [ "db_postgres::do_dump_import", "db_postgres::do_dump_export", "db_postgres::setup_continuous_export"  ]

attribute "db_postgres/dump/storage_account_secret",
  :display_name => "Storage Account Secret",
  :description => "In order to write the dump file to the specified cloud storage location, you will need to provide cloud authentication credentials. For Amazon S3, use AWS_SECRET_ACCESS_KEY. For Rackspace Cloud Files, use your Rackspace account API Key.",
  :required => false,
  :recipes => [ "db_postgres::do_dump_import", "db_postgres::do_dump_export", "db_postgres::setup_continuous_export"  ]

attribute "db_postgres/dump/container",
  :display_name => "Container",
  :description => "The cloud storage location where the PostgreSQL dump file will be saved to or restored from. For Amazon S3, use the bucket name.  For Rackspace Cloud Files, use the container name.",
  :required => false,
  :recipes => [ "db_postgres::do_dump_import", "db_postgres::do_dump_export", "db_postgres::setup_continuous_export"  ]

attribute "db_postgres/dump/prefix",
  :display_name => "Prefix",
  :description => "The prefix that will be used to name/locate the backup of a particular PostgreSQL database.  Defines the prefix of the PostgreSQL dump filename that will be used to name the backup database dumpfile along with a timestamp.",
  :required => false,
  :recipes => [ "db_postgres::do_dump_import", "db_postgres::do_dump_export", "db_postgres::setup_continuous_export"  ]
