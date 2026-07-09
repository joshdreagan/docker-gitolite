#!/bin/sh

# if command is sshd, set it up correctly
if [ "${1}" = 'sshd' ]; then
  shift 1
  set -- /usr/sbin/sshd -D -e "$@"
fi

# Setup SSH HostKeys if needed
conf_file='/etc/ssh/sshd_config.d/10-hostkey-overrides.conf'
echo '# HostKey overrides' > "$conf_file"
for algorithm in rsa ecdsa ed25519
do
  keyfile=/etc/ssh/keys/ssh_host_${algorithm}_key
  [ -f $keyfile ] || ssh-keygen -q -N '' -f $keyfile -t $algorithm
  chmod 600 $keyfile

  echo "HostKey $keyfile" >> "$conf_file"
done

# Disable unwanted authentications and enable wanted ones
conf_file='/etc/ssh/sshd_config.d/20-authentication-overrides.conf'
echo '# Authentication overrides' > "$conf_file"
echo 'PermitRootLogin no' >> "$conf_file"
echo 'UsePAM no' >> "$conf_file"
echo 'HostbasedAuthentication no' >> "$conf_file"
echo 'PasswordAuthentication no' >> "$conf_file"
echo 'KerberosAuthentication no' >> "$conf_file"
echo 'GSSAPIAuthentication no' >> "$conf_file"
echo 'PubkeyAuthentication yes' >> "$conf_file"

# Disable unwanted subsystems
conf_file='/etc/ssh/sshd_config.d/50-subsystem-overrides.conf'
echo '# Subsystem overrides' > "$conf_file"
echo 'Subsystem     sftp     /bin/false' >> "$conf_file"

# Add any additional customizations
conf_file='/etc/ssh/sshd_config.d/90-additional-overrides.conf'
echo '# Additional overrides' > "$conf_file"
if [ "$SSH_DEBUG" == 'true' ]; then
  echo 'LogLevel DEBUG' >> "$conf_file"
fi

# Fix permissions at every startup
chown -R git:git ~git

# Setup gitolite admin  
if [ ! -f ~git/.ssh/authorized_keys ]; then
  if [ -n "$SSH_KEY" ]; then
    [ -n "$SSH_KEY_NAME" ] || SSH_KEY_NAME=admin
    echo "$SSH_KEY" | tr -d '\n' > "/tmp/$SSH_KEY_NAME.pub"
    su - git -c "gitolite setup -pk \"/tmp/$SSH_KEY_NAME.pub\""
    rm "/tmp/$SSH_KEY_NAME.pub"
  else
    echo "You need to specify SSH_KEY on first run to setup gitolite"
    echo "You can also use SSH_KEY_NAME to specify the key name (optional)"
    echo 'Example: docker run -e SSH_KEY="$(cat ~/.ssh/id_rsa.pub)" -e SSH_KEY_NAME="$(whoami)" joshdreagan/gitolite'
    exit 1
  fi
# Check setup at every startup
else
  su - git -c "gitolite setup"
fi

exec "$@"
