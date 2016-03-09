MODULE_NAME='RmsSNMPDeviceMonitor'(DEV vdvRMS, dev vdvDeviceModule, dev dvMonitoredDevice)
(***********************************************************)
(*  FILE CREATED ON: 12/27/2015  AT: 20:36:24              *)
(***********************************************************)
(***********************************************************)
(***********************************************************)
(*  FILE_LAST_MODIFIED_ON: 03/10/2016  AT: 00:54:05        *)
(***********************************************************)
(* System Type : NetLinx                                   *)
(***********************************************************)
(* REV HISTORY:                                            *)
(***********************************************************)
(*
    $History: $
*)

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

char			MONITOR_NAME[] 				= 'RMS SNMP Device Monitor';
char			MONITOR_DEBUG_NAME[] 			= 'RmsSNMPDeviceMonitor';
char			MONITOR_VERSION[] 			= '1.0.0';
char			MONITOR_ASSET_TYPE[] 			= '';
char			MONITOR_ASSET_NAME[] 			= '';

integer			DATA_INITIALIZED			=   252;

integer			MAX_LEN_STR				=   255;
integer 		MAX_LEN_INTEGER				=     3;
integer			MAX_LEN_LONG				=    10;
integer 		MAX_LEN_DATE_LONG			=    10;

integer			MAX_LEN_FQDN				=   255;
integer 		MAX_LEN_MAC_ADDRESS			=    17;

integer			MAX_LEN_SNMP_TAG_VALUE			= 65535;
integer			MAX_LEN_OCTET_STRING			= 65535;
integer			MAX_LEN_OID_SUB_IDENTIFIER		=    10;
integer			MAX_LEN_OID 				=  1407;

integer 		NUM_VARBINDS				=    25;

char 			SNMPGET_OID 				=     1;
char 			SNMPGET_VALUE 				=     2;
char 			SNMPGET_TYPE	 			=     3;
char 			SNMPGET_COMMUNITY 			=     4;
char 			SNMPGET_ADDRESS 			=     5;
char 			SNMPGET_REQUEST_ID 			=     6;

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
(*                     INCLUDES GO BELOW                   *)
(***********************************************************)

#define SNAPI_MONITOR_MODULE;
#include 'RmsMonitorCommon';

(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

structure _snmp_agent {
    char 		address[MAX_LEN_FQDN]
    integer 		port
    char 		community[MAX_LEN_OCTET_STRING]
}

structure _varbind {
    char		oid[MAX_LEN_OID]
    char 		value[MAX_LEN_STR]
    char 		name[MAX_LEN_STR]
    char 		description[MAX_LEN_STR]
    integer 		type
    long 		request_id
    integer 		register
    integer 		update
}

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

constant long		parameter_poll_tl			=     1;
volatile long		parameter_poll_times[] 			= { 0, 5000 }


volatile _snmp_agent	snmp_agent;
volatile _varbind 	varbinds[NUM_VARBINDS];

volatile integer 	online_status;

(***********************************************************)
(*    LIBRARY SUBROUTINE/FUNCTIONS DEFINITIONS GO BELOW    *)
(***********************************************************)

#IF_NOT_DEFINED __PRIME_BOOLTOSTRING
    #DEFINE __PRIME_BOOLTOSTRING
    
define_function char[5] booltostring(integer bool) {
    if (bool) return 'true';
    else return 'false';
}

#END_IF


#IF_NOT_DEFINED __PRIME_LTOA
    #DEFINE __PRIME_LTOA
    
define_function char[MAX_LEN_LONG] ltoa(long l) {
    stack_var volatile char ret[MAX_LEN_LONG];
    
    // if (AMX_DEBUG <= get_log_level()) debug("'ltoa', '(', 'long', ')'");

    if (l < 100000) {
	ret = itoa(l);
    } else {
	ret = "itoa(l / 100000), itoa(l % 100000)"; // Keep itoa input under 16 bits
    }
    
    // if (AMX_DEBUG <= get_log_level()) debug("'ltoa', '() ', 'returning ', ret");
    return ret;
}

#END_IF


#IF_NOT_DEFINED __PRIME_ATOL_UNSIGNED
    #DEFINE __PRIME_ATOL_UNSIGNED
    
define_function long atol_unsigned(char str[]) {
    stack_var volatile integer i;
    stack_var volatile long l;
    
    // if (AMX_DEBUG <= get_log_level()) debug("'atol_unsigned', '(', 'str', ')'");

    for (i = 1; i <= length_string(str); i++) {
	l = l * 10;
	l = l + atoi("str[i]");
    }
    
    // if (AMX_DEBUG <= get_log_level()) debug("'atol_unsigned', '() ', 'returning ', ltoa(l)");
    return l;
}

#END_IF


#IF_NOT_DEFINED __PRIME_EXPLODE
    #DEFINE __PRIME_EXPLODE
    
define_function integer explode(char str[], char delim[], char quote, char parts[][]) {
    stack_var volatile integer i;
    stack_var volatile integer start, end;
    
    // if (AMX_DEBUG <= get_log_level()) debug("'explode', '(', 'str[', itoa(length_string(str)), ']', ', "', delim, '", "', quote, '", ', 'parts[', itoa(max_length_array(parts)), '][]', ')'");
    
    start = 1;
    while (start <= length_string(str)) {
	i++;
	
	/*
	if (str[start] == delim) {
	    start++;								// Avoid empty parts and delimiter padding (i.e. spaces)
	    continue;
	}
	*/
	if ((quote) && (str[start] == quote)) {					// Optionally consider quoted strings as a single parts
	    start++;
	    end = find_string(str, quote, start);
	} else {
	    end = find_string(str, delim, start);				// Find next delimiter
	}
	if ((!end) || (i == max_length_array(parts))) {				// Return remainder of string if no further delimiters found or the maximum number of parts have already been found
	    end = length_string(str) + 1;
	}
	
	parts[i] = mid_string(str, start, end - start);
	
	start = end + 1;
    }
    
    set_length_array(parts, i);

    // if (AMX_DEBUG <= get_log_level()) debug("'explode', '() ', 'returning array[', itoa(i), ']'");
    return i;
}

#END_IF


(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)

define_function integer setDebugState(integer lvl) {
    #IF_DEFINED __PRIME_DEBUG
	send_string vdvDeviceModule, "'DEBUG-', lvl";
	return debug_set_level(lvl);
    #ELSE
	set_log_level(lvl);
	return lvl;
    #END_IF
}

define_function integer setProperty(char key[], char value[]) {
    if (AMX_DEBUG <= get_log_level()) debug("'setProperty', '(', key, ', ', value, ')'");
    
    switch (key) {
	case 'IP_ADDRESS': snmp_agent.address = value;
	case 'PORT': snmp_agent.port = atoi(value);
	case 'COMMUNITY': snmp_agent.community = value;
	default: {
	    stack_var integer result;
	    
	    #IF_DEFINED __PRIME_DEBUG
		if (!result) result = debug_setProperty(key, value);
	    #END_IF
	    
	    if (!result) {
		if (AMX_ERROR <= get_log_level()) debug("'setProperty', '() ', 'error setting value for ', key, '!'");
		if (AMX_DEBUG <= get_log_level()) debug("'setProperty', '() ', 'returning false'");
		
		return false;
	    }
	}
    }
    
    if (AMX_DEBUG <= get_log_level()) debug("'setProperty', '() ', 'returning true'");
    send_string vdvDeviceModule, "'PROPERTY-', key, ',', value";
    
    return true;
}

define_function integer reinitialize() {
    if (AMX_DEBUG <= get_log_level()) debug("'reinitialize', '()'");
    
    off[vdvDeviceModule, DATA_INITIALIZED];
    
    #IF_DEFINED __PRIME_CONNMAN
    connman_reinitialize();
    #END_IF
    
    #IF_DEFINED __PRIME_CONNMAN_SERVER
    connman_server_reinitialize();
    #END_IF
    
    {
	stack_var volatile integer i;
	
	for (i = 1; i <= length_array(varbinds); i++) {
	    if (left_string(varbinds[i].oid, 3) == '1.3') {
		snmp_get(varbinds[i].oid)
	    }
	}
	
	if (!timeline_active(parameter_poll_tl)) {
	    timeline_create(parameter_poll_tl, parameter_poll_times, length_array(parameter_poll_times), TIMELINE_RELATIVE, TIMELINE_REPEAT);
	}
    }
    
    if (AMX_DEBUG <= get_log_level()) debug("'reinitialize', '() ', 'returning true'");
    
    return true;
}

define_function integer get_varbind_index(char oid[]) {
    stack_var volatile integer i;
    
    for (i = 1; i <= length_array(varbinds); i++) {
	if (varbinds[i].oid == oid) {
	    // if (AMX_DEBUG <= get_log_level()) debug("'get_varbind_index', '() ', 'oid found at index ', itoa(i), '. Returning ', varbinds[i].value");
	    return i;
	}
    }

    // if (AMX_DEBUG <= get_log_level()) debug("'get_varbind_index', '() ', 'oid could not be found. Returning false.'");
    return false;
}

define_function char[MAX_LEN_SNMP_TAG_VALUE] get_varbind(char oid[]) {
    stack_var volatile integer i;
    
    for (i = 1; i <= length_array(varbinds); i++) {
	if (varbinds[i].oid == oid) {
	    // if (AMX_DEBUG <= get_log_level()) debug("'get_varbind', '() ', 'oid found at index ', itoa(i), '. Returning ', varbinds[i].value");
	    return varbinds[i].value;
	}
    }

    // if (AMX_DEBUG <= get_log_level()) debug("'get_varbind', '() ', 'oid could not be found. Returning false.'");
    return false;
}

define_function char[MAX_LEN_SNMP_TAG_VALUE] get_varbind_by_type(integer type) {
    stack_var volatile integer i;
    
    for (i = 1; i <= length_array(varbinds); i++) {
	if (varbinds[i].type == type) {
	    // if (AMX_DEBUG <= get_log_level()) debug("'get_varbind_by_type', '() ', 'varbind found at index ', itoa(i), '. Returning ', varbinds[i].value");
	    return varbinds[i].value;
	}
    }

    // if (AMX_DEBUG <= get_log_level()) debug("'get_varbind_by_type', '() ', 'oid could not be found. Returning false.'");
    return '';;
}

define_function integer set_varbind(char oid[], char contents[]) {
    stack_var volatile integer i, pos;
    
    for (i = 1; i <= length_array(varbinds); i++) {
	if (varbinds[i].oid == oid) {
	    pos = i;
	    break;
	}
    }
    if (!pos) {
	if (length_string(varbinds) < max_length_array(varbinds)) {
	    pos = length_string(varbinds) + 1;
	    set_length_array(varbinds, i);
	} else {
	    // full
	}
    }
    if (pos) {
	varbinds[pos].oid = oid;
	varbinds[pos].value = contents;
	return pos;
    } else {
	return false;
    }
}

define_function long snmp_get(char oid[]) {
    if (AMX_DEBUG <= get_log_level()) debug("'snmp_get', '(', oid, ')'");
    
    snmp_get_ex(oid, false);
}

define_function long snmp_get_next(char oid[]) {
    if (AMX_DEBUG <= get_log_level()) debug("'snmp_get_next', '(', oid, ')'");
    
    snmp_get_ex(oid, true);
}

define_function long snmp_get_ex(char oid[], integer next) {
    stack_var volatile integer i;
    stack_var volatile long request_id;
    
    if (AMX_DEBUG <= get_log_level()) debug("'snmp_get_ex', '(', oid, ', ', booltostring(next), ')'");
    
    i = get_varbind_index(oid);

    request_id = random_number(get_timer);
    if (i) varbinds[i].request_id = request_id;
    
    if (next) {
	send_command dvMonitoredDevice, "'SNMPGETNEXT', '-', oid, ',', snmp_agent.community, ',', snmp_agent.address, ',', itoa(snmp_agent.port), ',', itoa(request_id)";
    } else {
	send_command dvMonitoredDevice, "'SNMPGET', '-', oid, ',', snmp_agent.community, ',', snmp_agent.address, ',', itoa(snmp_agent.port), ',', itoa(request_id)";
    }
    
    if (AMX_DEBUG <= get_log_level()) debug("'snmp_get_ex', '() ', 'returning ', itoa(request_id)");
    return request_id;
}

define_function char[MAX_LEN_STR] timeticks_to_time(char str[]) {
    stack_var volatile long timeticks, days, hours, minutes, seconds;
    stack_var volatile char ret[MAX_LEN_STR];
    
    if (AMX_DEBUG <= get_log_level()) debug("'timeticks_to_time', '(', str, ')'");

    timeticks = atol_unsigned(str);
    
    days = timeticks / 8640000; // 100 * 60 * 60 * 24
    timeticks = timeticks - (days * 8640000);
    
    hours = timeticks / 360000; // 100 * 60 * 60
    timeticks = timeticks - (hours * 360000);
    
    minutes = timeticks / 6000; // 100 * 60
    timeticks = timeticks - (minutes * 6000);
    
    seconds = timeticks / 100;
    
    if (days) ret = "itoa(days), ' days '";
    if (hours || length_string(ret)) ret = "ret, format('%02d', hours), ':'";
    if (minutes || length_string(ret)) ret = "ret, format('%02d', minutes), ':'";
    if (seconds || length_string(ret)) ret = "ret, format('%02d', seconds)";

    if (AMX_DEBUG <= get_log_level()) debug("'timeticks_to_time', '() ', 'returning ', ret");
    return ret;
}

(***********************************************************)
(* Name:  RegisterAsset                                    *)
(* Args:  RmsAsset asset data object to be registered .    *)
(*                                                         *)
(* Desc:  This is a callback method that is invoked by     *)
(*        RMS to notify this module that it is time to     *)
(*        register this asset.                             *)
(*                                                         *)
(*        This method should not be invoked/called         *)
(*        by any user implementation code.                 *)
(***********************************************************)

define_function RegisterAsset(RmsAsset asset) {
    asset.clientKey 		= RmsDevToString(vdvDeviceModule);
    asset.globalKey 		= "get_varbind_by_type(VARBIND_TYPE_MANUFACTURERNAME), '_', get_varbind_by_type(VARBIND_TYPE_SERIALNUMBER)";

    asset.name 			= get_varbind_by_type(VARBIND_TYPE_NAME);
    asset.assetType		= get_varbind_by_type(VARBIND_TYPE_ASSETTYPE);
    asset.manufacturerName	= get_varbind_by_type(VARBIND_TYPE_MANUFACTURERNAME);
    asset.modelName		= get_varbind_by_type(VARBIND_TYPE_MODELNAME);
    asset.description		= get_varbind_by_type(VARBIND_TYPE_DESCRIPTION);
    asset.serialNumber 		= get_varbind_by_type(VARBIND_TYPE_SERIALNUMBER);
    asset.firmwareVersion	= get_varbind_by_type(VARBIND_TYPE_FIRMWAREVERSION);
    
    RmsAssetRegister(vdvDeviceModule, asset);
}


(***********************************************************)
(* Name:  RegisterAssetParameters                          *)
(* Args:  -none-                                           *)
(*                                                         *)
(* Desc:  This is a callback method that is invoked by     *)
(*        RMS to notify this module that it is time to     *)
(*        register this asset's parameters to be monitored *)
(*        by RMS.                                          *)
(*                                                         *)
(*        This method should not be invoked/called         *)
(*        by any user implementation code.                 *)
(***********************************************************)
define_function RegisterAssetParameters() {
    stack_var volatile integer i;
    
    for (i = 1; i <= length_array(varbinds); i++) {
	if (varbinds[i].register == VARBIND_REGISTER_PARAMETER) {
	    RmsAssetParameterEnqueueString(
		assetClientKey, 
		varbinds[i].oid, 
		varbinds[i].name, 
		varbinds[i].description, 
		RMS_ASSET_PARAM_TYPE_NONE, 
		varbinds[i].value, 
		'', 
		RMS_ALLOW_RESET_NO, 
		'', 
		RMS_TRACK_CHANGES_YES
	    );
	}
    }
    
    RmsAssetOnlineParameterEnqueue(assetClientKey, true);
    
    RmsAssetParameterSubmit(assetClientKey);
}

(***********************************************************)
(* Name:  SynchronizeAssetParameters                       *)
(* Args:  -none-                                           *)
(*                                                         *)
(* Desc:  This is a callback method that is invoked by     *)
(*        RMS to notify this module that it is time to     *)
(*        update/synchronize this asset parameter values   *)
(*        with RMS.                                        *)
(*                                                         *)
(*        This method should not be invoked/called         *)
(*        by any user implementation code.                 *)
(***********************************************************)
define_function SynchronizeAssetParameters() {
    stack_var volatile integer i;
    
    for (i = 1; i <= length_array(varbinds); i++) {
	if (varbinds[i].register == VARBIND_REGISTER_PARAMETER) {
	    RmsAssetParameterSetValue(assetClientKey, varbinds[i].oid, varbinds[i].value);
	}
    }
    RmsAssetOnlineParameterUpdate(assetClientKey, online_status);
}



(***********************************************************)
(* Name:  ResetAssetParameterValue                         *)
(* Args:  parameterKey   - unique parameter key identifier *)
(*        parameterValue - new parameter value after reset *)
(*                                                         *)
(* Desc:  This is a callback method that is invoked by     *)
(*        RMS to notify this module that an asset          *)
(*        parameter value has been reset by the RMS server *)
(*                                                         *)
(*        This method should not be invoked/called         *)
(*        by any user implementation code.                 *)
(***********************************************************)
DEFINE_FUNCTION ResetAssetParameterValue(CHAR parameterKey[],CHAR parameterValue[])
{
  // if your monitoring module performs any parameter
  // value tracking, then you may want to update the
  // tracking value based on the new reset value
  // received from the RMS server.
}



(***********************************************************)
(* Name:  RegisterAssetMetadata                            *)
(* Args:  -none-                                           *)
(*                                                         *)
(* Desc:  This is a callback method that is invoked by     *)
(*        RMS to notify this module that it is time to     *)
(*        register this asset's metadata properties with   *)
(*        RMS.                                             *)
(*                                                         *)
(*        This method should not be invoked/called         *)
(*        by any user implementation code.                 *)
(***********************************************************)
define_function RegisterAssetMetadata() {
    stack_var volatile integer i;
    
    for (i = 1; i <= length_array(varbinds); i++) {
	if (varbinds[i].register == VARBIND_REGISTER_METADATA) {
	    RmsAssetMetadataEnqueueString(assetClientKey, varbinds[i].oid, varbinds[i].name, varbinds[i].value);
	}
    }
    
    RmsAssetMetadataSubmit(assetClientKey);
}


(***********************************************************)
(* Name:  SynchronizeAssetMetadata                         *)
(* Args:  -none-                                           *)
(*                                                         *)
(* Desc:  This is a callback method that is invoked by     *)
(*        RMS to notify this module that it is time to     *)
(*        update/synchronize this asset metadata properties *)
(*        with RMS if needed.                              *)
(*                                                         *)
(*        This method should not be invoked/called         *)
(*        by any user implementation code.                 *)
(***********************************************************)
define_function SynchronizeAssetMetadata() {
    stack_var volatile integer i;
    
    for (i = 1; i <= length_array(varbinds); i++) {
	if (varbinds[i].register == VARBIND_REGISTER_METADATA) {
	    RmsAssetMetadataUpdateString(assetClientKey, varbinds[i].oid, varbinds[i].value);
	}
    }
}


(***********************************************************)
(* Name:  RegisterAssetControlMethods                      *)
(* Args:  -none-                                           *)
(*                                                         *)
(* Desc:  This is a callback method that is invoked by     *)
(*        RMS to notify this module that it is time to     *)
(*        register this asset's control methods with RMS.  *)
(*                                                         *)
(*        This method should not be invoked/called         *)
(*        by any user implementation code.                 *)
(***********************************************************)
DEFINE_FUNCTION RegisterAssetControlMethods()
{
  // This Duet-based asset monitoring module will
  // automatically register the default asset type control
  // method.  If you wish to extend the capabilities
  // and add additional asset control methods, please
  // add them here.
}


(***********************************************************)
(* Name:  ExecuteAssetControlMethod                        *)
(* Args:  methodKey - unique method key that was executed  *)
(*        arguments - array of argument values invoked     *)
(*                    with the execution of this method.   *)
(*                                                         *)
(* Desc:  This is a callback method that is invoked by     *)
(*        RMS to notify this module that it should         *)
(*        fullfill the execution of one of this asset's    *)
(*        control methods.                                 *)
(*                                                         *)
(*        This method should not be invoked/called         *)
(*        by any user implementation code.                 *)
(***********************************************************)
DEFINE_FUNCTION ExecuteAssetControlMethod(CHAR methodKey[], CHAR arguments[])
{
  // This Duet-based asset monitoring module will
  // automatically handle the execution of the
  // default asset type control methods.  If you
  // extended the capabilities and add additional
  // custom asset control methods, please make sure
  // to handle the exeuction of those control methods
  // here.
}


(***********************************************************)
(* Name:  SystemPowerChanged                               *)
(* Args:  powerOn - boolean value representing ON/OFF      *)
(*                                                         *)
(* Desc:  This is a callback method that is invoked by     *)
(*        RMS to notify this module that the SYSTEM POWER  *)
(*        state has changed states.                        *)
(*                                                         *)
(*        This method should not be invoked/called         *)
(*        by any user implementation code.                 *)
(***********************************************************)
DEFINE_FUNCTION SystemPowerChanged(CHAR powerOn)
{
  // optionally implement logic based on
  // system power state.
}


(***********************************************************)
(* Name:  SystemModeChanged                                *)
(* Args:  modeName - string value representing mode change *)
(*                                                         *)
(* Desc:  This is a callback method that is invoked by     *)
(*        RMS to notify this module that the SYSTEM MODE   *)
(*        state has changed states.                        *)
(*                                                         *)
(*        This method should not be invoked/called         *)
(*        by any user implementation code.                 *)
(***********************************************************)
DEFINE_FUNCTION SystemModeChanged(CHAR modeName[])
{
  // optionally implement logic based on
  // newly selected system mode name.
}

(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT

data_event[vdvDeviceModule] {
    command: {
	stack_var volatile char cmd[MAX_LEN_STR];
	
	cmd = remove_string(data.text, '-', 1);
	if (cmd) {
	    cmd = left_string(cmd, length_string(cmd) - 1);
	} else {
	    cmd = data.text;
	}
	
	switch (cmd) {
	    case 'DEBUG': {
		setDebugState(atoi(data.text));
	    }
	    case 'PROPERTY': {
		stack_var char parts[2][MAX_LEN_STR];
		
		if (!explode(data.text, ',', true, parts)) {
		    if (AMX_ERROR <= get_log_level()) debug("'PROPERTY - ', 'Could not parse command parameters!'");
		} else {
		    setProperty(upper_string(parts[1]), parts[2]);
		}
	    }
	    // VARBIND-<type>,<oid>,<name>,<description>,<default value>,<register>,<update flag>
	    case 'VARBIND': {
		stack_var volatile char parts[7][MAX_LEN_STR];
		stack_var volatile integer i;
		
		explode(data.text, ',', true, parts);
		
		i = set_varbind(parts[VARBIND_OID], '');
		if (i) {
		    varbinds[i].type = atoi(parts[VARBIND_TYPE]);
		    varbinds[i].name = parts[VARBIND_NAME];
		    varbinds[i].description = parts[VARBIND_DESCRIPTION];
		    varbinds[i].value = parts[VARBIND_DEFAULT_VALUE];
		    varbinds[i].register = atoi(parts[VARBIND_REGISTER_FLAG]);
		    varbinds[i].update = atoi(parts[VARBIND_UPDATE_FLAG]);
		    
		    if (left_string(varbinds[i].oid, 3) == '1.3') snmp_get(varbinds[i].oid);
		}
	    }
	    case 'REINIT': {
		if (AMX_INFO <= get_log_level()) debug("'REINIT - Reinitialising...'");
		reinitialize();
	    }
	}
    }
}

data_event[dvMonitoredDevice] {
    string: {
	stack_var volatile char cmd[MAX_LEN_STR];
	
	cmd = remove_string(data.text, '-', 1);
	if (cmd) {
	    cmd = left_string(cmd, length_string(cmd) - 1);
	} else {
	    cmd = data.text;
	}
	
	switch (cmd) {
	    case 'OID': {
		stack_var volatile char parts[6][MAX_LEN_STR];
		
		explode(data.text, ',', true, parts);
		
		// OID-<oid>,<value>,<type>,<community>,<address>,<request id>
		if ((parts[SNMPGET_COMMUNITY] == snmp_agent.community) && (parts[SNMPGET_ADDRESS] == snmp_agent.address)) {
		    stack_var volatile char value[MAX_LEN_STR];
		    
		    value = get_varbind(parts[SNMPGET_OID]);
		    
		    switch (upper_string(parts[SNMPGET_TYPE])) {
			case 'TIMETICKS': {
			    parts[SNMPGET_VALUE] = timeticks_to_time(parts[SNMPGET_VALUE]);
			}
		    }
		    
		    if (value != parts[SNMPGET_VALUE]) {
			stack_var volatile integer i;
			
			i = set_varbind(parts[SNMPGET_OID], parts[SNMPGET_VALUE]);
			if (i) {
			    switch (varbinds[i].register) {
				case VARBIND_REGISTER_PARAMETER: {
				    RmsAssetParameterSetValue(assetClientKey, parts[SNMPGET_OID], parts[SNMPGET_VALUE]);
				    on[vdvDeviceModule, DATA_INITIALIZED];
				}
				case VARBIND_REGISTER_METADATA: {
				    RmsAssetMetadataUpdateString(assetClientKey, parts[SNMPGET_OID], parts[SNMPGET_VALUE]);
				    on[vdvDeviceModule, DATA_INITIALIZED];
				}
			    }
			}
		    }
		    
		    if (online_status == false) {
			stack_var volatile integer i;
			
			RmsAssetOnlineParameterUpdate(assetClientKey, true);
			online_status = true;
			
			if (timeline_active(parameter_poll_tl)) {
			    timeline_set(parameter_poll_tl, parameter_poll_times[1]);
			} else {
			    timeline_create(parameter_poll_tl, parameter_poll_times, length_array(parameter_poll_times), TIMELINE_RELATIVE, TIMELINE_REPEAT);
			}
		    }
		}
	    }
	    case 'TIMEOUT': {
		stack_var volatile char parts[5][MAX_LEN_STR];
		
		explode(data.text, ',', true, parts);
		
		// TIMEOUT-<address>,<port>
		if ((parts[1] == snmp_agent.address) && (parts[2] == itoa(snmp_agent.port))) {
		    if (online_status == true) {
			RmsAssetOnlineParameterUpdate(assetClientKey, false);
			online_status = false;
		    }
		}
	    }
	}
    }
}

timeline_event[parameter_poll_tl] {
    switch(timeline.sequence) {
	case 1: {
	    stack_var volatile integer i;
	    
	    for (i = 1; i <= length_array(varbinds); i++) {
		if (
		    (varbinds[i].update == VARBIND_UPDATE_AUTO) && 
		    (left_string(varbinds[i].oid, 3) == '1.3')
		) {
		    snmp_get(varbinds[i].oid);
		    if (!online_status) break;
		}
	    }
	}
    }
}

(***********************************************************)
(*            THE ACTUAL PROGRAM GOES BELOW                *)
(***********************************************************)
DEFINE_PROGRAM

(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)
