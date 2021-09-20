#! /bin/bash
myname=nikita
s3_bucket=upgrad-$myname


echo "Updating packages...."
sudo apt update -y
echo -e "Packages updated!\n"


echo "Installing apache webserver...."
installed=$(dpkg -s apache2 | gawk '$0 ~ /Status.*installed/{print "Installed"}')
if [ "$installed"  != 'Installed' ]
then
 (sudo apt-get install apache2 -y)
 installed=$?
 if [ $installed -gt 0 ]
 then
  echo "Failed to install apache2 package"
  exit 1
 fi
else
 echo -e "apache2 is installed!\n"
fi



echo "Starting apache webserver...."
running=$(sudo systemctl status apache2 | gawk '$0 ~ /Active: active/{print "running"}')
if [ "$running"  != 'running' ]
then
 (sudo systemctl start apache2)
 running=$?
 if [ $running -gt 0 ]
 then
  echo "Failed to start apache server"
  exit 3
 fi
else
 echo -e "apache server is running!\n"
fi


echo "Enabling apache webserver...."
enabled=$(sudo systemctl status apache2 | gawk '$0 ~ /Loaded:.*enabled/{print "enabled"}')
if [ "$enabled"  != 'enabled' ]
then
 (sudo systemctl enable apache2)
 enabled=$?
 if [ $enabled -gt 0 ]
 then
  echo "Failed to enable apache server"
  exit 2
 fi
else
 echo -e "apache server is enabled!\n"
fi

echo "Log Collection begins..."
timestamp=$(date '+%d%m%Y-%H%M%S')
tarfile=/tmp/${myname}-httpd-logs-${timestamp}.tar
tar -cvf $tarfile /var/log/apache2/*.log
if [ $? -gt 0 ]
then
 echo "Failed to create tar archive $tarfile."
 exit 4
else
 echo -e "tar archive $tarfile created!"
fi


aws s3 \
cp $tarfile \
s3://${s3_bucket}/${myname}-httpd-logs-${timestamp}.tar


