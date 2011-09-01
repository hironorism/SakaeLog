#!/bin/sh

MYSQL_USER=root
MYSQL_PASS=''

mysql -u $MYSQL_USER --password=$MYSQL_PASS < ./sql/my.sql

perl ./script/create_member.pl


