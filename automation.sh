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


echo "Bookkeeping begins....."
inventory_file="/var/www/html/inventory.html"
if [ -f "$inventory_file" ]; then
 echo -e "$inventory_file file already exists."
else
 echo -e "Creating $inventory_file placeholder file..."
 echo "<b>Log Type &nbsp;&nbsp;&nbsp;&nbsp; Date Created &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; Type &nbsp;&nbsp;&nbsp;&nbsp; Size</b><br>" > $inventory_file
fi
 archive_size=`du -hs /tmp/$myname-httpd-logs-$timestamp.tar | awk  '{print $1}'`
echo "<br>httpd-logs &nbsp;&nbsp;&nbsp; ${timestamp} &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; tar &nbsp;&nbsp;&nbsp; ${archive_size}" >> $inventory_file
echo -e "Inventory File Written with Archive Logs details."


echo "Scheduling Daily Execution..."
cronfile='/etc/cron.d/automation'

if [ ! -f  $cronfile ]
then
 echo "$cronfile will be created for daily script execution"
 (sudo echo '0 0 * * 0-6 root /root/Automation_Project/automation.sh >> /root/Automation_Project/cron.log 2>/root/Automation_Project/cron.err' > $cronfile)
 created=$?
 if [ ${created} -gt 0 ]
 then
  echo "Failed to create cron file $cronfile"
  exit 6
 else
  echo "cron entry created in $cronfile !"
 fi
else
 echo "$cronfile exists!"
fi
echo -e "Daily Execution scheduled!\n"
