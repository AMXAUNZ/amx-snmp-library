PROGRAM_NAME='Example (Simple)'
(***********************************************************)
(*  FILE CREATED ON: 03/09/2016  AT: 20:59:30              *)
(***********************************************************)
(***********************************************************)
(***********************************************************)
(*  FILE_LAST_MODIFIED_ON: 03/10/2016  AT: 01:05:33        *)
(***********************************************************)
(* System Type : NetLinx                                   *)
(***********************************************************)
(* REV HISTORY:                                            *)
(***********************************************************)
(*
    $History: $
*)
(***********************************************************)
(*          DEVICE NUMBER DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_DEVICE

dvMaster							=     0:1:0;

vdvSNMP								= 33001:1:0;
vdvRmsSNMPDeviceMonitor						= 33002:1:0;

vdvRMS								= 41001:1:0;

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile dev 		SNMP_Manager_Local_Port			= 0:(first_local_port + 1):0;
volatile dev 		SNMP_Manager_Trap_Local_Port		= 0:(first_local_port + 2):0;

(***********************************************************)
(*                INCLUDE DEFINITIONS GO BELOW             *)
(***********************************************************)

#INCLUDE 'RmsSNMPDeviceMonitorApi';

(***********************************************************)
(*               LATCHING DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_LATCHING

(***********************************************************)
(*       MUTUALLY EXCLUSIVE DEFINITIONS GO BELOW           *)
(***********************************************************)
DEFINE_MUTUALLY_EXCLUSIVE

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)
(* EXAMPLE: DEFINE_FUNCTION <RETURN_TYPE> <NAME> (<PARAMETERS>) *)
(* EXAMPLE: DEFINE_CALL '<NAME>' (<PARAMETERS>) *)

(***********************************************************)
(*              MODULE DEFINITIONS GO BELOW                *)
(***********************************************************)

define_module 'snmp-manager'			Module_SNMP_Manager(vdvSNMP, SNMP_Manager_Local_Port, SNMP_Manager_Trap_Local_Port);

define_module 'RmsNetLinxAdapter_dr4_0_0' 	Module_RmsNetLinxAdapter(vdvRMS);
define_module 'RmsSNMPDeviceMonitor'		Module_RmsSNMPDeviceMonitor(vdvRMS, vdvRmsSNMPDeviceMonitor, vdvSNMP);

(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT

data_event[vdvSNMP] {
    online: {
	// send_command data.device, "'PROPERTY-IP_ADDRESS,192.168.0.10'";	// Default SNMP agent address. Default: <none>
	// send_command data.device, "'PROPERTY-PORT,161'";			// Default SNMP agent port. Default: 161
	// send_command data.device, "'PROPERTY-COMMUNITY,public'";		// Default SNMP community name. Default: public
	send_command data.device, "'PROPERTY-TRAP_PORT,162'";			// SNMP trap listener port. Specify 0 to disable the listening socket. Default: 162
	send_command data.device, "'PROPERTY-SEND_DELAY,2000'";			// Delay concurrent SNMP requests for slower devices. Default: 0ms
	send_command data.device, "'PROPERTY-AUTO_RETRANSMIT,1'";		// Re-transmit SNMP requests for which a response is not received. Default: 1
	send_command data.device, "'REINIT'";					// Initialise the SNMP manager and open the trap listening socket
    }
}

data_event[vdvRmsSNMPDeviceMonitor] {
    online: {
	send_command data.device, "'PROPERTY-IP_ADDRESS,amx-lt-29.amx.local'";
	send_command data.device, "'PROPERTY-PORT,161'";
	send_command data.device, "'PROPERTY-COMMUNITY,public'";
	send_command data.device, "'REINIT'";
	
	varbind_string(data.device, itoa(VARBIND_TYPE_NAME), 			'1.3.6.1.2.1.1.5.0', 'Hostname', '.iso.org.dod.internet.mgmt.mib-2.system.sysName', '', 		VARBIND_REGISTER_PARAMETER, VARBIND_UPDATE_ONLINE);
	varbind_string(data.device, itoa(VARBIND_TYPE_ASSETTYPE), 		'asset.type', 'Asset Type', '', 'PC', 									VARBIND_REGISTER_NONE, VARBIND_UPDATE_NONE);
	varbind_string(data.device, itoa(VARBIND_TYPE_MANUFACTURERNAME), 	'asset.manufacturerName', 'Manufacturer', '', 'Unknown', 						VARBIND_REGISTER_NONE, VARBIND_UPDATE_NONE);
	varbind_string(data.device, itoa(VARBIND_TYPE_MODELNAME), 		'asset.modelName', 'Model Name', '', 'Unknown', 							VARBIND_REGISTER_NONE, VARBIND_UPDATE_NONE);
	varbind_string(data.device, itoa(VARBIND_TYPE_DESCRIPTION), 		'1.3.6.1.2.1.1.1.0', 'Description', '.iso.org.dod.internet.mgmt.mib-2.system.sysDescr', '', 		VARBIND_REGISTER_NONE, VARBIND_UPDATE_ONLINE);
	varbind_string(data.device, itoa(VARBIND_TYPE_SERIALNUMBER), 		'asset.serialNumber', 'Serial Number', '', '', 								VARBIND_REGISTER_NONE, VARBIND_UPDATE_NONE);
	varbind_string(data.device, itoa(VARBIND_TYPE_FIRMWAREVERSION), 	'asset.firmwareVersion', 'Firmware Version', '', '', 							VARBIND_REGISTER_NONE, VARBIND_UPDATE_NONE);
	
	varbind_string(data.device, itoa(VARBIND_TYPE_GENERAL), 		'1.3.6.1.2.1.25.1.1.0', 'Uptime', '.iso.org.dod.internet.mgmt.mib-2.host.hrSystem.hrSystemUptime', '', 	VARBIND_REGISTER_PARAMETER, VARBIND_UPDATE_AUTO);
    }
}

(*****************************************************************)
(*                                                               *)
(*                      !!!! WARNING !!!!                        *)
(*                                                               *)
(* Due to differences in the underlying architecture of the      *)
(* X-Series masters, changing variables in the DEFINE_PROGRAM    *)
(* section of code can negatively impact program performance.    *)
(*                                                               *)
(* See “Differences in DEFINE_PROGRAM Program Execution” section *)
(* of the NX-Series Controllers WebConsole & Programming Guide   *)
(* for additional and alternate coding methodologies.            *)
(*****************************************************************)

DEFINE_PROGRAM

(*****************************************************************)
(*                       END OF PROGRAM                          *)
(*                                                               *)
(*         !!!  DO NOT PUT ANY CODE BELOW THIS COMMENT  !!!      *)
(*                                                               *)
(*****************************************************************)
