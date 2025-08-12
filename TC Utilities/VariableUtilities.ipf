#pragma rtGlobals= 3				// Use modern global access method.
#pragma version= 2.01				
#pragma IgorVersion= 9.00			// Requires Igor 9.0 or newer.
#pragma ModuleName= VariableUtilities

// ===========================================================================
//                           VARIABLE UTILITIES
// ===========================================================================
// Description: Utility functions for variables, strings, constants etc. 
// Author: Thomas Cahir
// Created: 25-06-2025
// ===========================================================================
//	Updated: 25/06/2025 - Imported from TC Utility in this folder
//			 08/07/2025 - Added various functions, reorganised
//*********************************************************************************************************************
////////////////////////////////////////////////////////////////////////////////////////
//// STRING AND PARAM MANIPULATION
////////////////////////////////////////////////////////////////////////////////////////
Function/S ModifyString(string inputStr, [string rules, string ruleMods, string ruleListDelim, string returnType, string failParam])
// What: ModifyString is designed to apply a series of edits to a single string IN ORDER via a rules and rulemods list.
    // [returnType]: optional how you want to handle failed processes. E.g "strict" will return empty string if nothing found instead of returning unaltered string, "normal" (default) will keep processing string even if specific alterations fail
    // [failParam]: optional string to return if operationFailed (e.g "strict" mode)
    string ruleList, modList, rule, ruleMod, outStr, prevOutStr, shorthandList, ruleTypes
    variable i, j, numRules, insideParam, firstQ, secondQ, delimPos, afterStart, endPos, operationFailed = 0
    if(ParamIsDefault(rules))
        outStr = CleanupName(inputStr, 1)
        return outStr
    endif
    if(ParamIsDefault(ruleListDelim))
        ruleListDelim = ";"
    endif
    if(ParamIsDefault(returnType))
        returnType = "normal"
    endif
    if(ParamIsDefault(failParam))
        failParam = ""
    endif
    ruleList = rules; modList = SelectString(ParamIsDefault(ruleMods), ruleMods, "")
    outStr = inputStr; numRules = ItemsInList(ruleList, ruleListDelim)
    ruleTypes = "removeText;removeFromList;removeEmptyItems;extractAfter;extractBefore;extractBeforeAny;extractBetweenDelim;extractValue;extractFromList;inQuotes;splitSublist;addToList;replaceText;replaceItemsInList"
    shorthandList = "RTX;RFL;REI;EAF;EBF;EBA;EBD;EVL;EFL;INQ;SSL;ATL;RPT;RIL" // shorthand list
    for(i=0; i<numRules; i+=1)
        rule = StringFromList(i, ruleList, ruleListDelim); ruleMod = StringFromList(i, modList, ruleListDelim)
        if(strlen(rule) <= 3)
            //rule = GetMatchingListItem(rule, ruleMod)
            variable typeIndex = WhichListItem(rule, shorthandList)
            rule = StringFromList(typeIndex, ruleTypes)
        endif
        ruleMod = ReplaceString(num2char(1), ruleMod, ";"); prevOutStr = outStr; operationFailed = 0
        strswitch(rule)
            //// SUBTRACTIVE CHANGES - Rules that remove/extract from string while maintaining the whole
            case "removeText":
                if(strlen(StringFromList(0, ruleMod, ruleListDelim))>0)
                    outStr = ReplaceString(StringFromList(0, ruleMod, ruleListDelim), outStr, "")
                    if(StringMatch(outStr, prevOutStr))
                        operationFailed += 1  // Text to remove not found
                    endif
                endif
                break
            case "removeFromList":
                outStr = RemoveItemsFromList(outStr, ruleMod)
                if(StringMatch(outStr, prevOutStr))
                    operationFailed += 1  // Items to remove not found
                endif
                break
            case "removeEmptyItems":
                outStr = RemoveEmptyItemsFromList(outStr, ruleMod)
                if(StringMatch(outStr, prevOutStr))
                    operationFailed += 1  // Items to remove not found
                endif
                break
            //// EXTRACTIVE - Rules that extract a specific item or value from the string
            case "extractAfter":
                outStr = ExtractByDelimiter(outStr, StringFromList(0, ruleMod, ruleListDelim), "after")
                if(StringMatch(outStr, prevOutStr))
                    operationFailed += 1  // Delimiter not found
                endif
                break
            case "extractBefore":
                outStr = ExtractByDelimiter(outStr, StringFromList(0, ruleMod, ruleListDelim), "before")
                if(StringMatch(outStr, prevOutStr))
                    operationFailed += 1  // Delimiter not found
                endif
                break
            case "extractBeforeAny":
                string delimiterList = StringFromList(0, ruleMod, "|")
                string listDelimiter = StringFromList(1, ruleMod, "|")
                outStr = ExtractBeforeAnyDelimiter(outStr, delimiterList=delimiterList, listDelimiter=listDelimiter)
                if(StringMatch(outStr, prevOutStr))
                    operationFailed += 1  // No delimiters found
                endif
                break
            case "extractBetweenDelim": // Extract betweeb delim e.g "hello(1,2,3)" to "1,2,3"
                outStr = ExtractBetweenDelimiters(outStr, StringFromList(0, ruleMod, ruleListDelim))
                if(StringMatch(outStr, prevOutStr))
                    operationFailed += 1  // Delimiters not found
                endif
                break
            case "extractValue": // Extract numeric value
                outStr = ExtractNumericValue(outStr, ruleMod)
                if(strlen(outStr) == 0 && strlen(prevOutStr) > 0)
                    operationFailed += 1  // No numeric values found
                endif
                break
            case "extractFromList": // Extract item from list
                outStr = ExtractFromList(outStr, ruleMod)
                if(StringMatch(outStr, prevOutStr))
                    operationFailed += 1  // Index not found or list not recognized
                endif
                break
            case "inQuotes":
                firstQ = strsearch(outStr, "\"", 0)
                if(firstQ>=0)
                    secondQ = strsearch(outStr, "\"", firstQ+1)
                    if(secondQ>firstQ)
                        outStr = outStr[firstQ+1, secondQ-1]
                    else
                        outStr = ""; operationFailed += 1  // No closing quote
                    endif
                else
                    outStr = ""; operationFailed += 1  // No quotes found
                endif
                break
            case "splitSublist":
                outStr = ExtractSplitSublist(outStr, ruleMod)
                if(StringMatch(outStr, prevOutStr))
                    operationFailed += 1  // Split operation failed
                endif
                break
            // case "getMatchingListItem": // Get matching list item
            //     outStr = GetMatchingListItem(outStr, ruleMod)
            //     break
            //// ADDITIVE CHANGES - Rules that add things (rarely fail)
            case "add": // Add text to end of string
                outStr = outStr + ruleMod
                break
            case "addToList": // Add items to list (more cleanly than inbuilt func)
                outStr = AddItemsToList(outStr, ruleMod)
                break
            case "replaceText": // Replace text in string
                string findStr, replStr, delimStr, typeStr; variable numParts
                numParts = ItemsInList(ruleMod, "|"); findStr = StringFromList(0, ruleMod, "|"); replStr = StringFromList(1, ruleMod, "|")
                delimStr = StringFromList(2, ruleMod, "|"); typeStr = StringFromList(3, ruleMod, "|")
                if(numParts >= 4)
                    outStr = ReplaceInDelimitedString(outStr, findStr, replStr, delimStr, type=typeStr)
                elseif(numParts == 3)
                    outStr = ReplaceInDelimitedString(outStr, findStr, replStr, delimStr)
                elseif(numParts == 2)
                    outStr = ReplaceInDelimitedString(outStr, findStr, replStr, ";")
                else
                    operationFailed += 1  // Invalid parameters
                    PrintAdv("ModifyString replaceText: Invalid number of parts: " + num2str(numParts), type="error")
                endif
                if(!operationFailed && StringMatch(outStr, prevOutStr))
                    operationFailed += 1  // Text to replace not found
                endif
                break
            case "replaceItemsInList": // Replace items in list. e.g (1,2,3) to (4,5,6)
                numparts = ItemsInList(ruleMod, "|")
                if(numparts < 2)
                    operationFailed += 1 // Need at least old and new items
                elseif(numparts == 2)
                    outStr = ReplaceItemsInList(outStr, ruleMod)
                elseif(numparts == 3)
                    string replSpec = StringFromList(0, ruleMod, "|") + "|" + StringFromList(1, ruleMod, "|"), sepStr = StringFromList(2, ruleMod, "|")
                    outStr = ReplaceItemsInList(outStr, replSpec, separator=sepStr)
                endif
                break
            case "enclose": // Enclose string in thing
                outStr = encloseString(outStr, ruleMod)
                break
            //// TRIMMING - Rules that remove whitespace or other characters (rarely fail)
            case "trim": // Remove leading and trailing whitespace
                outStr = TrimString(outStr)
                break
            case "trimAll": // Remove all whitespace
                outStr = TrimString(outStr, 1)
                break
            case "cleanup": // Cleanup name
                outStr = CleanupName(outStr, str2num(ruleMod))
                break
        endswitch
        if(operationFailed > 0 && StringMatch(returnType, "strict"))
            return failParam
        endif
    endfor
    if(numRules==0)
        outStr = CleanupName(inputStr, 1)
    endif
    PrintAdv("ModifyString Done: Initial Input = " + inputStr + ") | Final Output =" + outStr, state="debugFull", type="process")
    return outStr
End
//--------------------------------------------------------------------------------------
Function [String p1, string p2, string p3, string p4, string p5] ExtractParams(string inputStr, string p1to5names, [string valueSeperator, string nameSeperator, string paramSeperator])
// What: Extract upto 5 paramters from a complex string list and return. You will need to declare 5 variables on calling even if you only want 1-4.
	string workStr, currentKey, keyValue, paramName = "", paramValue = ""; variable i, keyPos, valueStart, valueEnd, nextColonPos
	p1 = ""; p2 = ""; p3 = ""; p4 = ""; p5 = "";
	if(ParamIsDefault(valueSeperator))
		valueSeperator = "="
	endif
	if(ParamIsDefault(nameSeperator))
		nameSeperator = ","
	endif
	if(ParamIsDefault(paramSeperator))
		paramSeperator = ";"
	endif
	workStr = inputStr
	for(i = 0; i < 5; i += 1)
		paramName = StringFromList(i, p1to5names, nameSeperator)
		paramValue = ModifyString(inputStr, rules="extractBetweenDelim", ruleMods=paramName + valueSeperator + "|" + paramSeperator, returnType="strict")
		if(strlen(paramValue) == 0)
			continue
		endif
		switch(i)
			case 0: 
				p1 = paramValue
				break
			case 1: 
				p2 = paramValue
				break
			case 2: 
				p3 = paramValue
				break
			case 3: 
				p4 = paramValue
				break
			case 4: 
				p5 = paramValue
				break
		endswitch
	endfor
	return [p1, p2, p3, p4, p5]
End
//--------------------------------------------------------------------------------------
Function [Variable p1, Variable p2, Variable p3, Variable p4, Variable p5] ExtractParamsVars(string inputStr, string seperators)
// What: Extract upto 5 numeric paramters from a complex string list and return. You will need to declare 5 variables on calling even if you only want 1-4.
	string workStr, delimiter, keyList, currentKey, keyValue; variable i, keyPos, valueStart, valueEnd, nextColonPos
	p1 = NaN; p2 = NaN; p3 = NaN; p4 = NaN; p5 = NaN
	delimiter = StringFromList(0, seperators, ";"); keyList = seperators[strlen(delimiter)+1, inf]; workStr = inputStr
	variable bracketStart = strsearch(workStr, "[", 0); variable bracketEnd = strsearch(workStr, "]", 0)
	if(bracketStart >= 0 && bracketEnd > bracketStart)
		workStr = workStr[bracketStart+1, bracketEnd-1]
	endif
	for(i = 0; i < 5; i += 1)
		currentKey = StringFromList(i, keyList, ";")
		if(strlen(currentKey) == 0)
			break
		endif
		keyPos = strsearch(workStr, currentKey + delimiter, 0)
		if(keyPos >= 0)
			valueStart = keyPos + strlen(currentKey) + strlen(delimiter)
			nextColonPos = strsearch(workStr, ":", valueStart)
			valueEnd = (nextColonPos >= 0) ? nextColonPos - 1 : strlen(workStr) - 1
			keyValue = workStr[valueStart, valueEnd]
			switch(i)
				case 0: 
					p1 = str2num(keyValue); 
					break
				case 1: 
					p2 = str2num(keyValue); 
					break
				case 2: 
					p3 = str2num(keyValue); 
					break
				case 3: 
					p4 = str2num(keyValue); 
					break
				case 4: 
					p5 = str2num(keyValue); 
					break
			endswitch
		endif
	endfor
	return [p1, p2, p3, p4, p5]
End
//--------------------------------------------------------------------------------------
Function CheckString(string checkThisString, string containsThis)
// What: Checks if string matches pattern, combinging StringMatch and GrepString into one call.
	// Returns match type: 0 = neither, 1 = StringMatch (exact match), 2 = GrepString (regex/ partial match)
	variable matchType = 0, minLen = min(strlen(checkThisString), strlen(containsThis)), prefixLen = max(3, floor(minLen * 0.6))
	if(StringMatch(checkThisString, containsThis) == 1) // Exact Match
		matchType = 1
	elseif(GrepString(checkThisString, containsThis) == 1 || GrepString(containsThis, checkThisString) == 1)  // Regex Match
		matchType = 2
	elseif(minLen >= 3 && cmpstr(checkThisString[0,prefixLen-1], containsThis[0,prefixLen-1], 2) == 0) // Partial Match
		matchType = 3
	endif
	return matchType
End
//--------------------------------------------------------------------------------------
Function CheckConstant(string constantName) // TBD
// What: Safe way to check if a constant exists and return its value without causing compile errors if its non existant.
	string constantValue
	// add check stuff	
end
//--------------------------------------------------------------------------------------
Function [Variable numValue, String strValue, variable flag] GetGlobalVariable(string variableName, string variableType, [string variableValue, variable checkFolders, variable saveInDF])
// What: Lookup and creation func for global variable from repository at root:Packages:GlobalVariables or in local folder.
	// this is a shittly written piece of code, fix this dumpster fire when time permits. way toolong et c
	// numValue: if variable, strValue: if string, flag: 1 if found, 0 if user cancels 
	String savedDF = GetDataFolder(1), inputValue = "", foldersToSearch = "", currentFolder = "", varNameToCreate = variableName
	String numVarName, strVarName // For prefix variations
	Variable isBoth = WhichListItem(LowerStr(variableType), "both;dual;all") >= 0, isNumeric = WhichListItem(LowerStr(variableType), "variable;num;number;numeric") >= 0, found = 0, i
	strValue = ""; numValue = NaN
	checkFolders = ParamIsDefault(checkFolders) ? 0 : checkFolders // Default search mode
	if(checkFolders != 3) // Include packages unless mode 3
		SetCreateDataFolder("root:Packages:GlobalVariables")
		foldersToSearch = "root:Packages:GlobalVariables:"
	endif
	if(checkFolders > 0) // Add current folder for modes 1-3
		foldersToSearch += savedDF + ";"
	endif
	if(checkFolders == 2) // Add subfolders for mode 2
		foldersToSearch += GetAllSubFolders()
	endif
	for(i=0; i < ItemsInList(foldersToSearch) && !found; i+=1) // Search for variable in all folders
		currentFolder = StringFromList(i, foldersToSearch)
		// Try original name first
		if(exists(currentFolder + variableName) > 0) // Check if exists
			found = 1
			if(isBoth || isNumeric) // Get numeric value if needed
				NVAR/Z globalVar = $currentFolder + variableName
				if(NVAR_Exists(globalVar))
					numValue = globalVar
				endif
			endif
			if(isBoth || (!isNumeric && !isBoth)) // Get string value if needed
				SVAR/Z globalStr = $currentFolder + variableName
				if(SVAR_Exists(globalStr))
					strValue = globalStr
				endif
			endif
		endif
		// Try with prefix if not found
		if(!found && (isBoth || isNumeric) && strsearch(variableName, "v_", 0) != 0) // Try v_ prefix for numeric
			numVarName = "v_" + variableName
			if(exists(currentFolder + numVarName) > 0)
				found = 1
				NVAR/Z globalVar = $currentFolder + numVarName
				if(NVAR_Exists(globalVar))
					numValue = globalVar
				endif
			endif
		endif
		if(!found && (isBoth || (!isNumeric && !isBoth)) && strsearch(variableName, "S_", 0) != 0) // Try S_ prefix for string
			strVarName = "S_" + variableName
			if(exists(currentFolder + strVarName) > 0)
				found = 1
				SVAR/Z globalStr = $currentFolder + strVarName
				if(SVAR_Exists(globalStr))
					strValue = globalStr
				endif
			endif
		endif
	endfor
	String popupResult = ""
	if(!found) // Create new if not found
		currentFolder = StringFromList(0, foldersToSearch) // First folder in list
		// Add prefix if needed for new variables
		if(isNumeric && strsearch(varNameToCreate, "v_", 0) != 0)
			varNameToCreate = "v_" + varNameToCreate
			popupResult = "variable"
		endif
		if(!isNumeric && strsearch(varNameToCreate, "S_", 0) != 0)
			varNameToCreate = "S_" + varNameToCreate
			popupResult = "string"
		endif
		// Get value from param or prompt
		if(!ParamIsDefault(variableValue))
			inputValue = variableValue
		else
			Prompt popupResult, "Variable type:", popup "variable;string;both"
			Prompt inputValue, "Enter value for " + variableName + ":"
			DoPrompt "Create Global Variable", inputValue, popupResult
			if(V_Flag != 0)
				return [NaN, "", 0]
			endif
			isBoth = StringMatch(popupResult, "both")
			isNumeric = StringMatch(popupResult, "variable")
		endif
		// Create variable(s)
		if(isBoth || isNumeric)
			Variable/G $currentFolder + varNameToCreate = str2num(inputValue)
			numValue = str2num(inputValue)
		endif
		if(isBoth || (!isNumeric && !isBoth))
			String/G $(currentFolder + varNameToCreate + SelectString(isBoth, "", "_str")) = inputValue
			strValue = inputValue
		endif
	endif
	SetDataFolder savedDF
	return [numValue, strValue, 1]
End
//--------------------------------------------------------------------------------------
Function/S AppendToList(string inputList, string appendStr)
//// What: Takes a string list and appends a given string to each item
	// E.g 0,100,200 -> 0uA,100uA,200uA / 0A,100A,200A etc
	string outputList = ""
	variable numItems = ItemsInList(inputList)
	variable i	
	for(i=0; i<numItems; i+=1)
		string currentItem = StringFromList(i, inputList)
		outputList = AddListItem(currentItem + appendStr, outputList)
	endfor
	print outputList
	return outputList
End
//--------------------------------------------------------------------------------------
Function/S ExtractBetweenDelimiters(string inputStr, string delimiterSpec)
//What: Extract between delimter. E.g input=myWord=Hello;Goodbye. delim=myWord=|; will results in 'Hello'
   string startDelim, endDelim
   variable delimBar, startPos, afterStart, endPos
   delimBar = strsearch(delimiterSpec, "|", 0)
   if(delimBar == -1)
       return inputStr
   endif
   startDelim = delimiterSpec[0, delimBar-1]
   endDelim = delimiterSpec[delimBar+1, inf]
   startPos = strsearch(inputStr, startDelim, 0)
   if(startPos == -1)
       return inputStr
   endif
   afterStart = startPos + strlen(startDelim)
   endPos = strsearch(inputStr, endDelim, afterStart)
   if(endPos >= afterStart)
       return inputStr[afterStart, endPos-1]
   else
       return inputStr[afterStart, strlen(inputStr)-1]
   endif
End
//--------------------------------------------------------------------------------------
Function/S EncloseString(string inputStr, string enclosureSpec)
// What: Enclose a string in specified thing
    string enStart, enEnd
    if(StringMatch(enclosureSpec, "quotes"))
        return "\"" + inputStr + "\""
    elseif(StringMatch(enclosureSpec, "bracket"))
        return "(" + inputStr + ")"
    elseif(StringMatch(enclosureSpec, "brace"))
        return "{" + inputStr + "}"
    else
        enStart = "X"; enEnd = "Y"
        if(ItemsInList(enclosureSpec, "|") == 2)
            enStart = StringFromList(0, enclosureSpec, "|"); enEnd = StringFromList(1, enclosureSpec, "|")
        endif
        return enStart + inputStr + enEnd
    endif
End
//--------------------------------------------------------------------------------------
Function/S ReplaceInDelimitedString(string inputStr, string replace, string with, string delim, [string type])
// What: Replaces characters in a delimited string, supporting both single and multiple replacements
    // inputStr: Input string with delimiters | delim: Delimiter character. replace: Character(s) to replace (can be delimited list) | with: Character(s) to replace with (can be delimited list)
    // [type]: Optional - "all" (default) applies all replacements to each item, "item" applies nth replacement to nth item
    string outputStr = "", currentItem = ""
    variable itemIndex, replaceIndex, multiReplace = ItemsInList(replace, delim) > 1
    if(ParamIsDefault(type))
        type = "all"
    endif
    for(itemIndex=0; itemIndex<ItemsInList(inputStr, delim); itemIndex+=1) // Process each item in input string
        currentItem = StringFromList(itemIndex, inputStr, delim)        
        if(StringMatch(type, "item") && multiReplace) // Item-specific replacement mode
            replaceIndex = min(itemIndex, ItemsInList(replace, delim)-1) // Prevent index out of bounds
            currentItem = ReplaceString(StringFromList(replaceIndex, replace, delim), currentItem, StringFromList(replaceIndex, with, delim))
        else // Default "all" mode - apply all replacements to each item
            if(multiReplace) // Multiple replacements in sequence
                for(replaceIndex=0; replaceIndex<ItemsInList(replace, delim); replaceIndex+=1)
                    currentItem = ReplaceString(StringFromList(replaceIndex, replace, delim), currentItem, StringFromList(replaceIndex, with, delim))
                endfor
            else // Single replacement
                currentItem = ReplaceString(replace, currentItem, with)
            endif
        endif     
        if(strlen(outputStr) > 0)
            outputStr += delim
        endif
        outputStr += currentItem
    endfor
    return outputStr
End
//--------------------------------------------------------------------------------------
Function/S ExtractByDelimiter(string inputStr, string delimiter, string type)
// What: Extract text before or after a specified delimiter. type = "before" or "after"
    variable delimPos
    if(strlen(delimiter) == 0)
        return inputStr
    endif
    delimPos = strsearch(inputStr, delimiter, 0)
    if(StringMatch(type, "after"))
        if(delimPos >= 0)
            return inputStr[delimPos+strlen(delimiter), inf]
        endif
    else // before
        if(delimPos > 0)
            return inputStr[0, delimPos-1]
        endif
    endif
    return inputStr
End
//--------------------------------------------------------------------------------------
Function/S ExtractFromList(string inputStr, string indexSpec)
//what: Helper function for fromList
    string delimList, tmpDelim, tmpOut
    variable delimCount, delim, targetIndex
    delimList = ";|,|.|:|/|-|]|["; delimCount = ItemsInList(delimList, "|"); targetIndex = str2num(indexSpec)
    for(delim=0; delim<delimCount; delim+=1)
        tmpDelim = StringFromList(delim, delimList, "|"); tmpOut = StringFromList(targetIndex, inputStr, tmpDelim)
        if(StrLen(tmpOut) > 0 && !StringMatch(tmpOut, inputStr))
            return tmpOut
        endif
    endfor
    return inputStr
End
//--------------------------------------------------------------------------------------
Function/S ExtractBeforeAnyDelimiter(string inputStr, [string delimiterList, string listDelimiter])
//What: Helper function for extractBeforeAny
    variable pos, curPos, k, numDelims  
    if(ParamIsDefault(delimiterList) || strlen(delimiterList) == 0)
        delimiterList = "{}~[]~()~,~;~:~/~-~]~["
    endif
    if(ParamIsDefault(listDelimiter) || strlen(listDelimiter) == 0)
        listDelimiter = "~"
    endif
    pos = -1; numDelims = ItemsInList(delimiterList, listDelimiter)
    for(k=0; k<numDelims; k+=1)
        curPos = strsearch(inputStr, StringFromList(k, delimiterList, listDelimiter), 0)
        if(curPos >= 0 && (pos == -1 || curPos < pos))
            pos = curPos
        endif
    endfor
    if(pos >= 0)
        return inputStr[0, pos-1]
    endif
    return inputStr
End
//--------------------------------------------------------------------------------------
Function/S ExtractNumericValue(string inputStr, string includeDecimal)
//What: Helper function for extractValue
    string numStr = "", currentChar; variable charCount;
    for(charCount=0; charCount<strlen(inputStr); charCount+=1)
        currentChar = inputStr[charCount,charCount]
        if(strsearch("0123456789", currentChar, 0) >= 0)
            numStr += currentChar
        elseif(StringMatch(includeDecimal, "includeDecimal") && cmpstr(currentChar, ".") == 0)
            numStr += "."
        endif
    endfor
    return numStr
End
//--------------------------------------------------------------------------------------
Function/S ExtractSplitSublist(string inputStr, string splitSpec)
// What: Split up complex list
    string ssAction, ssList, ssSep, ssTemp, ssItem, ssFlat, ssJoin, ssFlat2
    variable ssIndex, ssSepCount, ssI, ssJ, ssN, ssM, ssK, startI, endI
    ssAction = StringFromList(0, splitSpec, "|"); ssIndex = str2num(StringFromList(1, splitSpec, "|"))
    ssSepCount = str2num(StringFromList(2, splitSpec, "|")); ssList = inputStr
    ssSep = StringFromList(3, splitSpec, "|"); ssN = ItemsInList(ssList, ssSep)
    ssFlat = ""; ssJoin = ";"
    if(StringMatch(ssAction, "relist*"))
        startI = (ssIndex == -1) ? 0 : ssIndex; endI = (ssIndex == -1) ? ssN-1 : ssIndex
        for(ssI=startI; ssI<=endI && ssI<ssN; ssI+=1)
            ssTemp = StringFromList(ssI, ssList, ssSep)
            for(ssJ=1; ssJ<ssSepCount; ssJ+=1)
                ssSep = StringFromList(3+ssJ, splitSpec, "|"); ssM = ItemsInList(ssTemp, ssSep); ssFlat2 = ""
                for(ssK=0; ssK<ssM; ssK+=1)
                    ssItem = StringFromList(ssK, ssTemp, ssSep)
                    if(strlen(ssFlat2)>0)
                        ssFlat2 += ssJoin
                    endif
                    ssFlat2 += ssItem
                endfor
                ssTemp = ssFlat2
            endfor
            ssFlat2 = ""; ssM = ItemsInList(ssTemp, ssJoin)
            for(ssK=0; ssK<ssM; ssK+=1)
                ssItem = StringFromList(ssK, ssTemp, ssJoin)
                if(strlen(ssItem)>0)
                    if(strlen(ssFlat2)>0)
                        ssFlat2 += ssJoin
                    endif
                    ssFlat2 += ssItem
                endif
            endfor
            if(strlen(ssFlat)>0)
                ssFlat += ssJoin
            endif
            ssFlat += ssFlat2
        endfor
        return ssFlat
    else
        if(ssIndex >= 0 && ssIndex < ssN)
            ssTemp = StringFromList(ssIndex, ssList, ssSep)
            for(ssJ=1; ssJ<ssSepCount; ssJ+=1)
                ssSep = StringFromList(3+ssJ, splitSpec, "|"); ssTemp = StringFromList(0, ssTemp, ssSep)
            endfor
            return ssTemp
        else
            return ""
        endif
    endif
End
//--------------------------------------------------------------------------------------
Function/S RemoveItemsFromList(string inputStr, string removeSpec)
// What: Jazzed up version of RemoveFromList that allows for multiple items to be removed in one go.
    string itemsToRemove, listSep, matchCaseStr
    variable numParts, matchCase
    numParts = ItemsInList(removeSpec, "|")
    itemsToRemove = StringFromList(0, removeSpec, "|")
    if(numParts >= 2)
        listSep = StringFromList(1, removeSpec, "|")
        if(numParts >= 3)
            matchCaseStr = StringFromList(2, removeSpec, "|"); matchCase = str2num(matchCaseStr)
            return RemoveFromList(itemsToRemove, inputStr, listSep, matchCase)
        else
            return RemoveFromList(itemsToRemove, inputStr, listSep)
        endif
    else
        return RemoveFromList(itemsToRemove, inputStr)
    endif
End
//--------------------------------------------------------------------------------------
Function/S RemoveEmptyItemsFromList(string inputStr, string delimiter)
// What: Removes empty items from a list (and superfluous list delimiters)
    string workingList = "", currentItem; variable i, numItems, hasAdded = 0
    inputStr = TrimString(inputStr); numItems = ItemsInList(inputStr, delimiter)
    for(i=0; i<numItems; i+=1)
        currentItem = TrimString(StringFromList(i, inputStr, delimiter))
        if(strlen(currentItem) > 0)
            if(hasAdded)
                workingList += delimiter
            endif
            workingList += currentItem
            hasAdded = 1
        endif
    endfor  
    return workingList
End
//--------------------------------------------------------------------------------------
Function/S AddItemsToList(string inputStr, string addSpec)
// What: Jazzed up version of AddListItem that allows for multiple items to be added in one go. addSpec: "items" or "items|position" or "items|position|separator"
    string itemsToAdd, position, listSep, targetItem, workingList
    variable numParts, insertIndex, targetIndex
    numParts = ItemsInList(addSpec, "|"); itemsToAdd = StringFromList(0, addSpec, "|")
    position = SelectString(numParts >= 2, "end", StringFromList(1, addSpec, "|"))
    listSep = SelectString(numParts >= 3, ";", StringFromList(2, addSpec, "|"))
    if(strlen(inputStr) == 0)
        return itemsToAdd
    endif
    if(StringMatch(position, "start"))
        insertIndex = 0
    elseif(StringMatch(position, "end"))
        insertIndex = inf
    elseif(strsearch(position, "after:", 0) == 0)
        targetItem = position[6, inf]; targetIndex = WhichListItem(targetItem, inputStr, listSep)
        insertIndex = (targetIndex == -1) ? inf : targetIndex + 1
    elseif(strsearch(position, "before:", 0) == 0)
        targetItem = position[7, inf]; insertIndex = WhichListItem(targetItem, inputStr, listSep)
        if(insertIndex == -1)
            insertIndex = inf
        endif
    else
        insertIndex = str2num(position)
    endif
    return AddListItem(itemsToAdd, inputStr, listSep, insertIndex)
End
//--------------------------------------------------------------------------------------
Function/S ReplaceItemsInList(string inputStr, string replaceSpec, [string separator])
// What: Replaces matching items in a list with new values. replaceSpec: "oldItems|newItems" or "oldItems|newItems|separator"
    string oldItems, newItems, listSep, workingList = "", currentItem, matchItem, replaceItem
    variable numParts, i, numItems, j, numReplacements, foundMatch
    if(ParamIsDefault(separator))
        separator = ";"
    endif
    numParts = ItemsInList(replaceSpec, "|")
    if(numParts < 2)
        return inputStr // Need at least old and new items
    endif
    oldItems = StringFromList(0, replaceSpec, "|"); newItems = StringFromList(1, replaceSpec, "|")
    listSep = SelectString(numParts >= 3, separator, StringFromList(2, replaceSpec, "|"))
    numItems = ItemsInList(inputStr, listSep); numReplacements = ItemsInList(oldItems, listSep)
    if(numReplacements != ItemsInList(newItems, listSep))
        return inputStr // Old and new item counts must match
    endif
    for(i=0; i<numItems; i+=1) // Process each item in input list
        currentItem = StringFromList(i, inputStr, listSep); foundMatch = 0
        for(j=0; j<numReplacements; j+=1) // Check against all replacement pairs
            matchItem = StringFromList(j, oldItems, listSep)
            if(StringMatch(currentItem, matchItem))
                replaceItem = StringFromList(j, newItems, listSep)
                currentItem = replaceItem; foundMatch = 1
                break
            endif
        endfor
        if(strlen(workingList) > 0)
            workingList += listSep
        endif
        workingList += currentItem
    endfor
    return workingList
End
//--------------------------------------------------------------------------------------
Function/S ReplaceTermsInString(string inputStr, string replaceSpec, [string separator])
// What: Replaces matching terms in any string with new values. replaceSpec: "oldTerm1|newTerm1;oldTerm2|newTerm2"
    string workingStr, pairSep, replacePair, oldTerm, newTerm
    variable numPairs, i
    pairSep = SelectString(ParamIsDefault(separator), separator, ";") // Default pair separator is semicolon
    workingStr = inputStr
    numPairs = ItemsInList(replaceSpec, pairSep)
    for(i=0; i<numPairs; i+=1) // Process each replacement pair
        replacePair = StringFromList(i, replaceSpec, pairSep)
        if(ItemsInList(replacePair, "|") != 2)
            continue // Skip invalid pairs
        endif
        oldTerm = StringFromList(0, replacePair, "|")
        newTerm = StringFromList(1, replacePair, "|")
        workingStr = ReplaceString(oldTerm, workingStr, newTerm)
    endfor
    return workingStr
End
//--------------------------------------------------------------------------------------
Function/S RemoveDuplicatesFromList(string inputList, [string separator])
// What: Removes duplicate items from a list string
    string uniqueList = "", currentItem
    variable i, itemCount
    if(ParamIsDefault(separator))
        separator = ";"
    endif
    itemCount = ItemsInList(inputList, separator)
    for(i=0; i<itemCount; i+=1)
        currentItem = StringFromList(i, inputList, separator)
        if(WhichListItem(currentItem, uniqueList, separator) < 0) // Item not already in list
            uniqueList = AddListItem(currentItem, uniqueList, separator, Inf)
        endif
    endfor
    return uniqueList
End
//--------------------------------------------------------------------------------------
Function/S GetMatchingListItem(string inputListA, string inputListB, string listItem, [string separator, string failedReturn])
// What: Returns the matching list item from A in B. E.g A="1;2;3" B="one;two;three" listItem="2" returns "two".
    variable typeIndex = WhichListItem(listItem, inputListA); string outputString = ""
    if(ParamIsDefault(separator))
        separator = ";"
    endif
    if(ParamIsDefault(failedReturn))
        failedReturn = ""
    endif
    if(typeIndex >= 0)
        outputString = StringFromList(typeIndex, inputListB, separator)
        if(strlen(outputString) == 0)
            outputString = failedReturn
        endif
    else
        outputString = failedReturn
    endif
    return outputString
End
//--------------------------------------------------------------------------------------
////////////////////////////////////////////////////////////////////////////////////////
//// MISC
////////////////////////////////////////////////////////////////////////////////////////
//--------------------------------------------------------------------------------------
Function StimList(Variable start, Variable stop, Variable spacer, [String suffix])
// What: Same as numberlist but appends a suffix to list for easy copy-paste
	String output
	make /FREE/N=((stop-start)/spacer) temp
	temp = start + p*spacer
	string numlist = ""
	variable c
	for (c=0; c<numpnts(temp); c++)
		numlist += num2str(temp[c]) + ","
	endfor
	numlist += num2str(stop)
	numlist = numlist[0, strlen(numlist) - 1]
	if(ParamIsDefault(suffix))
		output = numlist + " uA"
	else
		output = numlist + " " + suffix
	endif
	Print output
End
//--------------------------------------------------------------------------------------
Function [Variable NVAR, Variable SVAR, Variable typeReturned] NVAR_OR_SVAR(string varName, [variable varType, string location, string searchType])
// What: Returns a global variable or string variable based on name ((TBD WIP))
	// [varType]: 1 variable, 2 string, 3 variable then string if not found, 4 string then variable if not found[location]: DF to look in. Default is current DF
	// [typeReturned]: 0 neither found, 1 variable, 2 string, 3 both. [searchType]: "local" for location DF only (default), "subfolders" to search location and then subfolders until found target. having location root: and subfolders would search all DFs
end