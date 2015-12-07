#!/bin/sh
#

#vars:

## Variables for connecting to the Logitechmediaserver 

port=9000 ## The HTTP Port used by lms
server=192.168.199.11 ## The Ip Address from your PC running lms 

time_stamp=`date "+%d.%m.%Y %H:%M"`

check_ghostscript(){
                        lokal ghostscript_ok=$(which ghostscript)
                        if [ -t "ghostscript_ok" ]
                           then
                           lokal needed="ghostscript "
                        fi
                   }     
check_sqlite3()    {
			local sqlite3_ok=$(which sqlite3)
			if [ -z "$sqlite3_ok" ]
                           then  
                           lokal needed="sqlite3 "$needed 
                        fi
                 
                    }
                    
                    
                  
check_wkhtmltopdf() {
		        local wkhtmltopdf_ok=$(which wkhtmltopdf)
		        if [ -z "wkhtmltopdf_ok" ]
		           then  
		           lokal needed="wkhtmltopdf "$needed   
		        fi
		    }
		    

if [ -z "needed" ]
   then
   echo "you need $needed to run this"
   echo "under Debian you can install it via:"
   echo "sudo apt-get update && apt-get upgrade && apt-get install $needed"
   exit 1
fi

## Variables to connect to the (local) sqlite Database
## 

sqldb=/var/lib/squeezeboxserver/cache/library.db ## Here is the library from lms stored 

lms_offline_db=~/slimgallery/lms_offline.sqlite    ## Make sense not to use the real Database
                                                   ## If our lms Server is headless we dont
                                                   ## need to copy the whole Database only
                                                   ## Two Tables from it.


## Since i am a lazy guy and we need these long lines more than once
## the shared sql statements stored here
 
querybase="name, title, artwork FROM albums ,contributors WHERE albums.contributor=contributors.id"
querysort="ORDER by contributors.name COLLATE NOCASE ASC"

##HTML

## Which size the Images should have?
## 250 by 250 fits best for me.
## bigger is nicer but ends up with a much larger result ;-(

size="250"
## dont touch - needed exacly like this!
image="cover_"$size"x"$size"_o"


## If we're using a headless linux without X-Server
## for our logitechmediaserver - we can/should use a offline Database 
## with only the needed two tables.

offline_db(){
            rm $lms_offline_db
            sqlite3 $sqldb ".dump albums"|sqlite3 $lms_offline_db
            sqlite3 $sqldb ".dump contributors"|sqlite3 $lms_offline_db       
            sqldb=$lms_offline_db
            }
            
## Are we on the system that runs lms?
if [ -f "$sqldb" ]
   then
   offline_db     
fi

if [ ! -f $sqldb ]
   then
   sqldb=$lms_offline_db
fi   
   ## we need a homefolder
if [ ! -d ~/slimgallery/ ]
   then
   mkdir ~/slimgallery
fi

   ## we need a minimal css
if [ ! -f ~/slimgallery/screen.css ]
   then   
   echo "body    {">~/slimgallery/screen.css
   echo "         font-family: Verdana, Arial, sans-serif;">>~/slimgallery/screen.css
   echo "         font-size: 100.01%;">>~/slimgallery/screen.css
   echo "         padding: 0;">>~/slimgallery/screen.css
   echo "         width:100%;">>~/slimgallery/screen.css
   echo "         height:100%;">>~/slimgallery/screen.css
   echo "        }">>~/slimgallery/screen.css
   echo ".center {">>~/slimgallery/screen.css
   echo "         text-align: center;">>~/slimgallery/screen.css
   echo "         word-break: break-word;">>~/slimgallery/screen.css
   echo "         width: 220px;">>~/slimgallery/screen.css
   echo "         margin-top: 10px;">>~/slimgallery/screen.css
   echo "        }">>~/slimgallery/screen.css
   echo " ">>~/slimgallery/screen.css
   echo ".clear  {">>~/slimgallery/screen.css
   echo "         clear: both;">>~/slimgallery/screen.css
   echo "        }">>~/slimgallery/screen.css
   echo " ">>~/slimgallery/screen.css
   echo "h1      {">>~/slimgallery/screen.css
   echo "         text-align: center;">>~/slimgallery/screen.css
   echo "         width: 750px;">>~/slimgallery/screen.css
   echo "         font-size: 1.0em;">>~/slimgallery/screen.css
   echo "        }">>~/slimgallery/screen.css
   echo " ">>~/slimgallery/screen.css
   echo "menue      {">>~/slimgallery/screen.css
   echo "         margin: 80;">>~/slimgallery/screen.css 
   echo "         text-align: center;">>~/slimgallery/screen.css
   echo "         font-size: 1.1em;">>~/slimgallery/screen.css
   echo "        }">>~/slimgallery/screen.css
   echo " ">>~/slimgallery/screen.css
   echo "stamp      {">>~/slimgallery/screen.css
   echo "         text-align: left;">>~/slimgallery/screen.css
   echo "         width: 550px;">>~/slimgallery/screen.css
   echo "         font-size: 0.7em;">>~/slimgallery/screen.css
   echo "        }">>~/slimgallery/screen.css
   echo " ">>~/slimgallery/screen.css
   echo ".cover  {">>~/slimgallery/screen.css
   echo "         float: left;">>~/slimgallery/screen.css
   echo "         width: 250px;">>~/slimgallery/screen.css         
   echo "         padding: 3px;">>~/slimgallery/screen.css
   echo "         font-size: 0.7em;">>~/slimgallery/screen.css
   echo "        }">>~/slimgallery/screen.css
                                                           
fi   

cd  ~/slimgallery

if [ ! -f $sqldb ]
   then
   echo " ####################################"
   echo " #           STOP                   #" 
   echo " #     can't continue -  missing    #" 
   echo " #  $sqldb"
   echo " #        Please copy file to       #"
   echo " #       ~/slimgallery/             #"
   echo " #                                  #"
   echo " ####################################"
   exit 1
fi

## get the (virtual) Artistname for the Samplers

VA_result=$(sqlite3 $sqldb "select name, count (*) FROM albums ,contributors WHERE albums.contributor=contributors.id AND albums.compilation like '1';")
VA=$(echo $VA_result|cut -d ' ' -f1)
VA_count=$(echo $VA_result|cut -d '|' -f2)

## Make own html pages for each leading char
## and one for the non char Artists like 10cc or 2raumwohnung
## we do not forget the Sampler as well

to_check="0-9 A B C D E F G H I J K L M N O P Q R S T The U V W X Y Z $VA"

for include in $to_check
    do
    echo $include
    if [ "$include" = "0-9" ]
       then
       artist_count=$(sqlite3 $sqldb "select count (*) FROM contributors where contributors.name NOT GLOB '[a-z|A-Z]*';")
    else      
       artist_count=$(sqlite3 $sqldb "select count (*) FROM contributors where contributors.name LIKE '$include%';")
    fi
    echo $artist_count
    if [ ! "$artist_count" = "0" ]
       then
       all_artists="$all_artists "$include
    fi
done

if [ ! "$VA" = "" ]
   then
   va=$(echo $VA|cut -c -1)
   echo "   your compilation Artistname starts with $VA"
   echo "   $va and $VA will get a separate html file we dont mix them together."
   echo "   Logitechmediaserver lists $VA_count Albums for $VA"
   echo "   we do the same for 'T' and 'The' otherwise we end with to large files."
   echo " "
else
   echo "   can't find the virtual Artistname from your samplers!"
   echo "    - we continue anyway"
fi   

echo "      please remember don't pubish any created html or pdf to the public !"
echo "      "

## doit (here comes the html part)
## we need a html Header

for a in $all_artists
    do
    	echo creating $a.html
	output=$a.html
	i=1
				
	echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>">$output
	echo "<!DOCTYPE html PUBLIC /"-//W3C//DTD XHTML 1.0 Transitional//EN/" /"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd/">">>$output
	echo "<html>">>$output
	echo " <head>">>$output
	echo " <meta http-equiv=/"X-UA-Compatible/" content=/"IE=7/" />">>$output
	echo " <link rel=\"stylesheet\" type=\"text/css\" href=\"screen.css\">">>$output
	echo " <title>Muzzigbox Alben $a</title>">>$output
	echo " <meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\"/>">>$output
	echo "</head>">>$output
	echo " <body>">>$output
	echo " <stamp>created: $time_stamp</stamp>">>$output
        echo " <p> </p>">>$output
        ## lets get the content to our html
        
            ## eg 10cc; 2raumwohnung and others should be included!        
        if  [ "$a" = "0-9" ]
           then      
           sqlite3 $sqldb "SELECT $querybase AND contributors.name NOT GLOB '[a-z|A-Z]*' $querysort;" |sort -f>/tmp/sql.txt
           ## we want a separate file for the Sampler dont mix them into another file
       	elif [ "$a" = "$va" ]
	   then  
	   sqlite3 $sqldb "SELECT $querybase AND contributors.name LIKE '$a%%' AND contributors.name not LIKE '$VA%%' $querysort;" |sort -f>/tmp/sql.txt
	   ## same procedure for Artist like The Beatles; The Cure  
	elif [ "$a" = "T" ]
	   then
	   sqlite3 $sqldb "SELECT $querybase AND contributors.name LIKE '$a%%' AND contributors.name not LIKE 'The %%' $querysort;" |sort -f>/tmp/sql.txt
	else
	   ## our normal procedure without any fancy stuff
	   sqlite3 $sqldb "SELECT $querybase AND contributors.name LIKE '$a%%' $querysort;" |sort -f >/tmp/sql.txt
	fi
	
	filename="/tmp/sql.txt"
	
	## create a minimal Menue
	
	link=""
	for l in $all_artists
	    do
	    if [ $l = $a ]
	       then
	       echo " <h1><a href=\""$l.html\"">$l</a></h1>">>$output
	    fi     
	       link="$link<a href=\""$l.html\"">$l</a> "   
	done
	echo " <menue>$link</p></menue>">>$output
	row=0
	
	while read -r line
	do
		name=$(echo $line|cut -d '|' -f1)
		title=$(echo $line|cut -d '|' -f2)
		cover=$(echo $line|cut -d '|' -f3)
		
		echo "	<div class=\"cover\">">>$output
		echo "          <img src=\"http://$server:$port/music/$cover/$image.jpg\" width=\"$size\" height=\"$size\" alt=\"$name - $title\" title =\"$name - $title\">">>$output
		echo "		<p class=\"center\">&nbsp;$name -&nbsp;$title&nbsp;</p>">>$output
		echo "	</div>">>$output
		
		## by using 3 Covers in a row we get the best result 
		if [ $i -lt 3 ]
			then
			i=$(( $i + 1 ))
		else   
			echo "	<br style=\"clear: left;\">">>$output
			row=$(( $row + 1 ))
			i=1   
		fi
		if [ "$row" = "2" ]
		   then
		   echo "  <p>&nbsp;</p>">>$output
		   ## no more menue for each page
		   #echo " <menue>$link</p></menue>">>$output
		   row=0
		fi      
	done < "$filename"
		echo "       </body>">>$output  
		echo "</html>">>$output
done

for i in *.html
    do
    html="$html $i"
done

echo "   compose all together in a single pdf file - that needs some time!"
wkhtmltopdf -O landscape $html outfile.pdf

if [ -f outfile.pdf ]
   then
   echo "   Now its Time for another (silent) Task!"
   echo "   Dont panic take a cup of tea instead ;-)"
   echo "   even when Ghostscript is slow - i didnt find a tool that compose such clean & small files"
   if [ -f slimgallery.pdf ]
      then
      echo deleting the previous slimgallery.pdf
      rm slimgallery.pdf
   fi   
   gs -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -sOutputFile=slimgallery.pdf outfile.pdf
fi   
if [ -f outfile.pdf ]
   then
   echo "deleting the previous outfile.pdf"
   echo "we dont need that anymore"
   rm outfile.pdf
fi

echo "#####################################################################"
echo "#                                                                   #"
echo "#                              done                                 #"
echo "#         slimgallery.pdf is stored under ~/slimgallery             #"
echo "#  please remember - don't pubish slimgallery.pdf to the public !   #"
echo "#   you may end up with some Lawyer - cause you didnt have the      #"
echo "#      copyright for the Images - you dont want that                #"
echo "#                                                                   #"
echo "#####################################################################"
echo start: $time_stamp
echo stop `date "+%d.%m.%Y %H:%M"`
