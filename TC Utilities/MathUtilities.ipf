#pragma rtGlobals= 3				// Use modern global access method.
#pragma version= 2.01				
#pragma IgorVersion= 9.00			// Requires Igor 9.0 or newer.
#pragma ModuleName= MathUtilities

// ===========================================================================
//                           MATH UTILITIES
// ===========================================================================
// Description: Utility functions for math operations
// Author: Thomas Cahir
// Created: 30-07-2025
// ============================================================================
//	Updated: 30-07-2025 - Initial import
// ****************************************************************************
// CONVERSION CONSTANTS
// Base is whole int. E.g 1 "base" = 1000mA = 100000µA
constant conv_base2uA = 10e5 //Base to µA
constant conv_base2mA = 10e2 //Base to mA
constant conv_mA2base = 10e-2 //mA to base (or mV/mS etc)
constant conv_uA2base = 10e-5 //µA to base (or uV/uS etc)

//strconstant mu = 0xB5 // µ (micro) symbol. Igor doesnt allow raw use of µ
////////////////////////////////////////////////////////////////////////////////////////
//// GENERAL MATH FUNCTIONS
////////////////////////////////////////////////////////////////////////////////////////
Function round2decimals(variable inputValue, variable decimalCount)
// What: Rounds a number to specified decimal places. E.g round2decimals(2.3333, 2) = 2.33
	variable multiplier = 10^decimalCount
	return round(inputValue * multiplier) / multiplier
End
//--------------------------------------------------------------------------------------
Function/S CalculateRelativeMagnitudes(string valueList, string baselineList, [string params])
// What: Calculates relative magnitudes of values compared to a baseline value(s)
	// valueList: Semicolon-separated list of current values. baselineList: Semicolon-separated list of baseline values OR single baseline value
	variable asPercent = 0, useAbsolute = 1 // Default values
	if(!ParamIsDefault(params)) // Parse parameters if provided
		variable paramCount = ItemsInList(params, ";"), paramIndex
		for(paramIndex = 0; paramIndex < paramCount; paramIndex += 1)
			string fullParam = StringFromList(paramIndex, params, ";")
			string param = ModifyString(fullParam, rules="extractBeforeAny", ruleMods="(~;~[~|~")
			string paramArg = ModifyString(fullParam, rules="extractBetweenDelim", ruleMods="(|)", returnType="strict")
			strswitch(LowerStr(param))
			case "Percent": // E.g 20% baseline, 50% etc, 250% etc.
				asPercent = str2num(paramArg)
				break
			case "Absolute": // E.g 1.2x baseline, 0.5x, 2.5x etc.
				useAbsolute = str2num(paramArg)
				break
			endswitch
		endfor
	endif
	variable valueCount = ItemsInList(valueList), baselineCount = ItemsInList(baselineList)
	variable singleBaseline = (baselineCount == 1) // Check if using single baseline for all values
	if(valueCount == 0 || (!singleBaseline && valueCount != baselineCount)) // Check input validity
		PrintAdv("Error: ValueList cannot be empty. BaselineList must be single value or match valueList length", type="error")
		return ""
	endif
	string resultList = "", currentValue, baselineValue = SelectString(singleBaseline, "", StringFromList(0, baselineList))
	variable valueNum, baselineNum, relativeMag, valueIndex
	for(valueIndex = 0; valueIndex < valueCount; valueIndex += 1) // Calculate relative magnitude for each pair
		currentValue = StringFromList(valueIndex, valueList)
		if(!singleBaseline) // Get baseline for this index if not using single baseline
			baselineValue = StringFromList(valueIndex, baselineList)
		endif
		valueNum = useAbsolute ? abs(str2num(currentValue)) : str2num(currentValue)
		baselineNum = useAbsolute ? abs(str2num(baselineValue)) : str2num(baselineValue)
		if(baselineNum == 0) // Handle division by zero
			relativeMag = NaN
		else
			relativeMag = valueNum / baselineNum
			if(asPercent) // Convert to percentage if requested
				relativeMag *= 100
			endif
		endif
		resultList = AddListItem(num2str(relativeMag), resultList, ";", Inf)
	endfor
	return resultList
End
//--------------------------------------------------------------------------------------
////////////////////////////////////////////////////////////////////////////////////////
//// CONVERSIONS
////////////////////////////////////////////////////////////////////////////////////////
// SI = Standard Interational Unit
Function ToMicroseconds(Variable siValue)
    return siValue * 1e6
End
Function ToMilliseconds(Variable siValue)
    return siValue * 1e3
End