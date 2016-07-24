MODULE_NAME='RmsEpsonProjectorMonitor'(dev vdvRMS, dev vdvDeviceModule, dev dvMonitoredDevice, dev vdvSNMP)
(***********************************************************)
(*  FILE_LAST_MODIFIED_ON: 07/24/2016  AT: 21:07:42        *)
(***********************************************************)

(***********************************************************)
(* System Type : NetLinx                                   *)
(***********************************************************)

(*
	RmsEpsonProjectorMonitor.axs
	SNMP RMS Monitor Module for Epson Projectors
	
	Author: niek.groot@amxaustralia.com.au
	No rights or warranties implied
	
	This module implements the following for various Epson projectors models;
	
	- Projector Name
	- Firmware Version
	- Serial Number
	- Lamp Hours
	- Error Status
	- Power Status and Control
	- Input Status and Control
	
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
	
	send_command vdvDeviceModule, "'PROPERTY-CONTACT_TIMEOUT', itoa(<seconds>)";                            // Time in seconds after which, if no status updates have been received from the device, to mark the device as offline. This value must be greater than the POLL_INTERVAL.
	send_command vdvDeviceModule, "'POLL_INTERVAL', itoa(<seconds>)|DISABLE`";                              // Time in seconds between requests for device status updates. Set this to 0 (disable) if the device will send SNMP TRAPs as changes occur.
	
	send_command vdvDeviceModule, "'REINIT'";                                                               // Re-initialise the module and start the polling interval process.
*)

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

char                MONITOR_NAME[]                          = 'RMS Epson Projector Monitor';
char                MONITOR_DEBUG_NAME[]                    = 'RmsEpsonProjectorMonitor';
char                MONITOR_VERSION[]                       = '4.5.3';

char                ENTERPRISE_NUMBERS[][2][15]             = {                 // RMS Asset manufacturer name. https://www.iana.org/assignments/enterprise-numbers/enterprise-numbers
						{'9', 'Cisco'}, 
						{'11', 'HP'}, 
						{'311', 'Microsoft'}, 
						{'2636', 'Juniper'}, 
						{'8942', 'AMX'}, 
						{'14823', 'Aruba'}, 
						{'25053', 'Ruckus'}, 
						{'41639', 'SVSI'}, 
						{'1248', 'Epson'}
					}
char                ENTERPRISE_MODELS[][2][15]              = {                 // RMS Asset model name. http://www.dpstele.com/snmp/what-does-oid-network-elements.php
						{'311.1.1.3.1.1', 'Workstation'}, 
						{'311.1.1.3.1.2', 'Server'}, 
						{'1248.4.1', 'PowerLite Pro'}                           // UNVERIFIED
					}
char                ENTERPRISE_TYPES[][2][15]               = {                 // RMS Asset type key. These must exist in RMS database for successful asset registration!
						{'311.1.1.3.1.1', 'Utility'}, 
						{'311.1.1.3.1.2', 'Utility'}, 
						{'1248.4.1', 'VideoProjector'}
					}

char                LAMP_LIFE[][2][15]                      = {                 // RMS Asset type key. These must exist in RMS database for successful asset registration!
						{'1248.4.1', '3000'}
					}

char                OID_Epson_LampHours[]                   = '1.3.6.1.4.1.1248.4.1.1.1.1.0';
char                OID_Epson_Power[]                       = '1.3.6.1.4.1.1248.4.1.1.2.1.0';
char                OID_Epson_Serial[]                      = '1.3.6.1.4.1.1248.4.1.1.1.8.0';
char                OID_Epson_PWStatus[]                    = '1.3.6.1.4.1.1248.4.1.1.1.9.0';
char                OID_Epson_InputSource[]                 = '1.3.6.1.4.1.1248.4.1.1.2.2.0';
char                OID_Epson_Name[]                        = '1.3.6.1.4.1.1248.4.1.1.2.7.0';

char                INPUT_SOURCES[][2][19]                  = {
						{'10', 'INPUT1 (D-Sub)'}, 
						{'11', 'INPUT1 (RGB)'}, 
						{'14', 'INPUT1 (Component)'}, 
						{'20', 'INPUT2 (D-Sub)'}, 
						{'21', 'INPUT2 (RGB)'}, 
						{'24', 'INPUT2 (Component)'}, 
						{'30', 'INPUT3 (DVI)'}, 
						{'31', 'INPUT3 (D-RGB)'}, 
						{'33', 'INPUT3 (RGB-Video)'}, 
						{'34', 'INPUT3 (YCbCr)'}, 
						{'35', 'INPUT3 (YPbPr)'}, 
						{'40', 'VIDEO'}, 
						{'42', 'VIDEO (S)'}, 
						{'45', 'VIDEO1 (BNC)'}, 
						{'41', 'VIDEO2 (RCA)'}
					}

char                PROJECTOR_STATUS[][2][9]                = {
						{'01', 'Standby'}, 
						{'02', 'Warmup'}, 
						{'03', 'Normal'}, 
						{'04', 'Cool down'}, 
						{'FF', 'Abnormal'}
					}

char                WARNING_TYPES[][2][22]                  = {
						{'0000', 'OK'}, 
						{'0001', 'Lamp life'}, 
						{'0002', 'OK No signal'}, 
						{'0003', 'OK Unsupported signal'}, 
						{'0004', 'Air filter'}, 
						{'0005', 'High temperature'} 
					}

char                ALARM_TYPES[][2][27]                    = {
						{'0000', 'OK'}, 
						{'0001', 'Lamp ON failure'}, 
						{'0002', 'Lamp lid'}, 
						{'0003', 'Lamp burnout (ON, then OFF)'}, 
						{'0004', 'Fan'}, 
						{'0005', 'Temperature sensor'}, 
						{'0006', 'High temperature'}, 
						{'0007', 'Interior (system)'}
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

volatile integer    METADATA_PROPERTY_SOURCE_INPUT_COUNT    =    0;             // Populated with with source count in varbind_updated_callback()
volatile char       METADATA_PROPERTY_SOURCE_INPUT[255]     =   '';             // Populated with with source list in varbind_updated_callback()

volatile integer    METADATA_PROPERTY_LAMP_THRESHOLD        = 2000;             // Populated with with model-specific value in varbind_updated_callback()
volatile integer    METADATA_PROPERTY_LAMP_WARMUP_TIME      =   30;
volatile integer    METADATA_PROPERTY_LAMP_COOLDOWN_TIME    =   30;

(***********************************************************)
(*               INCLUDE DEFINITIONS GO BELOW              *)
(***********************************************************)

/*
CAVEAT: RegisterAssetParametersSnapiComponents() will register an source.input 
parameter as per HAS_SOURCE_SELECT with an enumerated list of sources
limited to DUET_MAX_PARAM_LEN (100 characters). Define an larger 
DUET_MAX_PARAM_LEN if the device has a large source list.
*/
#DEFINE DUET_MAX_PARAM_LEN 255
#INCLUDE 'SNAPI';

#DEFINE SNAPI_MONITOR_MODULE;
#DEFINE EXCLUDE_RMS_SYSTEM_POWER_CHANGE_CALLBACK
#DEFINE EXCLUDE_RMS_SYSTEM_MODE_CHANGE_CALLBACK
#INCLUDE 'RmsMonitorCommon';

/*
CAVEAT: RegisterAssetParametersSnapiComponents() will register a lamp.consumption 
parameter as per HAS_LAMP with a hard-coded 2000 hour upper limit.
This example addresses this by re-registering the lamp.consumption paramter
with an adjusted value range.
*/
#DEFINE HAS_POWER
#DEFINE HAS_LAMP
#DEFINE HAS_SOURCE_SELECT
#INCLUDE 'RmsNlSnapiComponents';

#DEFINE MAX_NUM_VARBINDS                                        25              // Number of parameter varbinds to cache. Default: 25.
#DEFINE MAX_LEN_VARBIND_VALUE                                   50              // Maximum length of cached parameter varbind value. Default: 50 as per RmsAssetParameter.initialValue in RmsApi
#DEFINE INCLUDE_VARBIND_UPDATED_CALLBACK
#DEFINE INCLUDE_DEVICE_INFO_POLL_CALLBACK
#DEFINE INCLUDE_DEVICE_STATUS_POLL_CALLBACK
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
	stack_var volatile char serialNumber[100], firmwareVersion[30];
	stack_var volatile integer pos;
	
	serialNumber = array_get(varbinds, OID_Epson_Serial);
	
	pos = find_string(serialNumber, '/', 1);
	if (pos) {
		firmwareVersion = left_string(serialNumber, pos - 1);
		serialNumber = right_string(serialNumber, length_string(serialNumber) - pos);
	}
	
	asset.clientKey         = RmsDevToString(dvMonitoredDevice);

	asset.name              = array_get(varbinds, OID_Epson_Name);
	asset.assetType         = array_get(ENTERPRISE_TYPES, sysObjectID_to_model(array_get(varbinds, OID_sysObjectID)));
	asset.description       = array_get(varbinds, OID_sysDescr);
	asset.manufacturerName  = array_get(ENTERPRISE_NUMBERS, sysObjectID_to_enterprise(array_get(varbinds, OID_sysObjectID)));
	asset.modelName         = array_get(ENTERPRISE_MODELS, sysObjectID_to_model(array_get(varbinds, OID_sysObjectID)));
	asset.serialNumber      = serialNumber;
	asset.firmwareVersion   = firmwareVersion;

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
	
	// Override the lamp consumption range set in RegisterAssetParametersSnapiComponents(), which is statically defined as 0-2000 hours.
	RmsAssetParameterEnqueueDecimalWithBargraph(assetClientKey,
								   'lamp.consumption',
								   'Lamp Consumption',
								   'Current usage of the lamp life',
								   RMS_ASSET_PARAM_TYPE_LAMP_USAGE,
								   0,
								   0,
								   METADATA_PROPERTY_LAMP_THRESHOLD + 1000, // As an exception to the rule (editable fields are not overwritten by code), these values /do/ overwrite values changed via the RMS dashboard.
								   'Hours',
								   RMS_ALLOW_RESET_YES,
								   0,
								   RMS_TRACK_CHANGES_YES,
								   'lamp.consumption');

	RmsAssetParameterEnqueueString(assetClientKey,
									'uptime',
									'Uptime', 'Time elapsed since the SNMP agent on the host was started',
									RMS_ASSET_PARAM_TYPE_NONE,
									'', '', 
									RMS_ALLOW_RESET_NO, '',
									RMS_TRACK_CHANGES_NO);
	
	RmsAssetParameterEnqueueString(assetClientKey,
									'status.projector',
									'Projector Status', 'Operational status',
									RMS_ASSET_PARAM_TYPE_NONE,
									array_get(PROJECTOR_STATUS, '03'), '', // For parameters with thresholds, set a default value that does not trigger the threshold as to avoid erronous alerts
									RMS_ALLOW_RESET_NO, '',
									RMS_TRACK_CHANGES_NO);
	
	RmsAssetParameterThresholdEnqueue(assetClientKey,
									'status.projector',
									'Error',
									RMS_STATUS_TYPE_MAINTENANCE,
									RMS_ASSET_PARAM_THRESHOLD_COMPARISON_EQUAL,
									array_get(PROJECTOR_STATUS, 'FF'));

	RmsAssetParameterEnqueueString(assetClientKey,
									'status.warning',
									'Warning Status', 'Warning status',
									RMS_ASSET_PARAM_TYPE_NONE,
									array_get(WARNING_TYPES, '0000'), '', 
									RMS_ALLOW_RESET_NO, '',
									RMS_TRACK_CHANGES_YES);

	RmsAssetParameterThresholdEnqueue(assetClientKey,
									'status.warning',
									'Warning',
									RMS_STATUS_TYPE_MAINTENANCE,
									RMS_ASSET_PARAM_THRESHOLD_COMPARISON_DOES_NOT_CONTAIN,
									array_get(WARNING_TYPES, '0000'));

	RmsAssetParameterEnqueueString(assetClientKey,
									'status.alarm',
									'Alarm Status', 'Alarm status', 
									RMS_ASSET_PARAM_TYPE_NONE,
									array_get(ALARM_TYPES, '0000'), '', 
									RMS_ALLOW_RESET_NO, '',
									RMS_TRACK_CHANGES_YES);
	
	RmsAssetParameterThresholdEnqueue(assetClientKey,
									'status.alarm', 
									'Alarm',
									RMS_STATUS_TYPE_MAINTENANCE,
									RMS_ASSET_PARAM_THRESHOLD_COMPARISON_DOES_NOT_CONTAIN,
									array_get(ALARM_TYPES, '0000'));

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
	
	Fix for RMS SDK 4.5.3 (and probably others):
	
	106c106
	<     IF(uKeys[nLoop].cName = cKey)
	---
	>     IF(uKeys[nLoop].cName == cKey)
	113a114
	>   uKeys[nKeyCount].cName = cKey
	132c133
	<     IF(uKeys[nLoop].cName = cKey)
	---
	>     IF(uKeys[nLoop].cName == cKey)
	*/

	// Synchronize all snapi HAS_xyz components
	SynchronizeAssetParametersSnapiComponents(assetClientKey);
	
	RmsAssetParameterEnqueueSetValue(assetClientKey, 'uptime', timeticks_to_time(atol_unsigned(array_get(varbinds, OID_sysUpTime))));
	RmsAssetParameterEnqueueSetValue(assetClientKey, 'status.projector', array_get(PROJECTOR_STATUS, mid_string(array_get(varbinds, OID_Epson_PWStatus), 1, 2)));
	RmsAssetParameterEnqueueSetValue(assetClientKey, 'status.warning', array_get(WARNING_TYPES, mid_string(array_get(varbinds, OID_Epson_PWStatus), 4, 4)));
	RmsAssetParameterEnqueueSetValue(assetClientKey, 'status.alarm', array_get(ALARM_TYPES, mid_string(array_get(varbinds, OID_Epson_PWStatus), 9, 4)));

	RmsAssetParameterUpdatesSubmit(assetClientKey); // RMS SDK monitor modules incorrectly call RmsAssetParameterSubmit() here
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
	// Exclude registration of warmup/cooldown metadata. Remove this as required.
	RmsAssetMetadataExclude(assetClientKey, 'projector.lamp.warmup.time');
	RmsAssetMetadataExclude(assetClientKey, 'projector.lamp.cooldown.time');

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
	
	RmsAssetMetadataEnqueueString(assetClientKey, 'projector.name', 'Projector Name', array_get(varbinds, OID_Epson_Name));
	
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
	// Synchronize all snapi HAS_xyz components
	if (SynchronizeAssetParametersSnapiComponents(assetClientKey)) {
		RmsAssetParameterSubmit (assetClientKey);
	}

	/*
	Not synchronising any of the previously registered metadata here, as  any 
	updates to this metadata, such as due to the replacement of the device,
	would also trigger a re-registration of the asset.
	*/
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
  
	switch (methodKey) {
		case 'projector.lamp.power': {
			snmp_set(OID_Epson_Power, "ASN1_TAG_INTEGER", itoa(RmsBooleanValue(arguments)));
		}
		case 'source.input': {
			snmp_set(OID_Epson_InputSource, "ASN1_TAG_OCTET_STRING", INPUT_SOURCES[array_find_value(INPUT_SOURCES, arguments)][ARRAY_KEY]);
		}
	}
}

// #DEFINE INCLUDE_DEVICE_INFO_POLL_CALLBACK
define_function device_info_poll_callback() {
	snmp_get(OID_sysDescr);
	snmp_get(OID_sysObjectID);
	snmp_get(OID_sysName);
	snmp_get(OID_Epson_Name);
	snmp_get(OID_Epson_Serial);
}

// #DEFINE INCLUDE_DEVICE_STATUS_POLL_CALLBACK
define_function device_status_poll_callback() {
	snmp_get(OID_sysUpTime);
	snmp_get(OID_Epson_LampHours);
	snmp_get(OID_Epson_Power);
	snmp_get(OID_Epson_PWStatus);
	
	if ([vdvDeviceModule, POWER_FB]) { // Only available when device is powered on
		snmp_get(OID_Epson_InputSource);
	}
}

// #DEFINE INCLUDE_VARBIND_UPDATED_CALLBACK
define_function varbind_updated_callback(char oid[], char value[]) {
	if (![vdvDeviceModule, DATA_INITIALIZED]) {
		if (
			length_string(array_get(varbinds, OID_sysDescr)) &&
			length_string(array_get(varbinds, OID_sysObjectID)) &&
			length_string(array_get(varbinds, OID_sysName)) && 
			length_string(array_get(varbinds, OID_Epson_Name)) && 
			length_string(array_get(varbinds, OID_Epson_Serial))
		) {
			stack_var volatile integer i;
			
			// INPUTCOUNT-<count>
			send_command vdvDeviceModule, "'INPUTCOUNT-', itoa(length_array(INPUT_SOURCES))";
			
			for (i = 1; i <= length_array(INPUT_SOURCES); i++) {
				// INPUTPROPERTIES-<index>,<inputGroup>,<signalType>,<deviceLabel>,<displayName>
				send_command vdvDeviceModule, "'INPUTPROPERTIES-"', itoa(i), ',', itoa(i), ',', INPUT_SOURCES[i][ARRAY_VALUE], ',', INPUT_SOURCES[i][ARRAY_VALUE], ',', INPUT_SOURCES[i][ARRAY_VALUE], '"'";
			}
			
			METADATA_PROPERTY_LAMP_THRESHOLD = atoi(array_get(LAMP_LIFE, sysObjectID_to_model(array_get(varbinds, OID_sysObjectID))));
			if (!METADATA_PROPERTY_LAMP_THRESHOLD) METADATA_PROPERTY_LAMP_THRESHOLD = 2000;
			
			on[vdvDeviceModule, DATA_INITIALIZED];
		}
	}
	
	if (parametersRegistered) {
		switch (oid) {
			case OID_sysUpTime: RmsAssetParameterSetValue(assetClientKey, 'uptime', timeticks_to_time(atol_unsigned(value)));
			case OID_Epson_PWStatus: {
				RmsAssetParameterSetValue(assetClientKey, 'status.projector', array_get(PROJECTOR_STATUS, mid_string(value, 1, 2)));
				RmsAssetParameterSetValue(assetClientKey, 'status.warning', array_get(WARNING_TYPES, mid_string(value, 4, 4)));
				RmsAssetParameterSetValue(assetClientKey, 'status.alarm', array_get(ALARM_TYPES, mid_string(value, 9, 4)));
			}
		}
	}
	
	// SNAPI redirect (for handling by RmsNlSnapiComponents)
	switch (oid) {
		case OID_Epson_Power: {
			[vdvDeviceModule, POWER_FB] = atoi(value);
		}
		case OID_Epson_LampHours: {
			// LAMPTIME-<hours>
			send_command vdvDeviceModule, "'LAMPTIME-', value";
		}
		case OID_Epson_InputSource: {
			// INPUTSELECT-<index>
			send_command vdvDeviceModule, "'INPUTSELECT-', itoa(array_find(INPUT_SOURCES, value))";
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
