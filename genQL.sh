#!/bin/bash
function f_blabla { #remove this line
echo "allows to hide text in editor"
#MIT Licence terms:
#Copyright (c) 2010 Open Skill - http://www.openskill.lu

# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.


# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !!!!!!!! Warning :                                              !!!!!!!!!!!!!
# !!!!!!!! This script is EXPERIMENTAL, so far, don't expect it   !!!!!!!!!!!!!
# !!!!!!!! to run flawlessly, and don't use it as only way of     !!!!!!!!!!!!!
# !!!!!!!! backup, unless you know what you are doing             !!!!!!!!!!!!!
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# Changelog
# V0.71
# Stupid/simple fixes

################################################################################
}
# 1. We Declare the variables
pwd_init=`pwd` # don't edit this one !
admin__mail="jupiter126@gmail.com" # where should the logs be mailed?
backup__dir="backup" #what is the directory to store the backup in (usefull for testing)
genQL__dir="genQL" #name of the dir on the server
rsabits=4096 #set the size of RSA key you want
datfile=datfile.dat #which datfile should be used
htstrength=18 #desired size of htaccess credentials.
debug=1 # Debug mode (1 Enable - 0 Disable )
##########DONE FOR THE VARS
mkdir -p var log $backup__dir && touch $datfile # 2. We create the required foldertree
echo "$0 $1 started on `date +%Y%m%d` at `date +%R` " >> log/backup.log # Start is logged
function f_debug { # Debug mode helps tracing where crashes occur (if $debug = 1)
if [ "x$debug" = "x1" ]; then
	echo "debug = $1"  && echo "pwd = `pwd`" && 
	echo "debug = $1" >> log/debug.log && echo "pwd = `pwd`" >> log/debug.log
fi
}
function f_maillog { # Mails the logs to $admin__mail (if mailx is configured properly on the system)
fonction="f_maillog"
f_debug $fonction
if [ `date +%H` = 23 ]; then # Time of mail sending is 23 - if you want the log to be sent each time genQL exits, change to if [ "23" = "23" ]; then
	rm log/index.html
	echo "Maillog started on `date +%d%m%Y` at `date +%R`" >> log/genQL.log 
	echo " " >> log/genQL.log && echo "Maillog started on `date +%d%m%Y` at `date +%R`"
	echo "Disk space Analysis:" >> log/genQL.log && df -h >> log/genQL.log && echo " " >> log/genQL.log
	for y in `ls $backup__dir/`
		do
		du -h --max-depth=1 $backup__dir/$y >> log/genQL.log
		done
	echo " " >> log/genQL.log
	for z in `ls log/`
		do
		if [ "x$z" != "xgenQL.log" ]; then
			echo " " >> log/genQL.log
			echo $z >> log/genQL.log
			cat log/$z >> log/genQL.log
			rm log/$z
		fi
		done
	f_makehtmlist
	cat log/genQL.log | mailx -s "genQL-`date +%d%m%Y`" $admin__mail && rm log/genQL.log && echo "Info mail should have been sent"
fi
}
function f_exit { # Exits "cleanly"
fonction="f_exit"
f_debug $fonction
cd $pwd_init
rm ${pidfile} && f_maillog && echo "we got out \"properly\""
exit 0
}
trap bashtrap INT # Catches control-C
bashtrap() {
echo "You termintated the program, calling f_exit" && echo "Bashtrap killed program on `date +%d%m%Y` at `date +%R`" >> log/backup.log
f_exit
}
function f_isempty { # Checks is a compulsary field is blank
if [ "x$1" = "x" ]; then
	echo "This can't be left blank, please retry filling it"
	sleep 2
	return 1
fi
}
scriptname=`basename $0` #  Before we do anything, we check if the script isn't allready running: 
pidfile=$pwd_init/var/${scriptname}.pid
if [ -f ${pidfile} ]; then
	oldpid=`cat ${pidfile}`
	result=`ps -ef | grep ${oldpid} | grep ${scriptname}`
	if [ -n "${result}" ]; then
		echo "Script already running! Exiting" && echo "Script already running on `date +%Y%m%d` at `date +%R` with pid=$oldpid" >> log/error.log
		f_exit
	fi
fi
pid=`ps -ef | grep ${scriptname} | head -n1 |  awk ' {print $2;} '`
echo ${pid} > ${pidfile}
function m_main { # Main Menu (displayed if genQL is called without args)
while [ 1 ]
do
	PS3='Choose a number: '
	select choix in "genQL" "Backup" "De_Activate" "Delete" "Restore" "Quit"
	do
		echo " ";echo "####################################";echo " "
		break
	done
	case $choix in
		genQL) 		f_genQL ;;
		Backup)		m_backup ;;
		De_Avtivate)	f_activate ;;
		Delete)		f_remove ;;
		Restore)	f_restore ;;
		Quit)		echo "errors of this session:";cat $pwd_init/log/error.log;echo " ";echo "bye ;)";f_exit ;;
		*)		f_nope ;;
	esac
done
}
function m_backup { # backup menu
while [ 1 ]
do
	PS3='Choose a number: '
	select choix in "Backup_Site" "Backup_db" "Backup_everything" "Back"
	do
		echo " ";echo "####################################";echo " "
		break
	done
	case $choix in
		Backup_Site) 		echo "Which site would you like to backup?";f_backup1site 1 ;;
		Backup_db)		echo "Which db would you like to backup?";f_backup1site 0 ;;
		Backup_everything)	f_backupeverything ;;
		Back) 			return 0 ;;
		*)		f_nope ;;
	esac
done
}
function f_genQL { # Interactive function to add sites to $datfile and generate required keys, files, ...
# This function generates the filetree to be uploaded on the server, the key auth mechanism and the ".htaccess" and ".htpasswd" files.
# !!! You should check those files before uploading them on the server !!!
fonction="f_genQL"
f_debug $fonction
########################################
# <DATA RECOLLECTION>
echo "What is the site's dns (compulsary)"
read dns
f_isempty $dns
if [ "x$?" = "x1" ]; then
	return 1
fi
if [ "`cat $datfile | grep $dns`" != '' ]; then
	echo "$dns is allready in $datfile, please check and try again!"
	return 0
fi
pingtest=1 # default value for pingtest
f_ping $dns
if [ "x$?" = "x2" ]; then
	echo "$dns does not reply to ping, are you sure you want to add it? (y or n)"
	read yn
	if [ "x$yn" != "xy" ]; then
		pingtest=0 && echo "$dns will be added without ping control"
		return 0
	fi
fi
mkdir -p var/$dns/$genQL__dir var/keys 
echo "Which protocol does the site use (ftp or defaults as ssh)"
read protocol
if [ "x$protocol" != "xftp" ]; then
	protocol="ssh"
fi
echo "What is your login for that protocol (compulsary)"
read l0gin
f_isempty $l0gin
if [ "x$?" = "x1" ]; then
	return 1
fi
if [ "x$protocol" = "xftp" ]; then
	echo "What is your ftp password"
	read ftpassword
	echo "On which port does the ftp server listen (defaults to 21)?"
	read $port
	if [ "x$port" = "x" ]; then
		port="21"
	fi
elif [ "x$protocol" = "xssh" ]; then
	echo "On which port does the ssh server listen (defaults to 22)?"
	read port
	if [ "x$port" = "x" ]; then
	port="22"
	fi
	echo "Do you already have a shared key on that server? (y or n)"
	read sharedkey
		if [ "x$sharedkey" = "xy" ]; then
			ls var/keys/|cat -n
			echo "Which is the key that should be used?"
			read key
			sshkeyname=`ls var/keys | sed -n "$key"p`
		elif [ "x$sharedkey" = "xn" ]; then
			echo "What should be the key's name (name it key.xxx and !avoid a name that's allready in use!)"
			read sshkeyname
			for i in `ls var/keys/`
				do
				if [ "x$i" = "x$sshkeyname" ]; then
					echo "$i is allready in use as ssh keyname"
					return 1
				fi
				done
			echo "Patience ...  $rsabits bits RSA keyset is being generated"
			ssh-keygen -b $rsabits -t rsa -f $sshkeyname
			mv $sshkeyname var/keys/
			mv $sshkeyname.pub var/$dns/
		else
			echo "y or n ... Please try again"
			return 1
		fi
else
	echo "ftp or ssh ... Please try again"
	return 1
fi
echo "What is your alternative dns (defaults as site's dns)"
read altdns
if [ "x$altdns" = "x" ]; then
	altdns=$dns && echo "Alternative dns set to $altdns"
fi
echo "What's the site's path on the server?"
echo "!!Start at / for ssh and at ~ for ftp!!"
read rpath
f_isempty $rpath
if [ "x$?" = "x1" ]; then
	return 1
fi
echo "At what time should the site be backed up? (defaults random)"
read timesite
if [ "x$timesite" = "x" ]; then
	f_randomhour
	timesite="$R" && echo "Time Site set to $timesite"
fi
echo "On what day(s) should the site be backed up? (defaults random)"
read daysite
if [ "x$daysite" = "x" ]; then
	f_randomday
	daysite="$d" && echo "Day Site set to $daysite"
fi
echo "At what time should the db be backed up? (defaults random)"
read timedb
if [ "x$timedb" = "x" ]; then
	f_randomhour
	timedb="$R" && echo "Time db set to $timedb"
fi
echo "On what day(s) should the db be backed up? (defaults every day)"
read daydb
if [ "x$daydb" = "x" ]; then
	daydb="Mon-Tue-Wed-Thu-Fri-Sat-Sun" && echo "Day db set to $daydb"
fi
echo "Site's coefficient (default 1 - will be used to define disk usage)"
read coef
if [ "x$coef" = "x" ]; then
	coef="1"
fi
echo "Site Allowance in Gigabite (default 1)"
read GB
if [ "x$GB" = "x" ]; then
	GB="1"
fi
echo "Site's priority (from 0 to 10 ; smallest are done sooner - Default 5)"
read priority
if [ "x$priority" = "x" ]; then
	priority="5"
fi
echo "Is the site active (put 0 for no ; defaults as 1)"
read active
if [ "x$active" = "x" ]; then
	active="1"
fi
echo "Please enter the database server's name (defaults to localhost)"
read dbserv
if [ "x$dbserv" = "x" ]; then
	dbserv='localhost'
fi
echo "Please enter the name of the database:"
read db
f_isempty $db
if [ "x$?" = "x1" ]; then
	return 1
fi
echo "Please enter the name of that database's user:"
read user
f_isempty $user
if [ "x$?" = "x1" ]; then
	return 1
fi
echo "Please enter the corresponding password:"
read pass
f_isempty $pass
if [ "x$?" = "x1" ]; then
	return 1
fi
# </DATA RECOLLECTION>
########################################
# <FILE GENERATION>
echo "Data Recollection complete, adding config to $datfile and preparing files to upload..."
touch $datfile
mkdir -p var/$dns/$genQL__dir/mysql
#index.php
echo '<?php' > var/$dns/$genQL__dir/index.php
echo \$rep_backup\ \=\ \'.\/mysql\/\'\; >> var/$dns/$genQL__dir/index.php
echo '$heure_j = date("H-i");' >> var/$dns/$genQL__dir/index.php
echo '$date_j = date("Ymd");' >> var/$dns/$genQL__dir/index.php
echo \$heure_j\ \=\ str_replace\(\'-\'\,\ \'H\'\,\ \$heure_j\)\; >> var/$dns/$genQL__dir/index.php
echo '$filename = '$db'."-".$date_j."-".$heure_j.".sql";' >> var/$dns/$genQL__dir/index.php
echo 'echo "Your DB is being backed up<p>";' >> var/$dns/$genQL__dir/index.php
echo 'system("'"mysqldump --host=$dbserv --user=$user --password=$pass -C -Q -e --default-character-set=utf8 $db | gzip -c > mysql/\$filename.gz"'");' >> var/$dns/$genQL__dir/index.php
echo 'echo "Done, you can now recover the backup";' >> var/$dns/$genQL__dir/index.php
echo "?>" >> var/$dns/$genQL__dir/index.php
#majeur.php
echo \<\?php > var/$dns/$genQL__dir/majeur.php
echo echo \"Your database is being restored ...... >> var/$dns/$genQL__dir/majeur.php
echo \<br\>\"\; >> var/$dns/$genQL__dir/majeur.php
echo system\(\"cat mysql\/notsuperdb.sql \| mysql --host\=$dbserv --user\=$user --password\=$pass --default-character-set\=utf8 $db\"\)\; >> var/$dns/$genQL__dir/majeur.php
echo echo \"Done, your database has been restored on this hosting.\"\; >> var/$dns/$genQL__dir/majeur.php
echo \?\> >> var/$dns/$genQL__dir/majeur.php
#Les .htaccess et .htpasswd
echo "AuthUserFile "$rpath"/$genQL__dir/.htpasswd" >> var/$dns/$genQL__dir/.htaccess
echo "AuthGroupFile /dev/null" >> var/$dns/$genQL__dir/.htaccess
echo 'AuthName "Restraint Access"' >> var/$dns/$genQL__dir/.htaccess
echo "AuthType Basic" >> var/$dns/$genQL__dir/.htaccess
echo "<Limit GET POST>" >> var/$dns/$genQL__dir/.htaccess
echo "require valid-user" >> var/$dns/$genQL__dir/.htaccess
echo "</Limit>" >> var/$dns/$genQL__dir/.htaccess
loginhtacces=`head -c $htstrength < /dev/urandom | uuencode -m - | tail -n 2 | head -n 1`
passhtaccess=`head -c $htstrength < /dev/urandom | uuencode -m - | tail -n 2 | head -n 1`
htpasswd -bc htpassword "$loginhtacces" "$passhtaccess" && mv htpassword var/$dns/$genQL__dir/.htpasswd
touch var/$dns/$genQL__dir/index.html
echo "AuthUserFile "$rpath"/$genQL__dir/mysql/.htpasswd" >> var/$dns/$genQL__dir/mysql/.htaccess
echo "AuthGroupFile /dev/null" >> var/$dns/$genQL__dir/mysql/.htaccess
echo 'AuthName "Restraint Access"' >> var/$dns/$genQL__dir/mysql/.htaccess
echo "AuthType Basic" >> var/$dns/$genQL__dir/mysql/.htaccess
echo "<Limit GET POST>" >> var/$dns/$genQL__dir/mysql/.htaccess
echo "require valid-user" >> var/$dns/$genQL__dir/mysql/.htaccess
echo "</Limit>" >> var/$dns/$genQL__dir/mysql/.htaccess
touch var/$dns/$genQL__dir/mysql/.htpasswd
touch var/$dns/$genQL__dir/mysql/index.html
echo "$dns;$active;$protocol;$l0gin;$ftpassword;$sshkeyname;$loginhtacces;$passhtaccess;$altdns;$port;$rpath;$timesite;$daysite;$timedb;$daydb;$coef;$GB;$priority;$pingtest" >> $datfile
# </FILE GENERATION>
########################################
# Upload Files
#scp -p $port var/$dns/$dns.pub $l0gin@:~/.ssh/authorized_keys
#####################################
#Should the script upload the files?
#if [ x$protocol = "xftp" ]; then
#		echo "patience, uploading!"
#		lftp -c "open ftp.$b && user $c $d && cd www && mirror --reverse --delete var/$dns/$genQL__dir var/$dns/$genQL__dir" 2>>$pwd_init/log/error.log && echo "genQL is in place on $b"
#	elif [ "x$service" = "xssh" ]; then
#		echo "patience, uploading!"
#		rsync -qaEzc -e ssh var/$dns/$genQL__dir root@$sme__domain:$sme__basedir/$site/html/ 2>>$pwd_init/log/error.log && echo "$genQL__dir is in place on $site"
#		ssh $sme__domain -l root "chown -R www:clients /home/e-smith/files/ibays/$site/html/" && echo "chown done"
#	OR	rsync -qaEzc -e ssh var/$dns/$genQL__dir root@$site:/home/sites/$site/web/ 2>>$pwd_init/log/error.log && echo "$genQL__dir is in place on $site"
#		andthenchownthefiles
#		rep=`ssh $site -l root ls -l /home/sites/|grep $site | cut -f 4 -d"/"`
#		ssh $site -l root "chown -R apache:$rep /home/sites/$site/web/" && echo "chown done"
# Eapeasy ! but so far, just:
tar -czf var/$dns.tar.gz var/$dns && rm -Rf var/$dns && echo "########################################" && echo "Everything has been generated as should be, you can now proceed to upload"
echo "var/$dns.tar.gz in order to place the $genQL__dir - Don't forget to put the shared key on the server!" 
echo "########################################"
#Don't forget to put the right permissions on database with "mysql -u root -p"
# REVOKE ALL PRIVILEGES ON `dbname` . * FROM 'dbuser'@'localhost';
# GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, CREATE TEMPORARY TABLES, LOCK TABLES ON `dbname` . * TO 'dbuser'@'localhost';
}
function f_enablesiteauth { # called with $linenumber as arg ! - sets the key in place for present server to backup.
keey=$1 && keeey=`sed $keey'q;d' $datfile|cut -f 6 -d";"`
echo $keeey
fonction="f_enablesiteauth"
f_debug $fonction
cp var/keys/$keeey /home/`whoami`/.ssh/id_rsa && echo "key of $keeey has been activated" && echo "key of $keeey has been activated" >> log/backup.log 2>>$pwd_init/log/error.log
return 0
}
function f_makehtmlist { # This function puts the logs in xhtml format (you can customize the css)
echo "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">" > log/index.html
echo "<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"en\" >" >> log/index.html
echo "<head>" >> log/index.html
echo "<title>GenQL log `date`</title>" >> log/index.html
echo "<meta http-equiv=\"content-type\" content=\"text/html; charset=utf8\">" >> log/index.html
echo "<link rel=\"stylesheet\" media=\"screen\" type=\"text/css\" title=\"Design\" href=\"design.css\" />" >> log/index.html
echo "</head><body>" >> log/index.html
echo "<div id=\"corps\">" >> log/index.html
for i in `ls $pwd_init/log`
	do
	if [ "x$i" != "xindex.html" ]; then
		echo "<h1 align=\"center\" $i</h1>" >> log/index.html
		echo "<p>" >> log/index.html
		cat log/$i >> log/index.html
		echo "</p>" >> log/index.html
	fi
	done
echo "</div>" >> log/index.html
echo "</body>" >> log/index.html
echo "</html>" >> log/index.html
echo "html log generated"
return 0
}
function f_remove { # to remove a site from $datfile
fonction="f_remove"
f_debug $fonction
echo "Choose which site you want to remove from datfile."
echo " ! The de/Activate provides a temporary alternative ! "
f_select
linenumber=$?
echo "Please confirm that this is the site you want to remove from the backup by pressing y"
sed $linenumber'q;d' $datfile 
read confirm
if [ "x$confirm" = "xy" ]; then
	sed -i "$linenumber"d $datfile && echo "site has been removed" && echo " "
else
	echo "that wasn't y!, please try again" && echo " "
	return 1
fi
}
function f_backup { # Main backup function; called with 2 args: $1=line to be backed up - $2= if set to full, backs up the whole site, else only the db.
linenumber=$1
dborfull=$2
fonction="f_backupsite"
f_debug $fonction
f_variables $linenumber
date=`date +%Y%m%d`
if [ "x$active" = "x1"  ]; then
	f_ping $dns
	if [ "x$?" = "x1" ]; then
		mkdir -p $backup__dir/$dns/files $backup__dir/$dns/mysql
		wget -q http://$dns/$genQL__dir/index.php --http-user=$loginhtacces --http-password=$passhtaccess 2>>$pwd_init/log/error.log
		rm index.php
		echo "Patience, $dns Is being downloaded. . ."
		if [ "x$protocol" = "xssh" ]; then
			f_enablesiteauth $linenumber
			rsync -qaEz -e ssh $l0gin@$altdns:$rpath/$genql__dir/mysql/ $backup__dir/$dns/files/$dns/mysql/ > /dev/null 2>>$pwd_init/log/error.log && echo "$dns's db has been downloaded"
		elif [ "x$protocol" = "xftp" ]; then
			lftp -c "open $altdns && user $l0gin $ftpassword && mirror -x .htpasswd -x www/$genQL__dir/index.php -x www/$genQL__dir/majeur.php /$genQL__dir/mysql $backup__dir/$dns/mysql" 2>>$pwd_init/log/error.log && echo "Database Downloaded"
		fi
		if [ "$dborfull" = "full" ]; then
			if [ "x$protocol" = "xssh" ]; then
				rsync -qaEz -e ssh $l0gin@$altdns:$rpath/ $backup__dir/$dns/files/$dns/ > /dev/null 2>>$pwd_init/log/error.log && echo "$dns has been downloaded"
			elif [ "x$protocol" = "xftp" ]; then
				lftp -c "open $dns && user $l0gin $ftpassword && mirror -x .htpasswd -x www/$genQL__dir/index.php -x www/$genQL__dir/majeur.php / $backup__dir/$dns/files/$dns/" 2>>$pwd_init/log/error.log && echo "$dns has been downloaded"
			fi
		fi
		echo "Patience, $dns is being compressed. . ."
		cd $backup__dir/$dns/files
		if [ `date +%d` = "01" ]; then
			mois=`date --date="yesterday" +%b`
			for j in `ls $dns/$genQL__dir/mysql/|grep -v \`date --date="yesterday" +%Y%m\`` #cleanup
			do
				rm $dns/$genQL__dir/mysql/$j
			done
			tar -cpzf $dns-$mois.`date +%Y`.tar.gz $dns 2>>$pwd_init/log/error.log 
			if [ -f $dns-$mois.`date +%Y`.tar.gz ]; then
				echo "$dns was saved in $backup__dir/$dns/files/$dns-$mois.`date +%Y`.tar.gz" && echo "$dns was saved in $backup__dir/$dns/files/$dns-$mois.`date +%Y`.tar.gz" >> $pwd_init/log/backup.log
				cd $pwd_init
				# FUNCTION f_clean $dns
				echo "$date" > var/$dns
			fi
		else
			for j in `ls $dns/$genQL__dir/mysql/|grep -v \`date +%Y%m\``
			do
				rm $dns/$genQL__dir/mysql/$j
			done
			tar -cpzf $dns-$date.tar.gz $dns 2>>$pwd_init/log/error.log
			if [ -f $dns-$date.tar.gz ]; then
				echo "$dns was saved in $backup__dir/$dns/files/$dns-$date.tar.gz" && echo "$dns was saved in $backup__dir/$dns/files/$dns-$date.tar.gz" >> $pwd_init/log/backup.log
				cd $pwd_init
				# FUNCTION f_clean $dns
				echo "$date" > var/$dns
			fi
		fi
	fi
	############################
	# Check if backup was done (replace $i with $dns ...... )
	#	checkifdone=`ls $backup__dir/sme/$i/files/ | grep "\`date +%Y%m%d\`"|tail -n 1`
	#	checkifdonesize=`ls -l $backup__dir/sme/$i/files/| grep "\`date +%Y%m%d\`"|tail -n 1|cut -f 6 -d" "`
	#	echo $checkifdone
	#	if [ `echo $checkifdone|wc -m` -lt "5" ]; then
	#		echo "ERROR !!! Can't find today's backup of $i which is supposed to just have been done !!! " && echo "ERROR !!! Can't find today's backup of $i which is supposed to just have been done !!!" >> log/error.sme.log
	#	else
	#		echo "$checkifdone has been correctly backed up and is $checkifdonesize in size"
	#		echo "size is $checkifdonesize on `date +%Y%m%d` at `date +%R`" >> $backup__dir/sme/$i/checkifdone
	#		checkifdonestate=`cat $backup__dir/sme/$i/checkifdone|grep $checkifdonesize|wc -l`
	#		let nochangetime=$checkifdonestate/`cat sme.dat|grep $i|cut -f 2 -d";"|sed 's/-/ /'|wc -w`
	#		if [ "$nochangetime" -gt "1" ]; then
	#			echo "!!! Warning, size of sme $i hasn't changed in $nochangetime days" >> log/warning.sme.log
	#		fi
	#	fi
	rm index.php 2>/dev/null #just in case
else
	echo "$dns is inactive"
fi
}
function f_backupeverything { # backs up everything
fonction="f_backupeverything"
f_debug $fonction
j=1
for i in `cat $datfile`
do
	f_backup $j full
	j=$(( j + 1 ))
done
}
function f_backup1site { # Allows to interactively select a site to backup Whole site if called with $1=1, else only 1 db
full=$1
fonction="f_backup1site"
f_debug $fonction
f_select
site=$?
if [ "x$full" != "x1" ]; then #if it's not full, then we do only the db
	echo "starting db backup" && f_backup $site
else
	echo "starting full backup" && f_backup $site full # else we backup everything
fi
}
function f_ping { # If $pingtest is set on 1 for the site, genQL performs a ping test before backing it up.
fonction="f_ping"
f_debug $fonction
if [ "$pingtest" = "1" ]; then
	if ping -c 1 -w 1 -q $1 </dev/null &>/dev/null; then
		echo "$1 Answers to pings: GOOD."
		return 1
	else 
		date=`date +%Y%m%d`
		echo "$1 doesn't answer to ping on $date !!! " >> $pwd_init/log/error.log
		return 2
	fi
else
	echo "ping test disabled."
	return 1
fi
}
function f_nope { # genQL's most graphical part, thanks to moo \o/
fonction="f_nope"
f_debug $fonction
#Sp�ciale d�dicace aux gens qui ne lisent pas les menus :p
echo " ___________________________________________________________________"
echo "| Error:                                                       |"
echo "| same player shoot again, wrong choice I guess !!! |"
echo " -------------------------------------------------------------------"
echo "        \   ^__^"
echo "         \  (oo)\_______"
echo "            (__)\       *\/\ "
echo "                ||----w | "
echo "                ||     || "
echo "/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/"
}
function f_cron { # If genQL is launched with param "cron", it parses $datfile and launches the backup of db and sites according to day_db, hour_db, day_site and hour_site
fonction="f_cron"
f_debug $fonction
priority=0
while [ $priority -lt "11" ]
do
	echo "Priority = $priority "  #remove after tests
	linenumber=1
	for i in `cat $datfile`
	do
		prioritX=`echo "$i"|cut -f 18 -d";"`
		if [ "$prioritX" = "$priority" ]; then
			hour_db=`echo "$i"|cut -f 14 -d";"|grep \`date +%H\``
			day_db=`echo "$i"|cut -f 15 -d";"|grep \`date +%a\``
			day_site=`echo "$i"|cut -f 13 -d";"|grep \`date +%a\``
			hour_site=`echo "$i"|cut -f 12 -d";"|grep \`date +%H\``
			date=`date +%Y%m%d`
			i=`echo $i|cut -f 1 -d";"`
			if [ "$day_db" != "" ]; then
				if [ "$hour_db" != "" ]; then
					f_backup $linenumber db
				else
					echo "No db backup for $i at this time"
				fi
			fi
			if [ "`date +%d`" = "01" ]; then
				f_backup $linenumber full
			elif [ "$day_site" != "" ]; then
				if [ "$hour_site" != "" ]; then
						f_backup $linenumber full
				else
					echo "No site backup for $i at this time"
				fi
			fi
		fi
	linenumber=$(( linenumber + 1 ))
	done
	let priority=$priority+1
done
f_exit
}
function f_randomhour { # gets a random hour to do the backup (function supposed to get some AI)
fonction="f_randomhour"
f_debug $fonction
let R=$RANDOM%24+100 &&R=`echo $R|cut -c 2-3`
}
function f_randomday { # gets a random day to do the backup (function supposed to get some AI)
fonction="f_randomday"
f_debug $fonction
let d=$RANDOM%700/100+1 && if [ $d -eq 1 ]; then d="Mon"
elif [ $d -eq 2 ]; then d="Tue"
elif [ $d -eq 3 ]; then d="Wed"
elif [ $d -eq 4 ]; then d="Thu"
elif [ $d -eq 5 ]; then d="Fri"
elif [ $d -eq 6 ]; then d="Sat"
elif [ $d -eq 7 ]; then d="Sun"
fi
}
function f_variables { # sets all the variables for a line in $datfile ($1 is linenumber)
linenumber=$1
fonction="f_variables"
f_debug $fonction
dns=`sed $linenumber'q;d' $datfile|cut -f 1 -d";"`
active=`sed $linenumber'q;d' $datfile|cut -f 2 -d";"`
protocol=`sed $linenumber'q;d' $datfile|cut -f 3 -d";"`
l0gin=`sed $linenumber'q;d' $datfile|cut -f 4 -d";"`
ftpassword=`sed $linenumber'q;d' $datfile|cut -f 5 -d";"`
sshkeyname=`sed $linenumber'q;d' $datfile|cut -f 6 -d";"`
loginhtacces=`sed $linenumber'q;d' $datfile|cut -f 7 -d";"`
passhtaccess=`sed $linenumber'q;d' $datfile|cut -f 8 -d";"`
altdns=`sed $linenumber'q;d' $datfile|cut -f 9 -d";"`
port=`sed $linenumber'q;d' $datfile|cut -f 10 -d";"`
rpath=`sed $linenumber'q;d' $datfile|cut -f 11 -d";"`
timesite=`sed $linenumber'q;d' $datfile|cut -f 12 -d";"|grep \`date +%H\``
daysite=`sed $linenumber'q;d' $datfile|cut -f 13 -d";"|grep \`date +%a\``
timedb=`sed $linenumber'q;d' $datfile|cut -f 14 -d";"|grep \`date +%H\``
daydb=`sed $linenumber'q;d' $datfile|cut -f 15 -d";"|grep \`date +%a\``
coef=`sed $linenumber'q;d' $datfile|cut -f 16 -d";"`
GB=`sed $linenumber'q;d' $datfile|cut -f 17 -d";"`
priority=`sed $linenumber'q;d' $datfile|cut -f 18 -d";"`
pingtest=`sed $linenumber'q;d' $datfile|cut -f 19 -d";"`
}
function f_select { # Allows to select a site from list
cat -n $datfile
read site
return $site
}
function f_activate { # this function enables/disables a site.
fonction="f_remove"
f_debug $fonction
echo "Choose which site you want to (De)Activate."
f_select
linenumber=$?
f_variables $linenumber
if [ "x$active" = "x1" ]; then
	active=0 && echo "$dns is now Unactive"
elif [ "x$active" = "x0" ]; then
	active=1 && echo "$dns is now Active"
fi
echo "$dns;$active;$protocol;$l0gin;$ftpassword;$sshkeyname;$loginhtacces;$passhtaccess;$altdns;$port;$rpath;$timesite;$daysite;$timedb;$daydb;$coef;$GB;$priority;$pingtest" >> $datfile && sed -i "$linenumber"d $datfile
}
# End of function declaration, program entry point
if [ "x$1" = "x" ]; then # go to main menu if there are no args
m_main
elif [ $1 = "cron" ]; then #if started with cron
	f_cron
else 
	echo "argument not known, arg can be \"cron\""
fi
#TODOLIST
function f_clean { # This function was allready buggy in genQL's older versions and hans't been ported yet... Disabled, clean by hand at the moment.
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!! Too experimental, not yet ported to new version, temporarily disabled !!"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
#fonction="f_cleansme"
#f_debug $fonction
#i=$1
#i=`cat $datfile|grep $i`
#coef=`echo $i|cut -f 5 -d";"`
#let trans=`echo $i|cut -f 3 -d";"|sed 's/-/ /'|wc -w`*`echo $i|cut -f 4 -d";"|sed 's/-/ /'|wc -w`
#let coeftot=$coef*$trans
#i=`echo $i|cut -f 1 -d";"`
#echo "clean des backup de $i"
#ls $backup__dir/sme/$i/files|grep tar.gz|grep -v Jan|grep -v Feb|grep -v Mar|grep -v Apr|grep -v May|grep -v Jun|grep -v Jul|grep -v Aug|grep -v Sep|grep -v Oct|grep -v Nov|grep -v Dec>tempclear
#let limit=$nb__site*$coeftot
#echo "$i a droit � $limit backups de sites"
#n=`cat tempclear|wc -l`
#echo "$i a $n backups de sites"
#n=$(( n - $limit ))
#[[ $n < 0 ]] && n=0
#for j in `head -n $n tempclear`
#do
#	rm $backup__dir/sme/$i/files/$j && echo "$backup__dir/sme/$i/files/$j � �t� effac�"
#done
#rm tempclear
#}
# sync with the server
#ls $backup__dir/sme/$i/mysql/|grep sql.gz|grep -v ZFIX >tempclear
#let limit=$nb__db*$coeftot
#echo "$i a droit � $limit backups de db"
#n=`cat tempclear|wc -l`
#echo "$i a $n backups de db"
#n=$(( n - $limit ))
#if [ $n -lt 0 ]; then
#	n=0
#fi
#for j in `head -n $n tempclear`
#do
#	rm $backup__dir/sme/$i/mysql/$j && echo "$backup__dir/sme/$i/mysql/$j � �t� effac�"
#done
#rm tempclear

}
function f_restore { # This function was allready buggy in genQL's older versions and hans't been ported yet... Disabled, restore by hand at the moment.
fonction="f_restore"
f_debug $fonction
# echo "Which site would you like to restore?"
# f_select
# echo "Would you like to restore everything or only the db?"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!! Too experimental, not yet ported to new version, temporarily disabled !!"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
#cat -n $datfile|cut -f 1 -d";"
#echo " "
#f_ping $dns
#if [ "$?" = "1" ]; then
#	echo "Quel site souhaitez vous restaurer?"
#	read site
#	site=`sed -n "$site"p sme.dat|cut -f 1 -d";"`
#	ls -t sme/$site/files/*.tar.gz | sed s:sme/$site/files/:: > templist
#	cat -n templist
#	echo "Quel backup souhaitez vous restaurer?"
#	read bck
#	bck=`sed -n "$bck"p templist`
#	rm -Rf sme/$site/files/$site/
#	echo "Patience, on d�compresse :D-"
#	tar -xpzf sme/$site/files/$bck 2>>$pwd_init/log/error.log  && echo "archive d�compress�e"
#	db=`ls sme/$site/files/$site/genQL/mysql/|grep .gz |tail -n1`
#	gunzip -dc sme/$site/files/$site/genQL/mysql/$db > sme/$site/files/$site/genQL/mysql/notsuperdb.sql 2>>$pwd_init/log/error.log && echo "db d�compress�e"
#	db=`echo $db|sed s:.gz::`
#	#chown -R www:\root sme/$site/files/$site/
#	echo "Patience, on upload ^^"
#	rsync -qaEzc -e ssh sme/$site/files/$site/ root@$sme__domain:/home/e-smith/files/ibays/$site/html/ 2>>$pwd_init/log/error.log && echo "synchronisation effectu�e"
#	ssh $sme__domain -l root "chown -R www:clients /home/e-smith/files/ibays/$site/html/"
#	echo "On r�instaure la base de donn�es"
#	wget -q "http://www.$sme__domain/$site/genQL/majeur.php" "--http-user=$htaccess__user" "--http-password=$htaccess__pwd_clr"
#	rm templist
#	rm majeur.php
#	echo "Et voilou, si tout va bien, le site $site a �t� remis en place comme il �tait lors du backup de "$db
# fi
# cat -n sme.dat|cut -f 1 -d";"
# echo " "
# echo "Quel site souhaitez vous restaurer?"
# read site
# site=`sed -n "$site"p sme.dat`
# ls -t sme/$site/mysql/*.sql.gz | sed s:sme/$site/mysql/:: > templist
# cat -n templist
# echo "Quelle db souhaitez vous restaurer?"
# read bck
# bck=`sed -n "$bck"p templist`
# echo "Patience, on d�compresse :D-"
# gzip -dc sme/$site/mysql/$bck > notsuperdb.sql 2>>$pwd_init/log/error.log && echo "db d�compress�e"
## chown www notsuperdb.sql
# echo "Patience, on upload ^^"
# rsync -qaEzc -e ssh notsuperdb.sql root@$sme__domain:/home/e-smith/files/ibays/$site/html/genQL/mysql/ 2>>$pwd_init/log/error.log && echo "db upload�e"
# ssh $sme__domain -l root "chown -R www:clients /home/e-smith/files/ibays/$site/html/"
# echo "On r�instaure la base de donn�es"
# wget -q "http://www.$sme__domain/$site/genQL/majeur.php" "--http-user=$htaccess__user" "--http-password=$htaccess__pwd_clr"
# rm templist majeur.php notsuperdb.sql
# echo "Et voilou, si tout va bien, la db du site $site a �t� remise en place comme elle �tait lors du backup de "$bck
}
function f_checkbackup { # supposed to add some checksums
#si heure=23; check r�cursivement dans tous les dossiers sql pour voir si un backup db a �t� effectu�!)
echo lol
}
function f_countbackup { # check that amount of backup files = theoric number according to $datfile
#a placer dans exi if heure=23 compter le nombre de db/sites a backupper selon les fichiers dat
#faire une var qui fait +1 chaque fois que un site/db est backupp� en fin de journ�e les chiffres doivent correspondre.
echo lol
}
