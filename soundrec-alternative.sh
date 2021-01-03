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
# * I have found in my setup a few random things:																						   #
#																																		   #
# 	1. When using motionEye format 'H264' the video tends to ends prematurely... I have found the MPEG4 (.avi) to be the most reliable.    #
# 	2. MPE4 (.avi) has the downsides of a) large files b) you can't stream recorded movies straight from the motionEye web interface / app #
# 	3. Therefore, what I'm currently trialing is; use .avi but then re-encode and compress to mp4 with ffmpeg. Hence the below variable    #
																																		   #
outputfiletype=".mp4"																													   #
																																		   #
#	4. I'm not sure how this works with multiple cameras. Probably best use seperate scripts for each device, or use / modifie the script  #
#	   from DeadEnded who has taken this into account: https://github.com/DeadEnded/MotionEyeAudio                                         #																								   #	
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
audiodelay=2000 							# milliseconds: Audio delay: used to sync audio and video
compress=true								# true = Re-encode and compress video, false = Don't re-encode and compress
subfolder=$(date +'%Y-%m-%d')				# Sub-folder date format

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
	
	# *** Add other case options here, if required ***
	
	*)
		mv $tempaudiofolder/recaudio.wav $tempaudiofolder/processaudio.wav
		
		videopath=$1
		videofilename=$(basename -- "$videopath")
		outputfilename=${videofilename/.avi/$outputfiletype}

		# To sync audio with video - In my case: add 2 seconds of silence before the audio stream
		ffmpeg -i $tempaudiofolder/processaudio.wav -af "adelay=$audiodelay|$audiodelay" $tempaudiofolder/readyaudio.wav			
		rm $tempaudiofolder/processaudio.wav || true
		
		# Merge audio and video streams into 1 file
		ffmpeg -y -i $videopath -i $tempaudiofolder/readyaudio.wav -c copy -shortest $outputcamerafolder/$subfolder/temp_$videofilename			
		rm $tempaudiofolder/readyaudio.wav || true	
		
		# Not highly tested. May issues in the long run, as this process takes a good few seconds to run
		case ${compress} in
			true) 	 		
				ffmpeg -y -i $outputcamerafolder/$subfolder/temp_$videofilename -vcodec libx264 -crf 24 $outputcamerafolder/$subfolder/temp2_$outputfilename
				rm $outputcamerafolder/$subfolder/$videofilename || true	
				rm $outputcamerafolder/$subfolder/temp_$videofilename || true
				mv $outputcamerafolder/$subfolder/temp2_$outputfilename $outputcamerafolder/$subfolder/$outputfilename
			;;			
			
			*)
				rm $outputcamerafolder/$subfolder/$videofilename || true		
				mv $outputcamerafolder/$subfolder/temp_$videofilename $outputcamerafolder/$subfolder/$videofilename		
			;;
		esac		
	;;
esac

exit 0