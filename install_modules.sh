#!/bin/bash

MODULE_PATH=/etc/puppet/modules

function clone_git() {
    REMOTE_URL=$1
    REPO=$2
    REV=$3

    if [ -d $MODULE_PATH/$REPO -a ! -d $MODULE_PATH/$REPO/.git ] ; then
        rm -rf $MODULE_PATH/$REPO
    fi
    if [ ! -d $MODULE_PATH/$REPO ] ; then
        git clone $REMOTE_URL $MODULE_PATH/$REPO
    fi
    OLDDIR=`pwd`
    cd $MODULE_PATH/$REPO
    if ! git rev-parse HEAD | grep "^$REV" >/dev/null; then
      git fetch $REMOTE_URL
      git reset --hard $REV >/dev/null
    fi
    cd $OLDDIR
}

if ! puppet help module >/dev/null 2>&1
then
    apt-get install -y -o Dpkg::Options::="--force-confold" puppet facter
fi

# Array of modules to be installed key:value is module:version.
declare -A MODULES
MODULES["openstackci-dashboard"]="0.0.4"

# freenode #puppet 2012-09-25:
# 18:25 < jeblair> i would like to use some code that someone wrote,
# but it's important that i understand how the author wants me to use
# it...
# 18:25 < jeblair> in the case of the vcsrepo module, there is
# ambiguity, and so we are trying to determine what the author(s)
# intent is
# 18:30 < jamesturnbull> jeblair: since we - being PL - are the author
# - our intent was not to limit it's use and it should be Apache
# licensed
MODULES["openstackci-vcsrepo"]="0.0.6"

MODULES["puppetlabs-apache"]="0.0.4"
MODULES["puppetlabs-apt"]="0.0.4"
MODULES["puppetlabs-mysql"]="0.5.0"
MODULES["saz-memcached"]="2.0.2"

MODULE_LIST=`puppet module list`

# Transition away from old things
if [ -d /etc/puppet/modules/vcsrepo/.git ]
then
    rm -rf /etc/puppet/modules/vcsrepo
fi

for MOD in ${!MODULES[*]} ; do
  # If the module at the current version does not exist upgrade or install it.
  if ! echo $MODULE_LIST | grep "$MOD.*${MODULES[$MOD]}" >/dev/null 2>&1
  then
    # Attempt module upgrade. If that fails try installing the module.
    if ! puppet module upgrade $MOD --version ${MODULES[$MOD]} >/dev/null 2>&1
    then
      # This will get run in cron, so silence non-error output
      puppet module install $MOD --version ${MODULES[$MOD]} >/dev/null
    fi
  fi
done
