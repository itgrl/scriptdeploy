define scriptdeploy::repo (
  $create_users       = false,
  $packages           = undef,  # Overwrites dynamic selection of packages.
  $package_ensure     = 'installed',
  $defaultmode        = '0550',
  # Information to connect to the repositories
  # Many items are optional
  $repo_user          = 'root',
  $repo_user_group    = undef, # Optional depending on if creating local user.
  $repo_user_uid      = undef, # Optional depending on if creating local user.
  $repo_user_gcos     = undef, # Optional depending on if creating local user.
  $repo_user_homedir  = '/home', # Basedir, Code will add user after
  $repo_user_pubkey   = $scriptdeploy::repo_user_pubkey,
  $repo_user_prikey   = $scriptdeploy::repo_user_prikey,
  $repo_host_key      = $scriptdeploy::repo_host_key,
  $repo_host_key_type = $scriptdeploy::repo_host_key_type,
  $repo_host          = $scriptdeploy::repo_host,
  # Repository information
  $ensure             = undef,
  $provider           = 'git',
  $source             = undef,
  $repo_path          = undef,
  $repo_rev           = 'master',
  # File Level ACL information
  $hasacl             = false,
  $recursive_acl      = true,
  $acl                = undef, # Array of ACLs
  $mode               = '0750',
  # File and directory owner
  $owner              = 'root',
  $group              = 'root',
) {

  ## Set packages by OS
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
        $git_pkg       = [ 'perl-Error', 'git' ]
        $mercurial_pkg = [ 'mercurial', 'python' ]
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
        fail("scriptdeploy supports osfamilies RedHat, Suse and Ubuntu. \
              Detected osfamily is <${::osfamily}>.")
      }
    }
  }

  ## Set packages by provider for OS
  case $provider {
    'Git',
    'git': {
      $packages_real = $git_pkg
      $packages_acl  = $acl_pkg
      $provider_real = 'git'
    }
    'SVN',
    'svn': {
      $packages_real = $svn_pkg
      $packages_acl  = $acl_pkg
      $provider_real = 'svn'
    }
    'Mercurial',
    'hg',
    'mercurial': {
      $packages_real = $mercurial_pkg
      $packages_acl  = $acl_pkg
      $provider_real = 'hg'
    }
    default: {
      fail("scriptdeploy supports provider options git, svn, and mercurial.  \
           I do not understand ${::provider} as a repo provider.")
    }
  }

  # Install packages
  package { $packages_real:
    ensure => $package_ensure,
  }
  package { $packages_acl:
    ensure => $package_ensure,
  }

  # Split User and domain if user format is user@domain
  # This allows for proper syntaxing for home directory
  if $repo_user =~ /^(.+)@(.+)/ {
    $has_domain             = true
    $myuser                 = $1
    $mydomain               = $2
    $repo_user_homedir_real = "${repo_user_homedir}/${mydomain}/${myuser}"
  }
  else {
    if "${repo_user}" == 'root' {
      $repo_user_homedir_real = '/root'
    }
    else {
      $repo_user_homedir_real = "${repo_user_homedir}/${repo_user}"
    }
  }

  # Evaluate boolean to determine if we should create user or not.
  if $create_users {
    if $has_domain {
      notify { "create_users flag was set to true, but this user ${myuser}
                is managed by a directory server with domain ${mydomain}.": }
    }
    else {
      user { $repo_user:
        ensure     => 'present',
        comment    => $repo_user_gcos,
        uid        => $repo_user_uid,
        groups     => $repo_user_group,
        managehome => true,
        before => [ File[$repo_user_homedir_real], File[$repo_path], ],
      }
    }
  }

  # Validate that the mode is a proper setting.
  validate_re($mode, '^[0-7]{4}$',
    "repository mode is <${mode}> /
     and must be a valid four digit mode in octal notation.")

  # Make sure the repo_path is defined and real.
  if $repo_path != undef {
    validate_absolute_path($repo_path)

    # Determine if nested directories
    $repo_patharray = split($repo_path, '/')
    $repo_patharray_length = size($repo_patharray)
    # Determine if parent directories are present.
    if "$repo_patharray_length" > '1' {
      exec { $repo_path:
        command => "mkdir -p ${repo_path}",
        unless  => "test -d ${repo_path}",
        path    => '/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/opt/puppetlabs/bin',
      }
      # Create directory for repository
      file { $repo_path:
        ensure => directory,
        mode   => $mode,
        owner  => $owner,
        group  => $group,
      }
    }
    else {
      # Create directory for repository
      file { $repo_path:
        ensure => directory,
        mode   => $mode,
        owner  => $owner,
        group  => $group,
      }
    }
  }
  else {
    fail("Path must be set, and it is currently ${repo_path}")
  }

  # Evaluate if ACL is set, and set ACLs.
  if $hasacl == true {

    # Extract each mode bit.
    $mode_user  = regsubst($mode, '^(.)(.)(.)(.)$', '\2')
    $mode_group = regsubst($mode, '^(.)(.)(.)(.)$', '\3')
    $mode_other = regsubst($mode, '^(.)(.)(.)(.)$', '\4')

    # Convert mode to rwx equivalent.
    case $mode_user {
      '7': { $mode_user_rwx = 'rwx' }
      '6': { $mode_user_rwx = 'rw-' }
      '5': { $mode_user_rwx = 'r-x' }
      '4': { $mode_user_rwx = 'r--' }
      '1': { $mode_user_rwx = '--x' }
      '0': { $mode_user_rwx = '---' }
      default: {
        fail("Mode must be values 0, 1, 4, 5, 6, or 7 and \
              you specified ${mode_user} for the user bit of ${mode}")
      }
    }
    case $mode_group {
      '7': { $mode_group_rwx = 'rwx' }
      '6': { $mode_group_rwx = 'rw-' }
      '5': { $mode_group_rwx = 'r-x' }
      '4': { $mode_group_rwx = 'r--' }
      '1': { $mode_group_rwx = '--x' }
      '0': { $mode_group_rwx = '---' }
      default: {
        fail("Mode must be values 0, 1, 4, 5, 6, or 7 and \
              you specified ${mode_other} for the other bit of ${mode}")
      }
    }
    case $mode_other {
      '7': { $mode_other_rwx = 'rwx' }
      '6': { $mode_other_rwx = 'rw-' }
      '5': { $mode_other_rwx = 'r-x' }
      '4': { $mode_other_rwx = 'r--' }
      '1': { $mode_other_rwx = '--x' }
      '0': { $mode_other_rwx = '---' }
      default: {
        fail("Mode must be values 0, 1, 4, 5, 6, or 7 and \
              you specified ${mode_other} for the other bit of ${mode}")
      }
    }

    # Set array of ACLs from directory creation.
    $defaultacl = [
                    "user:${mode_user_rwx}",
                    "default:user:${mode_user_rwx}",
                    "group:${mode_group_rwx}",
                    "default:group:${mode_group_rwx}",
                    "other:${mode_other_rwx}",
                    "default:other:${mode_other_rwx}",
                  ]
    # Set default array of ACLs.
    if $acl != undef {
      $myacls = $acl
    }
    else {
      fail("You stated that this has ACLs but there were not any ACLs provided.  ACLs are ${acl}")
    }

    $requires = [
                  File[$::repo_path],
                  Group[$::group],
                  Package[$::acl_pkg],
                ]

    acl { $repo_path:
      action     => set,
      permission => $myacls,
      provider   => posixacl,
      require    => $requires,
      recursive  => $recursive_acl,
    }
  }

  # Define full key path
  $keyfile = "${repo_user_homedir_real}/.ssh/id_rsa"
  $pubkeyfile = "${repo_user_homedir_real}/.ssh/id_rsa.pub"

  file { $repo_user_homedir_real:
    ensure  => directory,
    owner   => $::repo_user,
    group   => $::repo_group,
    mode    => '0700',
  }->
  File { "${repo_user_homedir_real}/.ssh":
    ensure  => directory,
    owner   => $::repo_user,
    group   => $::repo_group,
    mode    => '0700',
    before  => [ File[$::keyfile], File[$::pubkeyfile], ],
    require => [ File[$repo_user_homedir_real], ],
  }->
  File { $keyfile:
    ensure  => file,
    owner   => $repo_user,
    group   => $::repo_group,
    mode    => '0600',
    source  => "puppet:///modules/scriptdeploy/${repo_user_prikey}",
    require => [ File[$repo_user_homedir_real], ],
  }->
  File { $pubkeyfile:
    ensure  => file,
    owner   => $repo_user,
    group   => $::repo_group,
    mode    => '0600',
    source  => "puppet:///modules/scriptdeploy/${repo_user_pubkey}",
    require => [ File[$repo_user_homedir_real], ],
  }

  sshkey { $repo_host:
    ensure  => present,
    key     => $repo_host_key,
    type    => $repo_host_key_type,
  }

  ssh_authorized_key { $repo_host_key:
    user => $repo_user,
    type => $repo_host_key_type,
    key  => $repo_host_key,
  }

  # vcsrepo error such as in authentication, will purge directory.
  vcsrepo { $repo_path:
    ensure   => $ensure,
    provider => $provider_real,
    source   => $source,
    user     => $repo_user,
    revision => $repo_rev,
    require  => [ File[$::keyfile], File[$::pubkeyfile], ],
  }
}
