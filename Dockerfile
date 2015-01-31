FROM ubuntu:latest
MAINTAINER KIYOHIRO ADACHI <kiyoad@da2.so-net.ne.jp>
# I got the original idea from https://github.com/jlund/docker-chrome-pulseaudio. Thank a lot!

ENV REFRESHED_AT 2015-01-25

ENV DEBIAN_FRONTEND noninteractive
RUN \
  apt-get update && apt-get upgrade -y && apt-get install -y wget && \
  wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - && \
  echo "deb http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google.list && \
  apt-get update && \
  apt-get install -y google-chrome-stable && \
  rm /etc/apt/sources.list.d/google.list && \
  apt-get install -y fonts-takao fonts-takao-gothic fonts-takao-mincho fonts-takao-pgothic && \
  apt-get install -y language-pack-ja-base language-pack-ja && \
  apt-get install -y openssh-server pulseaudio && \
  rm -rf /var/lib/apt/lists/*

RUN \
  mkdir /var/run/sshd && \
  adduser --disabled-password --gecos "Chrome User" --uid 5001 chrome && \
  mkdir /home/chrome/.ssh
ADD id_rsa.pub /home/chrome/.ssh/authorized_keys
RUN chown -R chrome:chrome /home/chrome/.ssh

RUN \
  echo "chrome ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/chrome && \
  chmod 0440 /etc/sudoers.d/chrome

RUN \
  echo 'PULSE_SERVER=tcp:localhost:64713 google-chrome --no-sandbox' > /usr/local/bin/chrome-pulseaudio-forward && \
  chmod 755 /usr/local/bin/chrome-pulseaudio-forward

RUN \
  update-locale LANG=ja_JP.UTF-8 LANGUAGE="ja_JP:ja" && \
  cp -p /usr/share/zoneinfo/Asia/Tokyo /etc/localtime && \
  echo "Asia/Tokyo" > /etc/timezone && dpkg-reconfigure --frontend noninteractive tzdata
ENV LANG ja_jp.UTF-8

ENTRYPOINT ["/usr/sbin/sshd", "-D"]
EXPOSE 22

