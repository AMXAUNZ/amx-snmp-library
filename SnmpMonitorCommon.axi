PROGRAM_NAME='SnmpMonitorCommon'
(***********************************************************)
(*  FILE CREATED ON: 05/21/2016  AT: 20:18:04              *)
(***********************************************************)
(*  FILE_LAST_MODIFIED_ON: 12/12/2016  AT: 12:57:02        *)
(***********************************************************)
(*
This virtual device module must be monitored by a SNAPI
RMS monitor module including RmsNlSnapiComponents;

#DEFINE SNAPI_MONITOR_MODULE;
#INCLUDE 'RmsMonitorCommon';
#INCLUDE 'RmsNlSnapiComponents';

For the RmsMonitorCommon to register the asset in RMS, the physical device or
virtual device module must be ONLINE and channel DATA_INITIALIZED (252)
must be ON (as evaluated by the RegisterAssetWrapper() function).

DEVICE_COMMUNICATING is NOT evaluated during asset registration.

RmsNlSnapiComponents will update the "asset.online" parameter in RMS if the
SNAPI virtual device channel DEVICE_COMMUNICATING (251) changes.

For the "asset.online" parameter to show ONLINE, the physical device or
virtual device module must be ONLINE and DEVICE_COMMUNICATING (251)
must be ON (as evaluated by the GetOnlineSnapiValue() function).

For the "data.initialized" parameter to show TRUE the physical device or
virtual device module must be ONLINE and DATA_INITIALIZED (252)
must be ON (as evaluated by the GetDataInitializedSnapiValue() function).
*)
(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

integer             MAX_LEN_STR                             =   255;
integer             MAX_LEN_INTEGER                         =     5;
integer             MAX_LEN_LONG                            =    10;
integer             MAX_LEN_FQDN                            =   255;

integer             MAX_LEN_OID                             =  1407;
integer             MAX_NUM_OID_NODE                        =   128;
integer             MAX_LEN_OID_NODE                        = MAX_LEN_LONG;
integer             MAX_LEN_OCTET_STRING                    = 65535;

#IF_NOT_DEFINED MAX_NUM_VARBINDS
integer             MAX_NUM_VARBINDS                        =  25;                                  // Number of parameter varbinds to cache
#END_IF
#IF_NOT_DEFINED MAX_LEN_VARBIND_VALUE
integer             MAX_LEN_VARBIND_VALUE                   =  50;                                  // Constrained to maximum size of initialValue in RmsAssetParameter structure as defined in RmsApi
#END_IF

long                CONTACT_TIMEOUT                         = 190;                                  // Default seconds of no contact after which to consider asset to be offline (max time between traps received or SNMPGET polls)
long                POLL_INTERVAL                           =  60;                                  // Default seconds between update SNMP GET messages
long                CHANGE_POLL_DELAY                       =   3;                                  // Seconds after which to request a status update post a change.

integer             MAX_LEN_ARRAY_VALUE                     = MAX_LEN_VARBIND_VALUE;
integer             MAX_NUM_ARRAY_SIZE                      = MAX_NUM_VARBINDS;

integer             ARRAY_KEY                               =     1;
integer             ARRAY_VALUE                             =     2;

integer             SNMP_GET_CMD_PARAM_OID                  =     1;
integer             SNMP_GET_CMD_PARAM_COMMUNITY            =     2;
integer             SNMP_GET_CMD_PARAM_AGENT_ADDR           =     3;
integer             SNMP_GET_CMD_PARAM_AGENT_PORT           =     4;
integer             SNMP_GET_CMD_PARAM_REQUEST_ID           =     5;

integer             SNMP_SET_CMD_PARAM_OID                  =     1;
integer             SNMP_SET_CMD_PARAM_VALUE                =     2;
integer             SNMP_SET_CMD_PARAM_TYPE                 =     3;
integer             SNMP_SET_CMD_PARAM_COMMUNITY            =     4;
integer             SNMP_SET_CMD_PARAM_AGENT_ADDR           =     5;
integer             SNMP_SET_CMD_PARAM_AGENT_PORT           =     6;
integer             SNMP_SET_CMD_PARAM_REQUEST_ID           =     7;

integer             SNMP_RESPONSE_PARAM_OID                 =     1;
integer             SNMP_RESPONSE_PARAM_VALUE               =     2;
integer             SNMP_RESPONSE_PARAM_TYPE                =     3;
integer             SNMP_RESPONSE_PARAM_COMMUNITY           =     4;
integer             SNMP_RESPONSE_PARAM_SOURCE_ADDR         =     5;
integer             SNMP_RESPONSE_PARAM_REQUEST_ID          =     6;
integer             SNMP_RESPONSE_PARAM_ENTERPRISE          =     6;
integer             SNMP_RESPONSE_PARAM_AGENT_ADDR          =     7;
integer             SNMP_RESPONSE_PARAM_GENERIC_TRAP        =     8;
integer             SNMP_RESPONSE_PARAM_SPECIFIC_TRAP       =     9;
integer             SNMP_RESPONSE_PARAM_TIME_STAMP          =    10;

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

char                OID_sysDescr[]                          = '1.3.6.1.2.1.1.1.0';                  // .iso.org.dod.internet.mgmt.mib-2.system.sysDescr
char                OID_sysObjectID[]                       = '1.3.6.1.2.1.1.2.0';                  // .iso.org.dod.internet.mgmt.mib-2.system.sysObjectID
char                OID_sysUpTime[]                         = '1.3.6.1.2.1.1.3.0';                  // .iso.org.dod.internet.mgmt.mib-2.system.sysUpTime
char                OID_sysName[]                           = '1.3.6.1.2.1.1.5.0';                  // .iso.org.dod.internet.mgmt.mib-2.system.sysName
char                OID_enterprises[]                       = '1.3.6.1.4.1';

(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

structure _snmp_agent {
	char            address[MAX_LEN_FQDN]
	integer         port
	char            community[MAX_LEN_OCTET_STRING]
}

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile _snmp_agent snmp_agent;

volatile char       varbinds[MAX_NUM_ARRAY_SIZE][2][MAX_LEN_ARRAY_VALUE];
volatile char       requests[MAX_NUM_ARRAY_SIZE][2][MAX_LEN_ARRAY_VALUE];

volatile char       contact_last_seen[MAX_LEN_STR];
constant long       CONTACT_TIMEOUT_TL                      = 1;
volatile long       CONTACT_TIMEOUT_TIMES[]                 = {
						(CONTACT_TIMEOUT * 1000)
					}

constant long       STATUS_POLL_TL                          = 2;
volatile long       STATUS_POLL_TIMES[]                     = {
						0,
						(POLL_INTERVAL * 1000)
					}

(***********************************************************)
(*                     INCLUDES GO BELOW                   *)
(***********************************************************)

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)

define_function integer setProperty(char key[], char value[]) {
	if (AMX_DEBUG <= get_log_level()) debug("'setProperty', '(', key, ', ', value, ')'");

	switch (key) {
		case 'ASSET_NAME': MONITOR_ASSET_NAME = value;
		case 'IP_ADDRESS': snmp_agent.address = value;
		case 'PORT': snmp_agent.port = atoi(value);
		case 'COMMUNITY': snmp_agent.community = value;
		case 'CONTACT_TIMEOUT': CONTACT_TIMEOUT_TIMES[1] = atoi(value) * 1000;
		case 'POLL_INTERVAL': STATUS_POLL_TIMES[2] = atoi(value) * 1000;
		default: {
			if (AMX_ERROR <= get_log_level()) debug("'setProperty', '() ', 'error setting value for ', key");
			if (AMX_DEBUG <= get_log_level()) debug("'setProperty', '() ', 'returning false'");
			return false;
		}
	}

	send_string vdvDeviceModule, "'PROPERTY-', key, ',', value";

	if (AMX_DEBUG <= get_log_level()) debug("'setProperty', '() ', 'returning true'");
	return true;
}

define_function integer reinitialize() {
	stack_var volatile integer i;

	if (AMX_DEBUG <= get_log_level()) debug("'reinitialize', '()'");

	if (timeline_active(STATUS_POLL_TL)) timeline_kill(STATUS_POLL_TL);

	array_clear(varbinds);

	off[vdvDeviceModule, DEVICE_COMMUNICATING];
	off[vdvDeviceModule, DATA_INITIALIZED];

	if (!snmp_agent.port) snmp_agent.port = 161;
	if (!length_string(snmp_agent.community)) snmp_agent.community = 'public';

	if (!length_string(snmp_agent.address)) {
		if (AMX_INFO <= get_log_level()) debug("'reinitialize', '() ', 'SNMP host not configured, and will need to be passed as command parameters.'");
		if (AMX_DEBUG <= get_log_level()) debug("'reinitialize', '() ', 'returning false'");
		return false;
	}

	if (STATUS_POLL_TIMES[2] > 0) {
		timeline_create(STATUS_POLL_TL, STATUS_POLL_TIMES, length_array(STATUS_POLL_TIMES), TIMELINE_ABSOLUTE, TIMELINE_REPEAT);
	} else {
		if (timeline_active(STATUS_POLL_TL)) timeline_kill(STATUS_POLL_TL);
		if (AMX_DEBUG <= get_log_level()) debug("'reinitialize', '() ', 'status polling timeline is disabled'");
	}

	if (AMX_DEBUG <= get_log_level()) debug("'reinitialize', '() ', 'returning true'");
	return true;
}

#IF_NOT_DEFINED __PRIME_PLAIN_STRING
	#DEFINE __PRIME_PLAIN_STRING

define_function char[MAX_LEN_STR] plain_string(char str[MAX_LEN_STR]) {
	stack_var volatile integer i;
	stack_var volatile char ret[MAX_LEN_STR];

	for (i = 1; i <= length_string(str); i++) {
		if (
			((str[i] >= $30) && (str[i] <= $39)) || // 0-9
			((str[i] >= $41) && (str[i] <= $5A)) || // A-Z
			((str[i] >= $61) && (str[i] <= $7A))    // a-z
		) {
			ret = "ret, str[i]";
		}
	}

	return ret;
}

#END_IF

#IF_NOT_DEFINED __PRIME_EXPLODE
	#DEFINE __PRIME_EXPLODE

define_function integer explode(char str[], char delim[], char quote[], char parts[][]) {
	stack_var volatile integer i;
	stack_var volatile integer start, end, quoted;

	if (AMX_DEBUG <= get_log_level()) debug("'explode', '("', str, '", "', delim, '", "', quote, '", ', 'parts[', itoa(max_length_array(parts)), '][]', ')'");

	start = 1;
	while (start <= length_string(str)) {
		i++;

		if (length_string(quote) && (mid_string(str, start, length_string(quote)) == quote)) { // Consider quoted strings as a single parts
			quoted = true;
			start = start + length_string(quote); // Move starting position to omit quote
			end = find_string(str, quote, start); // Find next quote
		} else {
			quoted = false;
			end = find_string(str, delim, start); // Find next delimiter
		}
		if ((!end) || (i == max_length_array(parts))) { // Return remainder of string if no further delimiters or quotes are found, or the maximum number of parts have already been found
			end = length_string(str) + 1;
		}

		parts[i] = mid_string(str, start, end - start);
		if (AMX_DEBUG <= get_log_level()) debug("'explode', '() ', 'array[', itoa(i), '] ', parts[i]");

		start = end + length_string(delim); // Advance past the ending delimiter
		if (quoted) start = start + length_string(quote); // Advance past the quote
	}

	set_length_array(parts, i);

	if (AMX_DEBUG <= get_log_level()) debug("'explode', '() ', 'returning array[', itoa(i), ']'");
	return i;
}

#END_IF

#IF_NOT_DEFINED __PRIME_LTOA
	#DEFINE __PRIME_LTOA

define_function char[MAX_LEN_LONG] ltoa(long l) {
	stack_var volatile char ret[MAX_LEN_LONG];

	if (AMX_DEBUG <= get_log_level()) debug("'ltoa', '(', 'long', ')'");

	if (l < 100000) {
		ret = itoa(l);
	} else {
		ret = "itoa(l / 100000), itoa(l % 100000)"; // Keep itoa input under 16 bits
	}

	if (AMX_DEBUG <= get_log_level()) debug("'ltoa', '() ', 'returning ', ret");
	return ret;
}

#END_IF


#IF_NOT_DEFINED __PRIME_ATOL_UNSIGNED
	#DEFINE __PRIME_ATOL_UNSIGNED

define_function long atol_unsigned(char str[]) {
	stack_var volatile integer i;
	stack_var volatile long l;

	if (AMX_DEBUG <= get_log_level()) debug("'atol_unsigned', '(', 'str', ')'");

	for (i = 1; i <= length_string(str); i++) {
		stack_var volatile integer digit;

		if ((str[i] < '0') || (str[i] > '9')) {
			if (AMX_DEBUG <= get_log_level()) debug("'atol_unsigned', '() ', 'stopping at non-numerical character "', str[i], '"'");
			break;
		}

		digit = atoi("str[i]");
		l = l * 10;
		l = l + digit;
	}

	if (AMX_DEBUG <= get_log_level()) debug("'atol_unsigned', '() ', 'returning ', ltoa(l)");
	return l;
}

#END_IF

#IF_NOT_DEFINED __PRIME_ARRAY_FIND
	#DEFINE __PRIME_ARRAY_FIND

define_function integer array_find(char array[][][], char key[]) {
	stack_var volatile integer i;

	if (AMX_DEBUG <= get_log_level()) debug("'array_find', '(', 'array[]', ', ', key, ')'");

	for (i = 1; i <= length_array(array); i++) {
		if (array[i][ARRAY_KEY] == key) {
			if (AMX_DEBUG <= get_log_level()) debug("'array_find', '() ', 'key found. Returning ', itoa(i)");
			return i;
		}
	}

	if (AMX_DEBUG <= get_log_level()) debug("'array_find', '() ', 'key could not be found. Returning false.'");
	return false;
}

#END_IF

#IF_NOT_DEFINED __PRIME_ARRAY_FIND_VALUE
	#DEFINE __PRIME_ARRAY_FIND_VALUE

define_function integer array_find_value(char array[][][], char value[]) {
	stack_var volatile integer i;

	if (AMX_DEBUG <= get_log_level()) debug("'array_find_value', '(', 'array[]', ', ', value, ')'");

	for (i = 1; i <= length_array(array); i++) {
		if (array[i][ARRAY_VALUE] == value) {
			if (AMX_DEBUG <= get_log_level()) debug("'array_find_value', '() ', 'value found. Returning ', itoa(i)");
			return i;
		}
	}

	if (AMX_DEBUG <= get_log_level()) debug("'array_find_value', '() ', 'value could not be found. Returning false.'");
	return false;
}

#END_IF

#IF_NOT_DEFINED __PRIME_ARRAY_GET
	#DEFINE __PRIME_ARRAY_GET

define_function char[MAX_LEN_ARRAY_VALUE] array_get(char array[][][], char key[]) {
	stack_var volatile integer i;

	if (AMX_DEBUG <= get_log_level()) debug("'array_get', '(', 'array[]', ', ', key, ')'");

	i = array_find(array, key);
	if (i) {
		if (AMX_DEBUG <= get_log_level()) debug("'array_get', '() ', 'key found at index ', itoa(i), '. Returning ', array[i][ARRAY_VALUE]");
		return array[i][ARRAY_VALUE];
	} else {
		if (AMX_DEBUG <= get_log_level()) debug("'array_get', '() ', 'key could not be found. Returning empty string.'");
		return '';
	}
}

#END_IF

#IF_NOT_DEFINED __PRIME_ARRAY_SET
	#DEFINE __PRIME_ARRAY_SET

define_function integer array_set(char array[][][], char key[], char value[]) {
	stack_var volatile integer i;

	if (AMX_DEBUG <= get_log_level()) debug("'array_set', '(', 'array[]', ', ', key, ', ', value, ')'");

	i = array_find(array, key);
	if (!i && (length_array(array) < max_length_array(array))) { // OID does not exist
		i = length_array(array) + 1;
		set_length_array(array, i);

		array[i][ARRAY_KEY] = key;
	}

	if (!i) {
		if (AMX_DEBUG <= get_log_level()) debug("'array_set', '() ', 'varbind could not be stored because array is full. Returning false.'");
		return false;
	} else {
		if (array[i][ARRAY_VALUE] != value) {
			array[i][ARRAY_VALUE] = value;
			if (AMX_DEBUG <= get_log_level()) debug("'array_set', '() ', 'varbind at index ', itoa(i), ' updated. Returning true.'");
			return true;
		} else {
			if (AMX_DEBUG <= get_log_level()) debug("'array_set', '() ', 'varbind at index ', itoa(i), ' already up-to-date. Returning false.'");
			return false;
		}
	}
}

#END_IF

#IF_NOT_DEFINED __PRIME_ARRAY_CLEAR
	#DEFINE __PRIME_ARRAY_CLEAR

define_function integer array_clear(char array[][][]) {
	stack_var volatile integer i;

	if (AMX_DEBUG <= get_log_level()) debug("'array_clear', '(', 'array[]', ')'");

	for (i = 1; i <= length_string(array); i++) {
		array[i][ARRAY_VALUE] = '';
	}

	if (AMX_DEBUG <= get_log_level()) debug("'array_clear', '() ', 'returning'");
}

#END_IF

define_function char[MAX_LEN_LONG] snmp_get(char oid[]) {
	stack_var volatile char request_id[MAX_LEN_LONG];

	if (AMX_DEBUG <= get_log_level()) debug("'snmp_get', '(', oid, ')'");

	request_id = ltoa(random_number(get_timer));
	array_set(requests, oid, request_id);

	// send_command vdvSNMP, "'SNMPGET-<oid>[,<community>[,<host>[,<port>[,<request id>]]]]'";
	send_command vdvSNMP, "'SNMPGET', '-', oid, ',', snmp_agent.community, ',', snmp_agent.address, ',', itoa(snmp_agent.port), ',', request_id";

	if (AMX_DEBUG <= get_log_level()) debug("'snmp_get', '() ', 'returning ', itoa(request_id), '.'");
	return request_id;
}

define_function char[MAX_LEN_LONG] snmp_set(char oid[], char varbind_type[], char varbind_value[]) {
	stack_var volatile char request_id[MAX_LEN_LONG];

	if (AMX_DEBUG <= get_log_level()) debug("'snmp_set', '(', oid, ')'");

	request_id = ltoa(random_number(get_timer));
	array_set(requests, oid, request_id);

	// send_command vdvSNMP, "'SNMPSET-<oid>,<type>,<value>[,<community>[,<host>[,<port>[,<request id>]]]]'";
	send_command vdvSNMP, "'SNMPSET', '-', oid, ',', varbind_type, ',', varbind_value, ',', snmp_agent.community, ',', snmp_agent.address, ',', itoa(snmp_agent.port), ',', request_id";

	if (timeline_active(STATUS_POLL_TL)) {
		if (STATUS_POLL_TIMES[2] > CHANGE_POLL_DELAY * 1000) {
			if (AMX_DEBUG <= get_log_level()) debug("'snmp_set', '() ', 'requesting status update in ', itoa(CHANGE_POLL_DELAY), ' seconds.'");
			timeline_set(STATUS_POLL_TL, STATUS_POLL_TIMES[2] - (CHANGE_POLL_DELAY * 1000))
		}
	}

	if (AMX_DEBUG <= get_log_level()) debug("'snmp_set', '() ', 'returning ', request_id, '.'");
	return request_id;
}

define_function char[MAX_LEN_LONG] sysObjectID_to_enterprise(char oid[]) {
	stack_var volatile integer pos;
	stack_var volatile char enterprise[MAX_LEN_LONG];

	if (AMX_DEBUG <= get_log_level()) debug("'sysObjectID_to_enterprise', '(', oid, ')'");

	if (remove_string(oid, "OID_enterprises, '.'", 1)) {
		pos = find_string(oid, '.', 1);
		if (pos) {
			enterprise = left_string(oid, pos - 1);
		} else {
			enterprise = oid;
		}
	}

	if (length_string(enterprise)) {
		if (AMX_DEBUG <= get_log_level()) debug("'sysObjectID_to_enterprise', '() ', 'returning ', enterprise");
		return enterprise;
	} else {
		if (AMX_DEBUG <= get_log_level()) debug("'sysObjectID_to_enterprise', '() ', 'manufacturer not found. returning false.'");
		return '';
	}
}

define_function char[MAX_LEN_OID] sysObjectID_to_model(char oid[]) {
	stack_var volatile integer pos;
	stack_var volatile char model[MAX_LEN_OID];

	if (AMX_DEBUG <= get_log_level()) debug("'sysObjectID_to_model', '(', oid, ')'");

	if (remove_string(oid, "OID_enterprises, '.'", 1)) {
		if (AMX_DEBUG <= get_log_level()) debug("'sysObjectID_to_model', '() ', 'returning ', oid");
		return oid;
	} else {
		if (AMX_DEBUG <= get_log_level()) debug("'sysObjectID_to_model', '() ', 'model not found. returning false'");
		return '';
	}
}

define_function char[MAX_LEN_STR] timeticks_to_time(long timeticks) {
	stack_var volatile long days, hours, minutes, seconds;
	stack_var volatile char ret[MAX_LEN_STR];

	if (AMX_DEBUG <= get_log_level()) debug("'timeticks_to_time', '(', ltoa(timeticks), ')'");

	days = timeticks / 8640000; // 100 * 60 * 60 * 24
	timeticks = timeticks - (days * 8640000);

	hours = timeticks / 360000; // 100 * 60 * 60
	timeticks = timeticks - (hours * 360000);

	minutes = timeticks / 6000; // 100 * 60
	timeticks = timeticks - (minutes * 6000);

	seconds = timeticks / 100;

	if (days) ret = "itoa(days), ' days '";
	if (hours || length_string(ret)) ret = "ret, format('%d', hours), ':'";
	if (minutes || length_string(ret)) ret = "ret, format('%02d', minutes), ':'";
	if (seconds || length_string(ret)) ret = "ret, format('%02d', seconds)";

	if (AMX_DEBUG <= get_log_level()) debug("'timeticks_to_time', '() ', 'returning ', ret");
	return ret;
}

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT

data_event[vdvDeviceModule] {
	command: {
		stack_var volatile char cmd[MAX_LEN_STR];

		if (AMX_DEBUG <= get_log_level()) debug("'data_event command: ', data.text, ' (', itoa(length_string(data.text)), ' bytes)'");

		cmd = remove_string(data.text, '-', 1);
		if (cmd) {
			cmd = left_string(cmd, length_string(cmd) - 1);
		} else {
			cmd = data.text;
		}

		cmd = upper_string(cmd);
		switch (cmd) {
			case 'DEBUG': {
				set_log_level(atoi(data.text));
				send_string vdvDeviceModule, "'DEBUG-', data.text";
			}
			case 'PROPERTY': {
				stack_var char parts[2][MAX_LEN_STR];

				if (!explode(data.text, ',', '"', parts)) {
					if (AMX_ERROR <= get_log_level()) debug("'data_event command property: ', 'Could not parse parameters!'");
				} else {
					setProperty(parts[1], parts[2]);
				}
			}
			case 'REINIT': {
				if (AMX_INFO <= get_log_level()) debug("'data_event command reinit: re-initializing...'");
				reinitialize();
			}
		}
	}
}

data_event[vdvSNMP] {
	online: {
		/*
		ONLINE != DEVICE_COMMUNICATING. The connection to the device may be
		connectionless (UDP), or the device may be in a fault state and
		unresponsive.
		*/

		reinitialize();
	}
	offline: {
		/*
		OFFLINE != DEVICE_COMMUNICATING. The socket to the device may
		automatically close when a request completes or is idle for some time.
		*/
	}
	onerror: {
		/*
		DEVICE_COMMUNICATING status will be automatically updated by the
		CONTACT_TIMEOUT_TL timeline, the delay of which will cater for
		occasional poor network connectivity or packet loss.
		*/
	}
	string: {
		stack_var volatile char cmd[MAX_LEN_STR];

		cmd = remove_string(data.text, '-', 1);
		if (cmd) {
			cmd = left_string(cmd, length_string(cmd) - 1);
		} else {
			cmd = data.text;
		}

		cmd = upper_string(cmd);
		if ((cmd == 'OID') || (cmd == 'TRAP')) {
			stack_var char parts[10][MAX_LEN_STR];

			if (!explode(data.text, ',', '"', parts)) {
				debug("'data_event string ', cmd, ': ', 'could not parse parameters!'");
			} else {
				if (
					(
					 (cmd == 'OID') &&
					 (parts[SNMP_RESPONSE_PARAM_SOURCE_ADDR] == snmp_agent.address) &&
					 (parts[SNMP_RESPONSE_PARAM_COMMUNITY] == snmp_agent.community) &&
					 (parts[SNMP_RESPONSE_PARAM_REQUEST_ID] == array_get(requests, parts[SNMP_RESPONSE_PARAM_OID]))
					) || (
					 (cmd == 'TRAP') &&
					 (parts[SNMP_RESPONSE_PARAM_AGENT_ADDR] == snmp_agent.address) &&
					 (parts[SNMP_RESPONSE_PARAM_COMMUNITY] == snmp_agent.community)
					)
				) { // Ensure the agent response is destined for this monitor module
					if (AMX_DEBUG <= get_log_level()) debug("'data_event string ', cmd, ': processing varbind'");

					contact_last_seen = "date, ' ', time";

					// Device has become contactable
					if (![vdvDeviceModule, DEVICE_COMMUNICATING]) {
						on[vdvDeviceModule, DEVICE_COMMUNICATING];
					}

					// Attmept to retrieve device information when the devices becomes contactable.
					// Here instead of in DEVICE_COMMUNICATING channel event to ensure polling continues until the information received (otherwise would only be requested once)
					if (![vdvDeviceModule, DATA_INITIALIZED]) {
						if (parts[SNMP_RESPONSE_PARAM_OID] == OID_sysUpTime) { // Only poll the device following a response to OID_sysUpTime queried at a regular interval
							snmp_get(OID_sysDescr);
							snmp_get(OID_sysObjectID);
							snmp_get(OID_sysName);

							#IF_DEFINED INCLUDE_DEVICE_INFO_POLL_CALLBACK
							device_info_poll_callback();
							#END_IF
						}
					}

					if (!timeline_active(CONTACT_TIMEOUT_TL)) {
						timeline_create(CONTACT_TIMEOUT_TL, CONTACT_TIMEOUT_TIMES, length_array(CONTACT_TIMEOUT_TIMES), TIMELINE_ABSOLUTE, TIMELINE_ONCE);
					} else {
						timeline_set(CONTACT_TIMEOUT_TL, 0); // Re-start expiration of last contact
					}

					if (array_set(varbinds, parts[SNMP_RESPONSE_PARAM_OID], parts[SNMP_RESPONSE_PARAM_VALUE])) { // Avoid processing updates for unchanged values
						if (AMX_DEBUG <= get_log_level()) debug("'data_event string ', cmd, ': ', parts[SNMP_RESPONSE_PARAM_OID], ' updated'");

						#IF_DEFINED INCLUDE_VARBIND_UPDATED_CALLBACK
							varbind_updated_callback(parts[SNMP_RESPONSE_PARAM_OID], parts[SNMP_RESPONSE_PARAM_VALUE]);
						#END_IF
					}
				}
			}
		}
	}
}

timeline_event[STATUS_POLL_TL] {
	switch (timeline.sequence) {
		case 1: {
			snmp_get(OID_sysUpTime);

			#IF_DEFINED INCLUDE_DEVICE_STATUS_POLL_CALLBACK
			if ([vdvDeviceModule, DATA_INITIALIZED]) {
				device_status_poll_callback();
			}
			#END_IF
		}
		case 2: {
			// Wait...
		}
	}
}

timeline_event[CONTACT_TIMEOUT_TL] {
	stack_var volatile integer i;

	/*
	Set DEVICE_COMMUNICATING OFF to trigger an "asset.online" update via
	RmsNlSnapiComponents.
	*/
	off[vdvDeviceModule, DEVICE_COMMUNICATING];

	/*
	Set DATA_INITIALIZED OFF to prevent the RMS monitor module from
	re-registering the asset until all data has been received from the device
	after a connection is re-established.

	This is required to ensure the a new asset is registered when a device
	is replaced. Asset registration is triggered from RmsMonitorCommon when
	DATA_INITIALIZED is set ON.
	*/
	off[vdvDeviceModule, DATA_INITIALIZED];
}

channel_event[vdvDeviceModule, DATA_INITIALIZED] {
	off: {
		// Clear varbind values when the device can no longer be contacted (and may be replaced)
		array_clear(varbinds);
	}
}
