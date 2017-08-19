# ssn-central
## SSN messages main router and processor

This module performing proxing between different interfaces and objects via MQTT protocol.
Main goal of this module - sharing low level messages from/to SSN applications located in microcontrollers and integrate it into the high level logical infrastracture.

Messages from SSN applications connected by serial RS485 interface are processed, checked for SSN packages, routed if needed, published into MQTT broker and execute SSN commands.

Module is written in Lua and replaces previous version on Python and C.

# Main execution file: ssnCtrl.lua

Optional parameters - logging level: -l

### Example:
	lua ssnCtrl.lua script -l INFO
	
## Configuration parameters are stored in file ssn_conf.yaml
