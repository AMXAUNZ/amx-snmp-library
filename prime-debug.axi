PROGRAM_NAME='prime-debug'

#IF_NOT_DEFINED __PRIME_DEBUG
    #DEFINE __PRIME_DEBUG

(***********************************************************)
(*  FILE CREATED ON: 01/23/2016  AT: 21:43:16              *)
(***********************************************************)
(***********************************************************)
(***********************************************************)
(*  FILE_LAST_MODIFIED_ON: 04/15/2016  AT: 23:01:28        *)
(***********************************************************)
(* System Type : NetLinx                                   *)
(***********************************************************)
(* REV HISTORY:                                            *)
(***********************************************************)
(*
    $History: $
*)

(*

    prime-debug.axi
    Debug functions and error message describer
    
    Author: niek.groot@amxaustralia.com.au
    No rights or warranties implied.
    
    This include wraps the NetLinx amx_log() function, adding 
    line-wrapping and (optionally) decoding unprintable characters.
    
    This include also provides error code translation functions for 
    socket and file operations.
    
    These functions do carry some performance overhead, especially when 
    decoding unprintable characters. To maximise performance, prepend the 
    debug() calls with a conditional IF statement shown in the usage example.
    
    Please consider contributing by submitting bug fixes and improvements.
    
    
    Usage:

    #INCLUDE 'prime-debug'							// Use debug_setProperty() for preferences configuration

    debug_set_level(<AMX_ERROR|AMX_WARNING|AMX_INFO|AMX_DEBUG>)			// Debug message filter level. This function wraps the set_log_level() function.
    debug("'<message>'")							// Write a message to the console (diagnostics) and NetLinx log in accorance with the current log level
    if (AMX_DEBUG <= get_log_level()) debug("'<message>'");			// Conditional debug() call avoiding unnecessary runtime processing.
    
    devtoa(<dps>)								// Returns a string of the ASCII representation of a device D:P:S
    
    booltostring(<boolean>)							// Returns a string of the ASCII representation of a boolean
    stringtobool('<true|false>')						// Returns a boolean value from an ASCII string
    
    ip_error_desc(<errror code>)						// Returns the description for IP socket errors
    file_error_desc(<errror code>)						// Returns the description for file operation errors


    Response:
    
    Debug messages are output to the console (diagnostics) and NetLinx log


    Configuration:

    debug_setProperty('PROC_NAME', '<name>')					// Process name to be prefixed to all debug messages.
    debug_setProperty('DECODE_UNPRINTABLE', '<true|false>')			// Display unprintable characters as hexidecimal values in debug messages. Note this funciton has a significant performance impact!
*)

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

char			DEBUG_LEVEL_STRINGS[5][7] = {
			    'ERROR',
			    'WARN ',
			    'INFO ',
			    'DEBUG'
			}

integer			DEBUG_MAX_LEN_STR			=  255;
integer			DEBUG_MAX_LEN_PROPERTY_VALUE		=   50;

integer			DEBUG_MTU 				=  131; 	// Maximum chars shown without truncating in NetLinx Studio
long 			DEBUG_MAX_LEN 				= 2048;

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile integer 	DEBUG_DECODE_UNPRINTABLE 		= false;
volatile char 		DEBUG_PROC_NAME[DEBUG_MAX_LEN_PROPERTY_VALUE];

(***********************************************************)
(*    LIBRARY SUBROUTINE/FUNCTIONS DEFINITIONS GO BELOW    *)
(***********************************************************)

#IF_NOT_DEFINED __PRIME_DEVTOA
    #DEFINE __PRIME_DEVTOA
    
define_function char[17] devtoa(dev devDevice) {
    return "itoa(devDevice.number), ':', itoa(devDevice.port), ':', itoa(devDevice.system)";
}

#END_IF


#IF_NOT_DEFINED __PRIME_BOOLTOSTRING
    #DEFINE __PRIME_BOOLTOSTRING
    
define_function char[5] booltostring(integer bool) {
    if (bool) return 'true';
    else return 'false';
}

#END_IF


#IF_NOT_DEFINED __PRIME_STRINGTOBOOL
    #DEFINE __PRIME_STRINGTOBOOL
    
define_function integer stringtobool(char str[5]) {
    str = lower_string(str);
    
    if ((str == 'true') || (str == '1') || (str == 'on')) {
	return true;
    } else {
	return false;
    }
}

#END_IF


#IF_NOT_DEFINED __PRIME_IP_ERROR_DESC
    #DEFINE __PRIME_IP_ERROR_DESC
    
define_function char[33] ip_error_desc(slong errorcode) {
    select {
	active (errorcode == -3): { 
	    return 'Unable to open communication port';
	}
	active (errorcode == -2): { 
	    return 'Invalid value for Protocol';
	}
	active (errorcode == -1): { 
	    return 'Invalid server port';
	}
	active (errorcode == 0): { 
	    return 'Operation was successful';
	}
	active (errorcode == 2): { 
	    return 'General failure (out of memory)';
	}
	active (errorcode == 4): { 
	    return 'Unknown host';
	}
	active (errorcode == 6): { 
	    return 'Connection refused';
	}
	active (errorcode == 7): { 
	    return 'Connection timed out';
	}
	active (errorcode == 8): { 
	    return 'Unknown connection error';
	}
	active (errorcode == 9): { 
	    return 'Already closed';
	}
	active (errorcode == 10): { 
	    return 'Binding error';
	}
	active (errorcode == 11): { 
	    return 'Listening error';
	}
	active (errorcode == 14): { 
	    return 'Local port already used';
	}
	active (errorcode == 15): { 
	    return 'UDP socket already listening';
	}
	active (errorcode == 16): { 
	    return 'Too many open sockets';
	}
	active (errorcode == 17): { 
	    return 'Local Port Not Open';
	}
	active (1): { 
	    return "'Unidentified error code: ', itoa(errorcode)";
	}
    }
}

#END_IF


#IF_NOT_DEFINED __PRIME_FILE_ERROR_DESC
    #DEFINE __PRIME_FILE_ERROR_DESC

define_function char[52] file_error_desc(slong errorcode) {
    select {
	active (errorcode == -15): { 
	    return 'Invalid file path or name';
	}
	active (errorcode == -14): { 
	    return 'Invalid value supplied for IOFlag';
	}
	active (errorcode == -5): { 
	    return 'Disk I/O error';
	}
	active (errorcode == -3): { 
	    return 'Maximum number of files are already open (max is 10)';
	}
	active (errorcode == -2): { 
	    return 'Invalid file format';
	}
	active (errorcode > 0): {
	    return 'Handle to file (open was successful)';
	}
	active (1): { 
	    return "'Unidentified error code: ', itoa(errorcode)";
	}
    }
}

#END_IF

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)

define_function integer debug_setProperty(char key[], char value[]) {
    switch (key) {
	case 'PROC_NAME': DEBUG_PROC_NAME = value;
	case 'DECODE_UNPRINTABLE': DEBUG_DECODE_UNPRINTABLE = stringtobool(value);
	default: {
	    return false;
	}
    }
    
    return true;
}

define_function integer debug_set_level(integer lvl) {
    if (lvl && (lvl <= AMX_DEBUG)) {
	set_log_level(lvl);
	if (AMX_INFO <= get_log_level()) debug("'Set debug level to ', itoa(lvl), ' ', DEBUG_LEVEL_STRINGS[lvl]");
    } else {
	if (AMX_WARNING <= get_log_level()) debug("'Invalid debug level! Valid levels are 1-4)'");
    }
}

define_function debug(msg[DEBUG_MAX_LEN]) {
    #IF_NOT_DEFINED __PRIME_DEBUG_DISABLE
    if (DEBUG_PROC_NAME) {
	print("DEBUG_LEVEL_STRINGS[get_log_level()], ' [', DEBUG_PROC_NAME, '] ', msg");
    } else {
	print("DEBUG_LEVEL_STRINGS[get_log_level()], ' ', msg");
    }
    #END_IF
}

define_function print(char msg[DEBUG_MAX_LEN]) {
    stack_var integer start, end;
    
    if (DEBUG_DECODE_UNPRINTABLE) msg = str_decode_unprintable(msg);
    
    while (end < length_string(msg)) {
	start = end + 1;
	end = start + DEBUG_MTU - 1;
	if (end > length_string(msg)) end = length_string(msg);
	
	amx_log(get_log_level(), mid_string(msg, start, end - start + 1)); 	// Always log messages via print()
    }
}

define_function char[DEBUG_MAX_LEN] str_decode_unprintable(str[]) {
    stack_var long i;    
    stack_var char ret[DEBUG_MAX_LEN];
    
    for (i = 1; i <= length_string(str); i++) {
	if (length_string(ret) == DEBUG_MAX_LEN) {
	    if (get_log_level() >= AMX_WARNING) debug('Output buffer full while decoding unprintable characters. Truncating output.');
	    return ret;
	}
	
	if ((str[i] < $20) || (str[i] > $7E)) {
	    ret = "ret, format('$%02X', str[i])";
	} else {
	    ret = "ret, str[i]";
	}
    }
    
    return ret;
}

#END_IF
