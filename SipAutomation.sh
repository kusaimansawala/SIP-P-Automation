#!/bin/bash

source ./SipAutomationConfig

totalTests=0
passedTests=0
failedTests=0

main()
{
		ValidateConfigParam
		GetInputParam "$@"
		PrepareSetupForTest
		ProcessSetupForTest
}

#-------------------------------------------------------
#Function: ValidateConfigParam()
#Validates parameters from SipAutomationConfig file.
#-------------------------------------------------------
ValidateConfigParam()
{
	if [ "$CONFIG_DIR_PATH" == "" ]
	then
		echo "CONFIG_DIR_PATH field is empty in SipAutomationConfig file"
		exit
	fi
	if [ "$CONFIG_LOCAL_IP" == "" -o "$CONFIG_LOCAL_PORT" == "" ]
	then
		echo "Check local IP and local port values in SipAutomationConfig file, it should not be empty"
		exit
	fi
	if [ $CONFIG_CALL_QUANT -le 0 ]
	then
		echo "CONFIG_CALL_QUANT parameter cannot be 0 or less than 0 in SipAutomationConfig file"
		exit
	fi
	if [ "$CONFIG_XML_PATH" == "" -o "$CONFIG_CSV_PATH" == "" -o "$CONFIG_LOG_PATH" == "" -o "$CONFIG_PCAP_PATH" == "" ]
	then
		echo "XML, CSV, LOG, and PCAP paths cannot be empty, check SipAutomationConfig file"
		exit
	fi
	if [ "$CONFIG_INTERFACE_NAME" == "" ]
	then
		echo "Interface name is not entered in the SipAutomationConfig file"
		exit
	fi
}

#----------------------------------------------------------------------------
#Function: GetInputParam()
#Receives parameter such as Sip address and Transport type from commandline
#----------------------------------------------------------------------------
GetInputParam()
{
	#-----------------------------------------------------------
	#Set the call party IP, ID and port given at the commandline
	#-----------------------------------------------------------
	sipAddress=$1
	position=`expr index "$sipAddress" '@'`
	if [ "$position" -ne 0 ]
	then
		remoteIpAddress=${sipAddress:position}
		callingId=${sipAddress:0:$(expr "$position" - 1)}
		portIndex=`expr index "$remoteIpAddress" ':'`
		if [ $portIndex -eq 0 ]
		then
			remoteIpAddress+=":5060"
		fi
	else
		remoteIpAddress=${sipAddress:position}
		callingId=""
		portIndex=`expr index "$remoteIpAddress" ':'`
		if [ $portIndex -eq 0 ]
		then
			remoteIpAddress+=":5060"
		fi
	fi
	transportType=$2
	transportType=$(echo "$transportType" | tr '[:upper:]' '[:lower:]')
	echo "Remote_ip: $remoteIpAddress, Calling_Party_ID: $callingId, Transport_Type: $transportType"
	read -p "Do you want to run automated XML preparation procedure yes/no: " ans
	if [ "$ans" == "yes" ]
	then
		sh ./AutoXmlGen.sh $callingId@$remoteIpAddress $transportType
		exit
	fi
	read -p "Give path to test: " testPath
	ValidateInputParam $remoteIpAddress $transportType $testPath
}

#----------------------------------------------------------------------------
#Function: ValidateInputParam()
#Validates parameter entered by user from command line
#----------------------------------------------------------------------------
ValidateInputParam()
{
	local Address=$1
	local position=`expr index "$Address" ':'`
	local ip=${Address:0:$(expr "$position" - 1)}
	local port=${Address:position}
	
	if [ $port -gt 65535 -o $port -lt 1024 ]
	then
		echo "Entered remote port out of range"
		exit
	fi
	if [ "$2" != "tcp" -a "$2" != "udp" -a "$2" != "tls" ]
	then
		echo "Invalid transport protocol entered from command line, only UDP, TCP and TLS is suppoted"
		exit
	fi
	if [ "$3" == "" ]
	then
		echo "Kindly provide proper path to module to run scripts"
		exit
	fi
}

#---------------------------------------------------------------------------------------
#Function: PrepareSetupForTest()
#This function will make necessary folders where log, pcaps and csv files will be saved
#---------------------------------------------------------------------------------------
PrepareSetupForTest()
{
	rm -rf $CONFIG_CSV_PATH
	rm -rf $CONFIG_LOG_PATH
	rm -rf $CONFIG_PCAP_PATH
	mkdir $CONFIG_CSV_PATH
	mkdir $CONFIG_LOG_PATH
	mkdir $CONFIG_PCAP_PATH
	mkdir $CONFIG_DIR_PATH/Temp_files/
}

#-----------------------------------------------------------------------------------------------
#Function: ProcessSetupForTest()
#This function is resposible for calling functions for making CSV's, LOG's and generating pcaps
#It will also generate the list of scenarios in case if the testing for the module is concerned
#-----------------------------------------------------------------------------------------------
ProcessSetupForTest()
{
	if [ -f "$testPath" ]
	then
		totalTests=$((totalTests+1))
		CreateCsvFile $testPath
		cd $CONFIG_DIR_PATH/
		tcpdump -i $CONFIG_INTERFACE_NAME -w $CONFIG_DIR_PATH/Temp_files/test.pcap &
		RunScript $dirName $csvName $testPath
		GeneratePcap $testPath
		SaveResultInLogFile $result $testPath
	else
		cd $testPath
		du -a|cut -d$'\t'  -f2 > $CONFIG_DIR_PATH/Temp_files/text.txt
		for file in $(cat $CONFIG_DIR_PATH/Temp_files/text.txt)
		do
			echo $file
			if [ -f $file ]
			then
				continue
			fi
			totalTests=$((totalTests+1))
			CreateCsvFile $testPath
			cd $CONFIG_DIR_PATH/
			tcpdump -i $CONFIG_INTERFACE_NAME -w $CONFIG_DIR_PATH/Temp_files/test.pcap &
			RunScript $dirName $csvName $file
			GeneratePcap $file
			SaveResultInLogFile $result $file
		done
	fi
	rm -f $CONFIG_DIR_PATH/Temp_files/text.txt
	ShowSippTestResults
}

#--------------------------------------------------------------
#Function: CreateCsvFile()
#This function generates CSV files required to run SIPP utility
#--------------------------------------------------------------
CreateCsvFile()
{
	csvName=$(basename "$1")
	dirName=$(basename "$(dirname "$1")")
	if [ "$dirName" == "." ]
	then
		dirName=$(basename "$testPath")
	fi
	csvName=$(echo "$csvName" | cut -f 1 -d '.')
	csvName+=".csv"
	cd $CONFIG_CSV_PATH
	mkdir $dirName
	cd $dirName
	min=1
	echo "SEQUENTIAL" > $csvName
	while [ $min -le $CONFIG_CALL_QUANT ]
	do
		echo "$CONFIG_DISPLAY_NAME;$callingId" >> $csvName
		min=`expr $min + 1`
	done
}

#-------------------------------------------------------------------------------------------
#Function: RunScript()
#This function runs the sipp utlity base on the transport type user enters from command line
#By-default it will be UDP
#-------------------------------------------------------------------------------------------
RunScript()
{
	scriptName=$2
	scriptName=$(scriptName%.csv)
	scriptName+=".xml"
	#------------------------------------------------------------
	#Running sipp with either TCP, UDP or TLS mode
	#------------------------------------------------------------
	if [ "$transportType" == "tcp" ]
	then
		sudo sipp -sf $CONFIG_XML_PATH/$1/$scriptName -inf $CONFIG_CSV_PATH/$1/$2 -i $CONFIG_LOCAL_IP -p $CONFIG_LOCAL_PORT -mi $CONFIG_MEDIA_IP -mp $CONFIG_MEDIA_PORT -m $CONFIG_CALL_QUANT -trace_screen -t t1 $remoteIpAddress
	elif [ "$transportType" == "tls" ]
	then
		sudo sipp -sf $CONFIG_XML_PATH/$1/$scriptName -inf $CONFIG_CSV_PATH/$1/$2 -i $CONFIG_LOCAL_IP -p $CONFIG_LOCAL_PORT -mi $CONFIG_MEDIA_IP -mp $CONFIG_MEDIA_PORT -m $CONFIG_CALL_QUANT -trace_screen -t l1 $remoteIpAddress
	else	
		sudo sipp -sf $CONFIG_XML_PATH/$1/$scriptName -inf $CONFIG_CSV_PATH/$1/$2 -i $CONFIG_LOCAL_IP -p $CONFIG_LOCAL_PORT -mi $CONFIG_MEDIA_IP -mp $CONFIG_MEDIA_PORT -m $CONFIG_CALL_QUANT -trace_screen $remoteIpAddress
	fi
	result=$?
}

#-------------------------------------------------------------------------------------------
#Function: GeneratePcap()
#This function terminates the tcpdump command from ProcessSetupForTest() function
#It will then copy pcaps generated for individual scenario to the user defined location
#------------------------------------------------------------------------------------------
GeneratePcap()
{
	local processId=$(ps -ef | grep 'tcpdump' | grep -v 'grep' | awk '{ print $2 }')
	kill -9 $processId
	local pcapFileName=$(basename "$1")
	local pcapDirName=$(basename "$(dirname "$1")")
	if { "$pcapDirName" == "." }
	then
		pcapDirName=$(basename "$testPath")
	fi
	pcapFileName=$(echo "$pcapFileName" | cut -f 1 -d '.')
	pcapFileName+=".pcap"
	cd $CONFIG_PCAP_PATH
	mkdir $pcapDirName
	mv $CONFIG_DIR_PATH/Temp_files/test.pcap $CONFIG_PCAP_PATH/$pcapDirName/$pcapFileName
	rm -f $CONFIG_DIR_PATH/Temp_files/test.pcap
}

#-------------------------------------------------------------------------------------------
#Function: SaveResultInLogFile()
#This function generates logs for each and every individual tests
#------------------------------------------------------------------------------------------
SaveResultInLogFile()
{
	#--------------------------------------------------
	#Move Sipp statistics to LOG
	#--------------------------------------------------
	logDirName=$(basename "$(dirname "$2")")
	if [ "$logDirName" == "." ]
	then
		logDirName=$dirName
	fi
	cd $CONFIG_LOG_PATH
	mkdir $logDirName
	mv $CONFIG_XML_PATH/$logDirName/*.log $CONFIG_LOG_PATH/$logDirName
	rm -f $CONFIG_XML_PATH/$logDirName/*.log
	
	#--------------------------------------------------
	#Display Result
	#--------------------------------------------------
	echo "**************************************************************"
	if [ "$1" -eq 0 ]
	then
		passedTests=$((passedTests+1))
		echo "$2 Result = $1 Pass"	
	elif [ "$1" -eq 97 ]
	then
		echo "$2 Result = $1 Exit on internal command"	
	elif [ "$1" -eq 99 ]
	then
		echo "$2 Result = $1 Exit without call processed"	
	elif [ "$1" -eq -1 ]
	then
		echo "$2 Result = $1 Fatal error"
	else
		failedTests=$((failedTests+1))
		echo "$2" >> $CONFIG_DIR_PATH/Temp_files/failed.txt
		echo "$2 Result = $1 Fail"
	fi
	echo "**************************************************************" 	
}

#-------------------------------------------------------------------------------------------
#Function: ShowSippTestResults()
#Displays the final test results which include names of all the failed test-cases,
#total scenario executed and passed scenarios
#------------------------------------------------------------------------------------------
ShowSippTestResults()
{
	echo "**********************SIPP TEST RESULTS**********************"
	echo "[ TOTAL SCENARIOS ]	$totalTests"
	echo "[ PASSED ]		$passedTests"
	echo "[ FAILED ]		$failedTests"
	echo "**********************FAILED SCENARIO LIST**********************"
	cd $CONFIG_LOG_PATH
	cat $CONFIG_DIR_PATH/Temp_files/failed.txt
	echo "**********************END**********************"
	rm -f $CONFIG_DIR_PATH/Temp_files/failed.txt
	rm -rf $CONFIG_DIR_PATH/Temp_files/
}

main "$@"
