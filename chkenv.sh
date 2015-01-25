#!/bin/bash
#set -xv
set -eu

if ! which docker;
then
  echo 'docker is not installed, stop.'
  exit 1
fi

if [ ! -S /var/run/docker.sock ];
then
  echo 'docker is not running, stop.'
  exit 1
fi

if which sestatus;
then
  if [ `sestatus | awk 'match($0, /^SELinux status:/) {print $3}'` != 'disabled' ];
  then
    echo 'SELinux is not disabled, stop.'
    exit 1
  fi
fi

if which pulseaudio;
then
  if ! pulseaudio --check;
  then
    echo 'pulseaudio is not running, stop.'
    exit 1
  fi
  if ! netstat -4lnpt 2>&1 | fgrep :4713 | fgrep -q pulseaudio;
  then
    if [ -f ~/.config/pulse/default.pa ];
    then
      echo 'Please check the following settings in ~/.config/pulse/default.pa.'
      echo '------8<------8<------8<------8<------8<------8<------8<------8<------8<------'
      echo 'load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1'
      echo '------8<------8<------8<------8<------8<------8<------8<------8<------8<------'
      exit 1
    else
      echo 'Copy from /etc/pulse/default.pa to ~/.config/pulse/default.pa.'
      cp /etc/pulse/default.pa ~/.config/pulse/default.pa
      echo 'Enable PulseAudio over network(TCP support with anonymous clients).'
      echo 'load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1' \
        >> ~/.config/pulse/default.pa
      pulseaudio --kill && sleep 1 && pulseaudio --start && sleep 5
      if ! netstat -4lnpt 2>&1 | fgrep :4713 | fgrep -q pulseaudio;
      then
        echo 'Cannot enable PulseAudio over network(TCP support with anonymous clients), stop.'
        exit 1
      fi
    fi
  fi
else
  echo 'pulseaudio is not installed, stop.'
  exit 1
fi

if [ ! -f ./id_rsa.pub ];
then
  if [ ! -f ~/.ssh/id_rsa.pub ];
  then
    echo 'Cannot find your SSH key(~/.ssh/id_rsa.pub). Please generate a SSH key by ssh-keygen -t rsa.'
    exit 1
  else
    echo 'Copy from ~/.ssh/id_rsa.pub to ./id_rsa.pub.'
    cp ~/.ssh/id_rsa.pub .
  fi
fi

tmpfile=/tmp/$0.$$.tmp
trap 'rm -f "${tmpfile}"' 0
create_new_config=''

cat << EOF > ${tmpfile}
Host docker-chrome
  User      chrome
  Port      2222
  HostName  127.0.0.1
  RemoteForward 64713 localhost:4713
  ForwardX11 yes
EOF

if [ ! -f ~/.ssh/config ];
then
  echo 'Create new ~/.ssh/config.'
  cat ${tmpfile} >> ~/.ssh/config
  chmod 600 ~/.ssh/config
  create_new_config='yes'
fi

cat << EOF

*** Your build environment is LGTM. ***

Please start the build with the following command.

  sudo docker build --tag="YOUR_REPO_NAME" .
  sudo docker run -d -p 127.0.0.1:2222:22 --name="YOUR_CONTAINER_NAME" YOUR_REPO_NAME

EOF

if [ -z ${create_new_config} ];
then
  if ! fgrep -qw docker-chrome ~/.ssh/config;
  then
    echo 'Please add the following settings in ~/.ssh/config.'
    echo '------8<------8<------8<------8<------8<------8<------8<------8<------8<------'
    cat ${tmpfile}
    echo '------8<------8<------8<------8<------8<------8<------8<------8<------8<------'
  fi
fi

cat << EOF

Please start the chrome with the following command.

  ssh docker-chrome /usr/local/bin/chrome-pulseaudio-forward

Have a fun!
EOF
