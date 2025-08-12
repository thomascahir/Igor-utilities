#pragma rtGlobals= 3				// Use modern global access method.
#pragma version= 2.01				
#pragma IgorVersion= 9.00			// Requires Igor 9.0 or newer.
#pragma ModuleName= CommonUtilities
#include "IndexingUtilities"
// ===========================================================================
//                           COMMON UTILITIES
// ===========================================================================
// Description: General purpose utilities to cut down on code duplication
// Author: Thomas Cahir
// Created: 04-07-2025
// This is a test/WIP approach to reducing for loop in main files by making a dynamic function call system.
// ===========================================================================
//	Updated: 09-07-2025 - Moved GetFuncInfo to IndexingUtils
//*********************************************************************************************************************
////////////////////////////////////////////////////////////////////////////////////////
//// LOOP UTILITIES
////////////////////////////////////////////////////////////////////////////////////////
//----------------------------------------------------------------------------------------------------------------------------------------------
Structure forEachParams
    string callBackFunc
    variable startIndex
    variable endIndex
    variable upperBound
    string funcParamInputs
EndStructure
//----------------------------------------------------------------------------------------------------------------------------------------------
Function forEachIndex(string callBackFunc, variable startIndex, variable endIndex, variable upperBound, string funcParamInputs)
// What: Universal for-loop that calls a callback function for each iteration to reduce code duplication
    // startIndex: Starting index for the loop. endIndex: Ending index for the loop (inclusive). upperBound: Safety limit - ensures loop never exceeds this value regardless of endIndex. You must set this.
    // callbackFunc: Function reference to call for each iteration. [paramList]: Optional string parameter containing all parameters as key-value pairs (key=value;key2=value2)
    // paramString: Best Practice Hierarchy (High to low separators) is '; [] , () <> : then root item ='. e.g Item1[Key1=Val1,Key2=Val2];Item2[Key1=Val1,Key2=Val2]
	variable index, continueLoop = 1, protoWaveParam = 0, protoStringParam = 0, protoVariableParam = 0
	string funcInfo = ReplaceString(";",FunctionInfo(callBackFunc), ",")
	string requiredParams = "index= ,paramList=", optionalParams = "", funcRefName=ModifyString(funcInfo, rules="extractBetweenDelim", ruleMods="NAME:|,")
    endIndex = min(endIndex, upperBound-1)
    //// 1 - GET TARGET FUNCTION INFORMATION
    // Collect its paramters to rebuild Function Name(param1, param2, [optionalParam1 etc])
    [string allParams, string waveParams, string stringParams, string variableParams, string structParams] = GetFunctionParams(funcRefName)
    [string allOptParams, string waveOptParams, string stringOptParams, string variableOptParams] = GetFunctionOptionalParams(funcRefName)
    string parameterPattern = GetFuncInfo(funcRefName, infoType="paramPattern")

    //// 2 - PROCESSS/PARSE PARAMS  
    // Best practice for this is to make target functions that list params in following order. 1. Waves. 2 Strings 3. Variablbes (then same order for optional params)
    // E.g myFunction wave w, string s1, string s2, variable x1, variable x2, variable x3
    string str1, str2, str3, struct1, struct2, struct3
    variable var1, var2, var3
    if(CheckString(allParams, "Wave"))
        Wave/Z wave1 = $waveParams
        Wave/Z wave2 = $waveParams
    endif
    string callbackFuncString = funcRefName + "(" + allParams
    if(strlen(allOptParams) > 0)
        callbackFuncString += ", [" + allOptParams + "]"
    endif
    callbackFuncString += ")"


    //// 3 - SELECT CALLBACK FUNCTION BASED ON PARAMETER PATTERN (e.g variable,string (V,S) or variable,variable, optional string etc (V,V,[S])) 
    // Add in most common patterns aquired from index matching 
    str1 = funcParamInputs // MVP parsing of funcParamInputs. This will be expanded later.
    strswitch(parameterPattern)
        case "None": // If function has no inputs
            FUNCREF proto_None_t pFunc_None = $callBackFunc
            for(index = startIndex; index <= endIndex && continueLoop; index += 1)
                continueLoop = pFunc_None()
            endfor
            break
        case "S": // 1 STRING
            FUNCREF proto_S_t pFunc_S = $callBackFunc
            for(index = startIndex; index <= endIndex && continueLoop; index += 1)
                continueLoop = pFunc_S(str1)
            endfor
            break
        case "V": // 1 VARIABLE
            FUNCREF proto_V_t pFunc_V = $callBackFunc
            for(index = startIndex; index <= endIndex && continueLoop; index += 1)
                continueLoop = pFunc_V(index)
            endfor
            break
        case "W": // 1 WAVE
            FUNCREF proto_W_t pFunc_W = $callBackFunc
            for(index = startIndex; index <= endIndex && continueLoop; index += 1)
                continueLoop = pFunc_W(wave1)
            endfor
            break
        case "V,S": // 1 VARIABLE, 1 STRING
            FUNCREF proto_VS_t pFunc_VS = $callBackFunc
            for(index = startIndex; index <= endIndex && continueLoop; index += 1)
                continueLoop = pFunc_VS(index, str1)
            endfor
            break
        case "S,V": // 1 STRING, 1 VARIABLE
            FUNCREF proto_SV_t pFunc_SV = $callBackFunc
            for(index = startIndex; index <= endIndex && continueLoop; index += 1)
                continueLoop = pFunc_SV(str1, var1)
            endfor
            break
        case "S,S": // 2 STRINGS
            FUNCREF proto_SS_t pFunc_SS = $callBackFunc
            for(index = startIndex; index <= endIndex && continueLoop; index += 1)
                continueLoop = pFunc_SS(str1, str2)
            endfor
            break
        case "V,V": // 2 VARIABLES
            FUNCREF proto_VV_t pFunc_VV = $callBackFunc
            for(index = startIndex; index <= endIndex && continueLoop; index += 1)
                continueLoop = pFunc_VV(var1, var2)
            endfor
            break
        case "W,W": // 2 WAVES etc...
            FUNCREF proto_WW_t pFunc_WW = $callBackFunc
            for(index = startIndex; index <= endIndex && continueLoop; index += 1)
                continueLoop = pFunc_WW(wave1, wave2)
            endfor
        default:
            PrintAdv("Error: Unsupported parameter pattern: " + parameterPattern + " for function: " + funcRefName, type = "warning", state="warning")
            return -1
            break
    endswitch

    return index - 1 // Return the last processed index
End
//--------------------------------------------------------------------------------------
////////////////////////////////////////////////////////////////////////////////////////
//// PROTOTYPE FUNCTIONS (for FUNCREF signatures)
////////////////////////////////////////////////////////////////////////////////////////
Function proto_None_t()
    return 1
End
Function proto_S_t(string p1)
    return 1
End
Function proto_V_t(variable p1)
    return 1
End
Function proto_VS_t(variable p1, string p2)
    return 1
End
Function proto_SV_t(string p1, variable p2)
    return 1
End
Function proto_W_t(WAVE p1)
    return 1
End
Function proto_SS_t(string p1, string p2)
    return 1
End
Function proto_VV_t(variable p1, variable p2)
    return 1
End
Function proto_WW_t(WAVE p1, WAVE p2)
    return 1
End
//--------------------------------------------------------------------------------------
////////////////////////////////////////////////////////////////////////////////////////
//// CALLBACK FUNCTIONS
////////////////////////////////////////////////////////////////////////////////////////
Function cb_PopulateMatchingFolders(variable index, string paramList)
//What: Callback for populating matching folders wave
    //[string allFolders, string saveDF, string waveName, string d1, string d2] = ExtractParams(paramList, "allFolders;saveDF;waveName", valueSeperator="=", nameSeperator=";")
	string saveDF = ModifyString(paramList, rules="extractBetweenDelim", ruleMods="saveDF=[|]")
	string waveName = ModifyString(paramList, rules="extractBetweenDelim", ruleMods="waveName=[|]")
	string allFolders = ModifyString(paramList, rules="extractBetweenDelim", ruleMods="allFolders=[|]")
	WAVE/T matchingFolders = $waveName
    matchingFolders[index][%Name] = StringFromList(index, allFolders, ",")
    matchingFolders[index][%Path] = saveDF + StringFromList(index, allFolders, ",") + ":"
    return 1 // Return 1 to continue the loop
End
//--------------------------------------------------------------------------------------
Function cb_FilterListByPattern(variable index, string paramList)
//What: Callback for filtering a list based on a pattern match
    [string sourceList, string pattern, string listSep, string d1, string d2] = ExtractParams(paramList, ";|=")
    if(strlen(listSep) == 0)
        listSep = ";"
    endif
    string item = StringFromList(index, sourceList, listSep)
    return GrepString(item, pattern) > 0 // Return 1 if item matches pattern, 0 otherwise
End
////////////////////////////////////////////////////////////////////////////////////////
//// TEST FUNCTIONS
////////////////////////////////////////////////////////////////////////////////////////