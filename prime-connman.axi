PROGRAM_NAME='prime-connman'

#IF_NOT_DEFINED __PRIME_CONNMAN
    #DEFINE __PRIME_CONNMAN

(***********************************************************)
(*  FILE CREATED ON: 01/23/2016  AT: 21:43:16              *)
(***********************************************************)
(***********************************************************)
(***********************************************************)
(*  FILE_LAST_MODIFIED_ON: 04/15/2016  AT: 23:04:22        *)
(***********************************************************)
(*  FILE REVISION: Rev 2                                   *)
(*  REVISION DATE: 04/15/2016  AT: 23:04:19                *)
(*                                                         *)
(*  COMMENTS:                                              *)
(*  Added handling of unexpected open socket for           *)
(*  data_event onerror                                     *)
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

    prime-connman
    NetLinx IP Client Socket Connection Manager
    
    Author: niek.groot@amxaustralia.com.au
    No rights or warranties implied.
    
    
    Usage:

    #DEFINE CONNMAN_SET_MAX_NUM_BUFFER_OUT   10					// Maximum number of items that can be stored in the outbound buffer. Default: 10.
    #DEFINE CONNMAN_SET_MAX_LEN_BUFFER_OUT 1500					// Maximum size of an item in the outbound buffer. Default: 2048.
    #DEFINE CONNMAN_SET_MAX_LEN_BUFFER_IN  1500					// Maximum size of the inbound buffer. Default: 2048.
    #INCLUDE 'prime-connman'							// Use connman_setProperty() for IP client and preferences configuration

    connman_send_string("'<str[CONNMAN_MAX_LEN_BUFFER_OUT]>'");			// Send string to the configured server address.
    connman_connect();								// Connect to the target server.
    connman_disconnect();							// Disconnect from the target server.
    connman_buffer_clear();							// Clear the outbound buffer contents.


    Response:
    
    Strings received from the server are buffered in the 
    connman_buffer_in[CONNMAN_MAX_LEN_BUFFER_IN] variable.

    
    Configuration:
    
    connman_setProperty("'IP_ADDRESS', '<address>'");				// Server address.
    connman_setProperty("'PORT', itoa(<port>)");				// Server port.
    connman_setProperty("'PROTOCOL', itoa(<IP_TCP|IP_UDP|IP_UDP_2WAY>)");	// Transport protocol using NetLinx transport protocol constants.
    connman_setProperty("'CONNECT_DELAY', itoa(<msec>)");			// Delay between connection attempts. Default: 5000ms.
    connman_setProperty("'SEND_DELAY', itoa(<msec>)");				// Delay between concurrent strings sent from the outbound butter. Default: 0msec.
    connman_setProperty("'AUTO_RETRANSMIT', itoa(<num>)");			// Re-transmit strings sent from the buffer <num> times at the SEND_DELAY interval until a response is received. Default: 0 (transmit once).
    connman_setProperty("'ADVANCE_ON_RESPONSE', booltostring(<true|false>)");	// Advance the outbound buffer when a respons is received. Default: false.
    connman_setProperty("'AUTO_DISCONNECT', booltostring(<true|false>)");	// Automatically disconnect when all strings in the buffer have been sent. Default: false.
    connman_setProperty("'AUTO_RECONNECT', booltostring(<true|false>)");	// Automatically re-connect if the connection drops. Also connects on reinitialize() without buffer contents. Default: false.
    connman_reinitialize()
*)

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

integer			CONNMAN_MAX_LEN_FQDN			=   255;

// #DEFINE use as re-assignment below to avoid compiler bug preventing /re-use/ of #DEFINE values in DEFINE_TYPE
#IF_DEFINED CONNMAN_SET_MAX_NUM_BUFFER_OUT
    integer 		CONNMAN_MAX_NUM_BUFFER_OUT 		= CONNMAN_SET_MAX_NUM_BUFFER_OUT;
#ELSE
    integer 		CONNMAN_MAX_NUM_BUFFER_OUT 		=    10;
#END_IF

#IF_DEFINED CONNMAN_SET_MAX_LEN_BUFFER_OUT
    integer 		CONNMAN_MAX_LEN_BUFFER_OUT 		= CONNMAN_SET_MAX_LEN_BUFFER_OUT;
#ELSE
    integer 		CONNMAN_MAX_LEN_BUFFER_OUT 		=  2048;
#END_IF

#IF_DEFINED CONNMAN_SET_MAX_LEN_BUFFER_IN
    integer 		CONNMAN_MAX_LEN_BUFFER_IN 		= CONNMAN_SET_MAX_LEN_BUFFER_IN;
#ELSE
    integer 		CONNMAN_MAX_LEN_BUFFER_IN 		=  2048;
#END_IF

long			CONNMAN_BUFFPROC_TL			=  1101;
long 			CONNMAN_CONNECT_TL			=  1102;

integer 		CONNMAN_STATUS_DISCONNECTED		=     0;
integer 		CONNMAN_STATUS_CONNECTING		=     1;
integer 		CONNMAN_STATUS_CONNECTED		=     2;
integer 		CONNMAN_STATUS_DISCONNECTING		=     3;

#IF_NOT_DEFINED __IP_PROTOCOL_STRINGS
    #DEFINE __IP_PROTOCOL_STRINGS
    char		IP_PROTOCOL_STRINGS[3][8] = {
			    'TCP',
			    'UDP',
			    'UDP_2WAY'
			}
#END_IF

(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

structure _connman_host {
    integer 		protocol;
    char 		address[CONNMAN_MAX_LEN_FQDN];
    integer 		port;
}

structure _connman_buffer {
    char 		str[CONNMAN_MAX_LEN_BUFFER_OUT];
    _connman_host	host;
}


(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile _connman_host		connman_host;
volatile integer 		connman_auto_reconnect		= false;
volatile integer 		connman_auto_disconnect		= false;
volatile integer 		connman_advance_on_response	= false;
volatile integer 		connman_max_transmit_count	= 1;

volatile char 			connman_buffer_in[CONNMAN_MAX_LEN_BUFFER_IN];

volatile _connman_buffer 	connman_buffer_out[CONNMAN_MAX_NUM_BUFFER_OUT];
volatile integer 		connman_buffer_out_pos_in	= 1;
volatile integer 		connman_buffer_out_pos_out	= 1;
volatile long			connman_buffproc_times[]	= { 0, 0, 0 }
volatile integer 		connman_transmit_count		= 0;

volatile long			connman_connect_times[] 	= { 0, 5000 }
volatile integer 		connman_connect_status		= CONNMAN_STATUS_DISCONNECTED;

(***********************************************************)
(*                     INCLUDES GO BELOW                   *)
(***********************************************************)

#INCLUDE 'prime-debug';

(***********************************************************)
(*    LIBRARY SUBROUTINE/FUNCTIONS DEFINITIONS GO BELOW    *)
(***********************************************************)

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

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)

define_function integer connman_setProperty(char key[], char value[]) {
    if (AMX_DEBUG <= get_log_level()) debug("'connman_setProperty', '(', key, ', ', value, ')'");
    
    switch (key) {
	case 'IP_ADDRESS': {
	    connman_host.address = value;
	}
	case 'PORT': {
	    stack_var volatile integer i;
	    
	    i = atoi(value);
	    
	    if ((i < 1) || (i > 65535)) {
		if (AMX_ERROR <= get_log_level()) debug("'connman_setProperty', '() ', 'invalid port specified!'");
		if (AMX_DEBUG <= get_log_level()) debug("'connman_setProperty', '() ', 'returning false'");
		return false;
	    } else {
		connman_host.port = i;
	    }
	}
	case 'PROTOCOL': {
	    stack_var volatile integer i;
	    
	    i = atoi(value);
	    
	    if ((i < IP_TCP ) || (i > IP_UDP_2WAY)) {
		if (AMX_ERROR <= get_log_level()) debug("'connman_setProperty', '() ', 'invalid protocol specified!'");
		if (AMX_DEBUG <= get_log_level()) debug("'connman_setProperty', '() ', 'returning false'");
		return false;
	    } else {
		connman_host.protocol = atoi(value);
	    }
	}
	case 'CONNECT_DELAY': {
	    connman_connect_times[2] = atoi(value);
	}
	case 'SEND_DELAY': {
	    connman_buffproc_times[3] = atoi(value);
	}
	case 'ADVANCE_ON_RESPONSE': {
	    connman_advance_on_response = stringtobool(value);
	}
	case 'AUTO_DISCONNECT': {
	    connman_auto_disconnect = stringtobool(value);
	}
	case 'AUTO_RECONNECT': {
	    connman_auto_reconnect = stringtobool(value);
	}
	case 'AUTO_RETRANSMIT': {
	    connman_max_transmit_count = 1 + atoi(value);
	}
	default: {
	    return false;
	}
    }
    
    if (AMX_DEBUG <= get_log_level()) debug("'connman_setProperty', '() ', 'returning true'");
    return true;
}

define_function connman_reinitialize() {
    if (AMX_DEBUG <= get_log_level()) debug("'connman_reinitialize', '()'");
    
    connman_buffer_clear();
    if (connman_connect_status == CONNMAN_STATUS_DISCONNECTED) {
	if (connman_auto_reconnect) connman_connect();
    } else {
	connman_disconnect(); // connman_connect() will be called automatically by offline event if connman_auto_reconnect is true
    }
    
}

define_function connman_connect() {
    if (AMX_DEBUG <= get_log_level()) debug("'connman_connect', '()'");
    
    switch (connman_connect_status) {
	case CONNMAN_STATUS_CONNECTING: {
	    if (AMX_INFO <= get_log_level()) debug("'connman_connect', '() ', 'already connecting'");
	}
	case CONNMAN_STATUS_CONNECTED: {
	    if (AMX_INFO <= get_log_level()) debug("'connman_connect', '() ', 'already connected'");
	}
	case CONNMAN_STATUS_DISCONNECTING: {
	    if (AMX_INFO <= get_log_level()) debug("'connman_connect', '() ', 'disconnection in progress'");
	}
	case CONNMAN_STATUS_DISCONNECTED: {
	    connman_connect_status = CONNMAN_STATUS_CONNECTING;
	    if (AMX_INFO <= get_log_level()) debug("'connman_connect', '() ', 'starting connection'");
	    
	    if (!timeline_active(CONNMAN_CONNECT_TL)) {
		timeline_create(CONNMAN_CONNECT_TL, connman_connect_times, length_array(connman_connect_times), TIMELINE_RELATIVE, TIMELINE_ONCE);
		timeline_set(CONNMAN_CONNECT_TL, connman_connect_times[2]);
	    }
	}
	default: {
	    if (AMX_ERROR <= get_log_level()) debug("'connman_connect', '() ', 'unexpected connection status!'");
	}
    }
}

define_function connman_disconnect() {
    if (AMX_DEBUG <= get_log_level()) debug("'connman_disconnect', '()'");
    
    switch (connman_connect_status) {
	case CONNMAN_STATUS_CONNECTING: {
	    if (timeline_active(CONNMAN_CONNECT_TL)) {
		if (AMX_INFO <= get_log_level()) debug("'connman_disconnect', '() ', 'cancelling connection attempt'");
		
		connman_connect_status = CONNMAN_STATUS_DISCONNECTED;
		timeline_kill(CONNMAN_CONNECT_TL);
	    }
	}
	case CONNMAN_STATUS_CONNECTED: {
	    if (AMX_INFO <= get_log_level()) debug("'connman_disconnect', '() ', 'closing socket...'");
	    
	    connman_connect_status = CONNMAN_STATUS_DISCONNECTING;
	    ip_client_close(connman_device.port);
	}
	case CONNMAN_STATUS_DISCONNECTING: {
	    if (AMX_INFO <= get_log_level()) debug("'connman_disconnect', '() ', 'already disconnecting'");
	}
	case CONNMAN_STATUS_DISCONNECTED: {
	    if (AMX_INFO <= get_log_level()) debug("'connman_disconnect', '() ', 'already disconnected'");
	}
	default: {
	    if (AMX_ERROR <= get_log_level()) debug("'connman_disconnect', '() ', 'unexpected connection status!'");
	}
    }
}

define_function integer connman_buffer_add(char str[]) {
    if (AMX_DEBUG <= get_log_level()) debug("'connman_buffer_add', '(', str, ')'");
    
    return connman_buffer_add_ex(connman_host, str);
}

define_function integer connman_buffer_add_ex(_connman_host host, char str[]) {
    if (AMX_DEBUG <= get_log_level()) debug("'connman_buffer_add_ex', '(', '_connman_host host', ', ', str, ')'");
    
    if (length_string(connman_buffer_out[connman_buffer_out_pos_in].str)) {
	if (AMX_ERROR <= get_log_level()) debug("'connman_buffer_add_ex() ', 'buffer full! (', itoa(max_length_array(connman_buffer_out)), ' max strings)'");
	if (AMX_ERROR <= get_log_level()) debug("'connman_buffer_add_ex() ', 'returning false'");
	return false;
    }
    
    connman_buffer_out[connman_buffer_out_pos_in].str = str;
    connman_buffer_out[connman_buffer_out_pos_in].host = host;
    
    if (AMX_DEBUG <= get_log_level()) debug("'connman_buffer_add_ex() ', 'string added to buffer position ', itoa(connman_buffer_out_pos_in)");
    
    connman_buffer_out_pos_in++;
    if (connman_buffer_out_pos_in > max_length_array(connman_buffer_out)) connman_buffer_out_pos_in = 1;
    
    if (AMX_DEBUG <= get_log_level()) debug("'connman_buffer_add_ex() ', 'returning true'");
    return true;
}

define_function integer connman_buffer_process() {
    if (AMX_DEBUG <= get_log_level()) debug("'connman_buffer_process', '()'");
    
    if (!length_string(connman_buffer_out[connman_buffer_out_pos_out].str)) {
	if (AMX_DEBUG <= get_log_level()) debug("'connman_buffer_process', '() ', 'buffer is empty'");
    }
    
    if (connman_connect_status != CONNMAN_STATUS_CONNECTED) {
	connman_connect();
    } else 
    if (!timeline_active(CONNMAN_BUFFPROC_TL)) {
	timeline_create(CONNMAN_BUFFPROC_TL, connman_buffproc_times, length_array(connman_buffproc_times), TIMELINE_RELATIVE, TIMELINE_REPEAT);
    } else {
	// Buffer already processing
    }
}

define_function connman_buffer_advance() {
    if (AMX_DEBUG <= get_log_level()) debug("'connman_buffer_advance', '()'");
    
    connman_buffer_out[connman_buffer_out_pos_out].str = '';
    if (connman_buffer_out_pos_out < max_length_array(connman_buffer_out)) {
	connman_buffer_out_pos_out++;
    } else {
	connman_buffer_out_pos_out = 1;
    }
    
    connman_transmit_count = 0;
    
    if (AMX_DEBUG <= get_log_level()) debug("'connman_buffer_advance', '() ', 'advanced buffer to position ', itoa(connman_buffer_out_pos_out)");
    
    if (timeline_active(CONNMAN_BUFFPROC_TL)) timeline_set(CONNMAN_BUFFPROC_TL, 0);
}

define_function connman_buffer_clear() {
    stack_var volatile integer i;
    
    if (AMX_DEBUG <= get_log_level()) debug("'connman_buffer_clear', '()'");
    
    if (timeline_active(CONNMAN_BUFFPROC_TL)) timeline_kill(CONNMAN_BUFFPROC_TL);
    for (i = 1; i <= length_array(connman_buffer_out); i++) connman_buffer_out[i].str = '';
    
    connman_buffer_out_pos_in = 1;
    connman_buffer_out_pos_out = 1;
    
    if (AMX_DEBUG <= get_log_level()) debug("'connman_buffer_clear() ', 'buffer contents cleared.'");
    
    if (connman_auto_disconnect) connman_disconnect();
}

(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START

create_buffer connman_device, connman_buffer_in;

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT

data_event[connman_device] {
    online: {
	if (timeline_active(CONNMAN_CONNECT_TL)) timeline_kill(CONNMAN_CONNECT_TL);
	
        connman_connect_status = CONNMAN_STATUS_CONNECTED;
	if (AMX_INFO <= get_log_level()) debug("'connected to ', connman_host.address, ' on port ', itoa(connman_host.port), ' ', IP_PROTOCOL_STRINGS[connman_host.protocol]");
	
	if (length_string(connman_buffer_out[connman_buffer_out_pos_out].str)) connman_buffer_process();
    }
    offline: {
	if (timeline_active(CONNMAN_BUFFPROC_TL)) timeline_kill(CONNMAN_BUFFPROC_TL);
	
        connman_connect_status = CONNMAN_STATUS_DISCONNECTED;
	if (AMX_INFO <= get_log_level()) debug("'disconnected from ', connman_host.address, ' on port ', itoa(connman_host.port), ' ', IP_PROTOCOL_STRINGS[connman_host.protocol]");
	
	if (
	    (connman_auto_reconnect) || 
	    (length_string(connman_buffer_out[connman_buffer_out_pos_out].str))
	) {
	    connman_connect();
	}
    }
    onerror: {
	if (AMX_ERROR <= get_log_level()) debug("'could not connect to ', connman_host.address, ' on port ', itoa(connman_host.port), ' ', IP_PROTOCOL_STRINGS[connman_host.protocol], ' (Error ', itoa(data.number), ' ', ip_error_desc(type_cast(data.number)), ')'");
	
	if (data.number == 14) {
	    if (AMX_ERROR <= get_log_level()) debug("'closing unexpected open socket'");
	    ip_client_close(data.device.port); // Unexpected open socket
	}
	
	if (connman_connect_status == CONNMAN_STATUS_CONNECTING) {
	    if (!timeline_active(CONNMAN_CONNECT_TL)) {
		timeline_create(CONNMAN_CONNECT_TL, connman_connect_times, length_array(connman_connect_times), TIMELINE_RELATIVE, TIMELINE_ONCE);
	    }
	} else {
	    connman_connect_status = CONNMAN_STATUS_DISCONNECTED;
	}
    }
    string: {
	if (AMX_DEBUG <= get_log_level()) debug("'string received from ', data.sourceip, ' on port ', itoa(connman_host.port), ' ', IP_PROTOCOL_STRINGS[connman_host.protocol], ' (', itoa(length_string(data.text)), ' bytes): ', data.text");
	
	if (connman_advance_on_response) connman_buffer_advance();
    }
}

timeline_event[CONNMAN_CONNECT_TL] {
    switch(timeline.sequence) {
	case 1: {
	    connman_connect_status = CONNMAN_STATUS_CONNECTING;
	    if (AMX_DEBUG <= get_log_level()) debug("'CONNMAN_CONNECT_TL', '(', itoa(timeline.repetition), ', ', itoa(timeline.sequence), ') ', 'connecting in ', ftoa(connman_connect_times[2] / 1000), ' seconds...'");
	}
	case 2: {
	    if (connman_connect_status != CONNMAN_STATUS_CONNECTED) {
		if (length_string(connman_buffer_out[connman_buffer_out_pos_out].str)) {
		    connman_setProperty('IP_ADDRESS', connman_buffer_out[connman_buffer_out_pos_out].host.address);
		    connman_setProperty('PORT', itoa(connman_buffer_out[connman_buffer_out_pos_out].host.port));
		    connman_setProperty('PROTOCOL', itoa(connman_buffer_out[connman_buffer_out_pos_out].host.protocol));
		}
		
		if (AMX_DEBUG <= get_log_level()) debug("'CONNMAN_CONNECT_TL', '(', itoa(timeline.repetition), ', ', itoa(timeline.sequence), ') ', 'connecting to ', connman_host.address, ' on port ', itoa(connman_host.port), ' ', IP_PROTOCOL_STRINGS[connman_host.protocol]");
		ip_client_open(connman_device.port, connman_host.address, connman_host.port, connman_host.protocol);
	    }
	}
    }
}

timeline_event[CONNMAN_BUFFPROC_TL] {
    switch(timeline.sequence) {
	case 1: {
	    if (CONNMAN_CONNECT_STATUS != CONNMAN_STATUS_CONNECTED) { // Not connected
		if (timeline_active(timeline.id)) timeline_kill(timeline.id);
		break;
	    } else 
	    if (length_string(connman_buffer_out[connman_buffer_out_pos_out].str)) { // Check if there are contents in the buffer
		if (connman_transmit_count >= connman_max_transmit_count) {
		    if (AMX_WARNING <= get_log_level()) debug("'CONNMAN_BUFFPROC_TL', '(', itoa(timeline.repetition), ', ', itoa(timeline.sequence), ') ', 'request timed out. no response received after ', itoa(connman_transmit_count), ' attempts. Advancing buffer.'");
		    
		    #IF_DEFINED USE_CONNMAN_TIMEOUT_CALLBACK
		    connman_timeout_callback(connman_buffer_out[connman_buffer_out_pos_out].host, connman_buffer_out[connman_buffer_out_pos_out].str);
		    #END_IF
		    
		    connman_buffer_advance();
		    break;
		}
		
		if (
		    (connman_host.address != connman_buffer_out[connman_buffer_out_pos_out].host.address) || 
		    (connman_host.port != connman_buffer_out[connman_buffer_out_pos_out].host.port) || 
		    (connman_host.protocol != connman_buffer_out[connman_buffer_out_pos_out].host.protocol)
		) {
		    if (AMX_INFO <= get_log_level()) debug("'CONNMAN_BUFFPROC_TL', '(', itoa(timeline.repetition), ', ', itoa(timeline.sequence), ') ', 'reconfiguring connection to ', connman_buffer_out[connman_buffer_out_pos_out].host.address, ':', itoa(connman_buffer_out[connman_buffer_out_pos_out].host.port), ' ', IP_PROTOCOL_STRINGS[connman_buffer_out[connman_buffer_out_pos_out].host.protocol]");
		    connman_host = connman_buffer_out[connman_buffer_out_pos_out].host
		    connman_disconnect();
		    break;
		}
		
		if (connman_transmit_count) {
		    if (AMX_WARNING <= get_log_level()) debug("'CONNMAN_BUFFPROC_TL', '(', itoa(timeline.repetition), ', ', itoa(timeline.sequence), ') ', 'request timed out. re-sending string from buffer position ', itoa(connman_buffer_out_pos_out), ' (attempt ', itoa(connman_transmit_count + 1), ')'");
		} else {
		    if (AMX_DEBUG <= get_log_level()) debug("'CONNMAN_BUFFPROC_TL', '(', itoa(timeline.repetition), ', ', itoa(timeline.sequence), ') ', 'sending string from buffer position ', itoa(connman_buffer_out_pos_out), ' (attempt ', itoa(connman_transmit_count + 1), ')'");
		}
		
		send_string connman_device, connman_buffer_out[connman_buffer_out_pos_out].str;
		connman_transmit_count++;
	    } else { // Buffer is empty
		if (timeline_active(timeline.id)) { // Incase the timeline_event runs again whilst it is being terminated (http://www.amx.com/techsupport/technote.asp?id=1040)
		    timeline_kill(timeline.id);
		    
		    if (AMX_DEBUG <= get_log_level()) debug("'CONNMAN_BUFFPROC_TL', '(', itoa(timeline.repetition), ', ', itoa(timeline.sequence), ') ', 'stopping buffer processing because buffer is empty'");
		    
		    connman_buffer_out_pos_in = 1;
		    connman_buffer_out_pos_out = 1;
		    
		    if (connman_auto_disconnect) connman_disconnect();
		}
	    }
	}
	case 2: {
	    if (timeline_active(timeline.id)) { // Incase the timeline_event runs again whilst it is being terminated (http://www.amx.com/techsupport/technote.asp?id=1040)
		if (AMX_DEBUG <= get_log_level()) debug("'CONNMAN_BUFFPROC_TL', '(', itoa(timeline.repetition), ', ', itoa(timeline.sequence), ') ', 'waiting...'");
	    }
	}
    }
}

#END_IF
