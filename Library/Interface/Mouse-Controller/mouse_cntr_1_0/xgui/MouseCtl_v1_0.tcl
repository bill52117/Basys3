# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0" -display_name {Normal}]
  set_property tooltip {Normal} ${Page_0}
  ipgui::add_param $IPINST -name "SYSCLK_FREQUENCY_HZ" -parent ${Page_0}
  #Adding Group
  set Frame_Resulotion [ipgui::add_group $IPINST -name "Frame Resulotion" -parent ${Page_0}]
  ipgui::add_param $IPINST -name "HORIZONTAL_WIDTH" -parent ${Frame_Resulotion}
  ipgui::add_param $IPINST -name "VERTICAL_WIDTH" -parent ${Frame_Resulotion}


  #Adding Page
  set Timing [ipgui::add_page $IPINST -name "Timing"]
  ipgui::add_static_text $IPINST -name "Check Period" -parent ${Timing} -text {Period in miliseconds to check if the mouse is present}
  ipgui::add_param $IPINST -name "CHECK_PERIOD_MS" -parent ${Timing}
  ipgui::add_static_text $IPINST -name "space" -parent ${Timing} -text {}
  ipgui::add_static_text $IPINST -name "Timeout Period" -parent ${Timing} -text {Timeout period in miliseconds when the mouse presence is checked}
  ipgui::add_param $IPINST -name "TIMEOUT_PERIOD_MS" -parent ${Timing}


}

proc update_PARAM_VALUE.CHECK_PERIOD_MS { PARAM_VALUE.CHECK_PERIOD_MS } {
	# Procedure called to update CHECK_PERIOD_MS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.CHECK_PERIOD_MS { PARAM_VALUE.CHECK_PERIOD_MS } {
	# Procedure called to validate CHECK_PERIOD_MS
	return true
}

proc update_PARAM_VALUE.HORIZONTAL_WIDTH { PARAM_VALUE.HORIZONTAL_WIDTH } {
	# Procedure called to update HORIZONTAL_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.HORIZONTAL_WIDTH { PARAM_VALUE.HORIZONTAL_WIDTH } {
	# Procedure called to validate HORIZONTAL_WIDTH
	return true
}

proc update_PARAM_VALUE.SYSCLK_FREQUENCY_HZ { PARAM_VALUE.SYSCLK_FREQUENCY_HZ } {
	# Procedure called to update SYSCLK_FREQUENCY_HZ when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SYSCLK_FREQUENCY_HZ { PARAM_VALUE.SYSCLK_FREQUENCY_HZ } {
	# Procedure called to validate SYSCLK_FREQUENCY_HZ
	return true
}

proc update_PARAM_VALUE.TIMEOUT_PERIOD_MS { PARAM_VALUE.TIMEOUT_PERIOD_MS } {
	# Procedure called to update TIMEOUT_PERIOD_MS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.TIMEOUT_PERIOD_MS { PARAM_VALUE.TIMEOUT_PERIOD_MS } {
	# Procedure called to validate TIMEOUT_PERIOD_MS
	return true
}

proc update_PARAM_VALUE.VERTICAL_WIDTH { PARAM_VALUE.VERTICAL_WIDTH } {
	# Procedure called to update VERTICAL_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.VERTICAL_WIDTH { PARAM_VALUE.VERTICAL_WIDTH } {
	# Procedure called to validate VERTICAL_WIDTH
	return true
}


proc update_MODELPARAM_VALUE.SYSCLK_FREQUENCY_HZ { MODELPARAM_VALUE.SYSCLK_FREQUENCY_HZ PARAM_VALUE.SYSCLK_FREQUENCY_HZ } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SYSCLK_FREQUENCY_HZ}] ${MODELPARAM_VALUE.SYSCLK_FREQUENCY_HZ}
}

proc update_MODELPARAM_VALUE.CHECK_PERIOD_MS { MODELPARAM_VALUE.CHECK_PERIOD_MS PARAM_VALUE.CHECK_PERIOD_MS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.CHECK_PERIOD_MS}] ${MODELPARAM_VALUE.CHECK_PERIOD_MS}
}

proc update_MODELPARAM_VALUE.TIMEOUT_PERIOD_MS { MODELPARAM_VALUE.TIMEOUT_PERIOD_MS PARAM_VALUE.TIMEOUT_PERIOD_MS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.TIMEOUT_PERIOD_MS}] ${MODELPARAM_VALUE.TIMEOUT_PERIOD_MS}
}

proc update_MODELPARAM_VALUE.HORIZONTAL_WIDTH { MODELPARAM_VALUE.HORIZONTAL_WIDTH PARAM_VALUE.HORIZONTAL_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.HORIZONTAL_WIDTH}] ${MODELPARAM_VALUE.HORIZONTAL_WIDTH}
}

proc update_MODELPARAM_VALUE.VERTICAL_WIDTH { MODELPARAM_VALUE.VERTICAL_WIDTH PARAM_VALUE.VERTICAL_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.VERTICAL_WIDTH}] ${MODELPARAM_VALUE.VERTICAL_WIDTH}
}

