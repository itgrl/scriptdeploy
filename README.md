
# scriptdeploy

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with scriptdeploy](#setup)
    * [What scriptdeploy affects](#what-scriptdeploy-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with scriptdeploy](#beginning-with-scriptdeploy)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)

## Description

The scriptdeploy module was created to allow various teams the ability to manage their own management scripts and they would be automatically deployed to their systems leveraging ACLs, vcsrepo, and hiera.

## Setup

### Setup Requirements 

Requires: puppetlabs/vcsrepo, puppetlabs/stdlib, and autostructure/acl_posix modules
  

### Beginning with scriptdeploy  

 This class is designed to aid in the deployment of administrative scripts from various version control systems.

## Usage

 Preferred method is to use hiera and your hierarchy for selective deployment.

 Example:
 scriptdeploy::repo_user: 'root'
 scriptdeploy::repo_group: 'root'
 scriptdeploy::repo_user_pubkey: 'puppet:///modules/scriptdeploy/public_key'
 scriptdeploy::repo_user_prikey: 'puppet:///modules/scriptdeploy/private_key'
 scriptdeploy::scripts:
   ‘tier2’:
     ensure: 'latest'
     provider: 'git'
     source: 'git@git.example.com:example/tier2.git'
     path: '/root/bin/tier2'
     owner: 'root'
     group: 'root'
     hasacl: true
     acl:
       - 'g:sysadmins:rwx'
       - 'd:g:sysadmins:rwx'
   ‘dba’:
     ensure: 'latest'
     provider: 'git'      # Where provider is git, svn, mercurial
     source: 'git@git2.example.com:example/dba.git'
     repo_user: 'oracle'
     repo_group: 'oracle'
     repo_user_pubkey: 'puppet:///modules/scriptdeploy/oracle_public_key'
     repo_user_prikey: 'puppet:///modules/scriptdeploy/oracle_private_key'
     path: '/opt/dba/bin'
     owner: 'root'
     group: 'root'
     hasacl: true
     acl:
       - 'g:dba:rwx'
       - 'd:g:dba:rwx'

