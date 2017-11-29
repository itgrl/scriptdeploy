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
  $create_users        = false,
  $packages            = undef,  # Overwrites dynamic selection of packages.
  $package_ensure      = 'installed',
  $scripts             = undef,
  $scripts_hiera_merge = true,
  $recursive_acl       = true,
  $defaultmode         = '0550',
  $repo_user           = 'root',
  $repo_user_group     = 'root',
  $repo_user_uid       = '0',
  $repo_user_gcos      = undef,
  $repo_user_homedir   = '/home/',
  $repo_user_pubkey    = undef,
  $repo_user_prikey    = undef,
  $repo_host_key       = undef,
  $repo_host_key_type  = 'ssh-rsa',
  $repo_host           = undef,
) {

  # Validate hiera merge and set to boolean
  case $scripts_hiera_merge {
    true,
    'true':  { # lint:ignore:quoted_booleans
                $scripts_real = hiera_hash('scriptdeploy::scripts', undef)
    }  # lint:ignore:quoted_booleans
    false,
    'false': { # lint:ignore:quoted_booleans
                $scripts_real = $scriptdeploy::scripts
    } # lint:ignore:quoted_booleans
    default: {
      fail("scriptdeploy::scripts_hiera_merge is not a boolean. \
           It is <${scripts_hiera_merge}>."
      )
    }
  }

  if $scripts_real != undef {
    validate_hash($scripts_real)
    create_resources('::scriptdeploy::repo', $scripts_real)
  }
  else {
    notify { "No scripts to deploy. Your info is ${scripts_real}": }
  }

}
