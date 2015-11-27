#!/bin/sh
#

#vars:
## LMS 
port=9000
server=192.168.199.11

dateis=`date "+%d.%m"`


cp -u --preserve=timestamps '/run/user/1000/gvfs/smb-share:server=192.168.199.11,share=muzzigbox/lms_offline.sqlite' /home/jan/Musik/
#sqldb=/var/lib/squeezeboxserver/cache/library.db
lms_offline_db=/home/jan/Musik/lms_offline.sqlite
querybase="name, title, artwork FROM albums ,contributors WHERE albums.contributor=contributors.id"
querysort="ORDER by contributors.name COLLATE NOCASE ASC"

##HTML
size="250"
image="cover_"$size"x"$size"_o"


#VA=$(grep "variousArtistsString:" /var/lib/squeezeboxserver/prefs/server.prefs|grep -v "ts"|cut -d "'" -f2)



offline_db(){
            rm $lms_offline_db
            sqlite3 $sqldb ".dump albums"|sqlite3 $lms_offline_db
            sqlite3 $sqldb ".dump contributors"|sqlite3 $lms_offline_db       
            sqldb=$lms_offline_db
            }

##  offline_db

if [ "$sqldb" = "" ]
   then
   sqldb=$lms_offline_db
fi   

all_artists="[0-9] A B C D E F G H I J K L M N O P Q R S T The U V W X Y Z Diverse"

for a in $all_artists
# for a in [0-9] {A..Z} The Diverse ###doesnt work ?
    do
    	echo creating $a.html
	output=$a.html
	i=1
	
	#doit
	cd /home/jan/Musik/lms_offline/
	
	echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>">$output
	echo "<!DOCTYPE html PUBLIC /"-//W3C//DTD XHTML 1.0 Transitional//EN/" /"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd/">">>$output
	echo "<html>">>$output
	echo " <head>">>$output
	echo " <meta http-equiv=/"X-UA-Compatible/" content=/"IE=7/" />">>$output
	echo " <link rel=\"stylesheet\" type=\"text/css\" href=\"screen.css\">">>$output
	echo " <title>Muzzigbox Alben $a</title>">>$output
	echo " <meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\"/>">>$output
	echo "<style type=\"text/css\">">>$output
	echo "body">>$output
	echo "{">>$output
	echo "margin: 0;">>$output
	echo "padding: 0;">>$output
	echo "width:100%;">>$output
	echo "height:100%;">>$output
	echo "font-family: Verdana, Arial, sans-serif;">>$output
	echo "}">>$output
	echo "#center">>$output
	echo "{">>$output
	echo "width: 700px;">>$output
	echo "border: 1px solid blue;">>$output
	echo "margin: 30px auto;">>$output
	echo "background: #E0EEEE;">>$output
	echo "padding: 10px;">>$output
	echo "}">>$output
	echo ".img250u">>$output
	echo "{">>$output
	echo "float: left;">>$output
	echo "width: 250px;">>$output
	echo "padding: 3px;">>$output
	echo "font-size: 0.7em;">>$output
	echo "}">>$output
	echo "</style>">>$output
	echo "</head>">>$output
	echo " <body>">>$output
        
        if  [ "$a" = "[0-9]" ]
           then      
           sqlite3 $sqldb "SELECT $querybase AND contributors.name NOT GLOB '[a-z|A-Z]*' $querysort;" |sort -f>/tmp/sql.txt
       	elif [ "$a" = "D" ]
	   then  
	   sqlite3 $sqldb "SELECT $querybase AND contributors.name LIKE '$a%%' AND contributors.name not LIKE 'Diverse%%' $querysort;" |sort -f>/tmp/sql.txt
	elif [ "$a" = "T" ]
	   then
	   sqlite3 $sqldb "SELECT $querybase AND contributors.name LIKE '$a%%' AND contributors.name not LIKE 'The %%' $querysort;" |sort -f>/tmp/sql.txt
	else
	   sqlite3 $sqldb "SELECT $querybase AND contributors.name LIKE '$a%%' $querysort;" |sort -f >/tmp/sql.txt
	fi  
   
	mkdir -p ./images
	filename="/tmp/sql.txt"
	link=""
	for l in $all_artists
	    do
	    link="$link<a href=\""$l.html\"">$l</a> "
	done
	echo " <p class=\"center\">$link</p>">>$output
	
	while read -r line
	do
		name=$(echo $line|cut -d '|' -f1)
		title=$(echo $line|cut -d '|' -f2)
		cover=$(echo $line|cut -d '|' -f3)
		
		echo "	<div class=\"img250u\">">>$output
		echo "		<img src=\"images/$cover.jpg\" width=\"250\" height=\"250\" alt=\"$name - $title\" title =\"$name - $title\">">>$output
		echo "		<p class=\"center\">$name - $title</p>">>$output
		echo "	</div>">>$output
		if [ $i -lt 3 ]
			then
			i=$(( $i + 1 ))
		else   
			echo "	<br style=\"clear: left;\">">>$output
			i=1   
		fi
       
		if [ ! -f "./images/$cover.jpg" ]
		   then
		   wget --quiet http://$server:$port/music/$cover/$image -O ./images/$cover.jpg
		fi   
	done < "$filename"
		echo "       </body>">>$output  
		echo "</html>">>$output
		#wkhtmltopdf $output $a.pdf
done



for i in *.html
    do 
    echo now coverting $i to pdf    
    wkhtmltopdf -O landscape "$i" "`basename "\$i" .html`".pdf
done

echo compose all pdf together
gs -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -sOutputFile=/home/jan/Musik/muzzigbox.pdf *.pdf