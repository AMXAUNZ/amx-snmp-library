PROGRAM_NAME='RmsSNMPDeviceMonitorApi'
(***********************************************************)
(*  FILE CREATED ON: 03/07/2016  AT: 22:12:41              *)
(***********************************************************)
(*  FILE_LAST_MODIFIED_ON: 03/09/2016  AT: 22:20:34        *)
(***********************************************************)

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

char 			VARBIND_TYPE				=     1;
char 			VARBIND_OID				=     2;
char 			VARBIND_NAME				=     3;
char 			VARBIND_DESCRIPTION			=     4;
char 			VARBIND_DEFAULT_VALUE			=     5;
char 			VARBIND_REGISTER_FLAG			=     6;
char 			VARBIND_UPDATE_FLAG			=     7;

char 			VARBIND_TYPE_GENERAL			=     0;
char 			VARBIND_TYPE_NAME			=     1;
char 			VARBIND_TYPE_DESCRIPTION		=     2;
char 			VARBIND_TYPE_MODELNAME			=     3;
char 			VARBIND_TYPE_MANUFACTURERNAME		=     4;
char 			VARBIND_TYPE_ASSETTYPE			=     5;
char 			VARBIND_TYPE_SERIALNUMBER		=     6;
char 			VARBIND_TYPE_FIRMWAREVERSION		=     7;

char 			VARBIND_UPDATE_NONE			=     0;
char 			VARBIND_UPDATE_ONLINE			=     1;
char 			VARBIND_UPDATE_AUTO			=     2;

char 			VARBIND_REGISTER_NONE			=     0;
char 			VARBIND_REGISTER_PARAMETER		=     1;
char 			VARBIND_REGISTER_METADATA		=     2;

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)
(* EXAMPLE: DEFINE_FUNCTION <RETURN_TYPE> <NAME> (<PARAMETERS>) *)
(* EXAMPLE: DEFINE_CALL '<NAME>' (<PARAMETERS>) *)

define_function varbind_string(dev device, char type[], char oid[], char name[], char description[], char default_value[], integer register_flag, integer update_flag) {
    send_command device, "'VARBIND-', type, ',', oid, ',', name, ',', description, ',', default_value, ',', itoa(register_flag), ',', itoa(update_flag)";
}
