MODULE_NAME='RmsGenericSnmpDeviceMonitor'(dev vdvRMS, dev vdvDeviceModule, dev dvMonitoredDevice, dev vdvSNMP)
(***********************************************************)
(*  FILE_LAST_MODIFIED_ON: 10/03/2016  AT: 21:14:25        *)
(***********************************************************)

(***********************************************************)
(* System Type : NetLinx                                   *)
(***********************************************************)

(*
	RmsGenericSnmpDeviceMonitor.axs
	Generic RMS Monitor Module for SNMP-enabled devices

	Author: niek.groot@amxaustralia.com.au
	No rights or warranties implied

	This module implements the following for most SNMP-enabled devices:

	- Device Hostname
	- Device make / model discovery
	- Device description
	- SNMP agent uptime

	This SNMP device monitor module retreives the current status of a device
	via SNMP GET requests, and/or receives unsolicited SNMP TRAP updates sent
	by the device as changes occur.

	This monitor module can optionally provide control of a device by linking
	RMS Control Methods to SNMP SET requests.

	Devices are identified by by .iso.org.dod.internet.mgmt.mib-2.system.sysObjectID,
	which is matched to a manufacturer, model, and asset type through lookup
	tables defined in the DEFINE_CONSTANTS section of this module.

	The SnmpMonitorCommon.axi include provides required SNMP API functions and
	caches status parameter values, ensuring that only changs are sent to RMS.

	Whilst tested for broad compatibilty, this code should be considered a
	technology demo and should by carefully evaluated before using in a
	production environment.

	This module uses a seperately included SNMP Manager (snmp-manager.axs)
	module for ease of adoption and customisation.

	Debug information has been included for clarity, but when enabled can
	significantly affect performance. Only enable debug output when necessary.

	Please consider contributing by submitting bug fixes and improvements.


	Usage:

	DEFINE_MODULE 'RmsGenericSnmpDeviceMonitor' mdlSnmpDeviceMonitor(dev <rms virtual device>, dev <monitor module virtual device>, dev <monitor module virtual device>, dev <snmp manager virtual device>);


	Configuration:

	The SNMP agent address, port, and community must be configured. The
	listener port is configured globally for the SNMP manager module.

	Set an update interval if actively polling a device via SNMP GET. Disable
	the update interval if the device will send SNMP TRAPs as changes occur.

	send_command vdvDeviceModule, "'DEBUG-', itoa(<AMX_ERROR|AMX_WARNING|AMX_INFO|AMX_DEBUG>)";             // Sets the debug message filter level via the set_log_level() function.

	send_command vdvDeviceModule, "'PROPERTY-IP_ADDRESS,', '<address>'";                                    // Device IP address. This will be used to filter SNMP TRAP and GET responses.
	send_command vdvDeviceModule, "'PROPERTY-PORT,', itoa(<agent port>)";                                   // Device SNMP port. Default: 161.
	send_command vdvDeviceModule, "'PROPERTY-COMMUNITY,', '<community>'";                                   // Device SNMP community name. Default: public.

	send_command vdvDeviceModule, "'PROPERTY-ASSET_NAME', '<name>'";                                        // Override the asset name, which is otherwise retrieved from iso.org.dod.internet.mgmt.mib-2.system.sysName

	send_command vdvDeviceModule, "'PROPERTY-CONTACT_TIMEOUT', itoa(<seconds>)";                            // Time in seconds after which, if no status updates have been received from the device, to mark the device as offline. This value must be greater than the POLL_INTERVAL. Default: 190 seconds.
	send_command vdvDeviceModule, "'POLL_INTERVAL', itoa(<seconds>)|DISABLE`";                              // Time in seconds between requests for device status updates. Set this to 0 (disable) if the device will send SNMP TRAPs as changes occur. Default: 60 aeconds.

	send_command vdvDeviceModule, "'REINIT'";                                                               // Re-initialise the module and start the polling interval process.
*)

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

char                MONITOR_NAME[]                          = 'RMS SNMP Generic Host Monitor';
char                MONITOR_DEBUG_NAME[]                    = 'RmsSnmpGenericHostMonitor';
char                MONITOR_VERSION[]                       = '4.5.3';

char                ENTERPRISE_NUMBERS[][2][15]             = {                 // RMS Asset manufacturer name. https://www.iana.org/assignments/enterprise-numbers/enterprise-numbers
						{'9', 'Cisco'},
						{'11', 'HP'},
						{'311', 'Microsoft'},
						{'2636', 'Juniper'},
						{'8942', 'AMX'},
						{'14823', 'Aruba'},
						{'25053', 'Ruckus'},
						{'41639', 'SVSI'}
					}
char                ENTERPRISE_MODELS[][2][15]              = {                 // RMS Asset model name. http://www.dpstele.com/snmp/what-does-oid-network-elements.php
						{'311.1.1.3.1.1', 'Workstation'},
						{'311.1.1.3.1.2', 'Server'},
						{'9.1.1362', 'AP802GN'},
						{'9.1.1377', 'C887VA-W'},
						{'9.1.1154', 'SRP521W'}
					}
char                ENTERPRISE_TYPES[][2][15]               = {                 // RMS Asset type key. These must exist in RMS database for successful asset registration!
						{'311.1.1.3.1.1', 'Utility'},
						{'311.1.1.3.1.2', 'Utility'},
						{'9.1.1154', 'Utility'}
					}

(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile char       MONITOR_ASSET_NAME[50]                  =   '';             // This is usually declared as a constant in the RMS SDK monitor modules
volatile char       MONITOR_ASSET_GLOBALKEY[150]            =   '';

(***********************************************************)
(*               INCLUDE DEFINITIONS GO BELOW              *)
(***********************************************************)

/*
CAVEAT: RegisterAssetParametersSnapiComponents() will register an parameters
and values constrained to DUET_MAX_PARAM_LEN (100 characters).
Define an larger DUET_MAX_PARAM_LEN value as required.
*/
// #DEFINE DUET_MAX_PARAM_LEN 255
#INCLUDE 'SNAPI';

#DEFINE SNAPI_MONITOR_MODULE;
#DEFINE EXCLUDE_RMS_SYSTEM_POWER_CHANGE_CALLBACK
#DEFINE EXCLUDE_RMS_SYSTEM_MODE_CHANGE_CALLBACK
#INCLUDE 'RmsMonitorCommon';

#INCLUDE 'RmsNlSnapiComponents';

// #DEFINE MAX_NUM_VARBINDS                                     25              // Number of parameter varbinds to cache. Default: 25.
// #DEFINE MAX_LEN_VARBIND_VALUE                                50              // Maximum length of cached parameter varbind value. Default: 50 as per RmsAssetParameter.initialValue in RmsApi
#DEFINE INCLUDE_VARBIND_UPDATED_CALLBACK
#DEFINE INCLUDE_DEVICE_INFO_POLL_CALLBACK
// #DEFINE INCLUDE_DEVICE_STATUS_POLL_CALLBACK
#INCLUDE 'SnmpMonitorCommon';

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)

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
DEFINE_FUNCTION RegisterAsset(RmsAsset asset)
{
	asset.clientKey         = RmsDevToString(dvMonitoredDevice);

	asset.name              = array_get(varbinds, OID_sysName);
	asset.assetType         = array_get(ENTERPRISE_TYPES, sysObjectID_to_model(array_get(varbinds, OID_sysObjectID)));
	asset.description       = array_get(varbinds, OID_sysDescr);
	asset.manufacturerName  = array_get(ENTERPRISE_NUMBERS, sysObjectID_to_enterprise(array_get(varbinds, OID_sysObjectID)));
	asset.modelName         = array_get(ENTERPRISE_MODELS, sysObjectID_to_model(array_get(varbinds, OID_sysObjectID)));
	asset.serialNumber      = ''; // Serial number is not a universally implemented OID
	asset.firmwareVersion   = ''; // Firmware Version is not a universally implemented OID

	// Create device-derrived, globally unique, asset identifier.
	if (length_string(asset.manufacturerName) && length_string(asset.modelName) && length_string(asset.serialNumber)) {
		MONITOR_ASSET_GLOBALKEY = "plain_string(asset.serialNumber), '-', plain_string(asset.modelname), '-', plain_string(asset.manufacturerName)";
		asset.globalKey = MONITOR_ASSET_GLOBALKEY;
	}

	// Override asset name with friendly name if specified
	if (length_string(MONITOR_ASSET_NAME)) {
		asset.name = MONITOR_ASSET_NAME;
	}

	if (!length_string(asset.name))             asset.name              = 'Unknown';
	if (!length_string(asset.assetType))        asset.assetType         = RMS_ASSET_TYPE_UNKNOWN;
	if (!length_string(asset.manufacturerName)) asset.manufacturerName  = 'Unknown';
	if (!length_string(asset.modelName))        asset.modelName         = 'Unknown';

	RmsAssetRegister(dvMonitoredDevice, asset);
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
DEFINE_FUNCTION RegisterAssetParameters()
{
	// Register all snapi HAS_xyz components
	RegisterAssetParametersSnapiComponents(assetClientKey);

	RmsAssetParameterEnqueueString(assetClientKey,
									'uptime',
									'Uptime', 'Time elapsed since the SNMP agent on the host was started',
									RMS_ASSET_PARAM_TYPE_NONE,
									'', '',
									RMS_ALLOW_RESET_NO, '',
									RMS_TRACK_CHANGES_NO);

	// submit all parameter registrations
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
DEFINE_FUNCTION SynchronizeAssetParameters()
{
	// This callback method is invoked when either the RMS server connection
	// has been offline or this monitored device has been offline from some
	// amount of time.   Since the monitored parameter state values could
	// be out of sync with the RMS server, we must perform asset parameter
	// value updates for all monitored parameters so they will be in sync.
	// Update only asset monitoring parameters that may have changed in value.

	/*
	CAVEAT: keyLookup() in RmsNlSnapiComponents does not correctly cache
	values, and keyFind() does not correctly recall them, preventing
	SynchronizeAssetParametersSnapiComponents() from updating cached values
	when the connection to RMS becomes online.

	Immediate parameter updates /are/ sent correctly when the connection to
	RMS is online (because caching is not necessary).

	Fix for RmsNlSnapiComponents.axi from RMS SDK 4.5.3 (and probably others):

	112a113
	>   uKeys[nKeyCount].cName = cKey
	*/

	// Synchronize all snapi HAS_xyz components
	SynchronizeAssetParametersSnapiComponents(assetClientKey);

	RmsAssetParameterEnqueueSetValue(assetClientKey, 'uptime', timeticks_to_time(atol_unsigned(array_get(varbinds, OID_sysUpTime))));

	RmsAssetParameterUpdatesSubmit(assetClientKey); // Corrected. Monitor modules included with the RMS SDK incorrectly call RmsAssetParameterSubmit() here
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
DEFINE_FUNCTION RegisterAssetMetadata()
{
	// Register all snapi HAS_xyz components
	RegisterAssetMetadataSnapiComponents(assetClientKey);

	if (length_string(MONITOR_ASSET_GLOBALKEY)) {
		RmsAssetMetadataEnqueueString(assetClientKey, 'asset.globalKey', 'Asset Global Key', MONITOR_ASSET_GLOBALKEY);
	} else {
		RmsAssetMetadataEnqueueString(assetClientKey, 'asset.globalKey', 'Asset Global Key', 'Not specified (auto-generated)');
	}
	RmsAssetMetadataEnqueueString(assetClientKey, 'sysObjectID', 'sysObjectID', array_get(varbinds, OID_sysObjectID)); // NOTE: MetadataName is limited to 50 characters by the RMS Server
	RmsAssetMetadataEnqueueString(assetClientKey, 'hostname', 'Host Name', array_get(varbinds, OID_sysName));

	RmsAssetMetadataEnqueueString(assetClientKey, 'host-ip-address', 'Host IP Address', snmp_agent.address);
	RmsAssetMetadataEnqueueHyperlink(assetClientKey, 'link-web-config', 'Web Configuration', "'http://', snmp_agent.address, '/'", "'http://', snmp_agent.address, '/'");
	RmsAssetMetadataEnqueueString(assetClientKey, 'snmp.community', 'SNMP Community', snmp_agent.community);
	RmsAssetMetadataEnqueueString(assetClientKey, 'snmp.port', 'SNMP Port', itoa(snmp_agent.port));
	if (STATUS_POLL_TIMES[2] > 0) {
		RmsAssetMetadataEnqueueString(assetClientKey, 'poll.interval', 'Poll Interval (seconds)', itoa(STATUS_POLL_TIMES[2] / 1000));
	} else {
		RmsAssetMetadataEnqueueString(assetClientKey, 'poll.interval', 'Poll Interval', 'DISABLED');
	}
	RmsAssetMetadataEnqueueString(assetClientKey, 'contact.timeout', 'Contact Timeout (seconds)', itoa(CONTACT_TIMEOUT_TIMES[1] / 1000));

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
DEFINE_FUNCTION SynchronizeAssetMetadata()
{
	/*
	This module does not synchronise any of the previously registered metadata
	here, beacuse updates (i.e. because the device has been replaced) would
	also trigger a re-registration of the asset.
	*/

	// Synchronize all snapi HAS_xyz components
	if (SynchronizeAssetMetadataSnapiComponents(assetClientKey)) {
		RmsAssetMetadataSubmit(assetClientKey);
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
	//Register all snapi HAS_xyz components
	RegisterAssetControlMethodsSnapiComponents(assetClientKey);

	// when done enqueuing all asset control methods and
	// arguments for this asset, we just need to submit
	// them to finalize and register them with the RMS server
	RmsAssetControlMethodsSubmit(assetClientKey);
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
	debug("'<<< EXECUTE CONTROL METHOD : [', methodKey, '] args=', arguments, ' >>>'");
}

// #DEFINE INCLUDE_DEVICE_INFO_POLL_CALLBACK
define_function device_info_poll_callback() {
	/*
	SnmpMonitorCommon will automatically poll the following
	OIDs when the device becomes reachable:

	snmp_get(OID_sysDescr);
	snmp_get(OID_sysObjectID);
	snmp_get(OID_sysName);

	Add additional device-specific OIDs to poll here.
	*/
}

// #DEFINE INCLUDE_DEVICE_STATUS_POLL_CALLBACK
define_function device_status_poll_callback() {
	/*
	SnmpMonitorCommon will automatically poll the following
	OIDs at regular intervals:

	snmp_get(OID_sysUpTime);

	Add additional device-specific OIDs to automatically poll
	when the device is communicating and data is initialized here:
	*/
}

// #DEFINE INCLUDE_VARBIND_UPDATED_CALLBACK
define_function varbind_updated_callback(char oid[], char value[]) {
	if (![vdvDeviceModule, DATA_INITIALIZED]) {
		if (
			length_string(array_get(varbinds, OID_sysDescr)) &&
			length_string(array_get(varbinds, OID_sysObjectID)) &&
			length_string(array_get(varbinds, OID_sysName))
		) {
			on[vdvDeviceModule, DATA_INITIALIZED];
		}
	}

	if (parametersRegistered) {
		switch (oid) {
			case OID_sysUpTime: RmsAssetParameterSetValue(assetClientKey, 'uptime', timeticks_to_time(atol_unsigned(value)));
		}
	}
}

(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT

(***********************************************************)
(*            THE ACTUAL PROGRAM GOES BELOW                *)
(***********************************************************)
DEFINE_PROGRAM

(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)
