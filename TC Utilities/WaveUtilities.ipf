#pragma rtGlobals= 3				// Use modern global access method.
#pragma version= 2.01				
#pragma IgorVersion= 9.00			// Requires Igor 9.0 or newer.
#pragma ModuleName= WaveUtilities

// ===========================================================================
//                           WAVE UTILITIES
// ===========================================================================
// Description: Utility functions for waves. Merging, splitting, creating references etc
// Author: Thomas Cahir
// Created: 25-06-2025
// ============================================================================
//	Updated: 11-08-2025 - TC
//*********************************************************************************************************************
////////////////////////////////////////////////////////////////////////////////////////
//// LOOKUP AND EXTRACTION / INFO
////////////////////////////////////////////////////////////////////////////////////////
Function/WAVE WaveInformation(string inputWaveList, string analysisTypes, [string processRules, variable beSilent])
// What: Analyzes wave properties and outputs results to a reference table using CreateReferenceWave
	// inputWaveList: Semicolon-separated list of wave names to analyze
	// analysisTypes: samplingRate = get sampling rate in kHz; waveStats = basic statistics; waveInfo = general wave information
	// processRules: outputName = specify output wave name; outputPath = specify output location; rebuild = overwrite existing
	string currentDF = GetDataFolder(1), outputName = "WaveInfoTable", outputPath = currentDF
	variable rebuild = 0, i, j, analysisCount = ItemsInList(analysisTypes), deltaX; beSilent = ParamIsDefault(beSilent) ? 0 : beSilent
	///// PRE-PROCESSING - Standard format process1(argument);process2(argument) - can just be process1;process2 if no args
	if(StringMatch(inputWaveList, "all") || Strlen(inputWaveList) == 0)
		inputWaveList = WaveList("*", ";", "")
	endif
	if(StringMatch(analysisTypes, "all"))
		analysisTypes = "samplingRate;waveStats;waveInfo"
		analysisCount = 3
	endif	
	variable waveCount = ItemsInList(inputWaveList)	
	if(!ParamIsDefault(processRules))
		variable ruleCount = ItemsInList(processRules, ";"), ruleIter = 0
		for(ruleIter=0; ruleIter<ruleCount; ruleIter+=1)
			string process = StringFromList(ruleIter, processRules, ";")
			string processArg = ""
			if(strsearch(process, "(", 0) >= 0) // Extract argument if present
				processArg = process[strsearch(process, "(", 0)+1, strsearch(process, ")", inf)-1]
				process = process[0, strsearch(process, "(", 0)-1]
			endif
			strswitch(process)
				case "outputName": // Specify output wave name
					outputName = processArg
					break
				case "outputPath": // Specify output path
					outputPath = processArg
					break
				case "rebuild": // Rebuild/overwrite existing wave
					rebuild = 1
					break
			endswitch
		endfor
	endif
	//// SETUP OUTPUT WAVE
	string columnNames = "WaveName;WaveType" // Always include wave name and type
	for(j=0; j<analysisCount; j+=1) // Add analysis type columns
		string analysisType = StringFromList(j, analysisTypes)
		strswitch(analysisType)
			case "samplingRate":
				columnNames += ";SamplingRate_kHz"
				break
			case "waveStats":
				columnNames += ";NumPoints;WaveMin;WaveMax;WaveAvg;WaveStdDev"
				break
			case "waveInfo":
				columnNames += ";WaveDims;XUnits;YUnits;Delta;xLength"
				break
		endswitch
	endfor
	WAVE/T infoWave = CreateReferenceWave(outputName, columnNames, outputPath=outputPath, beSilent=beSilent) // Create reference wave
	//// ANALYZE WAVES
	for(i=0; i<waveCount; i+=1)
		string waveNameStr = StringFromList(i, inputWaveList) // Start with wave name
		Wave/Z targetWave = $waveNameStr
		if(!WaveExists(targetWave)) // Check wave exists
			PrintAdv("Warning: Wave " + waveNameStr + " does not exist, skipping", type="warning")
			continue
		endif	
		variable waveTypeVar = WaveType(targetWave)
		string rowData = waveNameStr + ";" + num2str(waveTypeVar)
		for(j=0; j<analysisCount; j+=1) // Perform each analysis
			analysisType = StringFromList(j, analysisTypes)
			strswitch(analysisType)
				case "samplingRate": // Calculate sampling rate in kHz
					rowData += ";" + num2str(CalculateSampleRate(targetWave))
					break
				case "waveStats": // Basic wave statistics
					WaveStats/Q/Z targetWave
					rowData += ";" + num2str(V_npnts) + ";" + num2str(V_min) + ";" + num2str(V_max) + ";" + num2str(V_avg) + ";" + num2str(V_sdev)
					break
				case "waveInfo": // General wave information
					variable waveDimsVar = WaveDims(targetWave)
					string xUnits = WaveUnits(targetWave, 0), yUnits = WaveUnits(targetWave, -1)
					deltaX = DimDelta(targetWave, 0)
					variable xLength = DimSize(targetWave, 0) * deltaX
					rowData += ";" + num2str(waveDimsVar) + ";" + xUnits + ";" + yUnits + ";" + num2str(deltaX) + ";" + num2str(xLength)
					break
			endswitch
		endfor
		AddToReferenceWave(infoWave, columnNames, rowValues=rowData) // Add row to reference wave
	endfor
	//// POST PROCESSING - TBD
	//PrintAdv("Wave analysis complete: " + num2str(waveCount) + " waves analyzed with " + num2str(analysisCount) + " analysis types", type="info", state="indented")
	//PrintAdv("Results saved to: " + outputPath + outputName, type="info", state="indented")
	return infoWave
End
//--------------------------------------------------------------------------------------
Function AddWaveNote(wave w, string noteText, [string prefix])
//// What: Adds a standardized note to a wave
	//// Input: w - wave to add note to, noteText - text to add, prefix (optional) - prefix for the note
	string currentNote = note(w)
	string timestamp = date() + " " + time()
	if(ParamIsDefault(prefix))
		prefix = "Note"
	endif	
	Note/NOCR w, currentNote + prefix + " (" + timestamp + "): " + noteText + "\r"
End
//--------------------------------------------------------------------------------------
Function ExtractParameterFromNote(wave w, string paramName)
// What: extracts parameter value from a wave note
	// Input: Wave reference, parameter name to extract (e.g., "Phase", "Delay")
	// Output: Parameter value (or NaN if not found)
	
	string noteText = note(w)
	if(strlen(noteText) == 0)
		return NaN  // No note found
	endif
	// This looks for the parameter name followed by colon, then captures the value until it hits whitespace, tab, semicolon or end of string
	string paramStr
	string regex = "(?:^|[\\s;])" + paramName + ":([0-9.e\\-+]+)"
	SplitString/E=regex noteText, paramStr
	
	if(strlen(paramStr) == 0)
		return NaN  // Parameter not found in the expected format
	endif
	
	// Convert to number
	variable paramValue = str2num(paramStr)
	return paramValue
End
//--------------------------------------------------------------------------------------
Function CalculateSampleRate(wave w)
	variable deltaX = DimDelta(w, 0), samplingRate = NaN
	if(deltaX > 0)
		samplingRate = 1/(deltaX*1000) // Convert to kHz
	endif
	return samplingRate
End
//--------------------------------------------------------------------------------------
Function/S GetUniqueParameters(wave w)
//// What: Creates a list of unique parameters from a wave
	//// Input: w - wave containing parameters
	//// Output: Returns a semicolon-separated list of unique values
	Duplicate/FREE w, tempWave
	Sort tempWave, tempWave
	string uniqueList = ""
	variable i, n = numpnts(tempWave)
	for(i=0; i<n; i+=1)
		if(i==0 || tempWave[i]!=tempWave[i-1])
			uniqueList = AddListItem(num2str(tempWave[i]), uniqueList, ";", inf)
		endif
	endfor
	return uniqueList
End
//--------------------------------------------------------------------------------------
Function /T GetUniqueValues(Wave inputWave, [string divider])
//// What: Extract unique values from a given wave and append output to a stringlist
	// E.g This wave has repeated values, but i only want unique values.
	Wave ListWave = inputWave
	variable i, listWaveLength = DimSize(ListWave,0)
	string outputlist, listItem
	if(ParamIsDefault(divider)) 
		divider = ";" 
	endif
	
	for (i=0;i<listWaveLength;i=i+1)
		listItem = num2str(ListWave[i])
		if(GrepString(outputlist, listItem))
			i = listWaveLength + 1
			break
		elseif (!strlen(ListItem)==0)
			outputlist = listItem + divider + outputlist
		endif
	endfor
	print outputlist
	return outputlist
end
//--------------------------------------------------------------------------------------
Function [variable rows, variable cols, variable waveTypeVar, variable effectiveRows, variable effectiveCols] AnalyseWaveProperties(WAVE w, string colSelection, string rowSelection)
// What: Analyse wave properties and return relevant information
	rows = DimSize(w, 0); cols = WaveDims(w) == 1 ? 1 : DimSize(w, 1); waveTypeVar = WaveType(w, 1); effectiveCols = cols; effectiveRows = rows
	if(strlen(colSelection) > 0) // Calculate effective columns based on selection
		if(strsearch(colSelection, ",", 0) >= 0)
			effectiveCols = ItemsInList(colSelection, ",")
		elseif(strsearch(colSelection, "-", 0) >= 0)
			variable startCol = str2num(ModifyString(colSelection, rules="extractBefore", ruleMods="-"))
			variable endCol = str2num(ModifyString(colSelection, rules="extractAfter", ruleMods="-"))
			effectiveCols = endCol - startCol + 1
		else
			effectiveCols = 1
		endif
	endif
	if(strlen(rowSelection) > 0) // Calculate effective rows based on selection
		if(strsearch(rowSelection, ",", 0) >= 0)
			effectiveRows = ItemsInList(rowSelection, ",")
		elseif(strsearch(rowSelection, "-", 0) >= 0)
			variable startRowSel = str2num(ModifyString(rowSelection, rules="extractBefore", ruleMods="-"))
			variable endRowSel = str2num(ModifyString(rowSelection, rules="extractAfter", ruleMods="-"))
			effectiveRows = endRowSel - startRowSel + 1
		else
			effectiveRows = 1
		endif
	endif
End
//--------------------------------------------------------------------------------------
Function [variable outputRows, variable outputCols] CalculateOutputDimensions(WAVE rowsData, WAVE colsData, string mode, variable existingRows, variable existingCols)
// What: Calculates the output dimensions for a wave based on the input dimensions and mode
	variable waveCount = DimSize(rowsData, 0), maxRows = 0, totalCols = 0, i
	if(StringMatch(mode, "append"))
		variable maxColsFromWaves = 0, totalRowsForAppend = 0
		for(i = 0; i < waveCount; i += 1)
			maxColsFromWaves = max(maxColsFromWaves, colsData[i])
			totalRowsForAppend += rowsData[i]
		endfor
		outputRows = existingRows + totalRowsForAppend
		outputCols = max(existingCols, maxColsFromWaves)
	else // expand or match modes
		for(i = 0; i < waveCount; i += 1)
			maxRows = max(maxRows, rowsData[i])
			if(StringMatch(mode, "expand"))
				totalCols += colsData[i] // Each input wave adds all its columns in expand mode
			else
				totalCols += colsData[i] // Match mode uses all columns
			endif
		endfor
		outputRows = max(existingRows, maxRows)
		outputCols = existingCols + totalCols
	endif
End
////////////////////////////////////////////////////////////////////////////////////////
//// STANDARDISED CREATION
////////////////////////////////////////////////////////////////////////////////////////
//--------------------------------------------------------------------------------------
Function/WAVE MakeWave(string wName, string wType, variable rowSize, variable colSize, [string flags, string colNames, string rowNames, variable overwrite])
// What: Creates a wave with specified dimensions and optionally sets dimension labels. More compact than Make if setting coldim/rowdim labels.
	// wName: Name of the wave to create. wType: "text" or "numeric" (default if empty)
	// colSize: Number of columns. rowSize: Number of rows.
	// flags: Optional flags list for Make command (e.g., "O;FREE"). colNames/rowNames: Optional semicolon-delimited lists of dimension labels.
	string makeCmd = "Make", savedDF = GetDataFolder(1)
	if(ParamIsDefault(flags))
		flags = ""
	endif
	variable isText = StringMatch(wType, "text"), isNumeric = StringMatch(wType, "numeric") || strlen(wType) == 0
	if(strlen(flags) > 0)
		variable flagCount
		for(flagCount = 0; flagCount < ItemsInList(flags, ";"); flagCount += 1)
			makeCmd += "/" + StringFromList(flagCount, flags, ";")
		endfor
	endif
	if(isText)
		if(!GrepString(flags, "/T"))
			makeCmd += "/T"
		endif
	else
		if(GrepString(flags, "/T"))
			PrintAdv("Error: MakeWave Error: Wave " + wName + " is numeric but /T flag was specified", type="error")
			return $""
		endif
	endif
	makeCmd += "/O/N=(" + num2str(rowSize) + "," + num2str(colSize) + ") "
	if(CheckString(wName, "root:") > 0) // wName is fullpath. e.g root:Data:wName not wName 
		variable depth = ItemsInList(wName, ":")
		string trueWName = StringFromList(depth-1, wName, ":"), trueFolder = RemoveFromList(trueWName, wName, ":")
		SetCreateDataFolder(trueFolder)
		makeCmd += trueWName
	else
		makeCmd += wName
	endif
	Execute makeCmd // Make the wave
	if(!WaveExists($wName))
		PrintAdv("MakeWave Error: Failed to create wave " + wName, type="error")
		return $""
	endif
	if(!ParamIsDefault(colNames) && strlen(colNames) > 0)
		variable colIndex
		for(colIndex = 0; colIndex < min(ItemsInList(colNames, ";"), colSize); colIndex += 1)
			string colLabel = StringFromList(colIndex, colNames, ";")
			SetDimLabel 1, colIndex, $colLabel, $wName
		endfor
	endif
	if(!ParamIsDefault(rowNames) && strlen(rowNames) > 0)
		variable rowIndex
		for(rowIndex = 0; rowIndex < min(ItemsInList(rowNames, ";"), rowSize); rowIndex += 1)
			string rowLabel = StringFromList(rowIndex, rowNames, ";")
			SetDimLabel 0, rowIndex, $rowLabel, $wName
		endfor
	endif
	SetDataFolder(savedDF)
	return $wName
End
//--------------------------------------------------------------------------------------
Function/WAVE MakeGetWave(string targetPath, variable outputRows, variable outputCols, variable inputType, variable rebuild)
	if(rebuild)
		KillWaves/Z $targetPath
	endif
	WAVE/Z targetWave = $targetPath
	if(WaveExists(targetWave)) // Wave exists, resize if needed
		variable needResize = (DimSize(targetWave, 0) < outputRows) || (DimSize(targetWave, 1) < outputCols)
		if(needResize)
			Redimension/N=(max(DimSize(targetWave, 0), outputRows), max(DimSize(targetWave, 1), outputCols)) targetWave
		endif
	else // Create new wave
		if(inputType == 2)
			Make/O/T/N=(outputRows, outputCols) $targetPath
		else
			Make/O/N=(outputRows, outputCols) $targetPath
			WAVE targetWave = $targetPath
			targetWave = NaN // Initialize with NaN for sparse data
		endif
		WAVE targetWave = $targetPath
	endif
	return targetWave
End
//-------------------------------------------------------------------------------------
Function/WAVE CreateReferenceWave(string newWaveName, string columnNames [,string rowNames, string inputData, string outputPath, string waveType, string waveParadigm, string inputTypes, variable rebuild, variable beSilent])
// What: Creates a text reference wave with dimension labels for variables in a package folder. These are intended as a more compact way to track various variable/strings without cluttering datafolders.
	// Input: newWaveName - name of Wave to create. columnNames - semicolon-separated list of column names to create.
	// [inputData] - complex stringlist of values for each row/col. Format: row1(5,10,15);row2(10,20,30) etc. If parsed without row will assume single row data (5;10;15;25 etc) [outputPath] - path to save wave, else will save to current DF. if contains package=xyz will save to defined Root:Packages:xyz. [rebuild] - rebuild/overwrite wave if it exists. [waveType] - type of wave to create (default is text)
	// [waveParadigm] - what function is this wave? Default to 'standard' aka rows with matched data. Can also be 'database' which is two row with row1 Data, row2 dataType (string, variable, path etc).
	string colName = "", rowName = "", inputValue = "", inputType = "", inputThing = "", inputList = "inputValue;inputType", packagePath = "", startDF = GetDataFolder(1), refWaveName = "", fullWavePath = ""
	variable numRows, multirowInput = 0
	//// INITIAL SETUP
	if(ParamIsDefault(outputPath))
		outputPath = startDF
	endif
	SetCreateDataFolder(outputPath) // Check or create output folder and move there
	if(ParamIsDefault(inputData)) // Consider adding multirow datainput TBD
		inputData = ""
	endif
	if(ParamIsDefault(rowNames)) // Consider adding multirow datainput TBD
		rowNames = ""
	endif
	if(!ParamIsDefault(rebuild) && rebuild == 1) // Kil Wave if rebuilt
		KillWaves/Z $outputPath + newWaveName
	else // Checks this wave doesnt exist. If it does will add to it instead
		string fullWaveName = outputPath + newWaveName
		WAVE/T/Z refWaveT = $fullWaveName
		if(WaveExists(refWaveT))
			if(ParamIsDefault(inputData) && ParamIsDefault(rowNames)) // Existing wave with no input data, just adding new rowNames
				AddToReferenceWave(refWaveT, columnNames)
			elseif(!ParamIsDefault(inputData)) // Existing wave with input data
				AddToReferenceWave(refWaveT, columnNames, rowNames=rowNames, rowValues=inputData)
			else // Existing wave with no input data, just adding new rowNames
				AddToReferenceWave(refWaveT, columnNames, rowNames=rowNames)
			endif
			PrintAdv("Wave already exists: " + fullWaveName + " Adding to wave...", type = "warning", state="debug")
			return refWaveT
		endif
	endif
	if(ParamIsDefault(waveParadigm)) // Kil Wave if rebuilt
		waveParadigm = "standard"
	endif
	if(strlen(newWaveName) == 0) // Default to ReferenceWave if empty
		newWaveName = "refWave"
	endif

	//// CREATE WAVE
	fullWavePath = outputPath + newWaveName
	fullWavePath = ReplaceString("::", fullWavePath, ":") // fix potential double ::
	variable isTextWave = ParamIsDefault(waveType) || StringMatch(waveType, "text")
	variable rowsToCreate = ParamIsDefault(rowNames) ? 1 : ItemsInList(rowNames), columnsToCreate = ItemsInList(columnNames, ";")

	if(isTextWave)
		Make/O/T/N=(rowsToCreate, columnsToCreate) $fullWavePath
		wave/T refWaveT = $fullWavePath
	else
		Make/O/N=(rowsToCreate, columnsToCreate) $fullWavePath
		wave refWave = $fullWavePath
	endif
	
	if(StringMatch(waveParadigm, "database")) // Special setup
		SetDimLabel 0, 0, Data, $fullWavePath
		SetDimLabel 0, 1, DataType, $fullWavePath
	endif
	//// FORMAT DATA
	if(GrepString(inputData, "row*"))
		multirowInput = 1
	endif

	//// ADD DATA & LABELS TO WAVE
	variable referenceCount, rowCount
	for(rowCount=0; rowCount < rowsToCreate; rowCount+=1)
		string inputValues = "", inputRowName = "" // num2str(rowCount)
		if(!ParamIsDefault(rowNames)) // Set dimension label for rows (if given)
			inputRowName = StringFromList(rowCount, rowNames)
			SetDimLabel 0, rowCount, $inputRowName, $fullWavePath 
		else
			inputRowName = "row" + num2str(rowCount)
		endif
		if(CheckString(inputData, inputRowName) > 0)
			inputValues = ModifyString(inputData, rules="extractBetweenDelim", ruleMods=inputRowName+"(|)")
			inputValues = ReplaceString(",", inputValues, ";")
		elseif(!GrepString(inputData, ","))
			inputValues = inputData	
		else
			inputValues = ""
		endif	
		for(referenceCount=0; referenceCount<ItemsInList(columnNames); referenceCount+=1)
			colName = StringFromList(referenceCount, columnNames)
			SetDimLabel 1, referenceCount, $colName, $fullWavePath // Set dimension label for column
			//refWaveT[0][referenceCount] = ""
			if(!ParamIsDefault(inputData)) // Input values for each column
					inputValue = StringFromList(referenceCount, inputValues)
					if(isTextWave) // Set value and type
						refWaveT[rowCount][referenceCount] = inputValue
						if(!ParamIsDefault(inputTypes))	
							inputType = StringFromList(referenceCount, inputTypes)
							refWaveT[rowCount][referenceCount] = inputType
						endif
					else
						refWave[rowCount][referenceCount] = str2num(inputValue)
						if(!ParamIsDefault(inputTypes))	
							refWave[rowCount+1][referenceCount] = 0  // Type 0 = variable (cant actaully be anything else)
						endif
					endif
			endif
		endfor
	endfor
	if(!Exists(fullWavePath))
		PrintAdv("Error: Wave " + newWaveName + " not created!", type="error", state="error")
	elseif(isTextWave)
		PrintAdv("Created " + newWaveName + " wave", type="info", state="indented", beSilent=beSilent)
		return refWaveT
	else
		PrintAdv("Created " + newWaveName + " wave", type="info", state="indented", beSilent=beSilent)
		return refWave
	endif
End
//--------------------------------------------------------------------------------------
Function AddToReferenceWave(wave refWave, string columnNames, [string rowNames, string rowValues, variable targetRow])
//// What: ADD DATA TO REFERENCE WAVE (supports both text and numeric waves)
	variable j, startCols = DimSize(refWave, 1), startRows = DimSize(refWave, 0), currentCols = startCols, rowIndex, wTypeVar = WaveType(refWave)
	string refWaveColNames = GetWaveColumnNames(refWave), result = columnNames
	// Create wave references for both types
	WAVE/T textRef = refWave  // Will only be used if wTypeVar == 0
	WAVE numRef = refWave     // Will only be used if wTypeVar > 0
	for(j = 0; j < ItemsInList(columnNames); j += 1)
		string item = StringFromList(j, columnNames)
		result = RemoveFromList(item, result)
	endfor
	if((ParamIsDefault(rowValues) && ParamIsDefault(rowNames)) && strlen(result) == 0)
		return 1 // no new data to add
	endif
	if(ParamIsDefault(rowNames))
		rowNames = ""
	endif
	rowIndex = ParamIsDefault(targetRow) ? startRows : targetRow
	if(ParamIsDefault(rowValues))
		rowValues = ""
	endif
	if(ParamIsDefault(targetRow) && startRows > 0 && strlen(GetWaveRowData(refWave, startRows-1)) == 0)
		rowIndex = startRows - 1
	endif
	if(ParamIsDefault(targetRow) && WhichListItem("WaveName", columnNames) >= 0)
		if(wTypeVar == 0) // Text wave
			FindValue/TEXT=StringFromList(WhichListItem("WaveName", columnNames), rowValues)/TXOP=4 textRef
		else // Numeric wave		
			variable searchVal = str2num(StringFromList(WhichListItem("WaveName", columnNames), rowValues)) // For numeric waves, convert the search value to number and search
			FindValue/V=(searchVal) numRef
		endif
		if(V_value >= 0)
			rowIndex = V_row
		endif
	endif
	variable requiredRows = max(rowIndex + 1, startRows), colCount
	for(colCount = 0; colCount < ItemsInList(columnNames); colCount += 1)
		string colName = StringFromList(colCount, columnNames)
		string colData = StringFromList(colCount, rowValues)
		variable colIndex = FindDimLabel(refWave, 1, colName)
		if(colIndex >= 0) // existing column found
			Redimension/N=(requiredRows, currentCols) refWave
			if(wTypeVar == 0) // Text wave
				textRef[rowIndex][colIndex] = colData
			else // Numeric wave
				numRef[rowIndex][colIndex] = str2num(colData)  // Convert string to number
			endif
		else // new column needed
			Redimension/N=(requiredRows, currentCols + 1) refWave
			SetDimLabel 1, currentCols, $colName, refWave
			if(wTypeVar == 0) // Text wave
				textRef[rowIndex][currentCols] = colData
			else // Numeric wave
				numRef[rowIndex][currentCols] = str2num(colData)  // Convert string to number
			endif
			currentCols += 1
		endif
		if(StringMatch(colName, "WaveName") || StringMatch(colName, "Name"))
			if(wTypeVar == 0) // Text wave
				SetDimLabel 0, rowIndex, $colData, refWave
			else // Numeric wave
				SetDimLabel 0, rowIndex, $colData, refWave  // Use string for row label even in numeric wave
			endif
			Variable colNameSet = 1
		elseif(!ParamIsDefault(rowNames) && !colNameSet)
			SetDimLabel 0, rowIndex, $StringFromList(rowIndex, rowNames), refWave
		endif
	endfor
	return 1
End
//--------------------------------------------------------------------------------------
Function/WAVE NormalizeWaveData(Wave waveToNormalize, string normMethod, [variable useLogTransform, variable beSilent])
// What: Normalizes a wave in-place using the specified method (zscore, median).
	// waveToNormalize: The wave to be normalized.. normMethod: The normalization method to apply ("zscore", "median", or "none").
	// [useLogTransform]: Optional. If 1, applies a log transform before normalization. Default is 1.
	if(!WaveExists(waveToNormalize))
		PrintAdv("NormalizeWaveData Error: Input wave does not exist.", type="error")
		return waveToNormalize
	endif
	if(strlen(normMethod) == 0)
		return waveToNormalize
	endif
	if(ParamIsDefault(beSilent))
		beSilent = 0
	endif
	if(ParamIsDefault(useLogTransform))
		useLogTransform = 1
	endif
	if(useLogTransform)
		variable smallConstant = 1e-6 // A small constant to avoid log(0)
		waveToNormalize = log(abs(waveToNormalize) + smallConstant) * sign(waveToNormalize)
	endif
	strswitch(normMethod)
		case "zscore":
			WaveStats/Q waveToNormalize
			if(V_sdev == 0)
				PrintAdv("NormalizeWaveData Warning: Standard deviation is zero. Cannot apply z-score.", type="warning")
				return waveToNormalize // Avoid division by zero.
			endif
			waveToNormalize = (waveToNormalize - V_avg) / V_sdev
			break
		case "median":
			StatsQuantiles/Q waveToNormalize
			WAVE W_StatsQuantiles
			if(W_StatsQuantiles[3] == 0)
				 PrintAdv("NormalizeWaveData Warning: Median is zero. Division by zero may result in NaNs or Infs.", type="warning")
			endif
			waveToNormalize = waveToNormalize / W_StatsQuantiles[3]
			KillWaves/Z W_StatsQuantiles
			break
		default:
			PrintAdv("NormalizeWaveData Error: Unknown normalization method '" + normMethod + "'.", type="error")
			return waveToNormalize
	endswitch
	PrintAdv("Applied " + normMethod + " normalization to " + NameOfWave(waveToNormalize), type="success", beSilent=beSilent)
	return waveToNormalize
End 
//--------------------------------------------------------------------------------------
Function/WAVE MakeRandomStringWave(String inputStr, Variable numCopies [,string outputWaveName])
// What: Creates a wave containing multiple randomized versions of input string
    // 		inputStr - semicolon-separated list to randomize (e.g. "A;B;C" or "1;2;3"). numCopies - number of randomized versions to create
    // 		outputWaveName - name for output otherwise use default     
    if(ParamIsDefault(outputWaveName))
        outputWaveName = "w_RandomWave"
    endif
    Variable numItems = ItemsInList(inputStr)
	Print "Input: " + inputStr + " | " + "Number of items: " + num2str(numItems)
    if(numItems == 0)
        Print "Error: No items in input string"
        return $""  // Return empty if no items
    endif
    Variable allNumeric = 1
    Variable i
    for(i=0; i<numItems && allNumeric; i+=1)
        String item = StringFromList(i, inputStr)
        if(numtype(str2num(item)) != 0)  // Not a valid number
            allNumeric = 0
            break
        endif
    endfor
    if(allNumeric)
        Make/O/N=(numItems, numCopies) $outputWaveName
        WAVE w_nums = $outputWaveName  // Numeric wave reference
        for(i=0; i<numItems; i+=1)
            w_nums[i][0] = str2num(StringFromList(i, inputStr))
        endfor
    else
        Make/O/T/N=(numItems, numCopies) $outputWaveName
        WAVE/T w_text = $outputWaveName  // Text wave reference
        for(i=0; i<numItems; i+=1)
            w_text[i][0] = StringFromList(i, inputStr)
        endfor
    endif
    Make/O/FREE/N=(numItems) indices
    indices = p  // Initialize with sequential numbers
    Variable j
    for(j=1; j<numCopies; j+=1)
        indices = p
        // Fisher-Yates shuffle
        Variable temp, randIdx
        for(i=numItems-1; i>0; i-=1)
            randIdx = abs(floor(enoise(i+1)))  // Random index between 0 and i
            if(randIdx > i)
                randIdx = i
            endif  
            temp = indices[i] // Swap elements
            indices[i] = indices[randIdx]
            indices[randIdx] = temp
        endfor     
        if(allNumeric) // Apply shuffled order
            for(i=0; i<numItems; i+=1)
                w_nums[i][j] = str2num(StringFromList(indices[i], inputStr))
            endfor
        else
            for(i=0; i<numItems; i+=1)
                w_text[i][j] = StringFromList(indices[i], inputStr)
            endfor
        endif
    endfor 
    if(allNumeric)
        return w_nums
    else
        return w_text
    endif
End
////////////////////////////////////////////////////////////////////////////////////////
//// ALTERATIONS AND MERGING
////////////////////////////////////////////////////////////////////////////////////////
Function/WAVE ModifyWave(wave inputWave, string modifications, [string processRules, variable beSilent])
// What: Master function that modifies a wave based on a string of modifications and rules (duplicate, copy, merge etc)
	// modifications: invert = flip all values (multiply by -1)
	// processRules: new, save
	string currentDF = GetDataFolder(1), saveDF = GetWavesDataFolder(inputWave, 2)
	string modWaveName = NameOfWave(inputWave), modWaveNameTmp = modWaveName + "tmp"; variable outputType = WaveType(inputWave)
	Wave modWave = inputWave
	///// PRE-PROCESSING - Standard format process1(argument);process2(argument) - can just be process1;process2 if no args
	if(!ParamIsDefault(processRules))
		variable ruleCount = ItemsInList(processRules, ";"), ruleIter = 0
		for(ruleIter=0; ruleIter<ruleCount; ruleIter+=1)
			string process = StringFromList(ruleIter, processRules, ";")
			string processArg = ModifyString(process, rules="extractBetweenDelim", ruleMods="(|)")
			strswitch(process)
				case "save": // Save modified wave to specific data folder e.g save("root:Data"), else saves to location of inputWave. Should be parsed first in rules
					String saveName = saveDF + ":" + NameOfWave(modWave)
					break
				case "new": // Modified wave is output as new wave, not overwriting original
					///String suffix = SelectString // use custom name if defined strlen >1, else use wavename + mod
					modWaveName = NameOfWave(inputWave) + "_Mod"
					Duplicate/O inputWave, $modWaveName
					Wave/Z modWave = $modWaveName
					break
				case "backup": // Make backup copy of inputWave
					String backupWaveName = NameOfWave(inputWave) + "_Original"
					Duplicate/O inputWave, $backupWaveName
					Duplicate/O modWave, $backupWaveName
					break
			endswitch
		endfor
	endif
	//// MODIFICATIONS
	variable modCount = ItemsInList(modifications, ";"), modIter = 0
	for(modIter=0; modIter<modCount; modIter+=1)
		string mod = StringFromList(modIter, modifications, ";")
		strswitch(mod)
			case "invert": // Flip all values (multiply by -1)
				modWave *= -1
				Note modWave, "Wave Inverted (*=-1) Original: " + NameOfWave(inputWave)
				break
			case "downsample": // Downsample wave
				//DownsampleWithAntialiasing(modWave, dsFactor)
				break
			case "shorten": // Shorten wave
				//ShorternWave(modWave, targetLength, dsFactor)
				break
			case "normalize": // Normalize wave
				//NormalizeWaveData(modWave, normMethod, useLogTransform)
				break
			case "convertToText": // Convert wave to numeric or text
				Rename inputWave, $modWaveName + "tmp"
				Make/T/O/N=(numpnts(modWave),DimSize(modWave,1)) txtConvert
				txtConvert[] = num2str(modWave[p])
				Rename txtConvert, $modWaveName
				WAVE/T modWaveTxt = $modWaveName
				outputType = 2
				KillWaves/Z inputWave; DoUpdate
				break
			case "convertToNumeric": // Convert wave to numeric or text
				Rename inputWave, $modWaveName + "tmp"
				WAVE/T modWaveTmp = $modWaveName + "tmp"
				variable numRows = DimSize(modWaveTmp, 0)
				variable numCols = DimSize(modWaveTmp, 1) 
				Make/O/N=(numRows, numCols) numConvert
				variable i, j
				for(i=0; i<numRows; i+=1)
					for(j=0; j<numCols; j+=1)
						numConvert[i][j] = str2num(modWaveTmp[i][j])
					endfor
				endfor		
				KillWaves/Z inputWave, modWaveTmp; DoUpdate
				Rename numConvert, $modWaveName
				WAVE modWave = $modWaveName
				outputType = 1
				break
		endswitch
	endfor
	//// POST MODIFICATIONS
	PrintAdv("Modified Wave: " + NameOfWave(modWave), type="info", state="indented", beSilent=beSilent)
	if(outputType == 2)
		return modWaveTxt
	else
		return modWave
	endif
End
//--------------------------------------------------------------------------------------
Function/WAVE MergeWaves(string waveList, [string params, variable beSilent])
// What: Merges multiple waves into a single wave based on specified parameters
    // Merge Parameters: expand (concatinate columns. can target specific columns (e.g expand(1,2)), append (concatinate rows), match (match columns by name)
    // Other parameters: targetWave (output to specific wave), kill (kill source waves), rebuild (rebuild output wave)
	variable waveCount = ItemsInList(waveList)
	beSilent = ParamIsDefault(beSilent) ? 0 : beSilent
	if(waveCount == 0 || ItemsInList(ListMatch(waveList, "*")) == 0)
		PrintAdv("Error: No valid waves in list", type="error", beSilent=beSilent)
		return $""
	endif
	string validWaves = ListMatch(waveList, "*")
	waveCount = ItemsInList(validWaves)
	if(waveCount == 1 && ParamIsDefault(params))
		PrintAdv("Error: Single wave requires target specification", type="error", beSilent=beSilent)
		return $""
	endif
	//// PARAMETER PROCESSING
	variable expand = 1, append = 0, match = 0, killSource = 0, rebuild = 0, skipUnmatched = 1, inputCol = 0, targetCol = 0
	string targetPath = "", colSelection = "", rowSelection = "", modeStr = "expand", outputName = "mergedWaves"
	if(!ParamIsDefault(params))
		modeStr = params
	endif
	variable paramCount = ItemsInList(modeStr, ";"), paramIndex
	for(paramIndex = 0; paramIndex < paramCount; paramIndex += 1)
		string fullParam = StringFromList(paramIndex, modeStr, ";")
		string param = ModifyString(fullParam, rules="extractBeforeAny", ruleMods="(~;~[~|~")
		string paramArg = ModifyString(fullParam, rules="extractBetweenDelim", ruleMods="(|)", returnType="strict")
		strswitch(LowerStr(param))
            // Merge Parameters
			case "expand":
				expand = 1; append = 0
				if(strlen(paramArg) > 0)
					if(numtype(str2num(paramArg)) != 0)
						colSelection = paramArg
					else
						colSelection = paramArg
					endif
				endif
				break
			case "append": 
				append = 1; expand = 0
				break
			case "match": 
				match = 1; append = 0; expand = 0
				if(strsearch(paramArg, "|", 0) >= 0)
					inputCol = str2num(ModifyString(paramArg, rules="extractBefore", ruleMods="|"))
					string remainder = ModifyString(paramArg, rules="extractAfter", ruleMods="|")
					if(strsearch(remainder, "|", 0) >= 0)
						targetCol = str2num(ModifyString(remainder, rules="extractBefore", ruleMods="|"))
						skipUnmatched = !StringMatch(ModifyString(remainder, rules="extractAfter", ruleMods="|"), "add")
					else
						targetCol = str2num(remainder)
					endif
				endif
				break
            // Other parameters
			case "targetwave": // Output to specific wave (either existing or name of new to create)
				targetPath = paramArg
				break
			case "kill":
				killSource = 1
				break
			case "rebuild":
				rebuild = 1
				break	
		endswitch
	endfor
	//// WAVE ANALYSIS
	Make/FREE/N=(waveCount) waveRows, waveCols, waveTypes, effectiveRows, effectiveCols
	variable doingWave, maxInputType = 1
	for(doingWave = 0; doingWave < waveCount; doingWave += 1)
		WAVE/Z w = $StringFromList(doingWave, validWaves)
		if(!WaveExists(w))
			PrintAdv("Wave " + StringFromList(doingWave, validWaves) + " does not exist. Merge Failed.", type="error", state="error")
			debugger
			return $""
		endif
		variable rows, cols, wType, effRows, effCols
		[rows, cols, wType, effRows, effCols] = AnalyseWaveProperties(w, colSelection, rowSelection)
		waveRows[doingWave] = rows; waveCols[doingWave] = cols
		waveTypes[doingWave] = wType; effectiveRows[doingWave] = effRows; effectiveCols[doingWave] = effCols
		maxInputType = max(maxInputType, wType)
	endfor
	//// OUTPUT WAVE PREPARATION
	string mode = ""
	if(append)
		mode = "append"
	elseif(match)
		mode = "match"
	else
		mode = "expand"
	endif
	variable existingRows = 0, existingCols = 0
	if(strlen(targetPath) > 0)
		WAVE/Z existingWave = $targetPath
		if(WaveExists(existingWave) && !rebuild)
			existingRows = DimSize(existingWave, 0)
			existingCols = DimSize(existingWave, 1)
		endif
		outputName = targetPath
	else
		WAVE/Z existingWave = $outputName
		if(WaveExists(existingWave) && !rebuild)
			existingRows = DimSize(existingWave, 0)
			existingCols = DimSize(existingWave, 1)
		endif
	endif
	variable outputRows, outputCols
	[outputRows, outputCols] = CalculateOutputDimensions(effectiveRows, effectiveCols, mode, existingRows, existingCols)
	WAVE targetWave = MakeGetWave(outputName, outputRows, outputCols, maxInputType, rebuild)
	//// DATA COPYING LOOP
	variable currentRow = append ? existingRows : 0
	variable currentCol = expand ? existingCols : 0
	variable isFirstMatchWave = 1
	for(doingWave = 0; doingWave < waveCount; doingWave += 1)
		WAVE/Z inputWave = $StringFromList(doingWave, validWaves)
		variable inputRows = waveRows[doingWave], inputCols = waveCols[doingWave]
		Make/FREE/N=0 colsToCopy
		if(strlen(colSelection) > 0) // Build columns to copy list
			if(strsearch(colSelection, ",", 0) >= 0)
				variable numCols = ItemsInList(colSelection, ","), colIdx
				Redimension/N=(numCols) colsToCopy
				for(colIdx = 0; colIdx < numCols; colIdx += 1)
					variable colNum = str2num(StringFromList(colIdx, colSelection, ","))
					colsToCopy[colIdx] = (numtype(colNum) == 0 && colNum >= 0 && colNum < inputCols) ? colNum : 0
				endfor
			elseif(strsearch(colSelection, "-", 0) >= 0)
				variable startColNum = str2num(ModifyString(colSelection, rules="extractBefore", ruleMods="-"))
				variable endColNum = str2num(ModifyString(colSelection, rules="extractAfter", ruleMods="-"))
				startColNum = (numtype(startColNum) == 0 && startColNum >= 0) ? startColNum : 0
				endColNum = (numtype(endColNum) == 0 && endColNum < inputCols) ? endColNum : inputCols - 1
				if(endColNum >= startColNum)
					variable rangeSize = endColNum - startColNum + 1
					Redimension/N=(rangeSize) colsToCopy
					for(colIdx = 0; colIdx < rangeSize; colIdx += 1)
						colsToCopy[colIdx] = startColNum + colIdx
					endfor
				else
					Redimension/N=1 colsToCopy
					colsToCopy[0] = 0
				endif
			else
				Redimension/N=1 colsToCopy
				colNum = str2num(colSelection)
				colsToCopy[0] = (numtype(colNum) == 0 && colNum >= 0 && colNum < inputCols) ? colNum : 0
			endif
		else
				Redimension/N=(inputCols) colsToCopy
				for(colIdx = 0; colIdx < inputCols; colIdx += 1)
					colsToCopy[colIdx] = colIdx
				endfor
		endif
		variable writeStartRow = append ? currentRow : 0
		variable writeStartCol = append ? 0 : currentCol
		CopyWaveData(inputWave, targetWave, colsToCopy, writeStartRow, writeStartCol, inputRows, skipUnmatched, isFirstMatchWave, targetCol, inputCol)
		if(append) // Update position counters
			currentRow += inputRows
		elseif(expand || match)
			currentCol += DimSize(colsToCopy, 0)
		endif
		if(match)
			isFirstMatchWave = 0
		endif
	endfor
	if(killSource) // Cleanup source waves
		for(doingWave = 0; doingWave < waveCount; doingWave += 1)
			KillWaves/Z $StringFromList(doingWave, validWaves)
		endfor
	endif
	return targetWave
End
//--------------------------------------------------------------------------------------
Function CopyWaveData(WAVE inputWave, WAVE targetWave, WAVE colsToCopy, variable writeStartRow, variable writeStartCol, variable inputRows, variable skipUnmatched, variable isFirstMatchWave, variable targetCol, variable inputCol)
// What: Copies data from one wave to another, handling text and numeric types
	variable wTypeOut = WaveType(targetWave, 1), wTypeInp = WaveType(inputWave, 1), numColsToCopy = DimSize(colsToCopy, 0),rowIteration, col
	if(wTypeOut == 1 && wTypeInp == 2) // Convert target to text if needed
		ConvertWaveToText(targetWave)
		wTypeOut = 2
	endif
	for(rowIteration = 0; rowIteration < inputRows; rowIteration += 1)
		variable sourceRow = rowIteration, writeRow = writeStartRow + rowIteration
		if(!isFirstMatchWave) // Match mode: find matching row
			variable matchSourceCol = DimSize(colsToCopy, 0) > 0 ? colsToCopy[0] : inputCol
			variable matchVal = inputWave[sourceRow][matchSourceCol]
			Make/FREE/N=(DimSize(targetWave,0)) tempCol = targetWave[p][targetCol]
			FindValue/V=(matchVal) tempCol
			if(V_value >= 0)
				writeRow = V_value
			elseif(skipUnmatched)
				continue
			else
				writeRow = DimSize(targetWave, 0) - 1
			endif
		endif
		for(col = 0; col < numColsToCopy; col += 1) // Copy columns
			variable sourceCol = colsToCopy[col], writeCol = writeStartCol + col
			if(wTypeOut == 2)
				WAVE/T targetTxt = targetWave
				if(wTypeInp == 2)
					WAVE/T inputTxt = inputWave
					if(WaveDims(inputWave) == 1)
						targetTxt[writeRow][writeCol] = inputTxt[sourceRow]
					else
						targetTxt[writeRow][writeCol] = inputTxt[sourceRow][sourceCol]
					endif
				else
					if(WaveDims(inputWave) == 1)
						targetTxt[writeRow][writeCol] = num2str(inputWave[sourceRow])
					else
						targetTxt[writeRow][writeCol] = num2str(inputWave[sourceRow][sourceCol])
					endif
				endif
			else
				if(WaveDims(inputWave) == 1)
					targetWave[writeRow][writeCol] = inputWave[sourceRow]
				else
					targetWave[writeRow][writeCol] = inputWave[sourceRow][sourceCol]
				endif
			endif
			string sourceColName = GetDimLabel(inputWave, 1, sourceCol) // Copy dimension label
			SetDimLabel 1, writeCol, $sourceColName, targetWave
		endfor
	endfor
End
//--------------------------------------------------------------------------------------
Function DownsampleWithAntialiasing(Wave wSource, Variable factor)
// What: Downsample a wave with antialiasing for signals with significant high-frequency components.
	Variable sampleRate = 1/DimDelta(wSource, 0) // Calculate sample rate from wave's delta
	Variable normNyquistFreq = 0.5/factor // Calculate normalized cutoff frequency (must be between 0 and 0.5)
	Variable normCutoffFreq = normNyquistFreq * 0.8  // 80% of Nyquist as safety margin
	
	normCutoffFreq = min(0.49, normCutoffFreq)  // Keep safely below 0.5
	String filteredName = NameOfWave(wSource) + "_filt" // Create filtered wave
	Duplicate/O wSource, $filteredName
	Wave wFiltered = $filteredName
	FilterIIR/LO=(normCutoffFreq) wFiltered // Apply low-pass filter with normalized frequency
	// Decimate filtered wave
	String newName = NameOfWave(wSource) + "_ds"
	Duplicate/O wFiltered, $newName
	Wave wTarget = $newName
	Resample/DOWN=(factor)/N=1/WINF=None wTarget
	KillWaves wFiltered // Clean up
	return 0
End
//--------------------------------------------------------------------------------------
Function ConvertWaveToText(WAVE numWave, [string textWaveName])
    if(ParamIsDefault(textWaveName))
        textWaveName = NameOfWave(numWave)
    endif
    variable rows = DimSize(numWave, 0), cols = WaveDims(numWave) == 1 ? 1 : DimSize(numWave, 1), i, j
    Make/FREE/N=(rows, cols) tempNumWave // Create free copy of original data
    tempNumWave = numWave // Copy the data
    KillWaves numWave // Kill the original numeric wave
    Make/O/T/N=(rows, cols) $textWaveName // Now create text wave with same name
    WAVE/T txtWave = $textWaveName
    for(i = 0; i < rows; i += 1)
        for(j = 0; j < cols; j += 1)
            txtWave[i][j] = SelectString(cols == 1, num2str(tempNumWave[i]), num2str(tempNumWave[i][j]))
        endfor
    endfor
    // Copy dimension labels
    for(j = 0; j < cols; j += 1)
        string label = GetDimLabel(tempNumWave, 1, j)
        if(strlen(label) > 0)
            SetDimLabel 1, j, $label, txtWave
        endif
    endfor
End
//--------------------------------------------------------------------------------------
Function/S RenameWaves(string waveList, string findChars, string replaceChars, [string listSeparator, variable renameWaves, variable beSilent])
// What: Rename wave names by replacing specified characters. Can work on lists or individual names, with optional wave renaming
    // waveList: semicolon-separated list of wave names or single wave name
    // findChars: characters to find (e.g. " ;_;i" for space, underscore, letter i). replaceChars: replacement characters (e.g. ";-;1" for empty, dash, number 1)
    listSeparator = SelectString(ParamIsDefault(listSeparator), listSeparator, ";")
    beSilent = ParamIsDefault(beSilent) ? 0 : beSilent
    string processedList = "", currentWave, processedName
    variable waveIndex, charIndex, findCharCount, replaceCharCount, wavesRenamed = 0, namesProcessed = 0
    findCharCount = strlen(findChars); replaceCharCount = strlen(replaceChars)
    if(findCharCount == 0)
        PrintAdv("ProcessWaveNames: No characters to find specified", type="warning", beSilent=beSilent)
        return waveList
    endif
    if(findCharCount != replaceCharCount)
        PrintAdv("ProcessWaveNames: Find and replace character counts must match", type="error", beSilent=beSilent)
        return waveList
    endif
    for(waveIndex=0; waveIndex<ItemsInList(waveList, listSeparator); waveIndex+=1)
        currentWave = StringFromList(waveIndex, waveList, listSeparator)
        if(strlen(currentWave) == 0)
            continue
        endif
        processedName = currentWave
        for(charIndex=0; charIndex<findCharCount; charIndex+=1)
            string findChar = findChars[charIndex]
            string replaceChar = replaceChars[charIndex]
            processedName = ReplaceString(findChar, processedName, replaceChar)
        endfor
        processedList = AddListItem(processedName, processedList, listSeparator, Inf)
        namesProcessed += 1
        //  rename actual waves
        if(!StringMatch(currentWave, processedName))
            Wave/Z originalWave = $currentWave
            if(WaveExists(originalWave) && !WaveExists($processedName))
                Duplicate/O originalWave, $processedName
                KillWaves/Z originalWave
                wavesRenamed += 1
                if(!beSilent)
                    PrintAdv("Renamed wave: '" + currentWave + "' → '" + processedName + "'", type="info", state="indented")
                endif
            elseif(WaveExists($processedName))
                if(!beSilent)
                    PrintAdv("Warning: Target wave '" + processedName + "' already exists, skipping rename", type="warning")
                endif
            elseif(!WaveExists(originalWave))
                if(!beSilent)
                    PrintAdv("Warning: Source wave '" + currentWave + "' not found", type="warning")
                endif
            endif
        endif
    endfor
    if(!beSilent)
        string summary = "RenameWaves: Processed " + num2str(namesProcessed) + " names"
        summary += ", renamed " + num2str(wavesRenamed) + " waves"
        PrintAdv(summary, type="info")
    endif
    return processedList
End
//--------------------------------------------------------------------------------------
Function ShorternWave(Wave wSource, Variable targetLength, [Variable dsFactor])
// What: temporal wave truncation with an optional downsampling capability
	// Target length in the wave's units (e.g seconds etc)
	// Optional parameter for downsampling factor (2,10,100 etc)
	
	// Extract wave parameters
	String sourceName = NameOfWave(wSource), units = WaveUnits(wSource, 0), dsName = sourceName + "_ds", outputName = sourceName + "_processed"
	Variable delta = DimDelta(wSource, 0), offset = delta, totalTime = delta * numpnts(wSource)
	
	// Validate input
	if (targetLength <= 0 || targetLength >= totalTime)
		Print "Error: Invalid target length"
		return -1
	endif

	// Apply downsampling if specified
	if (!ParamIsDefault(dsFactor) && dsFactor > 1)
		if (exists("DownsampleWithAntialiasing") != 6)
			Print "Error: DownsampleWithAntialiasing function not found"
			return -1
		endif
		
		// Create temporary wave for downsampling
		String tempName = "temp_" + num2str(abs(enoise(1e6)))
		Duplicate/O wSource, $tempName
		Wave tempWave = $tempName
		DownsampleWithAntialiasing(tempWave, dsFactor) // Perform downsampling
		
		// Get downsampled wave and update delta
		Wave dsWave = $(tempName + "_ds")
		delta = DimDelta(dsWave, 0)
		Variable targetPoints = round(targetLength / delta) // Calculate target points based on new delta
		
		if (targetPoints >= numpnts(dsWave))
			Print "Error: Requested length exceeds available points after downsampling"
			KillWaves/Z tempWave, dsWave
			return -1
		endif
		
		// Create final output wave from downsampled wave
		Duplicate/O/R=[0, targetPoints-1] dsWave, $outputName 
		KillWaves/Z tempWave, dsWave // Clean up intermediate waves
	else
		// No downsampling - directly create truncated wave
		targetPoints = round(targetLength / delta) // Calculate target points based on delta
		Duplicate/O/R=[0, targetPoints-1] wSource, $outputName
	endif
	
	// Set scaling on output wave
	Wave outputWave = $outputName
	SetScale/P x, offset, delta, units, outputWave
	if(!ParamIsDefault(dsFactor)) // Add notes
		Note outputWave, "Source: " + sourceName + "; Duration: " + num2str(targetLength) + units + "; Downsample Factor: " + num2str(dsFactor)
	else
		Note outputWave, "Source: " + sourceName + "; Duration: " + num2str(targetLength) + units
	endif
	return 0
End
//--------------------------------------------------------------------------------------
Function ProcessCombineXY(string params, string saveDF, [variable displayGraph, variable beSilent])
// What: Extracts X and Y data from a reference wave, filters it based on bounds, and creates a plot.
	// params: A string containing all parameters for the operation. saveDF: The base data folder path for resolving relative paths.
	string refWaveStr = ModifyString(params, rules="extractBetweenDelim", ruleMods="refWave=|:"), refWavePath = saveDF + refWaveStr
	string plotFolder = saveDF + ModifyString(params, rules="extractBetweenDelim", ruleMods="plotFolder=|:")
	string xCol = ModifyString(params, rules="extractBetweenDelim", ruleMods="xCol=|:"), yCol = ModifyString(params, rules="extractBetweenDelim", ruleMods="yCol=|:")
	string xBound = ModifyString(params, rules="extractBetweenDelim", ruleMods="xBound=|:"), yBound = ModifyString(params, rules="extractBetweenDelim", ruleMods="yBound=|:")
	string xLabel = ModifyString(params, rules="extractBetweenDelim", ruleMods="xLabel=|:"), yLabel = ModifyString(params, rules="extractBetweenDelim", ruleMods="yLabel=|:")
	string xName = ModifyString(params, rules="extractBetweenDelim", ruleMods="xWave=|:"), yName = ModifyString(params, rules="extractBetweenDelim", ruleMods="yWave=|:")
	string xBaselineCol = ModifyString(params, rules="extractBetweenDelim", ruleMods="xBlCol=|:"), yBaselineCol = ModifyString(params, rules="extractBetweenDelim", ruleMods="yBlCol=|:")
	WAVE/T/Z refWave = $(refWavePath)
	if(!WaveExists(refWave))
		PrintAdv("ProcessCombineXY Error: Reference wave does not exist: " + refWavePath, type="error", beSilent=beSilent)
		return 0
	endif
	SetCreateDataFolder(plotFolder)
	Make/O/N=(DimSize(refWave, 0)) xValues, yValues
	variable xBoundLow = str2num(StringFromList(0, xBound, "/")), xBoundHigh = str2num(StringFromList(1, xBound, "/"))
	variable yBoundLow = str2num(StringFromList(0, yBound, "/")), yBoundHigh = str2num(StringFromList(1, yBound, "/"))
	variable validPoints = 0, pointIndex
	for(pointIndex = 0; pointIndex < DimSize(refWave, 0); pointIndex+=1)
		variable xColDim = FindDimLabel(refWave, 1, xCol), yColDim = FindDimLabel(refWave, 1, yCol)
		//variable xBLdim=FindDimLabel(refWave, 1, xBaselineCol), yBLdim=FindDimLabel(refWave, 1, yBaselineCol)
		variable xVal = str2num(refWave[pointIndex][xColDim]), yVal = str2num(refWave[pointIndex][yColDim])
		//variable xBLVal = str2num(refWave[pointIndex][xBLdim]), yBLVal = str2num(refWave[pointIndex][yBLdim])
		//variable xBLRMSVal = str2num(refWave[pointIndex][xBLdim]), yBLRMSVal = str2num(refWave[pointIndex][yBLdim])
		if(xVal >= xBoundLow && xVal <= xBoundHigh && yVal >= yBoundLow && yVal <= yBoundHigh)
			xValues[validPoints] = xVal; yValues[validPoints] = yVal
			//xBLVal; xValues[validPoints][2] = xBLRMSVal; yValues[validPoints][2] = yBLRMSVal
			validPoints += 1
		endif
	endfor
	if(validPoints == 0)
		PrintAdv("ProcessCombineXY Warning: No valid data points found after filtering.", type="warning", beSilent=beSilent)
		KillWaves/Z xValues, yValues
		return 0
	endif
	if(!ParamIsDefault(displayGraph) && displayGraph == 1)
		string graphName = "plot_" + yCol + "_vs_" + xCol
		DoWindow/K $(graphName)
		Redimension/N=(validPoints) xValues, yValues
		Display/N=$(graphName)/W=(400,300,800,600) yValues vs xValues
		ModifyGraph mode=3,marker=19
		Label left yLabel
		Label bottom xLabel
	endif
	return 1
End
//--------------------------------------------------------------------------------------
Function/WAVE CollapseDataTable(WAVE inputWave, variable xColumn, variable yColumn, [string outputWaveName])
// What: Collapses a data table so each unique X value has multiple Y values in additional columns
    /// inputWave: 2D wave with X and Y columns. xColumn: Column index for X values, yColumn: Column index for Y values
    /// [outputWaveName]: Optional name for output wave (default: NameOfWave(inputWave) + "_Unique")
    if(ParamIsDefault(outputWaveName))
        outputWaveName = NameOfWave(inputWave) + "_Unique"
    endif
    // Check input wave dimensions
    if(!WaveExists(inputWave))
        PrintAdv("Error: Input wave does not exist", type="error")
        return $""
    endif 
    if(WaveDims(inputWave) < 2)
        PrintAdv("Error: Input wave must be 2D", type="error")
        return $""
    endif 
    // Extract unique X values
    variable numRows = DimSize(inputWave, 0)
    Make/O/N=(numRows) tempXValues
    variable i
    for(i=0; i<numRows; i+=1)
        tempXValues[i] = inputWave[i][xColumn]
    endfor
    // Sort and find unique X values
    Sort tempXValues, tempXValues
    Duplicate/O tempXValues, uniqueXValues
    uniqueXValues = uniqueXValues[p] != uniqueXValues[p-1] ? uniqueXValues[p] : NaN
    WaveStats/Q/M=1 uniqueXValues // Count non-NaN values
    variable numUniqueX = V_npnts 
    // Create a wave with only unique X values
    Make/O/N=(numUniqueX) uniqueXWave
    variable uniqueIndex = 0
    for(i=0; i<numRows; i+=1)
        if(!numtype(uniqueXValues[i]))
            uniqueXWave[uniqueIndex] = uniqueXValues[i]
            uniqueIndex += 1
        endif
    endfor 
    // Count maximum number of Y values for each unique X
    Make/O/N=(numUniqueX) yCountsPerX
    yCountsPerX = 0 
    for(i=0; i<numRows; i+=1)
        variable currentX = inputWave[i][xColumn]
        variable currentY = inputWave[i][yColumn]
        
        // Only count non-NaN Y values
        if(numtype(currentY) == 0)
            FindValue/V=(currentX) uniqueXWave
            if(V_Value >= 0)
                yCountsPerX[V_Value] += 1
            endif
        endif
    endfor
    WaveStats/Q yCountsPerX
    variable maxYCount = V_max
    Make/O/N=(numUniqueX, maxYCount+1) $outputWaveName
    WAVE outputWave = $outputWaveName
    // Initialize with NaN
    outputWave = NaN
    // Fill in X values in column 0
    for(i=0; i<numUniqueX; i+=1)
        outputWave[i][0] = uniqueXWave[i]
    endfor
    // Fill in Y values in columns 1+
    Make/O/N=(numUniqueX) currentYIndex
    currentYIndex = 0
    // First pass - collect all valid Y values for each X
    for(i=0; i<numRows; i+=1)
        variable xVal = inputWave[i][xColumn]
        variable yVal = inputWave[i][yColumn]
        // Skip if Y value is NaN
        if(numtype(yVal) != 0)
            continue
        endif
        FindValue/V=(xVal) uniqueXWave
        if(V_Value >= 0)
            variable xIndex = V_Value
            variable yIndex = currentYIndex[xIndex] + 1 // +1 because column 0 is for X values
            
            if(yIndex <= maxYCount)
                outputWave[xIndex][yIndex] = yVal
                currentYIndex[xIndex] += 1
            endif
        endif
    endfor
    // Remove rows that have , no Y values (all NaN in columns 1+)
    variable validRows = 0, j
    Make/O/N=(numUniqueX) validRowIndices
    validRowIndices = -1 // Initialize with invalid index
    for(i=0; i<numUniqueX; i+=1)
        // Check if this row has any valid Y values
        variable hasValues = 0
        for(j=1; j<=maxYCount; j+=1)
            if(numtype(outputWave[i][j]) == 0) // Not NaN
                hasValues = 1
                break
            endif
        endfor 
        if(hasValues)
            validRowIndices[validRows] = i
            validRows += 1
        endif
    endfor
    // If we have fewer valid rows than total rows, create a cleaned output wave
    if(validRows < numUniqueX)
        string cleanedWaveName = outputWaveName + "_Clean"
        Make/O/N=(validRows, maxYCount+1) $cleanedWaveName
        WAVE cleanedWave = $cleanedWaveName
        
        // Copy only valid rows to the cleaned wave
        for(i=0; i<validRows; i+=1)
            variable sourceRow = validRowIndices[i]
            for(j=0; j<=maxYCount; j+=1)
                cleanedWave[i][j] = outputWave[sourceRow][j]
            endfor
        endfor
        
        // Replace the original output wave with the cleaned one
        Duplicate/O cleanedWave, $outputWaveName
        KillWaves/Z cleanedWave
        WAVE outputWave = $outputWaveName
    endif
    KillWaves/Z tempXValues, uniqueXValues, uniqueXWave, yCountsPerX, currentYIndex, validRowIndices
    return outputWave
End
//----------------------------------------------------------------------
Function/S SegmentData(string dataPath, string fileList, string segParams, variable beSilent, [string outputPath])
/// What: Segments data according to specified parameters
    /// dataPath: Path to data folder
    /// fileList: List of files to process (semicolon-separated)
    /// segParams: Parameter string with segmentation options. newFile creates file for each segment, segIndex creates index wave instead (can do both). duration sets segment duration in seconds
    /// beSilent: If 1, suppresses output messages
    string saveDF = GetDataFolder(1), resultPath = ""
    PrintAdv("SegmentData [" + dataPath + fileList + "]", type="segment", beSilent=beSilent)
    // Handle output path
    string targetDF = saveDF
    if(!ParamIsDefault(outputPath) && strlen(outputPath) > 0)
        if(!DataFolderExists(outputPath))
            NewDataFolder/O $outputPath
        endif
        targetDF = outputPath
        PrintAdv("Using output path: " + outputPath, state="debug", beSilent=beSilent)
    else 
        string outFldrName = "SegmentData"
        targetDF = saveDF + outFldrName
        if(!DataFolderExists(targetDF))
            NewDataFolder/O $outFldrName
        endif
        PrintAdv("Using default output path: " + targetDF, state="debug", beSilent=beSilent)
    endif
    variable useNewFile = 0, useSegIndex = 0, useSetDuration = 0, duration = 1
    string splitIndexWave = ""
    // Parse parameters
    if(strlen(segParams) > 0)
        // Extract split index wave name if specified
        if(grepstring(segParams, "splitIndex="))
            splitIndexWave = ModifyString(segParams, rules="extractBetweenDelim", ruleMods="splitIndex=|:")
        endif     
        useNewFile = grepstring(segParams, "newFile")
        useSegIndex = grepstring(segParams, "segIndex")  
        // Parse duration parameter specifically looking for duration=X format
        useSetDuration = grepstring(segParams, "duration=")
        if(useSetDuration)
            // Find the portion containing duration=X
            variable i, foundDuration = 0
            for(i=0; i<ItemsInList(segParams, ":"); i+=1)
                string itemPart = StringFromList(i, segParams, ":")
                if(strsearch(itemPart, "duration=", 0) >= 0)
                    // Extract just the number part
                    duration = str2num(ModifyString(itemPart, rules="extractAfter", ruleMods="="))
                    PrintAdv("Set Duration: " + num2str(duration) + "s via segParams(" + itemPart + ")", type="time", state="debug", beSilent=beSilent)
                    foundDuration = 1
                    break
                endif
            endfor
            
            if(!foundDuration)
                // Fallback - keep default duration
                PrintAdv("Warning: Could not parse duration from parameters. Using default: " + num2str(duration) + "s", type="warning", beSilent=beSilent)
            endif
        endif
    else // Default to segIndex only
        useSegIndex = 1
    endif   
    // Validate data path
    if(StrLen(dataPath) == 0 || !DataFolderExists(dataPath))
        PrintAdv("Error: Invalid data path for segmentation", type="error", beSilent=beSilent)
        return ""
    endif  
    // Move to data folder
    SetDataFolder $dataPath 
    // Get split index wave if specified
    WAVE/Z/T splitWave = $""
    if(strlen(splitIndexWave) > 0)
        WAVE/Z/T splitWave = $splitIndexWave
        if(!WaveExists(splitWave))
            PrintAdv("Error: Split index wave not found: " + splitIndexWave + " (" + dataPath + ")", type="error", beSilent=beSilent)
            SetDataFolder $saveDF
            return ""
        endif
    endif
    
    // Process each file
    variable fileIndex, startPoint, endPoint
    PrintAdv("Processing files: " + fileList, type="data", beSilent=beSilent, state="indented")
    for(fileIndex=0; fileIndex<ItemsInList(fileList); fileIndex+=1)
        string currentFile = StringFromList(fileIndex, fileList)
        WAVE/Z dataWave = $currentFile      
        if(WaveExists(dataWave))
            // Debug wave information
            variable wavePoints = numpnts(dataWave), refcount = 0, waveDelta = DimDelta(dataWave, 0), waveStart = DimOffset(dataWave, 0), waveEnd = waveStart + (wavePoints-1) * waveDelta
            PrintAdv("Wave info: " + currentFile + ": Points=" + num2str(wavePoints) + ", Delta=" + num2str(waveDelta) + ", Range=[" + num2str(waveStart) + " to " + num2str(waveEnd) + "]", state="debug", beSilent=beSilent)
            // Create segments based on split wave
            if(WaveExists(splitWave))
                // Debug split wave information
                variable splitWaveRows = DimSize(splitWave, 0)
                variable splitWaveCols = 0
                if(WaveDims(splitWave) > 1)
                    splitWaveCols = DimSize(splitWave, 1)
                endif
                PrintAdv("Split wave info: " + splitIndexWave + ": Rows=" + num2str(splitWaveRows) + ", Cols=" + num2str(splitWaveCols) + ", WaveDims=" + num2str(WaveDims(splitWave)), state="debug", beSilent=beSilent)    
                variable segIndex
                for(segIndex=0; segIndex<splitWaveRows; segIndex+=1)
                    // Get segment boundaries - handle both 1D and 2D waves
                    variable startTime
                    if(WaveDims(splitWave) > 1)
                        startTime = str2num(splitWave[segIndex][%startTime])
                        if(!useSetDuration)
                            duration = str2num(splitWave[segIndex][%duration])
                        endif
                    else
                        // For 1D waves, use the value as the start time
                        startTime = str2num(splitWave[segIndex])
                    endif    
                    if(!useSetDuration) 
                        // Check duration is valid
                        if(duration <= 0)
                            PrintAdv("Error: Invalid duration specified in segParams(" + segParams + ")", type="error", beSilent=beSilent)
                            SetDataFolder $saveDF
                            return ""
                        endif
                    endif
                    
                    // Debug segment time boundary information
                    if(refcount < 3)
                        PrintAdv("Segment " + num2str(segIndex) + " for " + currentFile + ": StartTime=" + num2str(startTime) + ", Duration=" + num2str(duration) + ", EndTime=" + num2str(startTime + duration), state="debug", beSilent=beSilent)
                        refcount += 1
                    endif
                    
                    //// CREATE SEGMENT REFERENCE WAVE (if segIndex parsed)
                    if(useSegIndex)
                        string indexName = currentFile + "_segments"
                        string colNames = "Name;StartRow;StartTime;EndRow;EndTime"
                        string colTypes = "text;variable;variable;variable;variable"
                        WAVE/T/Z refWave = $""
                            
                        // Move to target data folder for creating/using reference waves
                        SetDataFolder $targetDF

                        // Calculate points from time
                        startPoint = x2pnt(dataWave, startTime)
                        endPoint = x2pnt(dataWave, startTime + duration)
                        
                        // Add segment to reference wave
                        string segName = "Segment_" + num2str(segIndex)
                        string segData = segName + ";" + num2str(startPoint) + ";" + num2str(startTime) + ";" + num2str(endPoint) + ";" + num2str(startTime + duration)

                        if(segIndex == 0) // Create new reference wave for first segment
                            // Create reference wave in the target folder
                            WAVE/T refWave = CreateReferenceWave(indexName, colNames, inputData=segData)
                            
                            // Add full path to result list
                            if(!ParamIsDefault(outputPath) && strlen(outputPath) > 0)
                                resultPath = AddListItem(outputPath+":"+indexName, resultPath)
                            else
                                resultPath = AddListItem(indexName, resultPath)
                            endif        
                            PrintAdv("✅ Created segment index wave: " + indexName + " for " + currentFile + " in " + targetDF, state="debug", beSilent=beSilent)
                        else
                            WAVE/T refWave = $indexName
                            AddToReferenceWave(refWave, colNames, rowValues=segData)
                        endif 
                        // Return to data path
                        SetDataFolder $dataPath
                    endif
                    
                    //// CREATE SEPRATE SEGMENT WAVES (if newFile parsed)
                    if(useNewFile)
                        string subWaveName = currentFile + "_seg" + num2str(segIndex)
                        
                        // Calculate points from time for duplication
                         startPoint = x2pnt(dataWave, startTime)
                         endPoint = x2pnt(dataWave, startTime + duration)

                        // Check if segment would be valid
                        if(startPoint < 0 || endPoint >= numpnts(dataWave) || endPoint <= startPoint || (endPoint - startPoint) <= 1)
                            PrintAdv("Warning: Invalid point range for segment " + subWaveName + ". StartPoint=" + num2str(startPoint) + ", EndPoint=" + num2str(endPoint), type="warning", beSilent=beSilent)
                            continue
                        endif
                        
                        // Create segment wave in target data folder
                        SetDataFolder $targetDF
                        Duplicate/O/R=[startPoint, endPoint] dataWave, $subWaveName
                        SetDataFolder $dataPath
                        
                        // Set scale of wave
                        variable segScale, startTimeMs
                        string durationUnit
                        if(useSetDuration && duration <= 1) // If correlation duration less than a second use ms instead of s
                             segScale = duration * 1000
                             durationUnit = "ms"
                        elseif(duration > 1)
                             segScale = duration
                             durationUnit = "s"
                        endif

                        SetDataFolder $targetDF
                        SetScale/I x 0, segScale, durationUnit, $subWaveName
                        SetDataFolder $dataPath
                        
                        // Add wave note (in target folder)
                        string noteSource = "Source: " + dataPath + ":" + currentFile
                        string noteTime = "Time | Start: " + num2str(startTime) + " s" + " / " + "Duration: " + num2str(segScale) + " " + durationUnit
                        string noteRows = "Start Row: " + num2str(startPoint) + " / " + "End Row: " + num2str(endPoint)
                        
                        SetDataFolder $targetDF
                        Note $subWaveName, noteSource + "\r" + noteTime + "\r" + noteRows 
                        SetDataFolder $dataPath
                        
                        // Check for corrupted segment (too few points)
                        SetDataFolder $targetDF
                        WAVE/Z segWave = $subWaveName
                        SetDataFolder $dataPath
                        if(!WaveExists(segWave) || numpnts(segWave) <= 1)
                            PrintAdv("Warning: Segment " + subWaveName + " has too few points and may be corrupted", type="warning", beSilent=beSilent)
                            if(WaveExists(segWave))
                                SetDataFolder $targetDF
                                KillWaves segWave
                                SetDataFolder $dataPath
                            endif
                        else
                            // Debug successful segment creation
                            //PrintAdv("✅ Successfully created segment: " + subWaveName + " with " + num2str(numpnts(segWave)) + " points", type="debug", beSilent=beSilent)
                            resultPath = AddListItem(subWaveName, resultPath)
                        endif
                    endif

                    //// CREATE MERGED SEGMENT WAVE (TBD)
                endfor
            endif
        else
            PrintAdv("Warning: Wave not found: " + currentFile, type="warning", beSilent=beSilent)
        endif
    endfor
    
    SetDataFolder $saveDF
    // Debug final result path before returning
    PrintAdv("Final result path contains " + num2str(ItemsInList(resultPath)) + " segments", state="debug", beSilent=beSilent)
    
    // Include output folder in results if applicable
    if(!ParamIsDefault(outputPath) && strlen(outputPath) > 0)
        PrintAdv("Segments created in output folder: " + outputPath, state="debug", beSilent=beSilent)
    endif
    
    return resultPath
End
//--------------------------------------------------------------------------------------
////////////////////////////////////////////////////////////////////////////////////////
//// WAVE FILTERING
////////////////////////////////////////////////////////////////////////////////////////
//--------------------------------------------------------------------------------------
Function ReduceWaveNoise(wave w, wave/t baselineStats, [string outputName])
// What: Creates wave keeping only points above baseline max or below baseline min, sets rest to 0
    if(ParamIsDefault(outputName))
        outputName = NameOfWave(w) + "_signals"
    endif  
    // Get baseline min and max
    variable baselineColIndex = FindDimLabel(baselineStats, 1, NameOfWave(w)), baselineRowMinIndex = FindDimLabel(baselineStats, 0, "Min"), baselineRowMaxIndex = FindDimLabel(baselineStats, 0, "Max")
    variable baselineMin = str2num(baselineStats[baselineRowMinIndex][baselineColIndex])
    variable baselineMax = str2num(baselineStats[baselineRowMaxIndex][baselineColIndex])
    // Create output wave
    Duplicate/O w, $outputName
    WAVE signalWave = $outputName
    // Keep signal points, zero out baseline
    variable i, signalPoints = 0
    for(i = 0; i < numpnts(signalWave); i += 1)
        if(w[i] > baselineMax || w[i] < baselineMin)
            // Keep original signal value
            signalPoints += 1
        else
            // Set baseline region to 0
            signalWave[i] = 0
        endif
    endfor
    PrintAdv("Preserved " + num2str(signalPoints) + " signal points above " + num2str(baselineMax) + " or below " + num2str(baselineMin))
    return 0
End
//--------------------------------------------------------------------------------------
Threadsafe Function/WAVE BandpassFilter(WAVE inputWave, variable lowHz, variable highHz, [string outputName, variable overwrite, variable fast, variable order, variable notch, variable removeDC, variable SNR])
// What: Applies bandpass filter with FIR (default) or fast IIR option, includes bidirectional filtering for zero-phase
    // inputWave: Wave to filter | lowHz: Low cutoff frequency | highHz: High cutoff frequency | [outputName]: Optional name for output wave | [overwrite]: If 1, filters inputWave directly; if 0, creates new wave | [fast]: If 1, use fast IIR filter; if 0, use FIR (default) | [order]: IIR filter order (default 4) | [notch]: If 1, applies 50Hz notch filter after bandpass | [removeDC]: If 1, removes DC component (mean) before filtering
    overwrite = ParamIsDefault(overwrite) ? 0 : overwrite
    fast = ParamIsDefault(fast) ? 0 : fast // Default to slower FIR mode
    order = ParamIsDefault(order) ? -4 : order // Default IIR order
    notch = ParamIsDefault(notch) ? 0 : notch // Default no notch filtering
    removeDC = ParamIsDefault(removeDC) ? 0 : removeDC // Default no DC removal
    variable sampleRate = 1/deltax(inputWave), nyquistFreq = sampleRate/2
    if(lowHz <= 0 || highHz <= 0 || lowHz >= highHz)
        return $"" 
    endif
    if(highHz >= nyquistFreq * 0.99)
        highHz = nyquistFreq * 0.99 // Limit to 90% of Nyquist for safety
		Print "highHz > nyquistFreq. Reducing to 0.99 of Nyquist ("+num2str(highHz)+")"
    endif
    if(lowHz >= nyquistFreq * 0.99)
		Print "lowHz > nyquistFreq. Reducing to 0.99 of Nyquist ("+num2str(lowHz)+")"
        lowHz = nyquistFreq * 0.99
    endif
    if(overwrite) // Filter input wave directly
        WAVE/Z filteredWave = inputWave
    else // Create new filtered wave
        string filteredName = SelectString(ParamIsDefault(outputName), outputName, NameOfWave(inputWave) + "_filtered")
        Duplicate/O inputWave, $filteredName
        WAVE/Z filteredWave = $filteredName
    endif
    if(removeDC == 1) // Remove DC component (mean) before filtering
        wavestats/q filteredWave; multithread filteredWave -= v_avg
    endif
	if(notch == 1)
		NotchFilter(filteredWave, 50, overwrite=1, order=order)
	endif
    // Apply filtering based on fast parameter (IIR not FIR)
    if(fast) // Fast IIR filtering with bidirectional option for zero-phase
        variable numPnt = numpnts(filteredWave)
        if(order > 0) // Forward filtering only
            FilterIIR/HI=(highHz*deltax(filteredWave))/LO=(lowHz*deltax(filteredWave))/ORD=(order) filteredWave
        else // True zero-phase bidirectional filtering (filtfilt approach)
            FilterIIR/HI=(highHz*deltax(filteredWave))/LO=(lowHz*deltax(filteredWave))/ORD=(abs(order)) filteredWave // Forward pass
            Duplicate/FREE filteredWave, backWave
            multithread backWave = filteredWave[numPnt-1-p] // Reverse the wave
            FilterIIR/HI=(highHz*deltax(backWave))/LO=(lowHz*deltax(backWave))/ORD=(abs(order)) backWave // Backward pass
            multithread filteredWave = backWave[numPnt-1-p] // Reverse back to original order
        endif
        Note filteredWave, "IIR Bandpass filtered: " + num2str(lowHz) + "-" + num2str(highHz) + " Hz (Order=" + num2str(abs(order)) + ", Bidirectional=" + SelectString(order>0, "Yes", "No") + ")"
    else // Standard FIR filtering | Slower, but may be more accurate
        variable lowNorm = lowHz / sampleRate, highNorm = highHz / sampleRate
        variable lowTransition = max(lowNorm * 0.1, 0.01), highTransition = max(highNorm * 0.1, 0.01)
        variable lowNorm1 = max(lowNorm - lowTransition, 0.001) // Low cutoff start
        variable lowNorm2 = min(lowNorm + lowTransition, 0.499) // Low cutoff end
        variable highNorm1 = max(highNorm - highTransition, lowNorm2 + 0.001) // High cutoff start
        variable highNorm2 = min(highNorm + highTransition, 0.499) // High cutoff end
        FilterFIR/LO={lowNorm1, lowNorm2, 101}/HI={highNorm1, highNorm2, 101} filteredWave
        Note filteredWave, "FIR Bandpass filtered: " + num2str(lowHz) + "-" + num2str(highHz) + " Hz (101-point, linear phase, sampleRate=" + num2str(sampleRate/1000) + "kHz)"
    endif
	if(!paramIsDefault(SNR)) // If you want to get printout of SNR
		Note filteredWave, "SNR: " + num2str(CalculateSNR(filteredWave, fast=1))+"dB"
	endif
    return filteredWave
End
//--------------------------------------------------------------------------------------
Threadsafe Function/WAVE NotchFilter(WAVE inputWave, variable notchHz, [string outputName, variable overwrite, variable bandwidth, variable order])
// What: Removes specific frequency (e.g., 50/60Hz power line noise) using IIR notch filter with zero-phase
    // inputWave: Wave to filter | notchHz: Frequency to remove | [outputName]: Optional name for output wave | [overwrite]: If 1, filters inputWave directly | [bandwidth]: Notch width in Hz (default 2Hz) | [order]: Filter order (default -4 for bidirectional, positive for forward only)
    overwrite = ParamIsDefault(overwrite) ? 0 : overwrite
	bandwidth = ParamIsDefault(bandwidth) ? 2 : bandwidth
	order = ParamIsDefault(order) ? -4 : order
    variable sampleRate = 1/deltax(inputWave), nyquistFreq = sampleRate/2
    if(notchHz <= 0 || notchHz >= nyquistFreq * 0.95)
        return $"" 
    endif
    if(overwrite) // Filter input wave directly
        WAVE/Z filteredWave = inputWave
    else // Create new filtered wave
        string filteredName = SelectString(ParamIsDefault(outputName), outputName, NameOfWave(inputWave) + "_notched")
        Duplicate/O inputWave, $filteredName
        WAVE/Z filteredWave = $filteredName
    endif
    variable numPnt = numpnts(filteredWave), notchQ = 50 // Q factor for notch width
    variable normalizedFreq = notchHz * deltax(filteredWave) // Normalize frequency
    if(order > 0) // Forward filtering only
        FilterIIR/N={normalizedFreq, notchQ}/ORD=(order) filteredWave
        Note filteredWave, "IIR Notch filtered: " + num2str(notchHz) + " Hz (±" + num2str(bandwidth/2) + "Hz, Order=" + num2str(order) + ", Forward only)"
    else // Zero-phase bidirectional IIR notch filtering
        FilterIIR/N={normalizedFreq, notchQ}/ORD=(abs(order)) filteredWave // Forward pass
        Duplicate/FREE filteredWave, backWave
        multithread backWave = filteredWave[numPnt-1-p] // Reverse the wave
        FilterIIR/N={normalizedFreq, notchQ}/ORD=(abs(order)) backWave // Backward pass
        multithread filteredWave = backWave[numPnt-1-p] // Reverse back to original order
        Note filteredWave, "IIR Notch filtered: " + num2str(notchHz) + " Hz (±" + num2str(bandwidth/2) + "Hz, Order=" + num2str(abs(order)) + ", Bidirectional=" + SelectString(order>0, "Yes", "No") + ")"
    endif
    return filteredWave
End