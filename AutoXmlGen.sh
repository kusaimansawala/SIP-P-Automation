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
	ValidateInputParam $remoteIpAddress $transportType
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
}

#---------------------------------------------------------------------------------------
#Function: PrepareSetupForTest()
#This function will make necessary folders where log, pcaps and csv files will be saved
#---------------------------------------------------------------------------------------
PrepareSetupForTest()
{
	rm -rf $CONFIG_AUTO_GEN_XML_PATH
	mkdir $CONFIG_AUTO_GEN_XML_PATH
	mkdir $CONFIG_AUTO_GEN_XML_PATH/Csv
	mkdir $CONFIG_AUTO_GEN_XML_PATH/Xml
	mkdir $CONFIG_AUTO_GEN_XML_PATH/Pcap
	mkdir $CONFIG_AUTO_GEN_XML_PATH/Log
}

#-----------------------------------------------------------------------------------------------
#Function: ProcessSetupForTest()
#This function is resposible for calling functions for making CSV's, LOG's and generating pcaps
#It will also generate the list of scenarios in case if the testing for the module is concerned
#-----------------------------------------------------------------------------------------------
ProcessSetupForTest()
{
	read -p "Enter the DTMF digits required by the call: " dtmfNo
	CreateCsvFile
	CreateXmlScenario $dtmfNo
	tcpdump -i $CONFIG_INTERFACE_NAME -w $CONFIG_AUTO_GEN_XML_PATH/Pcap/Auto_generated.pcap &
	RunScript
	GeneratePcap
	SaveResultInLogFile $result
	rm -f $CONFIG_DIR_PATH/Temp_files/text.txt
	ShowSippTestResults
}

#--------------------------------------------------------------
#Function: CreateCsvFile()
#This function generates CSV files required to run SIPP utility
#--------------------------------------------------------------
CreateCsvFile()
{
	cd $CONFIG_AUTO_GEN_XML_PATH
	echo "SEQUENTIAL" > Auto_generated.csv
	echo "$CONFIG_DISPLAY_NAME;$callingId" >> Auto_generated.csv
}

#--------------------------------------------------------------
#Function: CreateXmlScenario()
#This function will automatically generate the XML file
#--------------------------------------------------------------
CreateXmlScenario()
{
	local Dtmf=$1
	cd $CONFIG_AUTO_GEN_XML_PARTS
	cat part1.xml > $CONFIG_AUTO_GEN_XML_PATH/Xml/Auto_generated.xml
	for (( i=0; i< ${#Dtmf}; i++ ))
	do
		local digit=${Dtmf:$i:1}
		cat part2.xml >> $CONFIG_AUTO_GEN_XML_PATH/Xml/Auto_generated.xml
		sed -i s/substitute/$digit/g $CONFIG_AUTO_GEN_XML_PATH/Xml/Auto_generated.xml
	done
	if [ -f part3.xml ]
	then
		isPcapPresent=1
		cat part3.xml >> $CONFIG_AUTO_GEN_XML_PATH/Xml/Auto_generated.xml
	else
		isPcapPresent=0
	fi
	cat part4.xml >> $CONFIG_AUTO_GEN_XML_PATH/Xml/Auto_generated.xml
}

#-------------------------------------------------------------------------------------------
#Function: RunScript()
#This function runs the sipp utlity base on the transport type user enters from command line
#By-default it will be UDP
#-------------------------------------------------------------------------------------------
RunScript()
{
	#------------------------------------------------------------
	#Running sipp with either TCP, UDP or TLS mode
	#------------------------------------------------------------
	if [ $isPcapPresent -eq 0 ]
	then
		if [ "$transportType" == "tcp" ]
		then
			sudo sipp -sf $CONFIG_XML_PATH/$1/$scriptName -inf $CONFIG_CSV_PATH/$1/$2 -i $CONFIG_LOCAL_IP -p $CONFIG_LOCAL_PORT -mi $CONFIG_MEDIA_IP -mp $CONFIG_MEDIA_PORT -m $CONFIG_CALL_QUANT -trace_screen -t t1 -rtp_echo $remoteIpAddress
		elif [ "$transportType" == "tls" ]
		then
			sudo sipp -sf $CONFIG_XML_PATH/$1/$scriptName -inf $CONFIG_CSV_PATH/$1/$2 -i $CONFIG_LOCAL_IP -p $CONFIG_LOCAL_PORT -mi $CONFIG_MEDIA_IP -mp $CONFIG_MEDIA_PORT -m $CONFIG_CALL_QUANT -trace_screen -t l1 -rtp_echo $remoteIpAddress
		else	
			sudo sipp -sf $CONFIG_XML_PATH/$1/$scriptName -inf $CONFIG_CSV_PATH/$1/$2 -i $CONFIG_LOCAL_IP -p $CONFIG_LOCAL_PORT -mi $CONFIG_MEDIA_IP -mp $CONFIG_MEDIA_PORT -m $CONFIG_CALL_QUANT -trace_screen -rtp_echo $remoteIpAddress
		fi
	else
		if [ "$transportType" == "tcp" ]
                then
                        sudo sipp -sf $CONFIG_XML_PATH/$1/$scriptName -inf $CONFIG_CSV_PATH/$1/$2 -i $CONFIG_LOCAL_IP -p $CONFIG_LOCAL_PORT -mi $CONFIG_MEDIA_IP -mp $CONFIG_MEDIA_PORT -m $CONFIG_CALL_QUANT -trace_screen -t t1 $remoteIpAddress
                elif [ "$transportType" == "tls" ]
                then
                        sudo sipp -sf $CONFIG_XML_PATH/$1/$scriptName -inf $CONFIG_CSV_PATH/$1/$2 -i $CONFIG_LOCAL_IP -p $CONFIG_LOCAL_PORT -mi $CONFIG_MEDIA_IP -mp $CONFIG_MEDIA_PORT -m $CONFIG_CALL_QUANT -trace_screen -t l1 $remoteIpAddress
                else
                        sudo sipp -sf $CONFIG_XML_PATH/$1/$scriptName -inf $CONFIG_CSV_PATH/$1/$2 -i $CONFIG_LOCAL_IP -p $CONFIG_LOCAL_PORT -mi $CONFIG_MEDIA_IP -mp $CONFIG_MEDIA_PORT -m $CONFIG_CALL_QUANT -trace_screen $remoteIpAddress
		fi
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
}

#-------------------------------------------------------------------------------------------
#Function: SaveResultInLogFile()
#This function generates logs for each and every individual tests
#------------------------------------------------------------------------------------------
SaveResultInLogFile()
{
	cd $CONFIG_AUTO_GEN_XML_PATH/Xml/
	#--------------------------------------------------
	#Move Sipp statistics to LOG
	#--------------------------------------------------
	mv *.log $CONFIG_AUTO_GEN_XML_PATH/$Log/
	rm -f *.log
	
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
		echo "$2" >> $CONFIG_AUTO_GEN_XML_PATH/failed.txt
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
	cat $CONFIG_AUTO_GEN_XML_PATH/failed.txt
	echo "**********************END**********************"
	rm -f $CONFIG_AUTO_GEN_XML_PATH/failed.txt
}

main "$@"
