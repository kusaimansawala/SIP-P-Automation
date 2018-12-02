###############################################
Readme before executing the scripts
###############################################

Sipp_Automation includes three files:

1)SipAutomationConfig: All the configuration related to IP, ports, directory paths will be done here:

						CONFIG_LOCAL_IP = #Replace the data in this field with your PC's local IP
						CONFIG_LOCAL_PORT = #Replace the data in this field with your local SIP ports
						CONFIG_CALL_QUANT = #Replace the data in this field with the number of calls you want to make with sipp at a time
						CONFIG_CSV_PATH = #Give path where you wish the script to generate thye CSV files used for the sipp scenario execution
						CONFIG_XML_PATH = #Give path where all your XML scenarios are kept
						CONFG_DISPLAY_NAME = #You can enter your name in this field
						CONFIG_LOG_PATH = #Give path where you want the script to generate the logs of execution
						CONFIG_PCAP_PATH = #Give path where you want the script to generate the pcap of execution
						CONFIG_INTERFACE_NAME = #Replace this field with your PC's interface name

2)SipAutomation.sh: This is the file that each user needs to execute in the following manner:

					./SipAutomation.sh called_party_id@called_party_ip:called_party_port transport_type
					
					Example: 4002@192.168.1.125:5060 udp
					
					Here the called_party_id, called_party_port and transport_type is optional. If transport_type not provided, default will be UDP.

3)AutoXmlGen.sh:	This script can be executed when the user intends to generate the XML scenario from the script itself.
					AutoXmlGen.sh is intended to be used for the simple call scenarios only.
					CONFIG_AUTO_GEN_XML_PATH: User defined path where he wishes to create xml, csv, pcap and log files
					CONFIG_AUTO_GEN_XML_PARTS: This is the path for the XML scenario pieces which will be appended by the script.

###############################################
End of Readme
###############################################
