#IF_NOT_DEFINED __PRIME_CONNMAN
    #DEFINE __PRIME_CONNMAN

(***********************************************************)
(*  FILE CREATED ON: 01/23/2016  AT: 21:43:16              *)
(***********************************************************)
(*  FILE_LAST_MODIFIED_ON: 09/17/2016  AT: 22:36:05        *)
(***********************************************************)
(*  FILE REVISION: Rev 7                                   *)
(*  REVISION DATE: 07/19/2016  AT: 07:25:31                *)
(*                                                         *)
(*  COMMENTS:                                              *)
(*  Normalised CONNECT and SEND property configuration     *)
(*                                                         *)
(***********************************************************)
(*  FILE REVISION: Rev 6                                   *)
(*  REVISION DATE: 06/26/2016  AT: 20:41:06                *)
(*                                                         *)
(*  COMMENTS:                                              *)
(*  Full review and optimisation                           *)
(*                                                         *)
(***********************************************************)
(*  FILE REVISION: Rev 5                                   *)
(*  REVISION DATE: 05/12/2016  AT: 11:21:59                *)
(*                                                         *)
(*  COMMENTS:                                              *)
(*  Corrected debug messages, indentation.                 *)
(*  TODO: Optimise connection request calls - simplify     *)
(*  waits and remove recurring calls to connman_connect(). *)
(*                                                         *)
(***********************************************************)
(*  FILE REVISION: Rev 4                                   *)
(*  REVISION DATE: 05/06/2016  AT: 10:26:11                *)
(*                                                         *)
(*  COMMENTS:                                              *)
(*  Added connman_stat_online/offline/error count tracking *)
(*                                                         *)
(***********************************************************)
(*  FILE REVISION: Rev 3                                   *)
(*  REVISION DATE: 04/21/2016  AT: 14:02:00                *)
(*                                                         *)
(*  COMMENTS:                                              *)
(*  Added CONNECT_ATTEMPTS config parameter         *)
(*  Improved connect/disconnect and buffer management      *)
(*  handling for improved long-term stability.             *)
(*                                                         *)
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

    #DEFINE CONNMAN_SET_MAX_NUM_BUFFER_OUT   10                                 // Maximum number of items that can be stored in the outbound buffer. Default: 10.
    #DEFINE CONNMAN_SET_MAX_LEN_BUFFER_OUT 1500                                 // Maximum size of an item in the outbound buffer. Default: 2048.
    #DEFINE CONNMAN_SET_MAX_LEN_BUFFER_IN  1500                                 // Maximum size of the inbound buffer. Default: 2048.
    #INCLUDE 'prime-connman'                                                    // Use connman_setProperty() for IP client and preferences configuration.

    connman_send_string("'<str[CONNMAN_MAX_LEN_BUFFER_OUT]>'");                 // Send string to the configured server address.
    connman_connect();                                                          // Connect to the target server.
    connman_disconnect();                                                       // Disconnect from the target server.
    connman_buffer_clear();                                                     // Clear the outbound buffer contents.
    connman_advance_buffer();                                                   // Discard the current item and send the next item in the buffer.


    Response:

    Strings received from the server are buffered in the connman_buffer_in[CONNMAN_MAX_LEN_BUFFER_IN] variable.


    Configuration:

    connman_setProperty("'IP_ADDRESS', '<address>'");                           // Server address.
    connman_setProperty("'PORT', itoa(<port>)");                                // Server port.
    connman_setProperty("'PROTOCOL', itoa(<IP_TCP|IP_UDP|IP_UDP_2WAY>)");       // Transport protocol using NetLinx transport protocol constants.

    connman_setProperty("'CONNECT_ATTEMPTS', itoa(<num>)");                     // Maximum number of connection attempts. Default: 3.
    connman_setProperty("'CONNECT_DELAY', itoa(<msec>)");                       // Delay between connection attempts. Default: 1000ms.
    connman_setProperty("'AUTO_DISCONNECT', booltostring(<true|false>)");       // Automatically disconnect when all strings in the buffer have been sent. Default: false.
    connman_setProperty("'AUTO_RECONNECT', booltostring(<true|false>)");        // Automatically re-connect if the connection drops. Also connects on reinitialize() without buffer contents. Default: false.

	connman_setProperty("'SEND_ATTEMPTS', itoa(<num>)");                        // Send strings sent from the outbound buffer <num> times at the SEND_DELAY interval until a response is received. Default: 1.
    connman_setProperty("'SEND_DELAY', itoa(<msec>)");                          // Delay between concurrent strings sent from the outbound butter. Default: 0msec.
    connman_setProperty("'ADVANCE_ON_RESPONSE', booltostring(<true|false>)");   // Advance the outbound buffer when a respons is received. Default: false.

    connman_reinitialize()
*)

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

#IF_NOT_DEFINED MAX_LEN_LONG
integer             MAX_LEN_LONG                            =    10;            // 4294967295
#END_IF

integer             CONNMAN_MAX_LEN_FQDN                    =   255;

// #DEFINE use as re-assignment below to avoid compiler bug preventing /re-use/ of #DEFINE values in DEFINE_TYPE
#IF_DEFINED CONNMAN_SET_MAX_NUM_BUFFER_OUT
integer             CONNMAN_MAX_NUM_BUFFER_OUT              = CONNMAN_SET_MAX_NUM_BUFFER_OUT;
#ELSE
integer             CONNMAN_MAX_NUM_BUFFER_OUT              =    10;
#END_IF

#IF_DEFINED CONNMAN_SET_MAX_LEN_BUFFER_OUT
integer             CONNMAN_MAX_LEN_BUFFER_OUT              = CONNMAN_SET_MAX_LEN_BUFFER_OUT;
#ELSE
integer             CONNMAN_MAX_LEN_BUFFER_OUT              =  2048;
#END_IF

#IF_DEFINED CONNMAN_SET_MAX_LEN_BUFFER_IN
integer             CONNMAN_MAX_LEN_BUFFER_IN               = CONNMAN_SET_MAX_LEN_BUFFER_IN;
#ELSE
integer             CONNMAN_MAX_LEN_BUFFER_IN               =  2048;
#END_IF

long                CONNMAN_BUFFPROC_TL                     =  1101;
long                CONNMAN_CONNECT_TL                      =  1102;

integer             CONNMAN_STATUS_DISCONNECTED             =     0;
integer             CONNMAN_STATUS_CONNECTING               =     1;
integer             CONNMAN_STATUS_CONNECTED                =     2;
integer             CONNMAN_STATUS_DISCONNECTING            =     3;

integer             CONNMAN_REQUEST_DISCONNECT              =     0;
integer             CONNMAN_REQUEST_CONNECT                 =     1;

#IF_NOT_DEFINED __IP_PROTOCOL_STRINGS
    #DEFINE __IP_PROTOCOL_STRINGS

char                IP_PROTOCOL_STRINGS[3][8] = {
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
    integer         protocol
    char            address[CONNMAN_MAX_LEN_FQDN]
    integer         port
}

structure _connman_buffer {
    char            str[CONNMAN_MAX_LEN_BUFFER_OUT]
    _connman_host   host
}

structure _connman_stats {
    long            connected
    long            disconnected
    long            error
    long            attempts
}

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile _connman_host      connman_host;
volatile _connman_stats     connman_stats;

// Preferences
volatile integer            connman_auto_reconnect          = false;
volatile integer            connman_auto_disconnect         = false;
volatile integer            connman_advance_on_response     = false;
volatile integer            connman_max_transmit_count      = 1;
volatile integer            connman_max_connect_count       = 3;


// Buffer
volatile char               connman_buffer_in[connman_MAX_LEN_BUFFER_IN];
volatile _connman_buffer    connman_buffer_out[connman_MAX_NUM_BUFFER_OUT];
volatile integer            connman_buffer_out_pos_in       = 1;
volatile integer            connman_buffer_out_pos_out      = 1;

// Buffer processing
volatile long               connman_buffproc_times[]        = { 0, 0, 0 }
volatile integer            connman_transmit_count          = 0;

// Connection request handling
volatile long               connman_connect_times[]         = { 0, 5000 }
volatile integer            connman_status                  = CONNMAN_STATUS_DISCONNECTED;
volatile integer            connman_request                 = CONNMAN_REQUEST_DISCONNECT;

(***********************************************************)
(*                     INCLUDES GO BELOW                   *)
(***********************************************************)

#INCLUDE 'prime-debug';

(***********************************************************)
(*    LIBRARY SUBROUTINE/FUNCTIONS DEFINITIONS GO BELOW    *)
(***********************************************************)

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
    if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_setProperty', '(', key, ', ', value, ')'");

    switch (key) {
        case 'IP_ADDRESS': {
            connman_host.address = value;
        }
        case 'PORT': {
            stack_var volatile integer i;

            i = atoi(value);

            if ((i < 1) || (i > 65535)) {
                if (AMX_ERROR <= get_log_level()) debug(AMX_ERROR, "'connman_setProperty', '() ', 'invalid port specified!'");
                if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_setProperty', '() ', 'returning false'");
                return false;
            } else {
                connman_host.port = i;
            }
        }
        case 'PROTOCOL': {
            stack_var volatile integer i;

            i = atoi(value);

            if ((i < IP_TCP ) || (i > IP_UDP_2WAY)) {
                if (AMX_ERROR <= get_log_level()) debug(AMX_ERROR, "'connman_setProperty', '() ', 'invalid protocol specified!'");
                if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_setProperty', '() ', 'returning false'");
                return false;
            } else {
                connman_host.protocol = atoi(value);
            }
        }
        case 'CONNECT_ATTEMPTS': {
            connman_max_connect_count = atoi(value);
        }
        case 'CONNECT_DELAY': {
            connman_connect_times[2] = atoi(value);
        }
        case 'AUTO_DISCONNECT': {
            connman_auto_disconnect = stringtobool(value);
        }
        case 'AUTO_RECONNECT': {
            connman_auto_reconnect = stringtobool(value);
        }
        case 'SEND_ATTEMPTS': {
            connman_max_transmit_count = atoi(value);
        }
        case 'SEND_DELAY': {
            connman_buffproc_times[3] = atoi(value);
        }
        case 'ADVANCE_ON_RESPONSE': {
            connman_advance_on_response = stringtobool(value);
        }
        default: {
            return false;
        }
    }

    if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_setProperty', '() ', 'returning true'");
    return true;
}

define_function connman_reinitialize() {
    if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_reinitialize', '()'");

    connman_buffer_clear();

    if (connman_auto_reconnect) {
        connman_connect(); // connman_connect will validate the connection parameters
    } else {
        connman_disconnect();
    }

    if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_reinitialize', '() ', 'returning'");
}

define_function connman_buffer_add(char str[]) {
    if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_buffer_add', '(', str, ') passing to connman_buffer_add_ex()'");

    connman_buffer_add_ex(connman_host, str);
}

define_function connman_buffer_add_ex(_connman_host host, char str[]) {
    if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_buffer_add_ex', '(', '_connman_host host', ', ', str, ')'");

    if (length_string(connman_buffer_out[connman_buffer_out_pos_in].str)) {
        if (AMX_ERROR <= get_log_level()) debug(AMX_ERROR, "'connman_buffer_add_ex() ', 'buffer full! (', itoa(max_length_array(connman_buffer_out)), ' max strings)'");
    } else {
        connman_buffer_out[connman_buffer_out_pos_in].str = str;
        connman_buffer_out[connman_buffer_out_pos_in].host = host;

        if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_buffer_add_ex() ', 'string added to buffer position ', itoa(connman_buffer_out_pos_in)");

        connman_buffer_out_pos_in++;
        if (connman_buffer_out_pos_in > max_length_array(connman_buffer_out)) connman_buffer_out_pos_in = 1;
    }

    if (connman_status != CONNMAN_STATUS_CONNECTED) {
        if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_buffer_add_ex() ', 'requesting connection'");
        connman_connect();
    } else {
        if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_buffer_add_ex() ', 'requesting buffer processing'");
        connman_buffer_process();
    }

    if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_buffer_add_ex() ', 'returning'");
}

define_function connman_buffer_advance() {
    if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_buffer_advance', '()'");

	if (length_string(connman_buffer_out[connman_buffer_out_pos_out].str)) {
		// connman_buffer_out[connman_buffer_out_pos_out].str = '';
		set_length_string(connman_buffer_out[connman_buffer_out_pos_out].str, 0);

		connman_buffer_out_pos_out++;
		if (connman_buffer_out_pos_out > max_length_array(connman_buffer_out)) connman_buffer_out_pos_out = 1;

		connman_transmit_count = 0;

		if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_buffer_advance', '() ', 'advanced to buffer position ', itoa(connman_buffer_out_pos_out)");

		if (timeline_active(CONNMAN_BUFFPROC_TL)) {
			timeline_set(CONNMAN_BUFFPROC_TL, 0);
		} else {
			connman_buffer_process();
		}
	} else {
		if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_buffer_advance', '() ', 'no contents in buffer position ', itoa(connman_buffer_out_pos_out)");
	}
	
    if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_buffer_advance', '() ', 'returning'");
}

define_function connman_buffer_clear() {
    stack_var volatile integer i;

    if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_buffer_clear', '()'");

    if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_buffer_clear', '() ', 'stopping buffer processing'");
    if (timeline_active(CONNMAN_BUFFPROC_TL)) timeline_kill(CONNMAN_BUFFPROC_TL);

    if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_buffer_clear', '() ', 'clearing buffer contents'");
    for (i = 1; i <= max_length_array(connman_buffer_out); i++) {
		// connman_buffer_out[i].str = '';
		set_length_string(connman_buffer_out[i].str, 0);
	}
    connman_buffer_out_pos_in = 1;
    connman_buffer_out_pos_out = 1;
    if (AMX_INFO <= get_log_level()) debug(AMX_INFO, "'connman_buffer_clear() ', 'buffer contents cleared'");

    if (connman_auto_disconnect) connman_disconnect();

    if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_buffer_clear() ', 'returning'");
}

define_function connman_buffer_process() {
    if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_buffer_process', '()'");

    if (!length_string(connman_buffer_out[connman_buffer_out_pos_out].str)) {
        if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_buffer_process', '() ', 'buffer at pos ', itoa(connman_buffer_out_pos_out), ' is empty'");
    } else
    if (timeline_active(CONNMAN_BUFFPROC_TL)) {
        if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_buffer_process', '() ', 'buffer is already processing'");
    } else {
        if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_buffer_process', '() ', 'starting buffer processing'");

        timeline_create(CONNMAN_BUFFPROC_TL, connman_buffproc_times, length_array(connman_buffproc_times), TIMELINE_RELATIVE, TIMELINE_REPEAT);
    }

    if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_buffer_process', '() ', 'returning'");
}

define_function integer connman_validate_connection() {
    if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_validate_connection', '()'");

    if (!length_string(connman_buffer_out[connman_buffer_out_pos_out].str)) {
        if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_validate_connection', '() ', 'buffer is empty'");
    } else {
        if (
            (connman_host.address  != connman_buffer_out[connman_buffer_out_pos_out].host.address) ||
            (connman_host.port     != connman_buffer_out[connman_buffer_out_pos_out].host.port) ||
            (connman_host.protocol != connman_buffer_out[connman_buffer_out_pos_out].host.protocol)
        ) {
            if (AMX_INFO <= get_log_level()) debug(AMX_INFO, "'connman_validate_connection', '() ', 'current connection parameters are not correct'");

            if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_validate_connection', '() ', 'returning false'");
            return false;
        } else {
            if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_validate_connection', '() ', 'returning true'");
            return true;
        }
    }
    if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_validate_connection', '() ', 'returning true'");
    return true;
}

define_function connman_connect() {
    if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_connect', '()'");
    connman_request = CONNMAN_REQUEST_CONNECT;

    if (connman_status == CONNMAN_STATUS_CONNECTED) {
        if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_connect', '() ', 'already connected'");
    } else
    if (connman_status == CONNMAN_STATUS_CONNECTING) {
        if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_connect', '() ', 'connection already in-progress'");
    } else
    if (connman_status == CONNMAN_STATUS_DISCONNECTING) {
        if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_connect', '() ', 'disconnection in-progress'");
    } else {
        if (!connman_validate_connection()) {
            if (timeline_active(CONNMAN_CONNECT_TL)) {
                if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_connect', '() ', 'cancelling connection request pending in ', ftoa(type_cast(connman_connect_times[2] - timeline_get(CONNMAN_CONNECT_TL)) / 1000), ' seconds.'");
                timeline_kill(CONNMAN_CONNECT_TL);
            }

            if (AMX_INFO <= get_log_level()) debug(AMX_INFO, "'connman_connect', '() ', 'configuring connection parameters'");
            if (connman_host.address  != connman_buffer_out[connman_buffer_out_pos_out].host.address)  connman_setProperty('IP_ADDRESS', connman_buffer_out[connman_buffer_out_pos_out].host.address);
            if (connman_host.port     != connman_buffer_out[connman_buffer_out_pos_out].host.port)     connman_setProperty('PORT', itoa(connman_buffer_out[connman_buffer_out_pos_out].host.port));
            if (connman_host.protocol != connman_buffer_out[connman_buffer_out_pos_out].host.protocol) connman_setProperty('PROTOCOL', itoa(connman_buffer_out[connman_buffer_out_pos_out].host.protocol));
        }
        if (timeline_active(CONNMAN_CONNECT_TL)) {
            if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_connect', '() ', 'existing connection request pending in ', ftoa(type_cast(connman_connect_times[2] - timeline_get(CONNMAN_CONNECT_TL)) / 1000), ' seconds.'");
        } else {
            if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_connect', '() ', 'connecting'");
            connman_status = CONNMAN_STATUS_CONNECTING;

            if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_connect', '() ', 'connecting to ', connman_host.address, ' on port ', itoa(connman_host.port), ' ', IP_PROTOCOL_STRINGS[connman_host.protocol]");
            connman_stats.attempts++;
            ip_client_open(connman_device.port, connman_host.address, connman_host.port, connman_host.protocol);
        }
    }

    if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_connect', '()', ' returning'");
}

define_function connman_disconnect() {
    if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_disconnect', '()'");
    connman_request = CONNMAN_REQUEST_DISCONNECT;

    if (connman_status == CONNMAN_STATUS_DISCONNECTED) {
        if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_disconnect', '() ', 'already disconnected'");
    } else
    if (connman_status == CONNMAN_STATUS_DISCONNECTING) {
        if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_disconnect', '() ', 'disconnection already in-progress'");
    } else
    if (connman_status == CONNMAN_STATUS_CONNECTING) {
        if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_disconnect', '() ', 'connection in-progress'");
    } else {
        if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_disconnect', '() ', 'disconnecting'");
        connman_status = CONNMAN_STATUS_DISCONNECTING

        if (timeline_active(CONNMAN_CONNECT_TL)) {
            if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_disconnect', '() ', 'cancelling connection request pending in ', ftoa(type_cast(connman_connect_times[2] - timeline_get(CONNMAN_CONNECT_TL)) / 1000), ' seconds.'");
            timeline_kill(CONNMAN_CONNECT_TL);
        }

        if (timeline_active(CONNMAN_BUFFPROC_TL)) {
            if (AMX_INFO <= get_log_level()) debug(AMX_INFO, "'connman_disconnect', '() ', 'stopping buffer processing'");
            timeline_kill(CONNMAN_BUFFPROC_TL);
        }

        if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_disconnect', '() ', 'closing socket'");
		ip_client_close(connman_device.port);
    }

    if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'connman_connect', '()', ' returning'");
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
        if (AMX_INFO <= get_log_level()) debug(AMX_INFO, "devtoa(data.device), ' online: ', 'connected to ', connman_host.address, ' on port ', itoa(connman_host.port), ' ', IP_PROTOCOL_STRINGS[connman_host.protocol]");

        connman_status = CONNMAN_STATUS_CONNECTED;
        connman_stats.connected++;
        connman_stats.attempts = 0;

        // Should never occur because this timeline is only used onerror:
        if (timeline_active(CONNMAN_CONNECT_TL)) {
            if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "devtoa(data.device), ' online: ', 'cancelling pending connection request'");
            timeline_kill(CONNMAN_CONNECT_TL);
        }

        if (connman_request = CONNMAN_REQUEST_DISCONNECT) {
            if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "devtoa(data.device), ' online: ', 'resuming pending disconnection request'");
            connman_disconnect();
        } else {
            if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "devtoa(data.device), ' online: ', 'requesting buffer processing'");
            connman_buffer_process();
        }
    }
    offline: {
        if (AMX_INFO <= get_log_level()) debug(AMX_INFO, "devtoa(data.device), ' offline: ', 'disconnected from ', connman_host.address, ' on port ', itoa(connman_host.port), ' ', IP_PROTOCOL_STRINGS[connman_host.protocol]");

        connman_status = CONNMAN_STATUS_DISCONNECTED;
        connman_stats.disconnected++;
        connman_stats.attempts = 0;

        if (timeline_active(CONNMAN_BUFFPROC_TL)) {
            if (AMX_INFO <= get_log_level()) debug(AMX_INFO, "devtoa(data.device), ' offline: ', 'stopping buffer processing'");
            timeline_kill(CONNMAN_BUFFPROC_TL);
        }

        if (connman_request = CONNMAN_REQUEST_CONNECT) {
            if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "devtoa(data.device), ' offline: ', 'resuming pending connection request'");
            connman_connect();
        } else
        if (length_string(connman_buffer_out[connman_buffer_out_pos_out].str)) {
            if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "devtoa(data.device), ' offline: ', 'reconnecting because there are remaining items in the buffer'");
            connman_connect();
        } else
        if (connman_auto_reconnect) {
            if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "devtoa(data.device), ' offline: ', 'automatically re-connecting'");
            connman_connect();
        }
	}
    onerror: {
        if (AMX_ERROR <= get_log_level()) debug(AMX_ERROR, "devtoa(data.device), ' onerror: ', 'could not connect to ', connman_host.address, ' on port ', itoa(connman_host.port), ' ', IP_PROTOCOL_STRINGS[connman_host.protocol], ' (Error ', itoa(data.number), ' ', ip_error_desc(type_cast(data.number)), ')'");

        connman_status = CONNMAN_STATUS_DISCONNECTED;
        connman_stats.error++;

        if (timeline_active(CONNMAN_BUFFPROC_TL)) {
            if (AMX_ERROR <= get_log_level()) debug(AMX_ERROR, "devtoa(data.device), ' onerror: ', 'stopping buffer processing'");
            timeline_kill(CONNMAN_BUFFPROC_TL);
        }

        switch (data.number) {
			case 14: { // Local port already used
				if (AMX_ERROR <= get_log_level()) debug(AMX_ERROR, "devtoa(data.device), ' onerror: ', 'closing unexpected open socket'");
				ip_client_close(data.device.port);
			}
			/*
			case 9: { // Already closed
				if (AMX_ERROR <= get_log_level()) debug(AMX_ERROR, "devtoa(data.device), ' onerror: ', 'unexpected closed socket. Using next IP socket.'");
				connman_device.port++; // Bad idea
			}
			*/
			default: {
				if (connman_request = CONNMAN_REQUEST_CONNECT) {
					if (AMX_INFO <= get_log_level()) debug(AMX_INFO, "devtoa(data.device), ' onerror: ', 're-trying in ', ltoa(connman_connect_times[1] - timeline_get(CONNMAN_CONNECT_TL)), ' seconds.'");
					if (timeline_active(CONNMAN_BUFFPROC_TL)) {
						timeline_set(CONNMAN_CONNECT_TL, 0);
					} else {
						timeline_create(CONNMAN_CONNECT_TL, connman_connect_times, length_array(connman_connect_times), TIMELINE_ABSOLUTE, TIMELINE_ONCE);
					}
				}
			}
		}
    }
    string: {
        if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'string received from ', data.sourceip, ' on port ', itoa(connman_host.port), ' ', IP_PROTOCOL_STRINGS[connman_host.protocol], ' (', itoa(length_string(data.text)), ' bytes): ', data.text");

        if (connman_advance_on_response) {
			connman_buffer_advance();
		}
    }
}

timeline_event[CONNMAN_CONNECT_TL] {
    switch(timeline.sequence) {
        case 1: {
            #IF_DEFINED INCLUDE_CONNMAN_CONNECT_FAIL_CALLBACK
            connman_connect_fail_callback(connman_buffer_out[connman_buffer_out_pos_out].host, connman_buffer_out[connman_buffer_out_pos_out].str);
            #END_IF

            if (connman_stats.attempts >= connman_max_connect_count) {
                if (AMX_WARNING <= get_log_level()) debug(AMX_WARNING, "'CONNMAN_BUFFPROC_TL', '(', itoa(timeline.repetition), ', ', itoa(timeline.sequence), ') ', 'connection attempt failed after ', itoa(connman_stats.attempts), ' attempts'");

                connman_buffer_advance();
                timeline_kill(timeline.id);
            } else {
                if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'CONNMAN_CONNECT_TL', '(', itoa(timeline.repetition), ', ', itoa(timeline.sequence), ') ', 'connecting in ', ftoa(type_cast(CONNMAN_CONNECT_TIMES[2]) / 1000), ' seconds'");
            }
        }
        case 2: {
            if (AMX_WARNING <= get_log_level()) debug(AMX_DEBUG, "'CONNMAN_BUFFPROC_TL', '(', itoa(timeline.repetition), ', ', itoa(timeline.sequence), ') ', 'resuming pending connection request'");
            connman_connect();
        }
    }
}

timeline_event[CONNMAN_BUFFPROC_TL] {
    switch(timeline.sequence) {
        case 1: {
            if (!length_string(connman_buffer_out[connman_buffer_out_pos_out].str)) { // Confirm there are contents in the buffer
                if (timeline_active(timeline.id)) { // Incase the timeline_event runs again whilst it is being terminated (http://www.amx.com/techsupport/technote.asp?id=1040)
                    timeline_kill(timeline.id);

                    if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'CONNMAN_BUFFPROC_TL', '(', itoa(timeline.repetition), ', ', itoa(timeline.sequence), ') ', 'buffer is empty. stopping buffer processing.'");

                    if (connman_auto_disconnect) {
                        if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'CONNMAN_BUFFPROC_TL', '(', itoa(timeline.repetition), ', ', itoa(timeline.sequence), ') ', 'requesting automatic disconnection'");
                        connman_disconnect();
                    }
                }
            } else
            if (connman_status != CONNMAN_STATUS_CONNECTED) { // Confirm connection to host
                if (timeline_active(timeline.id)) timeline_kill(timeline.id);

                if (AMX_WARNING <= get_log_level()) debug(AMX_WARNING, "'CONNMAN_BUFFPROC_TL', '(', itoa(timeline.repetition), ', ', itoa(timeline.sequence), ') ', 'not connected. requesting connection.'");
                connman_connect();
            } else
            if (!connman_validate_connection()) { // Confirm connected to the correct host
                if (AMX_INFO <= get_log_level()) debug(AMX_INFO, "'CONNMAN_BUFFPROC_TL', '(', itoa(timeline.repetition), ', ', itoa(timeline.sequence), ') ', 'host connection parameters are incorrect. requesting disconnection.'");

		connman_disconnect(); // Subsequent connect event will cause for re-confguration of connection parameters
            } else
            if (connman_transmit_count >= connman_max_transmit_count) { // Check if current string has been sent the maximum number of times
                if (AMX_WARNING <= get_log_level()) debug(AMX_WARNING, "'CONNMAN_BUFFPROC_TL', '(', itoa(timeline.repetition), ', ', itoa(timeline.sequence), ') ', 'request timed out. advancing buffer after no response was received for ', itoa(connman_transmit_count), ' attempts.'");

                #IF_DEFINED INCLUDE_CONNMAN_TIMEOUT_CALLBACK
                connman_timeout_callback(connman_buffer_out[connman_buffer_out_pos_out].host, connman_buffer_out[connman_buffer_out_pos_out].str);
                #END_IF

                connman_buffer_advance();
            } else { // Send string from buffer
                if (connman_transmit_count) {
                    if (AMX_WARNING <= get_log_level()) debug(AMX_WARNING, "'CONNMAN_BUFFPROC_TL', '(', itoa(timeline.repetition), ', ', itoa(timeline.sequence), ') ', 'request timed out. re-sending string from buffer position ', itoa(connman_buffer_out_pos_out), ' (attempt ', itoa(connman_transmit_count + 1), ')'");
                } else {
                    if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'CONNMAN_BUFFPROC_TL', '(', itoa(timeline.repetition), ', ', itoa(timeline.sequence), ') ', 'sending string from buffer position ', itoa(connman_buffer_out_pos_out), ' (attempt ', itoa(connman_transmit_count + 1), ')'");
                }

                connman_transmit_count++;
                send_string connman_device, connman_buffer_out[connman_buffer_out_pos_out].str;
            }
        }
        case 2: {
            if (timeline_active(timeline.id)) { // Incase the timeline_event runs again whilst it is being terminated (http://www.amx.com/techsupport/technote.asp?id=1040)
                if (connman_advance_on_response) {
                    if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'CONNMAN_BUFFPROC_TL', '(', itoa(timeline.repetition), ', ', itoa(timeline.sequence), ') ', 'waiting for response...'");
                } else {
                    if (AMX_DEBUG <= get_log_level()) debug(AMX_DEBUG, "'CONNMAN_BUFFPROC_TL', '(', itoa(timeline.repetition), ', ', itoa(timeline.sequence), ') ', 'waiting...'");
                }
            }
        }
    }
}

#END_IF