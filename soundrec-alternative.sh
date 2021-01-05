#!/bin/bash

#----------------------------------------------------------------------------------------------------------------------------------------- #
# !!BASH SCRIPT TO MERGE AN AUDIO STREAM WITH MOTIONEYE RECORDED VIDEO!!																   #		
# 																																		   #
# Editor: James Brindle: https://github.com/jamesbrindle																				   #
# Creation Date: 03/01/2020																												   #
#																																		   #
# Modication of original scripts from: 																									   #
#		* DeadEnded: https://github.com/DeadEnded/MotionEyeAudio and 																	   #
#		* computerandstuff: https://github.com/computersandstuff 																		   #
#																																		   #
# As an alternative that works for me..																									   #
# 																																		   #
# * For use with:                           																							   #
#		* motionEye motion detection																									   #
# 		* script intended for use on motionEyeOS running on RPI4																		   #
#																																		   #
# * I'm not sure how this works with multiple cameras. Probably best use seperate scripts for each device, or use / modifie the script     #																																		   #
#	from DeadEnded who has taken this into account: https://github.com/DeadEnded/MotionEyeAudio                                            #																								   #	
#																																		   #
# !!USAGE!!																																   #
# 																																	       #
#   1. Place script in /data/etc (typical of motionEyeOs) or /etc/motionEye (installed motionEye application)				 			   #
#   2. Make file exectuable: chmod +x soundrec.sh																						   #
#   3. Within the motionEye web interface:																								   #
#		a) Set Video Device 'Extra Motion Options': on_movie_start /data/etc/soundrec.sh start											   #
#		b) Set file storage 'Command' to: sh /data/etc/soundrec.sh %f																	   #
#																																		   #
#------------------------------------------------------------------------------------------------------------------------------------------#

# Variables
operation=$1 								# Bash script input argument
outputcamerafolder=/data/output/Camera1 	# Typical of motionEyeOS
tempaudiofolder=/tmp 						# Needs to be writable folder
audiodelay=22200 							# milliseconds: Audio delay: used to sync audio and video
compress=false								# true = Re-encode and compress video, false = Don't re-encode and compress
subfolder=$(date +'%Y-%m-%d')				# Sub-folder date format
outputfiletype=".mp4"	

# Stop any active instance of arecord
if pidof arecord > /dev/null
then
	# -2 = Interrupt (not 'terminate') arecord process, as arecord utilises traping STDINT()
	kill -2 `pidof arecord`
fi

case ${operation} in
    start) # Start recording audio		 		
		arecord --device=hw:1,0 --format S16_LE --rate 44100 -c1 $tempaudiofolder/recaudio.wav -V mono
	;;

	*)
		mv $tempaudiofolder/recaudio.wav $tempaudiofolder/processaudio.wav
		
		videopath=$1
		videofilename=$(basename -- "$videopath")
		outputfilename=${videofilename/.avi/$outputfiletype}

		# To sync audio with video - In my case: add 2 seconds of silence before the audio stream
		ffmpeg -i $tempaudiofolder/processaudio.wav -af "adelay=$audiodelay|$audiodelay" $tempaudiofolder/readyaudio.wav			
		rm $tempaudiofolder/processaudio.wav || true	
		
		# Not highly tested. May issues in the long run, as this process takes a good few seconds to run
		case ${compress} in
			true) 	 		
				ffmpeg -y -i $videopath -i $tempaudiofolder/readyaudio.wav -c:v libx264 -crf 24 -preset medium -c:a aac -b:a 128k -shortest $outputcamerafolder/$subfolder/temp_$videofilename
		 ;;			
		
		*)
				ffmpeg -y -i $videopath -i $tempaudiofolder/readyaudio.wav -c:v copy -c:a aac -shortest $outputcamerafolder/$subfolder/temp_$videofilename		
		;;
		esac	

		rm $tempaudiofolder/readyaudio.wav || true		
		rm $outputcamerafolder/$subfolder/$videofilename || true		
		mv $outputcamerafolder/$subfolder/temp_$videofilename $outputcamerafolder/$subfolder/$videofilename				
	;;
esac

exit 0