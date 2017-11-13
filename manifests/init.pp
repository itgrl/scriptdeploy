# scriptdeploy
#
# This class is designed to aid in the deployment of administrative
# scripts from various version control systems.
#
# Preferred method is to use hiera and your hierarchy for selective
# deployment.
#
# Example:
# scriptdeploy::repo_user: 'root'
# scriptdeploy::repo_group: 'root'
# scriptdeploy::repo_user_pubkey: 'puppet:///modules/scriptdeploy/public_key'
# scriptdeploy::repo_user_prikey: 'puppet:///modules/scriptdeploy/private_key'
# scriptdeploy::scripts:
#   ‘tier2’:
#     ensure: 'latest'
#     provider: 'git'
#     source: 'git@git.example.com:example/tier2.git'
#     path: '/root/bin/tier2'
#     owner: 'root'
#     group: 'root'
#     hasacl: true
#     acl:
#       - 'g:sysadmins:rwx'
#       - 'd:g:sysadmins:rwx' 
#   ‘dba’:
#     ensure: 'latest'
#     provider: 'git'      # Where provider is git, svn, mercurial
#     source: 'git@git2.example.com:example/dba.git'
#     repo_user: 'oracle'
#     repo_group: 'oracle'
#     repo_user_pubkey: 'puppet:///modules/scriptdeploy/oracle_public_key'
#     repo_user_prikey: 'puppet:///modules/scriptdeploy/oracle_private_key'
#     path: '/opt/dba/bin'
#     owner: 'root'
#     group: 'root'
#     hasacl: true
#     acl:
#       - 'g:dba:rwx'
#       - 'd:g:dba:rwx'
#
# @summary A short summary of the purpose of this class
#
# @example
#   include scriptdeploy
class scriptdeploy (
  $create_users       = false,
  $packages           = undef,  # Overwrites dynamic selection of packages.
  $package_ensure     = 'installed',
  $scripts            = undef,
  $scripts_merge      = true,
  $defaultacl         = [ 'user::r-x', 'group::r-x', 'mask::r-x', 'other::---' ],
  $recursive_acl      = true,
  $defaultmode        = '0550',
  $repo_user          = 'root',
  $repo_user_group    = 'root',
  $repo_user_uid      = '0',
  $repo_user_gcos     = undef,
  $repo_user_homedir  = '/home/',
  $repo_user_pubkey   = undef,
  $repo_user_prikey   = undef,
  $repo_host_key      = undef,
  $repo_host_key_type = 'ssh-rsa',
  $repo_host          = undef,
){
	
  include vcsrepo
  include posix-acl

  # Loop through array of script repos to deploy and setup deployment.
  $scripts.each | $repo | {


    if $packages != undef {
      $packages_real = $packages
    }
    else {
      case $::osfamily {
        'Debian': {
          $mercurial_pkg = 'mercurial'
          $git_pkg       = 'git-core'
          $svn_pkg       = 'subversion'
          $acl_pkg       = 'acl'
        }
        'Suse': {
          $git_pkg       = [
                            "perl-Error",
                            "git",
                           ]
          $mercurial_pkg = [
                            'mercurial',
                            'python',
                           ]
          $svn_pkg       = 'subversion'
          $acl_pkg       = 'acl'
        }
        'RedHat': {
          $mercurial_pkg = 'mercurial'
          $git_pkg       = 'git-all'
          $svn_pkg       = 'subversion'
          $acl_pkg       = 'acl'
        }
        default: {
          fail("scriptdeploy supports osfamilies RedHat, Suse and Ubuntu. Detected osfamily is <${::osfamily}>.")
        }
      }
      case $repo['provider'] {
        'git': { 
          $packages_real = concat("$git_pkg","$acl_pkg")
        }
        'svn': { 
          $packages_real = concat("$svn_pkg","$acl_pkg")
        }
        'mercurial': { 
          $packages_real = concat("$mercurial_pkg","$acl_pkg")
        }
        default: {
          fail("scriptdeploy supports provider options git, svn, and mercurial  I do not understand $repo['provider'] as a repo provider.")
        }
      }
    }

    # Install packages
    package { $packages_real:
      ensure => $package_ensure,
    }

    # Use global repo_user unless set in hiera for this repo
    if $repo['repo_user'] != undef {
      $repo_user_real = $repo['repo_user']
    }
    else {
      $repo_user_real = $repo_user
    }

    # Use global repo_user_group unless set in hiera for this repo  ## Only used if $create_users = true
    if $repo['repo_user_group'] != undef {
      $repo_user_group_real = $repo['repo_user_group']
    }
    else {
      $repo_user_group_real = $repo_user_group
    }

    # Use global repo_user_uid unless set in hiera for this repo  ## Only used if $create_users = true
    if $repo['repo_user_uid'] != undef {
      $repo_user_uid_real = $repo['repo_user_uid']
    }
    else {
      $repo_user_uid_real = $repo_user_uid
    }

    # Use global repo_user_gcos unless set in hiera for this repo  ## Only used if $create_users = true
    if $repo['repo_user_gcos'] != undef {
      $repo_user_gcos_real = $repo['repo_user_gcos']
    }
    else {
      $repo_user_gcos_real = $repo_user_gcos
    }

    # Use global repo_pubkey unless set in hiera for this repo
    if $repo['repo_pubkey'] != undef {
      $repo_pubkey_real = $repo['repo_pubkey']
    }
    else {
      $repo_pubkey_real = $repo_pubkey
    }

    # Use global repo_prikey unless set in hiera for this repo
    if $repo['repo_prikey'] != undef {
      $repo_prikey_real = $repo['repo_prikey']
    }
    else {
      $repo_prikey_real = $repo_prikey
    }

    # Use global repo_host_key unless set in hiera for this repo
    if $repo['repo_host_key'] != undef {
      $repo_host_key_real = $repo['repo_host_key']
    }
    else {
      $repo_host_key_real = $repo_host_key
    }

    # Use global repo_host unless set in hiera for this repo
    if $repo['repo_host'] != undef {
      $repo_host_real = $repo['repo_host']
    }
    else {
      $repo_host_real = $repo_host
    }

    if $repo_user_real =~ /^(.+)@(.+)/ {
      $has_domain             = true
      $myuser                 = $1
      $mydomain               = $2
      $repo_user_homedir_real = "$repo_user_homedir/$mydomain/$myuser"
    }
    else {
      $repo_user_homedir_real = "$repo_user_homedir/$repo_user_real"
    }

    # Evaluate boolean to determine if we should create user or not. 
    if $create_users {
      if $has_domain {
        notify { "create_users flag was set to true, but this user $myuser is managed by a directory server with domain $mydomain.": }
      } 
      else {
        user { "$repo_user_real":
          ensure     => 'present',
          comment    => "$repo_user_gcos_real",
          uid        => "$repo_user_uid_real",
          groups     => "$repo_user_group_real",
          managehome => 'true',
        }
      }
    }

    # Determine if mode is set, if not set to default 0750
    if $repo['mode'] != undef {
      $mode_real = $repo['mode']
    }
    else {
      $mode_real = $defaultmode
    }

    # Evaluate recursive mode.  Use Default or repo based if set.
    if $repo['recursive_acl'] != undef {
      $recursive_acl_real = $repo['recursive_acl']
    }
    else {
      $recursive_acl_real = $recursive_acl
    }

    # Make sure the path is defined and real.
    if $repo['path'] != undef {

      validate_absolute_path($repo['path'])

      # Create directory for repository
      file { "$repo['path']":
        ensure => directory,
        mode   => "$mode_real",
        owner  => "$owner_real",
        group  => "$group_real".
      }
      
      # Set ACLs if used.
      $repo['hasacl'] {
        # Set default array.
        $myacls_real = concat( "$defaultacl", "$repo['acl']" )
        acl { "$repo['path']":
          action     => set,
          permission => $myacls_real,
          provider   => posixacl,
          require    => [
                          File["$repo['path']"],
                          User["$user_real"],
                          Group["$group_real"],
                          Package["$acl_pkg"],
                        ],         
          recursive  => $recursive_acl_real,
        }
      }
      
      # Define full key path
      $keyfile = "$repo_user_homedir_real/.ssh/$repo_prikey_real"
      $pubkeyfile = "$repo_user_homedir_real/.ssh/$repo_pubkey_real"

      file { "$repo_user_homedir_real/.ssh":
        ensure  => directory,
        owner   => $repo_user_real,
        group   => $repo_group_real,
        mode    => '0600',
        before  => [
                    File["$keyfile"],
                    File["$pubkeyfile"],
                   ],
        require => [
                    File["$repo_user_homedir"],
                    User["$repo_user_real"],
                   ],
      }

      file { "$keyfile":
        ensure  => present,
        owner   => $repo_user_real,
        group   => $repo_group_real,
        mode    => '0600',
        source  => $source_real,
        require => [
                    File["$repo_user_homedir"],
                    User["$repo_user_real"],
                   ],
      }

      file { "$pubkeyfile":
        ensure  => present,
        owner   => $repo_user_real,
        group   => $repo_group_real,
        mode    => '0600',
        source  => $source_real,
        require => [
                    File["$repo_user_homedir"],
                    User["$repo_user_real"],
                   ],
      }
    
      sshkey { "$repo_host_real":
        ensure => present,
        key    => "$repo_host_key_real",
        type   => "$repo_hostkey_type_real",
        require => [
                    File["$repo_user_homedir"],
                    User["$repo_user_real"],
                   ],
      }

      vcsrepo { "$repo['path']":
        ensure    => "$repo['ensure']",
        provider  => "$repo['provider']",
        source    => "$repo['source']",
        user      => "$repo_user_real",
        require   => [
                      File["$keyfile"],
                      File["$pubkeyfile"],
                      File["$repo['path']"],
                      User["$repo_user_real"],
                      Group["$group_real"],
                      File["$pubkeyfile"],
                      Package["$packages_real"],
                     ],
      } 
   
    }
    else {
      notify { "Oops, someone forgot something.  Deploying $repo['name'] into the void is not allowed. Please ensure the path is set and try again.": }
    }
  }
}
