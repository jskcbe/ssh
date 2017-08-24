  
mkdir -p .ssh
cat <<EOF> './.ssh/config'
Host *
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_rsa

Host mail_tunnel
  HostName      email.webonobos.com
  User          root
  Port          1022
  IdentityFile  ~/.ssh/id_rsa-cytopia@everythingcli
  LocalForward  5000 localhost:3306
  ServerAliveInterval 30
  ServerAliveCountMax 3

# usage:
# autossh -M 0 -f -T -N mail_tunnel
EOF


cat <<EOF > 'supervisord.conf'
[supervisord]
logfile = /tmp/supervisord.log
logfile_maxbytes = 50MB
logfile_backups=10
loglevel = info
pidfile = /tmp/supervisord.pid
nodaemon = true
minfds = 1024
minprocs = 200
umask = 022
user = root
identifier = supervisor
directory = /tmp
nocleanup = true
childlogdir = /tmp
strip_ansi = false
environment = PUSHY_KEY=$PUSHY_KEY,HELLO="WORLD"

[supervisorctl]
serverurl=unix://%(here)s/supervisor.sock

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[program:sshd]
command=/usr/sbin/sshd -D

#[program:fab]
#command=/bin/bash -c "sleep 5 && source venv/bin/activate && fab -H localhost,linuxbox provision"

#supervisorctl restart foo:

EOF


# build a base image for python apps
cat <<EOF > 'tunlr.pybase.dockerfile'
FROM ubuntu:xenial
RUN apt-get update
RUN apt-get install -y build-essential
RUN apt-get install -y gcc
RUN apt-get install -y git
RUN apt-get install -y libffi-dev
RUN apt-get install -y libssl-dev
RUN apt-get install -y libreadline-gplv2-dev
RUN apt-get install -y libncursesw5-dev
RUN apt-get install -y libsqlite3-dev
RUN apt-get install -y tk-dev
RUN apt-get install -y libgdbm-dev
RUN apt-get install -y libc6-dev
RUN apt-get install -y libbz2-dev
RUN apt-get install -y libpython-all-dev
RUN apt-get install -y python-pip
RUN apt-get install -y python-virtualenv
RUN apt-get install -y python-pygresql
RUN apt-get install -y ca-certificates
RUN apt-get install -y checkinstall
RUN apt-get install -y python-tox
RUN apt-get install -y openssh-server
RUN apt-get install -y supervisor
RUN apt-get install -y autossh
EOF
#docker build -f tunlr.pybase.dockerfile -t tunlr/pybase:latest . #CREATES --> tunlr.pybase:latest
### [TEST] --> docker run -it --rm -w /theta tunlr/pybase:latest /bin/bash

#####################################
### build the virtualenv artifact ###
#####################################
cat <<EOF > 'requirements.txt'
Fabric
ansible
fabric-verbose
EOF
cmds="""
virtualenv venv
source venv/bin/activate && pip install --upgrade pip && pip install -r requirements.txt
"""
#docker run -it --rm -v $(pwd):/theta -w /theta tunlr/pybase:latest /bin/bash -c "${cmds}"
### [TEST] --> docker run -it --rm -w /theta tunlr/pybase:latest /bin/bash

#################################
### build the composite image ###
#################################
cat <<EOF > 'tunlr.dockerfile'
FROM tunlr/pybase:latest

### VIRTUALENV
COPY venv /theta/venv
#COPY fabfile.py /theta

### SSHD
RUN  echo "    IdentityFile ~/.ssh/id_rsa" >> /etc/ssh/ssh_config
RUN mkdir /var/run/sshd
RUN echo 'root:letmein' | chpasswd
COPY ./.ssh/config /root/.ssh/config
RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile
EXPOSE 22 22

### SUPERVISORD
RUN mkdir -p /var/log/supervisor
RUN mkdir -p /etc/supervisor/conf.d/
RUN ls -al /etc/supervisor/conf.d/
COPY ./supervisord.conf /etc/supervisor/conf.d
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
EOF
### [TEST] --> docker run -it --rm -w /theta tunlr/pydeploy:latest
docker build -f tunlr.pybase.dockerfile -t tunlr/pybase:latest .
docker run -it --rm -v $(pwd):/theta -w /theta tunlr/pybase:latest /bin/bash -c "${cmds}"

docker build \
  -f tunlr.dockerfile \
  -t tunlr/pydeploy:latest .
docker network create endpoints_back-tier
docker run -it \
  --rm \
  --name tunlr \
  --network=endpoints_back-tier \
  --hostname=tunlr \
  -p 22:22 \
  -v $(pwd)/fabfile.py:/theta/fabfile.py \
  -w /theta \
  tunlr/pydeploy:latest
