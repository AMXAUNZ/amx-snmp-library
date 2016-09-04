PROGRAM_NAME='Example (RmsMonitorModule)'
(***********************************************************)
(*  FILE CREATED ON: 07/24/2016  AT: 21:25:46              *)
(***********************************************************)
(***********************************************************)
(***********************************************************)
(*  FILE_LAST_MODIFIED_ON: 08/30/2016  AT: 16:31:39        *)
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

vdvSNMP                                     = 33100:1:0;

vdvRmsGenericSnmpDeviceMonitor              = 33101:1:0;
vdvRmsEpsonProjectorMonitor                 = 33102:1:0;

vdvRMS                                      = 41001:1:0;

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

volatile dev SNMP_Manager_Local_Port        = 0:(first_local_port + 1):0;
volatile dev SNMP_Manager_Trap_Local_Port   = 0:(first_local_port + 2):0;

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

DEFINE_MODULE 'RmsNetLinxAdapter_dr4_0_0'   mdlRmsNetLinxAdapter(vdvRms);
DEFINE_MODULE 'snmp-manager'                mdlSnmpManager(vdvSNMP, SNMP_Manager_Local_Port, SNMP_Manager_Trap_Local_Port);

DEFINE_MODULE 'RmsGenericSnmpDeviceMonitor' mdlRmsGenericSnmpDeviceMonitor(vdvRms, vdvRmsGenericSnmpDeviceMonitor, vdvRmsGenericSnmpDeviceMonitor, vdvSNMP);
DEFINE_MODULE 'RmsEpsonProjectorMonitor'    mdlRmsEpsonProjectorMonitor(vdvRms, vdvRmsEpsonProjectorMonitor, vdvRmsEpsonProjectorMonitor, vdvSNMP);

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
		send_command data.device, "'PROPERTY-SEND_DELAY,2000'";                 // Delay between concurrent strings sent from the outbound butter. Default: 0msec.
		send_command data.device, "'PROPERTY-SEND_ATTEMPTS,3'";                 // Re-transmit strings sent from the buffer <num> times at the SEND_DELAY interval until a response is received. Default: 0 (transmit once).
		send_command data.device, "'REINIT'";
	}
}

data_event[vdvRmsGenericSnmpDeviceMonitor] {
	online: {
		send_command data.device, "'PROPERTY-ASSET_NAME,Room PC'";
		send_command data.device, "'PROPERTY-IP_ADDRESS,172.16.1.10'";
		send_command data.device, "'PROPERTY-PORT,161'";
		send_command data.device, "'PROPERTY-COMMUNITY,public'";
		send_command data.device, "'PROPERTY-POLL_INTERVAL,60'";
		send_command data.device, "'PROPERTY-CONTACT_TIMEOUT,300'";
		send_command data.device, "'REINIT'";
	}
}

data_event[vdvRmsEpsonProjectorMonitor] {
	online: {
		send_command data.device, "'PROPERTY-ASSET_NAME,Projector'";
		send_command data.device, "'PROPERTY-IP_ADDRESS,152.66.16.105'";
		send_command data.device, "'PROPERTY-PORT,161'";
		send_command data.device, "'PROPERTY-COMMUNITY,public'";
		send_command data.device, "'PROPERTY-POLL_INTERVAL,60'";
		send_command data.device, "'PROPERTY-CONTACT_TIMEOUT,300'";
		send_command data.device, "'REINIT'";
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


