# Class: postgresql::params
#
#   The postgresql configuration settings.
#
# Parameters:
#
# Actions:
#
# Requires:
#
# Sample Usage:
#
class postgresql::params {  
  $user                         = 'postgres'
  $group                        = 'postgres'
  $ip_mask_deny_postgres_user   = '0.0.0.0/0'
  $ip_mask_allow_all_users      = '127.0.0.1/32'
  $listen_addresses             = 'localhost'
  $ipv4acls                     = []
  $ipv6acls                     = []
  # TODO: figure out a way to make this not platform-specific
  $manage_redhat_firewall       = false

  # This is a bit hacky, but if the puppet nodes don't have pluginsync enabled,
  # they will fail with a not-so-helpful error message.  Here we are explicitly
  # verifying that the custom fact exists (which implies that pluginsync is
  # enabled and succeeded).  If not, we fail with a hint that tells the user
  # that pluginsync might not be enabled.  Ideally this would be handled directly
  # in puppet.
  if ($::postgres_default_version == undef) {
    fail "No value for postgres_default_version facter fact; it's possible that you don't have pluginsync enabled."
  }


  if defined(Class[Postgresql::Package_source_info]) {
    $version = $postgresql::package_source_info::version
  } else {
    $version = $::postgres_default_version
  }


  case $::operatingsystem {
    default: {
      $service_provider = undef
    }
  }

  case $::osfamily {
    'RedHat': {
      $needs_initdb             = true
      $firewall_supported       = true
      $persist_firewall_command = '/sbin/iptables-save > /etc/sysconfig/iptables'

      if $version == $::postgres_default_version {
        $client_package_name = 'postgresql'
        $server_package_name = 'postgresql-server'
        $devel_package_name  = 'postgresql-devel'
        $service_name = 'postgresql'
        $bindir       = '/usr/bin'
        $datadir      = '/var/lib/pgsql/data'
        $confdir      = $datadir
      } else {
        $version_parts       = split($version, '[.]')
        $package_version     = "${version_parts[0]}${version_parts[1]}"
        $client_package_name = "postgresql${package_version}"
        $server_package_name = "postgresql${package_version}-server"
        $devel_package_name  = "postgresql${package_version}-devel"
        $service_name = "postgresql-${version}"
        $bindir       = "/usr/pgsql-${version}/bin"
        $datadir      = "/var/lib/pgsql/${version}/data"
        $confdir      = $datadir
      }

      $service_status = undef
    }

    'Debian': {
      $needs_initdb             = false
      $firewall_supported       = false
      # TODO: not exactly sure yet what the right thing to do for Debian/Ubuntu is.
      #$persist_firewall_command = '/sbin/iptables-save > /etc/iptables/rules.v4'


      case $::operatingsystem {
        'Debian': {
            $service_name = 'postgresql'
        }

        'Ubuntu': {
            case $::lsbmajdistrelease {
                # thanks, ubuntu
                '10':       { $service_name = "postgresql-${::postgres_default_version}" }
                default:    { $service_name = 'postgresql' }
            }
        }
      }

      $client_package_name = 'postgresql-client'
      $server_package_name = 'postgresql'
      $devel_package_name  = 'libpq-dev'
      $bindir              = "/usr/lib/postgresql/${::postgres_default_version}/bin"
      $datadir             = "/var/lib/postgresql/${::postgres_default_version}/main"
      $confdir             = "/etc/postgresql/${::postgres_default_version}/main"
      $service_status      = "/etc/init.d/${service_name} status | /bin/egrep -q 'Running clusters: .+'"
    }

    default: {
      fail("Unsupported osfamily: ${::osfamily} operatingsystem: ${::operatingsystem}, module ${module_name} currently only supports osfamily RedHat and Debian")
    }
  }

  $initdb_path          = "${bindir}/initdb"
  $createdb_path        = "${bindir}/createdb"
  $psql_path            = "${bindir}/psql"
  $pg_hba_conf_path     = "${confdir}/pg_hba.conf"
  $postgresql_conf_path = "${confdir}/postgresql.conf"
}
