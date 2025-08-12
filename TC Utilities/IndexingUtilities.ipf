#pragma rtGlobals= 3				// Use modern global access method.
#pragma version= 2.01				
#pragma IgorVersion= 9.00			// Requires Igor 9.0 or newer.
#pragma ModuleName= IndexingUtilities
#include "WaveUtilities"
// ===========================================================================
//                           INDEXING UTILITIES
// ===========================================================================
// Description: Generalised system for importing, sorting and indexing experimental files from disk into Igor.
// Author: Thomas Cahir
// Created: 20-06-2025
// ============================================================================
// 1.0 | 20-06-2025 - Reorganised into categories
// 1.1 | 12-08-2025 - Reworked, deleted legacy funcs not in use anywhere
//*********************************************************************************************************************
////////////////////////////////////////////////////////////////////////////////////////
//// IGOR INDEXING
////////////////////////////////////////////////////////////////////////////////////////
Menu "DataBrowserObjectsPopup", dynamic
	GetCustomMenuItem("Save Wave", "WaveExists(w)", 0, 1, hideCondition="test"), /Q, HandleMenuSelection("SaveWaveToSystem")
End
//*********************************************************************************************************************
static strconstant indexWaveCols = "Name;allParams;paramPattern;WaveParams;StringParams;VariableParams;StructParams;WaveParamsOpt;StringParamsOpt;VariableParamsOpt;ReturnType;ProcedureFile;FullPath"
//--------------------------------------------------------------------------------------
////////////////////////////////////////////////////////////////////////////////////////
//// DATA FOLDER INDEXING & CREATION
////////////////////////////////////////////////////////////////////////////////////////
Function/S SetCreateDataFolder(string folderPath, [variable returnToCurrentFolder])
// What: Creates a data folder if it doesn't exist, or moves to it if it already exists.
	// Handles nested paths of any depth (e.g. root:Packages:MyPackage:Layouts)
	string startingFolder = GetDataFolder(1), dfString = "root:", currentFolder, pathParts, part, quotedPart
	variable i, numParts    
	// Handle absolute vs relative paths
	if(cmpstr(folderPath[0,4], "root:") == 0)
		currentFolder = "root:"
		pathParts = folderPath[5,inf]
	else
		currentFolder = GetDataFolder(1)
		pathParts = folderPath
	endif  
	// Split path and create each level
	numParts = ItemsInList(pathParts, ":")
	for(i=0; i<numParts; i+=1)
		part = StringFromList(i, pathParts, ":")
		if(strlen(part) > 0)
			// Check if folder name needs quotes (starts with digit or contains special chars)
			if(char2num(part[0]) >= 48 && char2num(part[0]) <= 57) // starts with digit
				quotedPart = "'" + part + "'"
			else
				quotedPart = part
			endif
			dfString += quotedPart		
			if(!DataFolderExists(dfString))
				NewDataFolder/S $part
			else
				SetDataFolder $dfString
			endif
			currentFolder = dfString
			dfString += ":"
		endif
	endfor
	string finalFolder = GetDataFolder(1)
	if(returnToCurrentFolder > 0)
		SetDataFolder startingFolder
	endif
	return finalFolder
End
//--------------------------------------------------------------------------------------
Function/S GetAllSubFolders([string startFolder, variable includeStartFolder])
// What: Returns a semicolon-separated list of all subfolders (recursively) in the given IGOR datafolder
	// Input: startFolder - the folder to start searching from (if empty, uses current folder)
	//        includeStartFolder - if 1, includes the start folder in the output list (default: 0)
	// Returns: semicolon-separated list of all subfolders (full paths)
	string allFolders = "", currentFolder, savedDataFolder
	savedDataFolder = GetDataFolder(1)
	if(ParamIsDefault(includeStartFolder))
		includeStartFolder = 0
	endif
	if(ParamIsDefault(startFolder))
		startFolder = GetDataFolder(1)
	endif
	if(strlen(startFolder) == 0)
		currentFolder = GetDataFolder(1)
	else	
		string prevfolder = startFolder
		currentFolder = RemoveEnding(startFolder, ":")
		currentFolder += ":" // Ensure path ends with ":"
	endif
	// Create temporary wave to store folders to process
	Make/O/T/N=1 root:W_FoldersToProcess = currentFolder
	Wave/T W_FoldersToProcess = root:W_FoldersToProcess
	variable numToProcess = 1, folderIndex = 0
	do
		if(folderIndex >= numToProcess)
			break
		endif
		// Get current folder to process and clean it
		string cleanFolder = W_FoldersToProcess[folderIndex]
		cleanFolder = RemoveEnding(cleanFolder, ":"); cleanFolder += ":"
		// Check if folder exists before trying to access it
		if(DataFolderExists(cleanFolder))
			SetDataFolder $cleanFolder
			// Add to output list if requested or not start folder
			if(includeStartFolder || cmpstr(cleanFolder, startFolder) != 0)
				// Remove trailing ":" before adding to list
				string cleanPath = RemoveEnding(cleanFolder, ":")
				allFolders = AddListItem(cleanPath, allFolders, ";", inf)
			endif
			// Get subfolders
			string rawFolderList = DataFolderDir(1)
			if(strsearch(rawFolderList, "FOLDERS:", 0) == 0)
				// Get folder list and clean it
				string subfolders = rawFolderList[8,inf]
				subfolders = RemoveEnding(subfolders, "\r")
				subfolders = RemoveEnding(subfolders, "\n")
				subfolders = RemoveEnding(subfolders, " ")
				subfolders = RemoveEnding(subfolders, ",")
				subfolders = RemoveEnding(subfolders, ";")
				variable numNew = ItemsInList(subfolders, ",")
				if(numNew > 0)
					InsertPoints numToProcess, numNew, W_FoldersToProcess
					variable i
					for(i=0; i<numNew; i+=1)
						string newFolder = StringFromList(i, subfolders, ",")
						if(strlen(newFolder) > 0)
							// Add quotes if folder name contains special characters
							if(strsearch(newFolder, " ", 0) >= 0 || strsearch(newFolder, "_", 0) >= 0 || strsearch(newFolder, "0", 0) >= 0)
								newFolder = "'" + newFolder + "'"
							endif
							W_FoldersToProcess[numToProcess + i] = cleanFolder + newFolder + ":" // Build Full Path
						endif
					endfor
					numToProcess += numNew
				endif
			endif
		else
			printf "⚠️ Warning: Could not access folder '%s'\r", cleanFolder
		endif	
		folderIndex += 1
	while(1)
	KillWaves/Z W_FoldersToProcess
	SetDataFolder $savedDataFolder
	allFolders = RemoveFromList("", allFolders, ";")
	return allFolders
End
//--------------------------------------------------------------------------------------
Function/WAVE GetMatchingFolders(string folderPattern)
// What: Discovers and validates folders matching the specified pattern. folderPattern: Base pattern to match folders (e.g., "datafolder" matches "datafolder001", etc.)
	string allFolders = ReplaceInDelimitedString(DataFolderDir(1), "FOLDERS:/;/\r", "/,/", "/")
	variable numFolders = ItemsInList(allFolders, ","), folderIndex
	for(folderIndex = numFolders-1; folderIndex >= 0; folderIndex -= 1) // Filter to only include matching folders
		if(CheckString(StringFromList(folderIndex, allFolders, ","), folderPattern) == 0)
			allFolders = RemoveListItem(folderIndex, allFolders, ",")
		endif
	endfor
	variable numMatches = ItemsInList(allFolders, ",")
	if(numMatches == 0)
		PrintAdv("No folders matching pattern '" + folderPattern + "' found", type="error")
		return $""
	endif
	Wave/Z/T matchingFolders = MakeWave("matchingFolders", "Text", numMatches, 2, colNames="Name;Path")
	string paramList = "allFolders=[" + allFolders + "];saveDF=[" + GetDataFolder(1) + "];waveName=[" + GetWavesDataFolder(matchingFolders, 2) + "]"
	forEachIndex("cb_PopulateMatchingFolders", 0, numMatches, numMatches, paramList) // experimental thing
	PrintAdv("Found " + num2str(numMatches) + " folders matching pattern '" + folderPattern + "'", type="success")
	return matchingFolders
End
//--------------------------------------------------------------------------------------
Function GetWavesRecursively(String path, String &listStr)
// What: Helper function to recursively get waves from all folders
	String saveDF = GetDataFolder(1)
	SetDataFolder $path
	// Get waves in current folder
	String currentWaves = WaveList("*", ";", "")
	Variable i
	for(i=0; i<ItemsInList(currentWaves); i+=1)
		String currentWave = StringFromList(i, currentWaves)
		listStr = AddListItem(path + currentWave, listStr, ";", inf)
	endfor	
	// Get subfolders and recurse
	String subfolders = DataFolderList(path, ";")
	for(i=0; i<ItemsInList(subfolders); i+=1)
		String currentFolder = StringFromList(i, subfolders)
		GetWavesRecursively(path + currentFolder + ":", listStr)
	endfor	
	SetDataFolder $saveDF
End
////////////////////////////////////////////////////////////////////////////////////////
//// WAVE INDEXING / SEARCHING / VALUE RETRIEVAL
////////////////////////////////////////////////////////////////////////////////////////
Function [Variable colIndex, Variable searchType] FindColumnByName(Wave w, String searchStr, [String divider])
// What: Finds column containing searchStr in wave using multiple search methods
	// Input: w - wave to search (numeric or text), searchStr - string to find. [divider] - optional divider for row linked data (default: ":")
	// Returns: [colIndex, searchType] where colIndex is column number (-2 if not found) - searchType: 1=dimension label, 2=first row name, 3=row linked data, 0=not found
	variable numCols = DimSize(w, 1), col
	string dimLabel, cellValue, rowData, searchPattern
	// Handle optional divider parameter
	if(ParamIsDefault(divider))
		divider = ":"
	endif
	// Method 1: Check dimension labels
	for(col=0; col<numCols; col+=1) 
		dimLabel = GetDimLabel(w, 1, col)
		if(StringMatch(dimLabel, searchStr))
			return [col, 1]
		endif
	endfor
	// Method 2: Check first row (text waves only)
	if(WaveType(w, 1) == 2)  // Text wave
		WAVE/T wText = w
		for(col=0; col<numCols; col+=1)
			if(StringMatch(wText[0][col], searchStr))
				return [col, 2]
			endif
		endfor
		// Method 3: Check for row linked data (format: "searchStr[divider]value")
		searchPattern = searchStr + divider
		for(col=0; col<numCols; col+=1)
			cellValue = wText[0][col]
			if(strsearch(cellValue, searchPattern, 0) == 0)
				return [col, 3]
			endif
		endfor
	endif
	return [-2, 0]  // Not found
End
//--------------------------------------------------------------------------------------
Function [Variable rowIndex, Variable searchType] FindRowByName(Wave w, String searchStr, [String divider])
// What: Finds row containing searchStr in wave using multiple search methods
	// Input: w - wave to search (numeric or text), searchStr - string to find. [divider] - optional divider for column linked data (default: ":")
	// Returns: [rowIndex, searchType] where rowIndex is row number (-2 if not found) - searchType: 1=dimension label, 2=first column name, 3=column linked data, 0=not found
	variable numRows = DimSize(w, 0), row
	string dimLabel, cellValue, colData, searchPattern
	// Handle optional divider parameter
	if(ParamIsDefault(divider))
		divider = ":"
	endif
	// Method 1: Check dimension labels
	for(row=0; row<numRows; row+=1) 
		dimLabel = GetDimLabel(w, 0, row)
		if(StringMatch(dimLabel, searchStr))
			return [row, 1]
		endif
	endfor
	// Method 2: Check first column (text waves only)
	if(WaveType(w, 1) == 2)  // Text wave
		WAVE/T wText = w
		for(row=0; row<numRows; row+=1)
			if(StringMatch(wText[row][0], searchStr))
				return [row, 2]
			endif
		endfor
		// Method 3: Check for column linked data (format: "searchStr[divider]value")
		searchPattern = searchStr + divider
		for(row=0; row<numRows; row+=1)
			cellValue = wText[row][0]
			if(strsearch(cellValue, searchPattern, 0) == 0)
				return [row, 3]
			endif
		endfor
	endif
	return [-2, 0]  // Not found
End
//--------------------------------------------------------------------------------------
Function/S GetWaveColumnNames(wave/T targetWave)
// What: Returns all column names of a wave as a semicolon-separated string
    string columnNames = ""
	variable i
    for(i=0; i<DimSize(targetWave, 1); i+=1)
        columnNames = AddListItem(GetDimLabel(targetWave, 1, i), columnNames, ";", Inf)
    endfor
	columnNames = columnNames[0,strlen(columnNames)-2]
    return columnNames
End
//--------------------------------------------------------------------------------------
Function/S GetWaveRowData(WAVE inputWave, variable rowIndex)
// What: Returns a semicolon-separated list of all data in the specified row. 
    string rowData = "", rowDataPoint = ""
    variable colIndex, colCount = DimSize(inputWave, 1) 
    for(colIndex=0; colIndex<colCount; colIndex+=1)
		if(WaveType(inputWave, 1) == 2)
			WAVE/T textWave = $(NameOfWave(inputWave))
			rowDataPoint = textWave[rowIndex][colIndex]
		else
			rowDataPoint = num2str(inputWave[rowIndex][colIndex])
		endif
		if(strlen(rowDataPoint) > 0)
			rowData = AddListItem(rowDataPoint, rowData, ";", Inf)
		endif
    endfor
    return rowData
End
//--------------------------------------------------------------------------------------
Function/S GetWaveValue(wave w, string row, string col)
// What: Get values from wave given row and column. Can be DIM name, index, or for rows Matching text (treats row in col as rowNames), This has the advantage of handling text and numeric waves in the same way.
	variable rowIndex, colIndex
	if(numtype(str2num(row)))
		FindValue/TEXT=row/TXOP=4 w
		rowIndex = V_value
	else
		rowIndex = str2num(row)
	endif
	colIndex = numtype(str2num(col)) ? WhichListItem(col, GetWaveColumnNames(w)) : str2num(col)
	if(rowIndex < 0 || colIndex < 0)
		return "NotFound: row=" + num2str(rowIndex) + " col=" + num2str(colIndex)
	endif
	WAVE/T/Z tw = w
	if(WaveExists(tw))
		return tw[rowIndex][colIndex]
	else
		return num2str(w[rowIndex][colIndex])
	endif
End
////////////////////////////////////////////////////////////////////////////////////////
//// SYSTEM INDEX AND SAVING
////////////////////////////////////////////////////////////////////////////////////////
Function/S GetSystemPath(string experimentName, [string message, string sysPathStr, variable forceNewPath])
// What: Get folder path for system folder of interest. Checks for existing global string SystemPath so can be used as reference and creation function.
	// experimentName: Name of datafolder in IGOR where files are stored (such as systemPath string). If "" passed then just checks root:
	// [message]: Prompt message if you want a special prompt
	// [sysPathStr]: Custom name of string that stores systemPath (default: "systemPath")
	String folder_path_string = "", checkExistingFolder = ""
	Variable notFoundFolder = 0, errorSVAR = 0
	if(ParamIsDefault(message))
		message = "Select Folder"
	endif
	if(ParamIsDefault(sysPathStr))
		sysPathStr = "systemPath"
	endif
	if(GrepString(experimentName, "root:"))
		checkExistingFolder = experimentName
	else
		checkExistingFolder = "root:" + experimentName
		experimentName = "root:" + experimentName
	endif
	if(DataFolderExists(checkExistingFolder)) // Folder exists
		SetDataFolder checkExistingFolder
		SVAR/Z systemPath = $sysPathStr
		if(SVAR_Exists(systemPath) && forceNewPath != 1) // SVAR exists
			folder_path_string = systemPath
			return folder_path_string
		else
			errorSVAR = 1
		endif
	else
		notFoundFolder = 1
		errorSVAR = 1
		SetCreateDataFolder(experimentName)
	endif
	if(errorSVAR == 2) // SVAR exists but is empty / badpath
		// not yet implemented
	elseif(errorSVAR == 1) // SVAR doesn't exist
		String/G $sysPathStr
		Newpath /O/Q folderPath // Get datafolder
		variable userChoice = V_flag	
		if(v_flag == -1)
			return "userCancelled"
		endif
		PathInfo folderPath  // obtain symbolic path info from "filePath"

		SVAR pathStr = $sysPathStr  // Reference the global string we just created
		pathStr = S_path  // Update the global string with the path
		folder_path_string = S_path  // Store the path in our return variable
		return folder_path_string
	endif
End
//--------------------------------------------------------------------------------------
Function/S GetSystemPathTemp()
// What: Return target system path
		String sysPathStr = ""
		Newpath /O/Q folderPath // Get datafolder
		PathInfo folderPath  // obtain symbolic path info from "filePath"
		string pathStr = S_path  // Update the global string with the path
		return pathStr
End
//--------------------------------------------------------------------------------------
Function SaveWaveToSystem(Wave targetWave, String sysPath, String fileType, [String waveNameStr])
// What: Save wave to system path with optional custom file name
	// E.g 	SaveWaveToSystem(sampleWave, "C:Users:username:Desktop:", "csv", "myCustomName")
	PrintAdv("Starting SaveWaveToSystem", state="debug")
	if(strlen(sysPath) == 0)
		sysPath = GetSystemPathTemp()
		if(strlen(sysPath) == 0)
			PrintAdv("Error: system path cannot be empty", state="error")
			return 0
		endif
	endif
	PrintAdv("Input path: " + sysPath, state="debug")	
	// Ensure path ends with colon
	if (StringMatch(sysPath[strlen(sysPath)-1], ":") == 0)
		sysPath += ":"
	endif
	PrintAdv("Processed path: " + sysPath, state="debug")
	// Get file name (use custom name if provided, otherwise use wave name)
	String waveName = "", fileName, fullPath
	Variable fileRef, isTextWave
	if(ParamIsDefault(waveNameStr) || strlen(waveNameStr) == 0)
		waveName = NameOfWave(targetWave)
	else
		waveName = waveNameStr
	endif
	PrintAdv("Using name for file: " + waveName, state="debug")	
	// Check wave type first
	Variable waveTypeValue = WaveType(targetWave)
	if(waveTypeValue == 0)
		isTextWave = 1
	else
		isTextWave = 0
	endif	
	// Determine separator based on file type
	String separator = "\t"
	if(StringMatch(LowerStr(fileType), "*csv*"))
		separator = ","
	endif
	PrintAdv("File type: " + fileType + ", separator: " + separator, state="debug")	
	// Handle file extension and create filename
	strswitch(LowerStr(fileType))
		case ".csv":
		case "csv":
			fileName = waveName + ".csv"
			break		
		case ".txt":
		case "txt":
			fileName = waveName + ".txt"
			break		
		case ".ibw":
		case "ibw":
			fileName = waveName + ".ibw"
			fullPath = sysPath + fileName
			PrintAdv("IBW save path: " + fullPath, state="debug")
			Save/C/O targetWave as fullPath
			PrintAdv("Wave saved successfully: " + fullPath, state="debug")
			return 0
			break		
		default:
			PrintAdv("Error: Unsupported file type. Supported: .csv, .txt, .ibw", state="error")
			return -1
	endswitch
	fullPath = sysPath + fileName
	GetFileFolderInfo/Q/Z fullPath
	if(V_flag == 0)
		PrintAdv("File already exists, attempting to delete", state="debug")
		DeleteFile/Z fullPath
	endif
	Open/Z fileRef as fullPath
	PrintAdv("Open file V_flag: " + num2str(V_flag), state="debug")
	if(V_flag != 0)
		PrintAdv("Error: Failed to open file for writing: " + fullPath, state="error")
		PrintAdv("V_flag value: " + num2str(V_flag), state="error")
		return -1
	endif
	// Write wave data
	Variable i, j
	String line
	if(isTextWave)  // Text wave
		PrintAdv("Processing text wave", state="debug")
		WAVE/T textWave = targetWave
		if(DimSize(targetWave, 1) > 0)  // 2D text wave
			PrintAdv("Writing 2D text wave", state="debug")
			for(i = 0; i < DimSize(targetWave, 0); i += 1)
				line = ""
				for(j = 0; j < DimSize(targetWave, 1); j += 1)
					line += textWave[i][j]
					if(j < DimSize(targetWave, 1) - 1)
						line += separator
					endif
				endfor
				fprintf fileRef, "%s\r\n", line
			endfor
		else  // 1D text wave
			PrintAdv("Writing 1D text wave", state="debug")
			for(i = 0; i < DimSize(targetWave, 0); i += 1)
				fprintf fileRef, "%s\r\n", textWave[i]
			endfor
		endif
	else  // Numeric wave
		PrintAdv("Processing numeric wave", state="debug")
		if(DimSize(targetWave, 1) > 0)  // 2D numeric wave
			PrintAdv("Writing 2D numeric wave", state="debug")
			for(i = 0; i < DimSize(targetWave, 0); i += 1)
				line = ""
				for(j = 0; j < DimSize(targetWave, 1); j += 1)
					line += num2str(targetWave[i][j])
					if(j < DimSize(targetWave, 1) - 1)
						line += separator
					endif
				endfor
				fprintf fileRef, "%s\r\n", line
			endfor
		else  // 1D numeric wave
			PrintAdv("Writing 1D numeric wave", state="debug")
			for(i = 0; i < DimSize(targetWave, 0); i += 1)
				fprintf fileRef, "%g\r\n", targetWave[i]
			endfor
		endif
	endif	
	Close fileRef
	PrintAdv(waveName + " saved successfully: " + fullPath, type = "folder")
	return 0
End
//--------------------------------------------------------------------------------------
Function/S GetAllSysSubFolders(string startFolder, [variable includeStartFolder, string format, string fullPath, variable automated])
// What: Returns a semicolon-separated list of all system subfolders (recursively) in the given folder
	// Input: startFolder - the folder to start searching from (must be a valid system path)
	//        includeStartFolder - if 1, includes the start folder in the output list (default: 0)
	//        format - path format to return: "win" (backslash), "linux" (forward slash), or "igor" (colon). Default: "igor"
	//        fullPath - "yes" or "no". If no, returns paths relative to Igor Pro User Files. Default: "yes"
	// Returns: semicolon-separated list of all subfolders (full paths)
	string allFolders = ""
	// Handle default parameters
	if(ParamIsDefault(includeStartFolder))
		includeStartFolder = 0
	endif
	if(ParamIsDefault(format))
		format = "igor"
	endif
	if(ParamIsDefault(fullPath))
		fullPath = "yes"
	endif
	string basePath = ""
	if(StringMatch(fullPath, "no"))
		basePath = ParseFilePath(5, SpecialDirPath("Igor Pro User Files", 0, 0, 0), "\\", 0, 0)
	endif
	// Clean up input path
	startFolder = RemoveEnding(startFolder, ":")  // Remove Igor path separator if present
	startFolder = RemoveEnding(startFolder, "\\")  // Remove Windows path separator if present
	startFolder = RemoveEnding(startFolder, "/")   // Remove Linux path separator if present
	string tempPathName = "TempFolderPath_" + num2istr(abs(enoise(inf)))
	NewPath/Q/O $tempPathName, startFolder
	if(V_flag != 0)
		print "❌ Error: Invalid start folder path: " + startFolder
		return ""
	endif
	KillPath/Z $tempPathName
	// Add start folder if requested
	if(includeStartFolder)
		allFolders = startFolder
	endif
	// Create wave to store folders to process
	Make/O/T/N=1 root:W_FoldersToProcess = startFolder
	Wave/T W_FoldersToProcess = root:W_FoldersToProcess
	variable numToProcess = 1
	variable folderIndex = 0
	do
		if(folderIndex >= numToProcess)
			break
		endif	
		string currentFolder = W_FoldersToProcess[folderIndex]	
		// Create symbolic path for current folder
		NewPath/Q/O $tempPathName, currentFolder
		if(V_flag == 0)
			variable i = 0
			do
				// Get next directory using IndexedDir
				string item = IndexedDir($tempPathName, i, 1)  // 1 means return full path
				if(strlen(item) == 0)
					break  // No more items
				endif			
				// Skip "." and ".." directories
				if(StringMatch(item, "*.") || StringMatch(item, "*.."))
					i += 1
					continue
				endif
				string formattedPath
				if(!StringMatch(fullPath, "yes") && strlen(basePath) > 0 && StringMatch(item, basePath + "*"))
					// Remove base path for relative paths
					formattedPath = item[strlen(basePath),inf]
				else
					formattedPath = item
				endif		
				strswitch(format) // Convert to requested format
					case "win":
						formattedPath = ParseFilePath(5, formattedPath, "\\", 0, 0)
						break
					case "linux":
						formattedPath = ParseFilePath(5, formattedPath, "/", 0, 0)
						break
					case "igor":
						formattedPath = ParseFilePath(5, formattedPath, ":", 0, 0)
						break
					default:
						formattedPath = ParseFilePath(5, formattedPath, ":", 0, 0)  // Default to Igor format
				endswitch
				// Add to results if not already there
				if(WhichListItem(formattedPath, allFolders) < 0)
					allFolders += SelectString(strlen(allFolders), "", ";") + formattedPath
				endif
				// Add to processing queue (keep original Windows format for processing)
				InsertPoints numToProcess, 1, W_FoldersToProcess
				W_FoldersToProcess[numToProcess] = item
				numToProcess += 1
				i += 1
			while(1)
		endif
		folderIndex += 1
	while(1)
	// Clean up
	KillPath/Z $tempPathName, W_FoldersToProcess
	return allFolders
End
//--------------------------------------------------------------------------------------
Function/S ListOpenFiles([String separator, String ignore, variable beSilent])
// What: Lists all files IGOR pro has open/accessing from system. Good to check if your code isnt properly closing files after func.	
    if(ParamIsDefault(separator))
		separator = ";"
	endif
    beSilent = ParamIsDefault(beSilent) ? 0 : beSilent
    String fileList = "", fileName = ""; Variable fileRef = 0, fileCount = 0, i = 0, j = 0, shouldIgnore = 0
    for(i = 1; i <= 1000; i += 1)
        fileRef = i
        FStatus fileRef
        if(V_flag != 0)  // File reference is valid
            fileName = S_fileName
            if(strlen(fileName) > 0)
                if(strlen(ignore) > 0)
                    for(j=0; j<ItemsInList(ignore); j+=1)
                        String pattern = StringFromList(j, ignore)
                        if(GrepString(fileName, pattern))
                            shouldIgnore = 1
                            break
                        endif
                    endfor
                endif
                if(!shouldIgnore)
                    if(strlen(fileList) > 0)
                        fileList += separator
                    endif
                    fileList += fileName
                    fileCount += 1
                endif
            endif
        endif
    endfor  
    PrintAdv("Total open files found: " + num2str(fileCount) + " (" + fileList + ")", type="info", beSilent=beSilent)
    if(strlen(fileList) == 0)
        fileList = ""
    endif
    return fileList
End
//--------------------------------------------------------------------------------------
Function CloseAllFiles([String ignore, variable beSilent])
// What: Closes all files IGOR pro has open/accessing from system. ignore: Semicolon-separated list of filename patterns to ignore (can use * as wildcard)
    if(ParamIsDefault(ignore))
		ignore = ""
	endif
	beSilent = ParamIsDefault(beSilent) ? 0 : beSilent
	String openFilesList = ListOpenFiles(ignore=ignore, beSilent=beSilent, separator=";")
    if(StringMatch(openFilesList, "None") || strlen(openFilesList) < 1)
        PrintAdv("No open files found to close", type="info", beSilent=beSilent)
        return 0
    else // close them files
        Variable closedCount = 0, i, fileRef; String fileName
        for(i = 0; i < ItemsInList(openFilesList); i += 1)
            fileName = StringFromList(i, openFilesList)          
            for(fileRef = 1; fileRef <= 1000; fileRef += 1) // Find the reference for this file
				FStatus fileRef
				if(V_flag != 0 && StringMatch(S_fileName, fileName))
					Close fileRef
					closedCount += 1
					break
				endif
			endfor
		endfor
    	PrintAdv("Closed " + num2str(closedCount) + " files", type="info", beSilent=beSilent)
    	return closedCount
    endif
End
//--------------------------------------------------------------------------------------
////////////////////////////////////////////////////////////////////////////////////////
//// USER FUNCTION INDEXING
////////////////////////////////////////////////////////////////////////////////////////
Function/S GetFuncInfo(string functionName, [string infoType, variable makingIndex])
// What: Returns information about a function based on the infoType parameter, and places info in index wave
	string waveParams = "", stringParams = "", variableParams = "", pType="", pName = "", procText = "", funcDefLine = "", fullPath = "", procFile = "", paramNames = "", rawParams = "", paramTypes = "", paramWaves = "", paramStrings = "", paramVars = "", structParams = "", waveParamsOpt = "", stringParamsOpt = "", variableParamsOpt = "", returnType = "variable", currentParam = "", funcParamLine = "", funcMandatoryParams = "", funcOptionalParams = "" // Initialize key variables
	variable row, startParen, endParen, numParams, paramIndex, isOptional, typeEndPos, hasBodyDeclarations = 0 // Control variables
	variable i, isOpt, isTypeInline, spacePos, mandatoryParamCount = 0, optionalParamCount = 0 // Parameter processing variables
	if(paramisdefault(infoType))
		infoType = "allParams" // Default info type
	endif
	//Quick return if index exists, else will make index
	WAVE/T indexWave = GetFunctionIndexWave() // Get index wave reference
	row = FindDimLabel(indexWave, 0, functionName) // Find function in index
	if(row >= 0) // Return existing info if found
		variable targetCol = FindDimLabel(indexWave, 1, infoType)
		if(targetCol < 0 )
			Debugger
			return ""
		else
			return indexWave[row][targetCol]
		endif
	endif
	procText = ProcedureText(functionName) // Get function text
	if(strlen(procText) == 0) 
		return "" // Function not found
	endif
	variable lineIndex = strsearch(procText, "Function", 0) // Find function declaration
	if(lineIndex < 0) // Case insensitive search
		lineIndex = strsearch(procText, "function", 0)
	endif
	if(lineIndex < 0)
		return "" // Not a function
	endif
	variable nlPos = strsearch(procText, "\r", lineIndex) // Find end of line
	funcDefLine = procText[lineIndex, nlPos-1] // Extract function declaration
	funcParamLine = ModifyString(funcDefLine, rules="extractBetweenDelim;trim", ruleMods="(|)")
	funcMandatoryParams = ModifyString(funcParamLine, rules="ExtractBeforeAny;removeEmptyItems;trim", ruleMods="[;,"); mandatoryParamCount = ItemsInList(funcMandatoryParams, ",")
	funcOptionalParams = ModifyString(funcParamLine, rules="extractBetweenDelim;removeEmptyItems;trim", ruleMods="[|];,", returnType="strict"); optionalParamCount = ItemsInList(funcOptionalParams, ",")
	fullPath = FunctionPath(functionName); procFile = ParseFilePath(0, fullPath, ":", 1, 0) // Get procedure file name	
	startParen = strsearch(funcDefLine, "(", 0); endParen = strsearch(funcDefLine, ")", startParen) // Find parameter list
	if(startParen > 0 && endParen > startParen) // Extract parameters
		rawParams = funcDefLine[startParen+1, endParen-1]
	else
		rawParams = ""
	endif
	numParams = ItemsInList(rawParams, ",") // Count parameters	
	// Process mandatory parameters
	for(i=0; i<mandatoryParamCount; i+=1)
		currentParam = TrimString(StringFromList(i, funcMandatoryParams, ","))
		isOpt = 0; spacePos = strsearch(currentParam, " ", 0); isTypeInline = spacePos > 0	
		if(isTypeInline) // Modern style with type in declaration
			pType = TrimString(currentParam[0, spacePos-1]); pName = TrimString(currentParam[spacePos+1, Inf])		
			// Add to appropriate type list based on parameter type
			if(StringMatch(pType, "wave*") || StringMatch(pType, "WAVE*"))
				paramWaves = AddListItem(pName, paramWaves, ",", inf)
			elseif(StringMatch(pType, "struct*") || StringMatch(pType, "STRUCT*"))
				structParams = AddListItem(pName, structParams, ",", inf)
			elseif(StringMatch(pType, "string*"))
				paramStrings = AddListItem(pName, paramStrings, ",", inf)
			elseif(StringMatch(pType, "variable*") || StringMatch(pType, "double*") || StringMatch(pType, "int*"))
				paramVars = AddListItem(pName, paramVars, ",", inf)
			endif
		else
			pName = currentParam
			hasBodyDeclarations = 1 // Need to check function body
		endif
		paramNames = AddListItem(pName, paramNames, ",", inf)
	endfor	
	// Process optional parameters
	for(i=0; i<optionalParamCount; i+=1)
		currentParam = TrimString(StringFromList(i, funcOptionalParams, ","))
		isOpt = 1; spacePos = strsearch(currentParam, " ", 0); isTypeInline = spacePos > 0
		if(isTypeInline) // Modern style with type in declaration
			pType = TrimString(currentParam[0, spacePos-1]); pName = TrimString(currentParam[spacePos+1, Inf])
			// Add to appropriate type list based on parameter type
			if(StringMatch(pType, "wave*") || StringMatch(pType, "WAVE*"))
				waveParamsOpt = AddListItem(pName, waveParamsOpt, ",", inf)
			elseif(StringMatch(pType, "struct*") || StringMatch(pType, "STRUCT*"))
				structParams = AddListItem(pName, structParams, ",", inf) // No optional structs category
			elseif(StringMatch(pType, "string*"))
				stringParamsOpt = AddListItem(pName, stringParamsOpt, ",", inf)
			elseif(StringMatch(pType, "variable*") || StringMatch(pType, "double*") || StringMatch(pType, "int*"))
				variableParamsOpt = AddListItem(pName, variableParamsOpt, ",", inf)
			endif
		else
			pName = currentParam + "_optional" // Mark optional old-style params
			hasBodyDeclarations = 1 // Need to check function body
		endif
		paramNames = AddListItem(pName, paramNames, ",", inf)
	endfor
	if(hasBodyDeclarations) // Check for old-style parameter declarations in function body
		string funcLines = procText // Full function text for line-by-line search
		variable lineStart, lineEnd, currentLine = nlPos + 1, paramCount = ItemsInList(paramNames, ",")
		for(paramIndex = 0; paramIndex < paramCount; paramIndex++) // Check each parameter
			pName = StringFromList(paramIndex, paramNames, ",")
			lineStart = currentLine
			do
				lineEnd = strsearch(funcLines, "\r", lineStart)
				if(lineEnd < 0) 
					break // End of function
				endif
				string lineText = funcLines[lineStart, lineEnd-1] // Current line
				lineStart = lineEnd + 1 // Move to next line
				lineText = LowerStr(TrimString(lineText))
				if(strlen(lineText) > 1 && stringmatch(lineText[0,1], "//*"))
					continue // Skip commented lines
				endif
				// Check if this line contains the parameter name (as a word)
				if(GrepString(lineText, "\\b" + pName + "\\b") || GrepString(lineText, "&" + pName + "\\b") || grepstring(linetext, pName) || grepstring(lowerstr(linetext), lowerstr(pName)))
					// Check for parameter type
					if(GrepString(lineText, "\\bSTRUCT\\b") || GrepString(lineText, "\\bstruct\\b") || grepstring(linetext, "struct"))
						structParams = AddListItem(pName, structParams, ",")
						break
					endif
					if(GrepString(lineText, "\\bvariable\\b") || grepstring(linetext, "variable"))
						paramVars = AddListItem(pName, paramVars, ",")
						break
					endif
					if(GrepString(lineText, "\\bstring\\b") || grepstring(linetext, "string"))
						paramStrings = AddListItem(pName, paramStrings, ",")
						break
					endif
					if(GrepString(lineText, "\\bwave\\b") || grepstring(linetext, "wave"))
						paramWaves = AddListItem(pName, paramWaves, ",")
						break
					endif
				endif
			while(lineStart < strlen(funcLines) && lineStart < currentLine + 5) // Limit search to first 500 lines
		endfor
	endif
	if(StringMatch(funcDefLine, "Function/S*") || StringMatch(funcDefLine, "function/s*")) // Determine return type
		returnType = "string" // String return
	elseif(StringMatch(funcDefLine, "Function/WAVE*") || StringMatch(funcDefLine, "function/wave*"))
		returnType = "wave" // Wave return
	elseif(StringMatch(funcDefLine, "*[*]*")) // Multiple return syntax
		returnType = "multiple:" + ModifyString(funcDefLine, rules="extractBetweenDelim", ruleMods="[|]") // Multiple returns
	endif
	// Remove trailing commas from all parameter lists
	paramWaves = RemoveEnding(paramWaves, ","); paramStrings = RemoveEnding(paramStrings, ",");paramVars = RemoveEnding(paramVars, ","); structParams = RemoveEnding(structParams, ",");
	waveParamsOpt = RemoveEnding(waveParamsOpt, ","); stringParamsOpt = RemoveEnding(stringParamsOpt, ","); variableParamsOpt = RemoveEnding(variableParamsOpt, ",")	
	string typedParamList = "", optParamList = ""; numParams = ItemsInList(paramNames, ",")
	variable waveCount = 0, stringCount = 0, varCount = 0, structCount = 0, waveOptCount = 0, stringOptCount = 0, varOptCount = 0
	for(i=0; i<numParams; i+=1) 	// Combine all param types and build parameter list with types for allParams
		pName = StringFromList(i, paramNames, ",")
		if(WhichListItem(pName, paramWaves, ",") >= 0)
			waveCount += 1		
			typedParamList += "W,"
		elseif(WhichListItem(pName, paramStrings, ",") >= 0)
			stringCount += 1
			typedParamList += "S,"
		elseif(WhichListItem(pName, paramVars, ",") >= 0)
			varCount += 1
			typedParamList += "V,"
		elseif(WhichListItem(pName, structParams, ",") >= 0)
			structCount += 1
			typedParamList += "ST,"
		elseif(WhichListItem(pName, waveParamsOpt, ",") >= 0)
			waveOptCount += 1
			optParamList += "W,"
		elseif(WhichListItem(pName, stringParamsOpt, ",") >= 0)
			stringOptCount += 1
			optParamList += "S,"
		elseif(WhichListItem(pName, variableParamsOpt, ",") >= 0)
			varOptCount += 1
			optParamList += "V,"
		else
			typedParamList += "?,"
		endif
	endfor
	typedParamList = RemoveEnding(typedParamList, ",")
	optParamList = RemoveEnding(optParamList, ",")
	string listConcat = typedParamList
	if(strlen(optParamList) > 0)
		listConcat += "[" + optParamList + "]"
	endif
	string paramCounts = num2str(waveCount) + ", " + num2str(stringCount) + ", " + num2str(varCount) + ", " + num2str(structCount) + ",[" + num2str(waveOptCount) + ", " + num2str(stringOptCount) + ", " + num2str(varOptCount) + "]"

	paramTypes = paramWaves + paramStrings + paramVars // Combine all param types
	string rowValues = functionName + ";" + rawParams + ";" + listConcat + ";" + paramWaves + ";" + paramStrings + ";" + paramVars + ";" + structParams + ";" + waveParamsOpt + ";" + stringParamsOpt + ";" + variableParamsOpt + ";" + returnType + ";" + procFile + ";" + fullPath
	AddToReferenceWave(indexWave, indexWaveCols, rowNames=functionName, rowValues=rowValues) // Update index
	if(StringMatch(infoType, "allParams") || StringMatch(infoType, "all")) // Return requested info
		return rawParams
	elseif(StringMatch(infoType, "waveParams"))
		return paramWaves
	elseif(StringMatch(infoType, "stringParams"))
		return paramStrings
	elseif(StringMatch(infoType, "variableParams"))
		return paramVars
	elseif(StringMatch(infoType, "structParams"))
		return structParams
	elseif(StringMatch(infoType, "allOptParams"))
		return optParamList
	elseif(StringMatch(infoType, "waveOptParams"))
		return waveParamsOpt
	elseif(StringMatch(infoType, "variableOptParams"))
		return variableParamsOpt
	elseif(StringMatch(infoType, "returnType"))
		return returnType
	elseif(StringMatch(infoType, "procedureFile"))
		return procFile
	elseif(StringMatch(infoType, "fullPath"))
		return fullPath
	endif
	return indexWave[row][%Parameters] // Default return
End
//--------------------------------------------------------------------------------------
Function/WAVE GetFunctionIndexWave()
// What: Ensures the FunctionIndex wave exists and returns a reference to it.
    string wavePath = "root:Packages:Indexes:functionIndex"
    WAVE/Z/T w = $(wavePath)
    if(!WaveExists(w))
        WAVE/Z/T w = MakeFunctionIndex(beSilent=1)//
    endif
    return w
End
//--------------------------------------------------------------------------------------
Function/WAVE MakeFunctionIndex([variable beSilent])
// What: Creates an index of all functions in the Igor system.
    besilent = ParamIsDefault(beSilent) ? 1 : 0
	string indexPath = SetCreateDataFolder("root:Packages:Indexes", returnToCurrentFolder=1) + "functionIndex"; KillWaves/Z $indexPath
	Wave/T functionIndex = MakeWave(indexPath, "Text", 0, ItemsInList(indexWaveCols), colNames=indexWaveCols)
	string listOfUserAllFunctions = GetAllUserDefinedFunctions()
	variable numFunctions = ItemsInList(listOfUserAllFunctions, ";"), funcIteration, timeStart = ticks
	for(funcIteration=0; funcIteration<numFunctions; funcIteration+=1)
		string functionName = StringFromList(funcIteration, listOfUserAllFunctions, ";")
		GetFuncInfo(functionName, makingIndex=1)
	endfor
	variable timeEnd = ticks, elapsedTime = (timeEnd - timeStart) / 1000 
	PrintAdv("Indexed " + num2str(numFunctions) + " functions in " + num2str(elapsedTime) + " seconds.", type="info", beSilent=beSilent)
	return functionIndex
End
//--------------------------------------------------------------------------------------
Function [string allParams, string waveParams, string stringParams, string variableParams, string strctParams] GetFunctionParams(string functionName)
// What: Retrieves the parameters of a function from the FunctionIndex wave.
	allParams = GetFuncInfo(functionName, infoType="allParams")
	waveParams = GetFuncInfo(functionName, infoType="waveParams")
	stringParams = GetFuncInfo(functionName, infoType="stringParams")
	variableParams = GetFuncInfo(functionName, infoType="variableParams")
	strctParams = GetFuncInfo(functionName, infoType="structParams")
	return [allParams, waveParams, stringParams, variableParams, strctParams]
End
Function [string allOptParams, string waveOptParams, string stringOptParams, string variableOptParams] GetFunctionOptionalParams(string functionName)
// What: Retrieves the parameters of a function from the FunctionIndex wave.
	waveOptParams = ""; stringOptParams = ""; variableOptParams = ""; allOptParams = ""
	waveOptParams = GetFuncInfo(functionName, infoType="waveParamsOpt"); allOptParams = AddListItem(waveOptParams, allOptParams, ";")
	stringOptParams = GetFuncInfo(functionName, infoType="stringParamsOpt"); allOptParams = AddListItem(stringOptParams, allOptParams, ";")
	variableOptParams = GetFuncInfo(functionName, infoType="variableParamsOpt"); allOptParams = AddListItem(variableOptParams, allOptParams, ";")
	if(StringMatch(allOptParams, ";;;"))
		allOptParams = ""
	endif
	return [allOptParams, waveOptParams, stringOptParams, variableOptParams]
End
//--------------------------------------------------------------------------------------
Function/S GetAllUserDefinedFunctions([string separator])
// What: Returns a list of all user-defined functions across all procedure files
    string allFunctions = ""
    if(ParamIsDefault(separator))
        separator = ";" // Default separator is semicolon
    endif
    allFunctions = FunctionList("*", separator, "KIND:2") // KIND:2 = user-defined functions 
    string staticFuncs = FunctionList("*", separator, "KIND:18") // To include static functions, use KIND:18 (2+16)
    allFunctions = allFunctions + staticFuncs
    allFunctions = RemoveDuplicatesFromList(allFunctions, separator=separator)
    return allFunctions
End
////////////////////////////////////////////////////////////////////////////////////////
//// OLDER FUNCTION - Likely superceeded or less well designed to be reworked.
////////////////////////////////////////////////////////////////////////////////////////
Function/WAVE IndexMatchingWaves(string searchPattern [, string startFolder, variable match_any, string filter_list, string excludeWave, variable silent, string matchType, string searchType, string findMatches])	// What: Creates a text wave containing names and paths of waves matching the search pattern(s)
// What: Finds waves or folders matching a pattern (or list of patterns) in a folder and all subfolders
	// Returns a text wave with paths and wave names
	// searchPattern: semicolon-separated list of patterns to search for
	// startFolder: folder to start search in (default: current folder)
	// match_any: if 1, match any part of the name (default: 0, match full name)
	// filter_list: semicolon-separated list of patterns to filter results by (default: none)
	//              prefix with ! to exclude matches (e.g. "!_src" excludes waves with _src in name)
	// excludeWave: name of a wave to exclude from results (default: none)
	// silent: if 1, suppress output (default: 0)
	// matchType: how to combine multiple patterns (default: "OR")
	//            "OR": include if ANY pattern matches
	//            "AND": include if ALL patterns match
	//            "NOT": include if NO patterns match
	//            "NOR": include if NOT ALL patterns match
	// searchType: what to search for (default: "wave")
	//            "wave": search for waves
	//            "folder": search for folders
	// findMatches: how many matches to find (default: "All")
	//            "All": find all matches
	//            "Single": find only the first match
	string savedDataFolder, currentFolder, allFolders, matchingWavesList, waveName
	variable numFolders, totalWaves, numWaves, i, j, k, rowcount, numPatterns, patternIndex
	variable foundAnyPattern, addThisFolder	
	savedDataFolder = GetDataFolder(1)
	// Handle default parameters
	if(ParamIsDefault(startFolder))
		startFolder = GetDataFolder(1)
	endif
	if(ParamIsDefault(match_any))
		match_any = 0
	endif    
	if(ParamIsDefault(filter_list))
		filter_list = ""
	endif
	if(ParamIsDefault(excludeWave))
		excludeWave = ""
	endif
	if(ParamIsDefault(matchType))
		matchType = "AND"  // Default to all items in list needeing to be present
	endif
	if(ParamIsDefault(searchType))
		searchType = "wave"  // Default to searching for waves
	endif
	if(ParamIsDefault(findMatches))
		findMatches = "All"  // Default to finding all matches
	endif		
	strswitch(searchType) // Input validation for searchType
		case "wave":
		case "string":
		case "variable":
			break
		default:
			print "❌ Error: Invalid searchType. Must be wave, string, or variable. Defaulting to wave."
			searchType = "wave"
	endswitch	
	strswitch(matchType) // Input validation for matchType
		case "AND":
		case "OR":
		case "NOT":
		case "NOR":
			break
		default:
			print "❌ Error: Invalid matchType. Must be AND, OR, NOT, or NOR. Defaulting to AND."
			matchType = "AND"
	endswitch	
	numPatterns = ItemsInList(searchPattern, ";")
	if(numPatterns == 0)  // If no semicolons, treat as single pattern
		numPatterns = 1
		searchPattern = searchPattern + ";"  // Add semicolon for consistent handling
	endif
	allFolders = GetAllSubFolders(startFolder=startFolder, includeStartFolder=1)
	numFolders = ItemsInList(allFolders, ";")
	// Create text wave to store matches
	Make/O/T/N=(1000,numPatterns+1) wave_index  // +1 for path column
	Wave/T wave_index = wave_index
	SetDimLabel 1,0,Path,wave_index  // Column 0 is always path
	// Set column labels for each pattern
	for(i=0; i<numPatterns; i+=1)
		SetDimLabel 1,i+1,$(StringFromList(i,searchPattern,";")),wave_index
	endfor	
	totalWaves = 0 // Search each folder for matching waves
	for(i=0; i<numFolders; i+=1)
		currentFolder = StringFromList(i, allFolders, ";")
		if(strlen(currentFolder) == 0)
			continue
		endif	
		// Ensure folder path ends with ":"
		currentFolder = RemoveEnding(currentFolder, ":")
		currentFolder += ":"
		SetDataFolder $currentFolder
		Make/O/T/N=(numPatterns) tempMatches = ""  // Store matches for this folder
		variable matchCount = 0
		// Search for each pattern
		for(patternIndex=0; patternIndex<numPatterns; patternIndex+=1)
			string currentPattern = StringFromList(patternIndex, searchPattern, ";")
			// Prepare search pattern based on match_any
			string searchWildcard
			if(match_any)
				searchWildcard = "*" + currentPattern + "*"
			else
				searchWildcard = currentPattern + "*"
			endif
			// Get list of matching objects based on searchType
			strswitch(searchType)
				case "wave":
					matchingWavesList = WaveList(searchWildcard, ";", "")
					//print "NumWaves: " + num2str(ItemsInList(matchingWavesList, ";"))
					break
				case "string":
					matchingWavesList = StringList(searchWildcard, ";")
					break
				case "variable":
					// For variables, always use *pattern* format to find them anywhere in the name
					// Search for both scalar (4) and complex (5) variables
					string scalarList = VariableList("*" + currentPattern + "*", ";", 4)
					string complexList = VariableList("*" + currentPattern + "*", ";", 5)
					matchingWavesList = scalarList + complexList
					break
			endswitch
			numWaves = ItemsInList(matchingWavesList, ";")
			// Process matching waves
			if(numWaves > 0)
				// Find valid wave matches for this pattern
				variable foundValidWave = 0; string validMatches = ""				
				for(j=0; j<numWaves; j+=1)
					waveName = StringFromList(j, matchingWavesList)
					if(strlen(waveName) == 0 || StringMatch(waveName, "wave_index") || (strlen(excludeWave) > 0 && StringMatch(waveName, excludeWave)))
						continue
					endif				
					variable passesFilter = 1
					if(strlen(filter_list) > 0) // Check filter criteria
						variable numFilters = ItemsInList(filter_list, ";")
						for(k=0; k<numFilters; k+=1)
							string filterTerm = StringFromList(k, filter_list)
							if(strlen(filterTerm) == 0)
								continue
							endif
							if(char2num(filterTerm[0]) == char2num("!"))
								string excludeTerm = filterTerm[1,inf]
								if(strsearch(waveName, excludeTerm, 0) != -1)
									passesFilter = 0
									break
								endif
							else
								if(strsearch(waveName, filterTerm, 0) == -1)
									passesFilter = 0
									break
								endif
							endif
						endfor
					endif
					// Check if object exists based on searchType
					variable objectExists = 0
					strswitch(searchType)
						case "wave":
							WAVE/Z foundWave = $waveName
							objectExists = WaveExists(foundWave)
							break
						case "string":
							SVAR/Z foundString = $waveName
							objectExists = SVAR_Exists(foundString)
							break
						case "variable":
							NVAR/Z foundVariable = $waveName
							objectExists = NVAR_Exists(foundVariable)
							break
					endswitch
					if(objectExists && passesFilter)
						if(StringMatch(findMatches, "Single"))
							// Single match mode - just store the first valid match
							tempMatches[patternIndex] = waveName
							matchCount += 1
							foundValidWave = 1
							break  // Exit after finding first match
						else
							// All matches mode - collect all valid matches
							validMatches = AddListItem(waveName, validMatches, ";", Inf)
							foundValidWave = 1
						endif
					endif
				endfor
				// For All matches mode, store the list of valid matches
				if(foundValidWave && !StringMatch(findMatches, "Single"))
					tempMatches[patternIndex] = validMatches
					matchCount += 1
				endif
			endif
		endfor		
		// Determine if we should add this folder based on matchType
		addThisFolder = 0
		strswitch(matchType)
			case "AND":
				addThisFolder = (matchCount == numPatterns)  // All patterns found
				break
			case "OR":
				addThisFolder = (matchCount > 0)  // Any pattern found
				break
			case "NOT":
				addThisFolder = (matchCount == 0)  // No patterns found
				break
			case "NOR":
				addThisFolder = (matchCount < numPatterns)  // At least one pattern missing
				break
		endswitch		
		if(addThisFolder)
			// For NOT/NOR, we only store paths. For AND/OR, store the matches			
			if(!StringMatch(matchType, "NOT") && !StringMatch(matchType, "NOR"))
				for(k=0; k<numPatterns; k+=1)
					string matchesList = tempMatches[k]
					// Skip empty matches
					if(strlen(matchesList) == 0)
						continue
					endif
					// Handle each match as a separate row
					variable numMatches = ItemsInList(matchesList, ";")
					for(rowcount=0; rowcount<numMatches; rowcount+=1)
						// Make sure we have enough space
						if(totalWaves >= DimSize(wave_index,0))
							Redimension/N=(totalWaves + 100, -1) wave_index
						endif
						wave_index[totalWaves][0] = currentFolder  // Store path
						wave_index[totalWaves][k+1] = StringFromList(rowcount, matchesList, ";")  // Store single wave name
						totalWaves += 1
					endfor
				endfor
			else
				// For NOT/NOR, we only store paths
				if(totalWaves >= DimSize(wave_index,0))
					Redimension/N=(totalWaves + 100, -1) wave_index
				endif
				wave_index[totalWaves][0] = currentFolder  // Store path
				totalWaves += 1
			endif
		endif
		KillWaves/Z tempMatches
	endfor	
	if(totalWaves > 0)// Trim wave to actual size
		Redimension/N=(totalWaves, -1) wave_index
	else
		Redimension/N=(0, -1) wave_index
	endif
	SetDataFolder $savedDataFolder
	if(!silent == 1)
		string matchDescription
		strswitch(matchType)
			case "AND":
				matchDescription = "containing ALL patterns"
				break
			case "OR":
				matchDescription = "containing ANY pattern"
				break
			case "NOT":
				matchDescription = "containing NO patterns"
				break
			case "NOR":
				matchDescription = "missing AT LEAST ONE pattern"
				break
		endswitch
		print "✅ Found " + num2str(totalWaves) + " locations " + matchDescription + " in '" + searchPattern + "'"
	endif
	return wave_index
End