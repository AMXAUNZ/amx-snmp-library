MODULE_NAME='snmp-manager'(dev vdvModule, dev connman_device, dev connman_server_device)
(***********************************************************)
(*  FILE CREATED ON: 12/27/2015  AT: 20:36:24              *)
(***********************************************************)
(***********************************************************)
(***********************************************************)
(*  FILE_LAST_MODIFIED_ON: 04/21/2016  AT: 13:19:21        *)
(***********************************************************)
(*  FILE REVISION: Rev 3                                   *)
(*  REVISION DATE: 04/21/2016  AT: 12:29:15                *)
(*                                                         *)
(*  COMMENTS:                                              *)
(*  Additional debug messages                              *)
(*  Expanded notes                                         *)
(*  No-response request delay changed to 1000ms            *)
(*  Additional configuration for updated prime-connman     *)
(*  Expanded SNMP Trap notification message detail         *)
(*                                                         *)
(***********************************************************)
(*  FILE REVISION: Rev 2                                   *)
(*  REVISION DATE: 04/15/2016  AT: 11:03:06                *)
(*                                                         *)
(*  COMMENTS:                                              *)
(*  Corrected connman_server_reinitialize() call in        *)
(*  reinitialize(), which prevented the SNMP trap listener *)
(*  from starting.                                         *)
(*                                                         *)
(***********************************************************)
(* System Type : NetLinx                                   *)
(***********************************************************)
(* REV HISTORY:                                            *)
(***********************************************************)
(*
	$History: $
*)

(*
	snmp-manager.axs
	NetLinx SNMP Manager
	
	Author: niek.groot@amxaustralia.com.au
	No rights or warranties implied
	
	This NetLinx SNMP manager module can send SNMP GET, GETNEXT, and SET 
	requests to SNMPv1 agents, and can receive SNMP traps by SNMPv1 agents.
	
	Whilst tested for broad compatibilty, this code should be considered a 
	technology demo and should by carefully evaluated before using in a 
	production environment.
	
	Note that the SNMP Opaque tag has not been implemented.
	
	This module uses a seperately included client connection manager, listening 
	socket manager, and debug library for ease of adoption and customisation.
	
	Please consider contributing by submitting bug fixes and improvements.
	
	
	Usage:
	
	DEFINE_MODULE 'snmp-manager' mdl(dev <snmp manager virtual device>, dev <client socket local port>, dev <trap listening socket local port>);
	
	send_command vdvSNMP, "'SNMPGET-<oid>[,<community>[,<host>[,<port>[,<request id>]]]]'";                 // Retrieve the value of a variable.
	send_command vdvSNMP, "'SNMPGETNEXT-<oid>[,<community>[,<host>[,<port>[,<request id>]]]]'";             // Retrieve the value for the lexicographically next variable in the MIB in reference to the specified OID.
	send_command vdvSNMP, "'SNMPSET-<oid>,<type>,<value>[,<community>[,<host>[,<port>[,<request id>]]]]'";  // Request to change the value of a variable. Send <value> as string and specify <type> as ASN.1 type (below).
	
	Responses and traps are passed as data_event strings to the vdvModule device in the following format:
	
	OID-<oid>,<value>,<type>,<community>,<source address>,<request id>
	TRAP-<oid>,<value>,<type>,<community>,<source address>,<enterprise>,<agent address>,<generic trap>,<specific trap>,<time stamp>
	
	
	Configuration:
	
	The SNMP agent address, port, and community may be configured globally, 
	or passed as parameters with each request.
	
	Parameters are to be passed as character strings.
	
	send_command vdvSNMP, "'DEBUG-', itoa(<AMX_ERROR|AMX_WARNING|AMX_INFO|AMX_DEBUG>)";                     // Sets the debug message filter level. This function wraps the set_log_level() function.
	send_command vdvSNMP, "'PROPERTY-DECODE_UNPRINTABLE,', booltostring(<true|false>)";                     // Display unprintable characters as hexidecimal values in debug messages. Default: true.
	
	send_command vdvSNMP, "'PROPERTY-IP_ADDRESS,', '<address>'";                                            // Default SNMP agent address. Default: <none>.
	send_command vdvSNMP, "'PROPERTY-PORT,', itoa(<port>)";                                                 // Default SNMP agent port. Default: 161.
	send_command vdvSNMP, "'PROPERTY-COMMUNITY,', '<community>'";                                           // Default SNMP community name. Default: public.
	send_command vdvSNMP, "'PROPERTY-TRAP_PORT,', itoa(<port>)";                                            // SNMP trap listener port. Specify 0 to disable the listening socket. Default: 162.

	send_command vdvSNMP, "'PROPERTY-CONNECT_DELAY,', itoa(<msec>)";                                        // Delay between (failed) connection attempts. Default: 5000ms.
	send_command vdvSNMP, "'PROPERTY-MAX_CONNECTION_ATTEMPTS', itoa(<num>)");                               // Maximum number of attempts to open a SNMP agent client socket. Default: 3.

	send_command vdvSNMP, "'PROPERTY-SEND_DELAY,', itoa(<msec>)";                                           // Delay between SNMP requests to which a response is not received. Default: 1000ms.
	send_command vdvSNMP, "'PROPERTY-ADVANCE_ON_RESPONSE', booltostring(<true|false>)");                    // Immediately send the next request when a response is received. Default: true.
	send_command vdvSNMP, "'PROPERTY-AUTO_RETRANSMIT,', itoa(<num>)";                                       // Re-transmit SNMP requests for which a response is not received. Default: 1.

	send_command vdvSNMP, "'REINIT'";
*)

(***********************************************************)
(*          DEVICE NUMBER DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_DEVICE

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

integer             DATA_INITIALIZED                        =   252;            // Feedback: Data initialized event

char                NULL[]                                  =  "$00";           // Defined in this manner to ensure it is evaluated a string

integer             MAX_LEN_STR                             =   255;
integer             MAX_LEN_FQDN                            =   255;
integer             MAX_LEN_LONG                            =    10;            // 4294967295
integer             MAX_LEN_LONG_ENCODED                    =     4;            // 32-bit unsigned integer in base256
integer             MAX_LEN_INTEGER                         =     5;            // 65535
integer             MAX_LEN_LONG_BASE128                    =     8;            // 4 * 2; // 32-bit unsigned integer in base128

integer             MAX_NUM_SNMP_TAGS                       =    25;
integer             MAX_LEN_SNMP_MESSAGE                    =  1500;            // Cisco default
integer             MAX_LEN_SNMP_TAG_VALUE                  = 65535;            // Cannot use MAX_LEN_OCTET_STRING (compiler reports symbol is not defined)

integer             MAX_LEN_OCTET_STRING                    = 65535;            // Defined explicitly instead calculating or referencing other constants to avoid compiler errors
integer             MAX_NUM_OID_SUB_IDENTIFIER              =   128;
integer             MAX_LEN_OID_SUB_IDENTIFIER              =    10;            // MAX_LEN_LONG; // ASCII representation of 32-bit unsigned integer
integer             MAX_LEN_OID                             =  1407;            // (MAX_NUM_OID_SUB_IDENTIFIER * MAX_LEN_OID_SUB_IDENTIFIER) + (MAX_NUM_OID_SUB_IDENTIFIER - 1); // 4294967295.4294967295.4294967295.4294967295.4294967295
integer             MAX_LEN_OID_ENCODED                     =  1009;            // 1 + ((MAX_NUM_OID_SUB_IDENTIFIER - 2) * (4 * 2)); // First two sub identifiers are stored in the first octet, with subsequent encoded in base128
integer             MAX_LEN_IPADDRESS                       =    15;            // (3 * 4) + 3;
integer             MAX_LEN_IPADDRESS_ENCODED               =     4;
integer             NUM_IPADDRESS_OCTETS                    =     4;
integer             MAX_LEN_IPADDRESS_OCTET                 =     3;
integer             MAX_LEN_ASN1_LENGTH_ENCODED             =     5;

integer             SNMP_FIELD_MESSAGE                      =     1;
integer             SNMP_MESSAGE_FIELD_VERSION              =     1;
integer             SNMP_MESSAGE_FIELD_COMMUNITY            =     2;
integer             SNMP_MESSAGE_FIELD_PDU                  =     3;
integer             SNMP_PDU_FIELD_REQUEST_ID               =     1;
integer             SNMP_PDU_FIELD_ERROR                    =     2;
integer             SNMP_PDU_FIELD_ERROR_INDEX              =     3;
integer             SNMP_PDU_FIELD_RESPONSE_VARBIND_LIST    =     4;
integer             SNMP_PDU_FIELD_ENTERPRISE               =     1;
integer             SNMP_PDU_FIELD_AGENT_ADDR               =     2;
integer             SNMP_PDU_FIELD_GENERIC_TRAP             =     3;
integer             SNMP_PDU_FIELD_SPECIFIC_TRAP            =     4;
integer             SNMP_PDU_FIELD_TIME_STAMP               =     5;
integer             SNMP_PDU_FIELD_TRAP_VARBIND_LIST        =     6;
integer             SNMP_VARBIND_FIELD_OID                  =     1;
integer             SNMP_VARBIND_FIELD_VALUE                =     2;

char                ASN1_BITMASK_LENGTH_SHORT               =   $00;            // 00000000
char                ASN1_BITMASK_LENGTH_LONG                =   $80;            // 10000000

char                ASN1_TAG_CLASS_UNIVERSAL                =   $00;            // 00000000
char                ASN1_TAG_CLASS_APPLICATION              =   $40;            // 01000000
char                ASN1_TAG_CLASS_CONTEXT_SPECIFIC         =   $80;            // 10000000
char                ASN1_TAG_CLASS_PRIVATE                  =   $C0;            // 11000000

char                ASN1_TAG_ENCODING_PRIMITIVE             =   $00;            // 00000000
char                ASN1_TAG_ENCODING_CONSTRUCTED           =   $20;            // 00100000

char                ASN1_TAG_INTEGER                        =   $02;            // 00000010 Primitive
char                ASN1_TAG_OCTET_STRING                   =   $04;            // 00000100 Primitive
char                ASN1_TAG_NULL                           =   $05;            // 00000101 Primitive
char                ASN1_TAG_OBJECT_IDENTIFIER              =   $06;            // 00000110 Primitive
char                ASN1_TAG_SEQUENCE                       =   $30;            // 00110000 Constructed
char                ASN1_TAG_IPADDRESS                      =   $40;            // 01000000 Application Primitive (SNMP)
char                ASN1_TAG_COUNTER                        =   $41;            // 01000001 Application Primitive (SNMP)
char                ASN1_TAG_GAUGE                          =   $42;            // 01000010 Application Primitive (SNMP)
char                ASN1_TAG_TIMETICKS                      =   $43;            // 01000011 Application Primitive (SNMP) 
char                ASN1_TAG_OPAQUE                         =   $44;            // 01000100 Application Primitive (SNMP)
char                ASN1_TAG_GETREQUEST_PDU                 =   $A0;            // 10100000 Context-Specific Constructed (SNMP Manager)
char                ASN1_TAG_GETNEXTREQUEST_PDU             =   $A1;            // 10100001 Context-Specific Constructed (SNMP Manager)
char                ASN1_TAG_RESPONSE_PDU                   =   $A2;            // 10100010 Context-Specific Constructed (SNMP Manager)
char                ASN1_TAG_SETREQUEST_PDU                 =   $A3;            // 10100011 Context-Specific Constructed (SNMP Agent)
char                ASN1_TAG_TRAP_PDU                       =   $A4;            // 10100100 Context-Specific Constructed (SNMP Agent)

char                ASN1_TAGS[][1] = {
						{ ASN1_TAG_INTEGER }, 
						{ ASN1_TAG_OCTET_STRING }, 
						{ ASN1_TAG_NULL }, 
						{ ASN1_TAG_OBJECT_IDENTIFIER }, 
						{ ASN1_TAG_SEQUENCE }, 
						{ ASN1_TAG_IPADDRESS }, 
						{ ASN1_TAG_COUNTER }, 
						{ ASN1_TAG_GAUGE }, 
						{ ASN1_TAG_TIMETICKS }, 
						{ ASN1_TAG_OPAQUE }, 
						{ ASN1_TAG_GETREQUEST_PDU }, 
						{ ASN1_TAG_GETNEXTREQUEST_PDU }, 
						{ ASN1_TAG_RESPONSE_PDU }, 
						{ ASN1_TAG_SETREQUEST_PDU },
						{ ASN1_TAG_TRAP_PDU }
					}

char                ASN1_TAG_STRINGS[][19] = {
						'Integer', 
						'Octet String', 
						'Null', 
						'Object Identifier', 
						'Sequence', 
						'IPAddress', 
						'Counter', 
						'Gauge', 
						'TimeTicks', 
						'Opaque', 
						'GetRequest PDU', 
						'GetNextRequest PDU', 
						'Response PDU', 
						'SetRequest PDU', 
						'Trap PDU'
					}

char                SNMP_ERROR_NO_ERROR                     =   $00;
char                SNMP_ERROR_TOO_BIG                      =   $01;
char                SNMP_ERROR_NO_SUCH_NAME                 =   $02;
char                SNMP_ERROR_BAD_TAG                      =   $03;    
char                SNMP_ERROR_READ_ONLY                    =   $04;
char                SNMP_ERROR_GEN_ERR                      =   $05;

char                SNMP_ERRORS[][1] = {
						{ SNMP_ERROR_NO_ERROR }, 
						{ SNMP_ERROR_TOO_BIG }, 
						{ SNMP_ERROR_NO_SUCH_NAME }, 
						{ SNMP_ERROR_BAD_TAG }, 
						{ SNMP_ERROR_READ_ONLY }, 
						{ SNMP_ERROR_GEN_ERR }
					}

char                SNMP_ERROR_STRINGS[][72] = {
						'None', 
						'Response message too large to transport', 
						'The name of the requested object was not found', 
						'A data type in the request did not match the data type in the SNMP agent', 
						'The SNMP manager attempted to set a read-only parameter', 
						'General Error'
					}

(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

structure _snmp_agent {
	char            address[MAX_LEN_FQDN]
	integer         port
	char            community[MAX_LEN_OCTET_STRING]
}

structure _tag {
	char            type
	long            length
	char            contents[MAX_LEN_SNMP_TAG_VALUE]
}

structure _snmp_request {
	_connman_host   host
	long            id
	char            community[MAX_LEN_OCTET_STRING]
	char            pdu
	char            oid[MAX_LEN_OID]
	_tag            tag
}

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile _snmp_agent    snmp_agent;
volatile integer        snmp_manager_trap_port;

(***********************************************************)
(*                     INCLUDES GO BELOW                   *)
(***********************************************************)

#INCLUDE 'prime-debug';

#DEFINE CONNMAN_SET_MAX_NUM_BUFFER_OUT                          255             // Maximum number of items that can be stored in the outbound buffer. Default: 10.
#DEFINE CONNMAN_SET_MAX_LEN_BUFFER_OUT                         1500             // Maximum size of an item in the outbound buffer. Default: 2048.
#DEFINE CONNMAN_SET_MAX_LEN_BUFFER_IN                          1500             // Maximum size of the inbound buffer. Default: 2048.
#DEFINE USE_CONNMAN_TIMEOUT_CALLBACK
#DEFINE USE_CONNMAN_CONNECT_FAIL_CALLBACK
#INCLUDE 'prime-connman';                                                       // Use connman_setProperty() for IP client and preferences configuration

#DEFINE CONNMAN_SERVER_SET_MAX_LEN_BUFFER_IN                   1500             // Maximum size of the inbound buffer. Default: 2048.
#INCLUDE 'prime-connman-server';                                                // Use connman_setProperty() for IP server and preferences configuration

(***********************************************************)
(*               LATCHING DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_LATCHING

(***********************************************************)
(*       MUTUALLY EXCLUSIVE DEFINITIONS GO BELOW           *)
(***********************************************************)
DEFINE_MUTUALLY_EXCLUSIVE

(***********************************************************)
(*    LIBRARY SUBROUTINE/FUNCTIONS DEFINITIONS GO BELOW    *)
(***********************************************************)

#IF_NOT_DEFINED __PRIME_RAWTOL
	#DEFINE __PRIME_RAWTOL
	
define_function long rawtol(char str[]) {
	stack_var volatile integer i;
	stack_var volatile long ret;
	
	// if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'rawtol', '(', str, ')'");
	
	for (i = 1; i <= length_string(str); i++) {
		ret = (ret LSHIFT 8) + str[i];
	}

	// if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'rawtol', '() ', 'returning ', ltoa(ret)");
	return ret;
}

#END_IF


#IF_NOT_DEFINED __PRIME_LTOA
	#DEFINE __PRIME_LTOA
	
define_function char[MAX_LEN_LONG] ltoa(long l) {
	stack_var volatile char ret[MAX_LEN_LONG];
	
	// if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'ltoa', '(', 'long', ')'");

	if (l < 100000) {
		ret = itoa(l);
	} else {
		ret = "itoa(l / 100000), itoa(l % 100000)"; // Keep itoa input under 16 bits
	}
	
	// if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'ltoa', '() ', 'returning ', ret");
	return ret;
}

#END_IF


#IF_NOT_DEFINED __PRIME_ATOL_UNSIGNED
	#DEFINE __PRIME_ATOL_UNSIGNED
	
define_function long atol_unsigned(char str[]) {
	stack_var volatile integer i;
	stack_var volatile long l;
	
	// if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'atol_unsigned', '(', 'str', ')'");

	for (i = 1; i <= length_string(str); i++) {
		l = l * 10;
		l = l + atoi("str[i]");
	}
	
	// if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'atol_unsigned', '() ', 'returning ', ltoa(l)");
	return l;
}

#END_IF


#IF_NOT_DEFINED __PRIME_ARRAY_SEARCH
	#DEFINE __PRIME_ARRAY_SEARCH
	
define_function integer array_search(char needle[], char haystack[][]) {
	stack_var volatile integer i;
	
	// if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'array_search', '(', itoa(needle), ', ', 'haystack[', itoa(length_array(haystack)), ']', ')'");
	
	for (i = 1; i <= length_array(haystack); i++) {
		if (haystack[i] == "needle") {
			// if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'array_search', '() ', 'needle found. returning index ', itoa(i)");
			return i;
		}
	}
	
	// if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'array_search', '() ', 'needle could not be found. returning false'");
	return false;
}

#END_IF


#IF_NOT_DEFINED __PRIME_BASE128_ENCODE
	#DEFINE __PRIME_BASE128_ENCODE
	
define_function char[MAX_LEN_LONG_BASE128] base128_encode(long n) {
	stack_var volatile char ret[MAX_LEN_LONG_BASE128];
	
	// if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'base128_encode', '(', itoa(n), ')'");
	
	if (n < 128) {
		ret = "n";                              // Compiler errors when omitting quotes (C10533: Illegal assignment statement)
	} else 
	while (n) {
		stack_var volatile long rem;
		
		rem = n % 128;
		n = n / 128;
		
		ret = "rem, ret";
	}
	
	// if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'base128_encode', '() ', 'returning ', ret");
	return ret;
}

#END_IF


#IF_NOT_DEFINED __PRIME_BASE128_DECODE
	#DEFINE __PRIME_BASE128_DECODE
	
define_function long base128_decode(char str[MAX_LEN_LONG_BASE128]) {
	stack_var volatile integer pos;
	stack_var volatile long ret;
	
	// if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'base128_decode', '(', str, ')'");
	
	for (pos = 1; pos <= length_string(str); pos++) {
		ret = (ret LSHIFT 7) + str[pos];
	}
	
	// if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'base128_decode', '() ', 'returning ', itoa(ret)");
	return ret;
}

#END_IF


#IF_NOT_DEFINED __PRIME_IMPLODE
	#DEFINE __PRIME_IMPLODE
	
define_function char[MAX_LEN_STR] implode(char parts[][], char delim[]) {
	stack_var volatile integer i;
	stack_var volatile char str[MAX_LEN_STR];
	
	// if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'implode', '(', 'parts[', itoa(length_array(parts)), '], "', delim, '"', ')'");
	
	for (i = 1; i <= length_array(parts); i++) {
		str = "str, parts[i]";
		if ((delim) && (i < length_array(parts))) str = "str, delim";
	}

	// if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'implode', '() ', 'returning ', str");
	return str;
}

#END_IF


#IF_NOT_DEFINED __PRIME_EXPLODE
	#DEFINE __PRIME_EXPLODE
	
define_function integer explode(char str[], char delim[], char quote, char parts[][]) {
	stack_var volatile integer i;
	stack_var volatile integer start, end;
	
	// if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'explode', '(', 'str[', itoa(length_string(str)), ']', ', "', delim, '", "', quote, '", ', 'parts[', itoa(max_length_array(parts)), '][]', ')'");
	
	start = 1;
	while (start <= length_string(str)) {
		i++;
		
		/*
		if (str[start] == delim) {
			start++;                                    // Avoid empty parts and delimiter padding (i.e. spaces)
			continue;
		}
		*/
		if ((quote) && (str[start] == quote)) {         // Optionally consider quoted strings as a single parts
			start++;
			end = find_string(str, quote, start);
		} else {
			end = find_string(str, delim, start);       // Find next delimiter
		}
		if ((!end) || (i == max_length_array(parts))) { // Return remainder of string if no further delimiters found or the maximum number of parts have already been found
			end = length_string(str) + 1;
		}
		
		parts[i] = mid_string(str, start, end - start);
		
		start = end + 1;
	}
	
	set_length_array(parts, i);

	// if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'explode', '() ', 'returning array[', itoa(i), ']'");
	return i;
}

#END_IF

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)

define_function setDebugState(integer lvl) {
	if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'setDebugState', '(', itoa(lvl), ')'");

#IF_DEFINED __PRIME_DEBUG
	if (debug_set_level(lvl)) {
		send_string vdvModule, "'DEBUG-', itoa(lvl)";
	} else {
		if (AMX_ERROR <= get_log_level()) debug(AMX_ERROR, "'setDebugState', '() ', 'could not set debug level to', itoa(lvl)");
	}
#ELSE
	set_log_level(lvl);
#END_IF

	if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'setDebugState', '() ', 'returning'");
}

define_function integer setProperty(char key[], char value[]) {
	if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'setProperty', '(', key, ', ', value, ')'");
	
	switch (key) {
		case 'IP_ADDRESS': snmp_agent.address = value;
		case 'PORT': snmp_agent.port = atoi(value);
		case 'COMMUNITY': snmp_agent.community = value;
		case 'TRAP_PORT': snmp_manager_trap_port = atoi(value);
		
		default: {
			stack_var integer result;
			
		#IF_DEFINED __PRIME_CONNMAN
			if (!result) result = connman_setProperty(key, value);
		#END_IF
		
		#IF_DEFINED __PRIME_CONNMAN_SERVER
			if (!result) result = connman_server_setProperty(key, value);
		#END_IF
		
		#IF_DEFINED __PRIME_DEBUG
			if (!result) result = debug_setProperty(key, value);
		#END_IF
			
			if (!result) {
				if (AMX_ERROR <= get_log_level()) debug(AMX_ERROR, "'setProperty', '() ', 'error setting value for ', key, '!'");
				if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'setProperty', '() ', 'returning false'");
				return false;
			}
		}
	}
	
	send_string vdvModule, "'PROPERTY-', key, ',', value";
	
	if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'setProperty', '() ', 'returning true'");
	return true;
}

define_function reinitialize() {
	if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'reinitialize', '()'");
	
	off[vdvModule, DATA_INITIALIZED];
	
	if (!length_string(snmp_agent.address) || !snmp_agent.port || !length_string(snmp_agent.community)) {
		if (AMX_INFO <= get_log_level()) debug(AMX_INFO, "'reinitialize', '() ', 'default SNMP host and port not configured, and will need to be passed as command parameters.'");
	}
	if (!snmp_manager_trap_port) {
		if (AMX_INFO <= get_log_level()) debug(AMX_INFO, "'reinitialize', '() ', 'SNMP trap port not configured. Trap listener disabled.'");
	}

	// This module uses connman_buffer_add_ex() to specify the server address, port, and protocol for each string sent. connman_reinitialize() is still called to configure other parameters (such as connect and retry interval).
	// connman_setProperty('HOST', '<address>');
	// connman_setProperty('PORT', itoa(<port>));
	// connman_setProperty('PROTOCOL', itoa(IP_UDP_2WAY));

	connman_server_setProperty('PROTOCOL', itoa(IP_UDP));
	connman_server_setProperty('PORT', itoa(snmp_manager_trap_port));
	
#IF_DEFINED __PRIME_CONNMAN
	connman_reinitialize();
#END_IF
	
#IF_DEFINED __PRIME_CONNMAN_SERVER
	connman_server_reinitialize();
#END_IF
	
	on[vdvModule, DATA_INITIALIZED];
}

define_function integer snmp_request(_connman_host host, _snmp_request request) {
	stack_var volatile long timer;
	stack_var volatile char message[MAX_LEN_STR];
	
	if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'snmp_request', '(', '_connman_host ', host.address, ':', itoa(host.port), ', ', request.pdu, ', ', request.oid, '@', request.community, ', ', request.tag.type, ', ', request.tag.contents, ')'");
	
	if (!host.protocol) host.protocol = IP_UDP_2WAY;
	if (!length_string(host.address)) host.address = snmp_agent.address;
	if (host.port) host.port = snmp_agent.port;
	
	if (!length_string(request.community)) request.community = snmp_agent.community;
	
	if (!length_string(host.address) || !host.port || !length_string(request.community)) {
		if (AMX_ERROR <= get_log_level()) debug(AMX_ERROR, "'snmp_request', '() ', 'host, port, and community must be specified or configured!'");
		if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'snmp_request', '() ', 'returning false'");
		return false;
	}
	
	if (length_string(connman_buffer_out[connman_buffer_out_pos_in].str)) {
		if (AMX_ERROR <= get_log_level()) debug(AMX_ERROR, "'snmp_request', '() ', 'outbound buffer is full. Cannot send message!'");
		if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'snmp_request', '() ', 'returning false'");
		return false;
	}
	
	if (AMX_INFO <= get_log_level()) debug(AMX_INFO, "'snmp_request', '() ', 'encoding message...'");
	
	timer = get_timer;
	if (!request.id) request.id = random_number(timer);
	
	message = 
		asn1_tag_encode(ASN1_TAG_SEQUENCE, "
			asn1_tag_encode(ASN1_TAG_INTEGER, NULL),                            // SNMP Version
			asn1_tag_encode(ASN1_TAG_OCTET_STRING, request.community),          // SNMP Community
			asn1_tag_encode(request.pdu, "                                      // SNMP GetRequest PDU
			asn1_tag_encode(ASN1_TAG_INTEGER, itoa(request.id)),                // Request ID
			asn1_tag_encode(ASN1_TAG_INTEGER, NULL),                            // Error
			asn1_tag_encode(ASN1_TAG_INTEGER, NULL),                            // Error Index
			asn1_tag_encode(ASN1_TAG_SEQUENCE, "                                // Varbind List
				asn1_tag_encode(ASN1_TAG_SEQUENCE, "                            // Varbind
				asn1_tag_encode(ASN1_TAG_OBJECT_IDENTIFIER, request.oid),       // Object Identifier
				asn1_tag_encode(request.tag.type, request.tag.contents)         // Value
				")
			")
		")
	");
	
	if (!message) {
		if (AMX_ERROR <= get_log_level()) debug(AMX_ERROR, "'snmp_request', '() ', 'message could not be encoded!'");
		if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'snmp_request', '() ', 'returning false'");
		return false;
	} else {
		if (AMX_INFO <= get_log_level()) debug(AMX_INFO, "'snmp_request', '() ', 'message encoded in ', itoa(get_timer - timer), ' 1/10th sec'");
	}
	
	connman_buffer_add_ex(host, message);
	
	if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'snmp_request', '() ', 'returning true'");
	return true;
}

define_function char[MAX_LEN_OCTET_STRING] asn1_tag_encode(char type, char value[MAX_LEN_OCTET_STRING]) {
	stack_var volatile char ret[MAX_LEN_OCTET_STRING];
	
	if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'asn1_tag_encode', '(', type, ', ', value, ')'");

	switch (type) {
		case ASN1_TAG_SEQUENCE: {
			// Sequence assumed to be already encoded
		}
		case ASN1_TAG_OCTET_STRING: {
			// Octet string does not need encoding
		}
		case ASN1_TAG_INTEGER: {
			value = raw_be(atoi(value));
		}
		case ASN1_TAG_TIMETICKS: {
			value = raw_be(atol(value));
		}
		case ASN1_TAG_COUNTER: {
			value = raw_be(atol(value));
		}
		case ASN1_TAG_GAUGE: {
			value = raw_be(atol(value));
		}
		case ASN1_TAG_OBJECT_IDENTIFIER: {
			value = asn1_tag_oid_encode(value);
		}
		case ASN1_TAG_NULL: {
			value = "";
		}
	}
	
	ret = "type, asn1_length_encode(length_string(value)), value";
	
	if (array_search(type, ASN1_TAGS)) {
		if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'asn1_tag_encode', '() ', 'encoded tag of type ', format('$%02X', type), ' ', ASN1_TAG_STRINGS[array_search(type, ASN1_TAGS)], ' (', itoa(length_string(ret)), ' bytes)'");
	} else {
		if (AMX_WARNING <= get_log_level()) debug(AMX_WARNING, "'asn1_tag_encode', '() ', 'encoded tag of type ', format('$%02X', type), ' ', 'UNKNOWN', ' (', itoa(length_string(ret)), ' bytes)'");
	}

	if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'asn1_tag_encode', '() ', 'returning ', ret");
	return ret;
}

define_function char[MAX_LEN_ASN1_LENGTH_ENCODED] asn1_length_encode(long length) {
	stack_var volatile char ret[MAX_LEN_ASN1_LENGTH_ENCODED];
	
	if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'asn1_length_encode', '(', itoa(length), ')'");
	
	if (length < 128) { // Length fits inside a single octet
		ret = "length";
	} else { // Length requires more than one octet
		ret = raw_be(length); // Store long as reting
		ret = "(ASN1_BITMASK_LENGTH_LONG BOR length_string(ret)), ret"; // Prefix reting with number of length octets and long form bitmask
	}
	
	if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'asn1_length_encode', '() ', 'returning ', ret");
	return ret;
}

define_function char[MAX_LEN_OID_ENCODED] asn1_tag_oid_encode(char str[]) {
	stack_var volatile integer i;
	stack_var volatile char oid_sub_identifiers[MAX_NUM_OID_SUB_IDENTIFIER][MAX_LEN_LONG];
	stack_var volatile char ret[MAX_LEN_OID_ENCODED];
	
	if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'asn1_tag_oid_encode', '(', str, ')'");
	
	explode(str, '.', false, oid_sub_identifiers);
	
	ret = "(atoi(oid_sub_identifiers[1]) * 40) + atoi(oid_sub_identifiers[2])";
	
	for (i = 3; i <= length_array(oid_sub_identifiers); i++) {
		stack_var volatile char base128_str[MAX_LEN_LONG_BASE128];
		stack_var volatile integer o;
		
		base128_str = base128_encode(atoi(oid_sub_identifiers[i])); // Get base128-encoded long
		
		for (o = 1; o < length_array(base128_str); o++) { // Add bitmask to all but final octet
			base128_str[o] = base128_str[o] BOR ASN1_BITMASK_LENGTH_LONG;
		}
		ret = "ret, base128_str";
	}
	
	if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'asn1_tag_oid_encode', '() ', 'returning ', ret");
	return ret;
}

define_function char[MAX_LEN_IPADDRESS_ENCODED] asn1_tag_ipaddress_encode(char str[]) {
	stack_var volatile char ret[MAX_LEN_IPADDRESS]
	stack_var volatile char octets[NUM_IPADDRESS_OCTETS][MAX_LEN_IPADDRESS_OCTET]
	
	if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'asn1_tag_ipaddress_encode', '(', str, ')'");
	
	if (!explode(str, '.', false, octets)) {
		if (AMX_ERROR <= get_log_level()) debug(AMX_ERROR, "'asn1_tag_ipaddress_encode', '() ', 'could not parse address!', ret");
	} else {
		stack_var volatile integer i;
		
		for (i = 1; i <= length_array(octets); i++) {
			ret = "ret, raw_be(atoi(octets[i]))"
		}
	}
	
	if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'asn1_tag_ipaddress_encode', '() ', 'returning ', ret");
	return ret;
}

define_function integer asn1_tag_decode(char str[], _tag tags[]) {
	stack_var volatile long pos;
	stack_var volatile integer i;
	
	if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'asn1_tag_decode', '(', str, ', ', 'tags[', itoa(max_length_array(tags)), ']', ')'");
	
	pos = 1;
	
	while (pos <= length_string(str)) {
		stack_var volatile long length;
		
		i++;
		tags[i].type = str[pos]; pos++;
		
		if (str[pos] BAND ASN1_BITMASK_LENGTH_LONG) { // Long form length octet
			stack_var volatile long octet, num_octets;
			
			num_octets = str[pos] BAND (BNOT ASN1_BITMASK_LENGTH_LONG); pos++; // Determine number of octets in long-form length
			
			length = rawtol(mid_string(str, pos, num_octets)); // Convert string to long
			pos = pos + num_octets;
		} else { // Short form length octet
			length = str[pos]; pos++;
		}
		
		tags[i].contents = mid_string(str, pos, length); pos = pos + length;
		
		if (array_search(tags[i].type, ASN1_TAGS)) {
			if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'asn1_tag_decode', '() ', 'found tag ', itoa(i), ' of type ', format('$%02X', tags[i].type), ' ', ASN1_TAG_STRINGS[array_search(tags[i].type, ASN1_TAGS)], ': ', tags[i].contents, ' (', itoa(length), ' bytes)'");
		} else {
			if (AMX_WARNING <= get_log_level()) debug(AMX_WARNING, "'asn1_tag_decode', '() ', 'found tag ', itoa(i), ' of type ', format('$%02X', tags[i].type), ' ', 'UNKNOWN', ': ', tags[i].contents, ' (', itoa(length), ' bytes)'");
		}
		
		switch (tags[i].type) {
			case ASN1_TAG_OCTET_STRING: {
			// Octet string does not need decoding
			}
			case ASN1_TAG_INTEGER: {
				tags[i].contents = ltoa(rawtol(tags[i].contents));
			}
			case ASN1_TAG_TIMETICKS: {
				tags[i].contents = ltoa(rawtol(tags[i].contents));
			}
			case ASN1_TAG_COUNTER: {
				tags[i].contents = ltoa(rawtol(tags[i].contents));
			}
			case ASN1_TAG_GAUGE: {
				tags[i].contents = ltoa(rawtol(tags[i].contents));
			}
			case ASN1_TAG_IPADDRESS: {
				tags[i].contents = asn1_tag_ipaddress_decode(tags[i].contents);
			}
			case ASN1_TAG_OBJECT_IDENTIFIER: {
				tags[i].contents = asn1_tag_oid_decode(tags[i].contents);
			}
			case ASN1_TAG_NULL: {
				tags[i].contents = NULL;
			}
		}
		
		if (array_search(tags[i].type, ASN1_TAGS)) {
			if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'asn1_tag_decode', '() ', 'decoded tag ', itoa(i), ' of type ', format('$%02X', tags[i].type), ' ', ASN1_TAG_STRINGS[array_search(tags[i].type, ASN1_TAGS)], ': ', tags[i].contents, ' (', itoa(length_string(tags[i].contents)), ' bytes)'");
		} else {
			if (AMX_WARNING <= get_log_level()) debug(AMX_WARNING, "'asn1_tag_decode', '() ', 'decoded tag ', itoa(i), ' of type ', format('$%02X', tags[i].type), ' ', 'UNKNOWN', ': ', tags[i].contents, ' (', itoa(length_string(tags[i].contents)), ' bytes)'");
		}
	}
	
	set_length_array(tags, i);

	if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'asn1_tag_decode', '() ', 'returning ', itoa(i)");
	return i;
}

define_function char[MAX_LEN_OID] asn1_tag_oid_decode(char str[]) {
	stack_var volatile integer pos, i;
	stack_var volatile char base128_str[MAX_LEN_LONG_BASE128];
	stack_var volatile char oid[MAX_NUM_OID_SUB_IDENTIFIER][MAX_LEN_OID_SUB_IDENTIFIER];
	stack_var volatile char ret[MAX_LEN_OID]
	
	if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'asn1_tag_oid_decode', '(', str, ')'");
	
	i++; oid[i] = itoa(str[1] / 40);
	i++; oid[i] = itoa(str[1] % 40);
	
	for (pos = 2; pos <= length_string(str); pos++) {
		base128_str = "base128_str, str[pos] BAND (BNOT ASN1_BITMASK_LENGTH_LONG)"; // Create base128 string // remove 10000000
		
		if (!(str[pos] BAND ASN1_BITMASK_LENGTH_LONG)) { // If length does not span any additional octets        
			i++; oid[i] = itoa(base128_decode(base128_str)); // Decode base128 string into long (and ascii number)
			base128_str = "";
		}
	}
	set_length_array(oid, i);
	
	ret = implode(oid, '.');
	
	if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'asn1_tag_oid_decode', '() ', 'returning ', ret");
	return ret;
}

define_function char[MAX_LEN_IPADDRESS] asn1_tag_ipaddress_decode(char str[]) {
	stack_var volatile char ret[MAX_LEN_IPADDRESS]
	stack_var volatile char octets[4][3]
	stack_var volatile integer i;
	
	if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'asn1_tag_ipaddress_decode', '(', str, ')'");
	
	for (i = 1; i <= 4; i++) {
		octets[i] = itoa(str[i]);
	}
	set_length_array(octets, 4);
	
	ret = implode(octets, '.');
	
	if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'asn1_tag_oid_decode', '() ', 'returning ', ret");
	return ret;
}


(***********************************************************)
(*    CALLBACK SUBROUTINE/FUNCTION DEFINITIONS GO BELOW    *)
(***********************************************************)

// #DEFINE USE_CONNMAN_TIMEOUT_CALLBACK
define_function connman_timeout_callback(_connman_host host, char str[]) {
	if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_timeout_callback', '(', '_connman_host ', host.address, ':', itoa(host.port), ', ', 'str[])'");
	
	send_string vdvModule, "'TIMEOUT-', host.address, ',', itoa(host.port)";
}

// #DEFINE USE_CONNMAN_CONNECT_FAIL_CALLBACK
define_function connman_connect_fail_callback(_connman_host host, char str[]) {
	if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_connect_fail_callback', '(', '_connman_host ', host.address, ':', itoa(host.port), ', ', 'str[])'");
	
	send_string vdvModule, "'TIMEOUT-', host.address, ',', itoa(host.port)";
}

(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START

// Debug configuration
debug_setProperty('PROC_NAME', 'SNMP');                                         // Process name prefix for debug messages
debug_setProperty('DECODE_UNPRINTABLE', booltostring(true));                    // Show unprintable characters as hexadecimal values

// Module default configuration
// setProperty('HOST', '<address>');                                            // SNMP manager (remote device) address
setProperty('PORT', itoa(161));                                                 // Default SNMP manager (remote device) port
setProperty('TRAP_PORT', itoa(162));                                            // Default Listening port for SNMP traps
setProperty('COMMUNITY', 'public');                                             // Default SNMP community

// prime-connman configuration
// IP_ADDRESS, PORT, PROTOCOL are set for each SNMP GET, GETNEXT, SET request
// connman_reinitialize() will be called by module-specific reinitialize()

// connman_setProperty("'IP_ADDRESS', '<address>'");                            // Server address.
// connman_setProperty("'PORT', itoa(<port>)");                                 // Server port.
// connman_setProperty("'PROTOCOL', itoa(<IP_TCP|IP_UDP|IP_UDP_2WAY>)");        // Transport protocol using NetLinx transport protocol constants.

connman_setProperty('CONNECT_DELAY', itoa(1000));                               // Delay between connection attempts. Default: 5000ms.
// connman_setProperty('MAX_CONNECTION_ATTEMPTS', itoa(<num>)");                // Maximum number of connection attempts. Default: 3.
// connman_setProperty('AUTO_DISCONNECT', booltostring(<true|false>)");         // Automatically disconnect when all strings in the buffer have been sent. Default: false.
// connman_setProperty('AUTO_RECONNECT', booltostring(<true|false>)");          // Automatically re-connect if the connection drops. Also connects on reinitialize() without buffer contents. Default: false.

connman_setProperty('SEND_DELAY', itoa(1000));                                  // Delay between concurrent strings sent from the outbound butter. Default: 0msec.
connman_setProperty('ADVANCE_ON_RESPONSE', booltostring(true));                 // Advance the outbound buffer when a respons is received. Default: false.
connman_setProperty('AUTO_RETRANSMIT', itoa(1));                                // Re-transmit strings sent from the buffer <num> times at the SEND_DELAY interval until a response is received. Default: 0 (transmit once).

// connman_reinitialize();

// prime-connman-server configuration
// connman_server_setProperty('PORT', itoa(snmp_manager_trap_port));            // Listening port.
// connman_server_setProperty('PROTOCOL', itoa(<IP_TCP|IP_UDP>));               // Transport protocol using NetLinx transport protocol constants.
// connman_server_setProperty('AUTO_REOPEN', booltostring(true));               // Automatically re-open the listening socket if it is closed. Default: true.
// connman_server_setProperty('OPEN_DELAY', itoa(<msec>));                      // Delay between attempts to open the listening socket. Default: 5000ms.
// connman_server_reinitialize();                                               // Re-initialise and open the listening socket if AUTO_REOPEN

// reinitialize();                                                              // Must be called before SNMP trap listening socket will be opened

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT

data_event[vdvModule] {
	command: {
		stack_var volatile char cmd[MAX_LEN_STR];
		
		if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'data_event command: ', data.text, ' (', itoa(length_string(data.text)), ' bytes)'");
		
		cmd = remove_string(data.text, '-', 1);
		if (cmd) {
			cmd = left_string(cmd, length_string(cmd) - 1);
		} else {
			cmd = data.text;
		}
		
		cmd = upper_string(cmd);
		switch (cmd) {
			case 'DEBUG': {
				setDebugState(atoi(data.text));
			}
			case 'PROPERTY': {
				stack_var char parts[2][MAX_LEN_STR];
				
				if (!explode(data.text, ',', true, parts)) {
					if (AMX_ERROR <= get_log_level()) debug(AMX_ERROR, "'data_event command property: ', 'Could not parse parameters!'");
				} else {
					setProperty(parts[1], parts[2]);
				}
			}
			case 'REINIT': {
				if (AMX_INFO <= get_log_level()) debug(AMX_INFO, "'data_event command reinit: re-initializing...'");
				reinitialize();
			}
			case 'SNMPGET':       // SNMPGET-<oid>[,<community>[,<host>[,<port>[,<request id>]]]]
			case 'SNMPGETNEXT': { // SNMPGETNEXT-<oid>[,<community>[,<host>[,<port>[,<request id>]]]]
				stack_var char parts[5][MAX_LEN_OCTET_STRING];
				
				explode(data.text, ',', true, parts);
				
				if (length_array(parts) < 1) {
					if (AMX_ERROR <= get_log_level()) debug(AMX_ERROR, "'data_event command ', lower_string(cmd), ': ', 'could not parse parameters!'");
					if (AMX_ERROR <= get_log_level()) debug(AMX_ERROR, "'data_event command ', lower_string(cmd), ': ', 'usage: ', cmd, '-<oid>[,<community>[,<host>[,<port>[,<request id>]]]]'");
				} else {
					stack_var volatile _snmp_request request;
					stack_var volatile _connman_host host;
					
					if (length_array(parts) >= 2) request.community = parts[2];
					if (length_array(parts) >= 3) host.address      = parts[3];
					if (length_array(parts) >= 4) host.port         = atoi(parts[4]);
					if (length_array(parts) >= 5) request.id        = atoi(parts[5]);
					
					switch (cmd) {
						case 'SNMPGET': {
							request.pdu         = ASN1_TAG_GETREQUEST_PDU;
							request.oid         = parts[1];
							request.tag.type    = ASN1_TAG_NULL;
							
							snmp_request(host, request);
						}
						case 'SNMPGETNEXT': {
							request.pdu         = ASN1_TAG_GETNEXTREQUEST_PDU;
							request.oid         = parts[1];
							request.tag.type    = ASN1_TAG_NULL;
							
							snmp_request(host, request);
						}
					}
				}
			}
			case 'SNMPSET': { // SNMPSET-<oid>,<type>,<value>[,<community>[,<host>[,<port>[,<request id>]]]]
				stack_var char parts[7][MAX_LEN_OCTET_STRING];
				
				explode(data.text, ',', true, parts);
				
				if (length_array(parts) < 3) {
					if (AMX_ERROR <= get_log_level()) debug(AMX_ERROR, "'data_event command ', lower_string(cmd), ': ', 'could not parse parameters!'");
					if (AMX_ERROR <= get_log_level()) debug(AMX_ERROR, "'data_event command ', lower_string(cmd), ': ', 'usage: SNMPSET-<oid>,<type>,<value>[,<community>[,<host>[,<port>[,<request id>]]]]'");
				} else {
					stack_var volatile _snmp_request request;
					stack_var volatile _connman_host host;
					
					if (length_array(parts) >= 4) request.community = parts[4];
					if (length_array(parts) >= 5) host.address      = parts[5];
					if (length_array(parts) >= 6) host.port         = atoi(parts[6]);
					if (length_array(parts) >= 7) request.id        = atoi(parts[7]);
					
					request.pdu                 = ASN1_TAG_SETREQUEST_PDU;
					request.oid                 = parts[1];
					request.tag.type            = parts[2][1];
					request.tag.contents        = parts[3];
					
					snmp_request(host, request);
				}
			}
			default: {
				if (AMX_ERROR <= get_log_level()) debug(AMX_ERROR, "'data_event command: ', 'unknown command: ', cmd");
			}
		}
	}
}

data_event[connman_device]
data_event[connman_server_device] {
	string: {
		stack_var volatile long timer;
		stack_var volatile _tag message[1], snmp_message[3];
		
		if (AMX_INFO <= get_log_level()) debug(AMX_INFO, "'response: ', 'message processing...'");
		timer = get_timer;
		
		asn1_tag_decode(data.text, message);
		asn1_tag_decode(message[SNMP_FIELD_MESSAGE].contents, snmp_message)
		
		if (AMX_INFO <= get_log_level()) debug(AMX_INFO, "'response: ', 'version: ',   snmp_message[SNMP_MESSAGE_FIELD_VERSION].contents");
		if (AMX_INFO <= get_log_level()) debug(AMX_INFO, "'response: ', 'community: ', snmp_message[SNMP_MESSAGE_FIELD_COMMUNITY].contents");
		if (AMX_INFO <= get_log_level()) debug(AMX_INFO, "'response: ', 'pdu: ',       ASN1_TAG_STRINGS[array_search(snmp_message[SNMP_MESSAGE_FIELD_PDU].type, ASN1_TAGS)]");
		
		switch (snmp_message[SNMP_MESSAGE_FIELD_PDU].type) {
			case ASN1_TAG_RESPONSE_PDU: {
				stack_var volatile integer i;
				stack_var volatile _tag snmp_pdu[4], snmp_varbind_list[MAX_NUM_SNMP_TAGS];
				
				if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'response: ', 'processing response PDU...'");
				
				asn1_tag_decode(snmp_message[SNMP_MESSAGE_FIELD_PDU].contents, snmp_pdu);
				
				if (AMX_INFO <= get_log_level()) debug(AMX_INFO, "'response: ', 'request id: ', snmp_pdu[SNMP_PDU_FIELD_REQUEST_ID].contents");
				
				asn1_tag_decode(snmp_pdu[SNMP_PDU_FIELD_RESPONSE_VARBIND_LIST].contents, snmp_varbind_list);
				
				remove_string(data.sourceip, '::ffff:', 1);
				
				// Error handling
				if (snmp_pdu[SNMP_PDU_FIELD_ERROR].contents != itoa(SNMP_ERROR_NO_ERROR)) {
					if (atoi(snmp_pdu[SNMP_PDU_FIELD_ERROR_INDEX].contents)) {
						stack_var volatile _tag snmp_varbind[2];
						
						asn1_tag_decode(snmp_varbind_list[atoi(snmp_pdu[SNMP_PDU_FIELD_ERROR_INDEX].contents)].contents, snmp_varbind);
						
						if (AMX_ERROR <= get_log_level()) debug(AMX_ERROR, "'response: ', 'error index: ', snmp_pdu[SNMP_PDU_FIELD_ERROR_INDEX].contents, ' (', snmp_varbind[SNMP_VARBIND_FIELD_OID].contents, ')'");
						send_string vdvModule, "'ERROR', '-', snmp_varbind[SNMP_VARBIND_FIELD_OID].contents, ',', snmp_pdu[SNMP_PDU_FIELD_ERROR].contents, ',', SNMP_ERROR_STRINGS[atoi(snmp_pdu[SNMP_PDU_FIELD_ERROR].contents) + 1], ',', snmp_message[SNMP_MESSAGE_FIELD_COMMUNITY].contents, ',', data.sourceip";
					} else {
						if (AMX_ERROR <= get_log_level()) debug(AMX_ERROR, "'response: ', 'error: ', snmp_pdu[SNMP_PDU_FIELD_ERROR].contents, ' ', SNMP_ERROR_STRINGS[atoi(snmp_pdu[SNMP_PDU_FIELD_ERROR].contents) + 1]");
						send_string vdvModule, "'ERROR', '-', snmp_pdu[SNMP_PDU_FIELD_ERROR].contents, ',', SNMP_ERROR_STRINGS[atoi(snmp_pdu[SNMP_PDU_FIELD_ERROR].contents) + 1], ',', snmp_message[SNMP_MESSAGE_FIELD_COMMUNITY].contents, ',', data.sourceip";
					}
					
					break;
				}
				
				// Varbind Processing
				for (i = 1; i <= length_array(snmp_varbind_list); i++) {
					stack_var volatile _tag snmp_varbind[2];
					
					asn1_tag_decode(snmp_varbind_list[i].contents, snmp_varbind);
					
					if (AMX_INFO <= get_log_level()) debug(AMX_INFO, "'response: ', 'OID ', snmp_varbind[SNMP_VARBIND_FIELD_OID].contents, ' = ', snmp_varbind[SNMP_VARBIND_FIELD_VALUE].contents, ' (', ASN1_TAG_STRINGS[array_search(snmp_varbind[SNMP_VARBIND_FIELD_VALUE].type, ASN1_TAGS)], ')'");
					
					send_string vdvModule, "
						'OID', '-', 
						snmp_varbind[SNMP_VARBIND_FIELD_OID].contents, ',', 
						snmp_varbind[SNMP_VARBIND_FIELD_VALUE].contents, ',', 
						ASN1_TAG_STRINGS[array_search(snmp_varbind[SNMP_VARBIND_FIELD_VALUE].type, ASN1_TAGS)], ',', 
						snmp_message[SNMP_MESSAGE_FIELD_COMMUNITY].contents, ',', 
						data.sourceip, ',', 
						snmp_pdu[SNMP_PDU_FIELD_REQUEST_ID].contents";
				}
			}
			case ASN1_TAG_TRAP_PDU: {
				stack_var volatile integer i;
				stack_var volatile _tag snmp_pdu[6], snmp_varbind_list[MAX_NUM_SNMP_TAGS];
				
				if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'response: ', 'processing trap PDU...'");
				
				asn1_tag_decode(snmp_message[SNMP_MESSAGE_FIELD_PDU].contents, snmp_pdu);
				
				if (AMX_INFO <= get_log_level()) debug(AMX_INFO, "'response: ', 'enterprise: ',    snmp_pdu[SNMP_PDU_FIELD_ENTERPRISE].contents");
				if (AMX_INFO <= get_log_level()) debug(AMX_INFO, "'response: ', 'agent address: ', snmp_pdu[SNMP_PDU_FIELD_AGENT_ADDR].contents");
				if (AMX_INFO <= get_log_level()) debug(AMX_INFO, "'response: ', 'generic trap: ',  snmp_pdu[SNMP_PDU_FIELD_GENERIC_TRAP].contents");
				if (AMX_INFO <= get_log_level()) debug(AMX_INFO, "'response: ', 'specific trap: ', snmp_pdu[SNMP_PDU_FIELD_SPECIFIC_TRAP].contents");
				if (AMX_INFO <= get_log_level()) debug(AMX_INFO, "'response: ', 'time stamp: ',    snmp_pdu[SNMP_PDU_FIELD_TIME_STAMP].contents");
				
				asn1_tag_decode(snmp_pdu[SNMP_PDU_FIELD_TRAP_VARBIND_LIST].contents, snmp_varbind_list);
				
				// Varbind Processing
				for (i = 1; i <= length_array(snmp_varbind_list); i++) {
					stack_var volatile _tag snmp_varbind[2];
					
					asn1_tag_decode(snmp_varbind_list[i].contents, snmp_varbind);
					
					if (AMX_INFO <= get_log_level()) debug(AMX_INFO, "'response: ', 'OID ', snmp_varbind[SNMP_VARBIND_FIELD_OID].contents, ' = ', snmp_varbind[SNMP_VARBIND_FIELD_VALUE].contents, ' (', ASN1_TAG_STRINGS[array_search(snmp_varbind[SNMP_VARBIND_FIELD_VALUE].type, ASN1_TAGS)], ')'");
					
					send_string vdvModule, "
						'TRAP', '-', 
						snmp_varbind[SNMP_VARBIND_FIELD_OID].contents, ',', 
						snmp_varbind[SNMP_VARBIND_FIELD_VALUE].contents, ',', 
						ASN1_TAG_STRINGS[array_search(snmp_varbind[SNMP_VARBIND_FIELD_VALUE].type, ASN1_TAGS)], ',', 
						snmp_message[SNMP_MESSAGE_FIELD_COMMUNITY].contents, ',', 
						data.sourceip, ',', 
						snmp_pdu[SNMP_PDU_FIELD_ENTERPRISE].contents, ',', 
						snmp_pdu[SNMP_PDU_FIELD_AGENT_ADDR].contents, ',', 
						snmp_pdu[SNMP_PDU_FIELD_GENERIC_TRAP].contents, ',', 
						snmp_pdu[SNMP_PDU_FIELD_SPECIFIC_TRAP].contents, ',', 
						snmp_pdu[SNMP_PDU_FIELD_TIME_STAMP].contents";
				}
			}
		}
		
	if (AMX_INFO <= get_log_level()) debug(AMX_INFO, "'response: ', 'message processed in ', itoa(get_timer - timer), ' 1/10th sec'");
	}
}

DEFINE_PROGRAM

(*****************************************************************)
(*                       END OF PROGRAM                          *)
(*                                                               *)
(*         !!!  DO NOT PUT ANY CODE BELOW THIS COMMENT  !!!      *)
(*                                                               *)
(*****************************************************************)
