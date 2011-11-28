maintainer       "RightScale, Inc."
maintainer_email "support@rightscale.com"
license          "All rights reserved"
description      "Installs/Configures lapp"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.rdoc'))
version          "0.1"

depends "db_postgres"
depends "app_php"


recipe "lapp::default", "Allows the LAPP cookbook to override attributes from other cookbooks.  No installation or configuration is done."
