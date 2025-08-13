#pragma rtGlobals= 3				// Use modern global access method.
#pragma version= 2.01				
#pragma IgorVersion= 9.00			// Requires Igor 9.0 or newer.
#pragma ModuleName= FileImportSystem
// ===========================================================================
//                           Modular Filesystem
// ===========================================================================
// Description: Generalised system for importing, sorting and indexing experimental files from disk into Igor.
// Author: Thomas Cahir
// Created:28-04-2025
// ============================================================================
//	Updated: 
// 1.0 - 28-04-2025 - Thomas Cahir
// 1.01 - 01-06-2025 - Added various file loading options
// 1.02 - 12-08-2025 - Fully reworked file import logic. Now uses reworked import functions and ImportNEV/NSX etc
//*********************************************************************************************************************
/////////////////////////////////////////////////////////////////////////////////////////
Function/S ExperimentLoader(string name, string loadFile, [string params, string experimentPath, variable overwrite, variable beSilent])
// What: Generalised Experiment Loader. Loads experimental files from disk into Igor.
	// name: Name of datatype/folder e.g 'EPs'/'Data' data will be stored in root:EPs. If blank will be in root: unless paradigm overrides
	// loadFile: Are we loading single file, multiple, or everything in folder? Parse strlist of file(s) to load (e.g "datafile001;datafile002") or pass "all" / "" to load all files in folder.
	// [params]: applies specific formatting params, whether paradigm passed or not. [overwrite]: 1 = overwrite existing run subfolders, 2 = overwrite whole datafolder
	string importList = "", ignoreFiles = "", subfoldername = "", referenceFileExt = "????", postFixList = "", usedLegacy = "" // ???? means default to index all files
	string saveFolderPath = "root:", saveFilePath = "", systemPath = "", saveDF = GetDataFolder(1), fileToLoad = "", fileName = "", fileBase = "", fileType = ""
	variable i = 0, timeStart = ticks
	params = SelectString(!ParamIsDefault(params), "", params)
	PrintAdv("ExperimentLoader [" + name + "] File(s): " + loadfile, type="experiment", state="start",beSilent=beSilent)
	saveFolderPath = SetCreateDataFolder(name) // Create folders & paths
	systemPath = SelectString(ParamIsDefault(experimentPath), experimentPath, "")	
	if(Strlen(systemPath) < 1)
		systemPath = GetSystemPath(name, message="Select datafolder with files")
		if(CheckString(systemPath, "userCancelled"))
			return "userCancelled"
		endif
	endif
	//// PARAMS - These apply various stdructure or alteration params
	if(strlen(params) > 0)
		variable paramIndex = 0
		for(paramIndex=0; paramIndex<ItemsInList(params); paramIndex++)
			string fullParam = StringFromList(paramIndex, params, ";")
			string param = ModifyString(fullParam, rules="extractBeforeAny", ruleMods="(~;~[~|~")
			string paramArg = ModifyString(fullParam, rules="extractBetweenDelim", ruleMods="(|)", returnType="strict")
			PrintAdv("param: " + param, state="debug", type="debug", beSilent=beSilent)
			strswitch(param) // apply params
				case "importList": // What file extensions to import (e.g .csv,.log,.ns2,.ns5). Else import all.
					importList = SelectString(strlen(paramArg) > 0, "", paramArg)
					break
				case "ignoreFiles": // What files to ignore (either file name e.g datafile002)
					// not yet implemented
					ignoreFiles = SelectString(strlen(paramArg) > 0, "", paramArg)
					break
				case "postFixes": // Apply the following stringlist postFixes. E.g fix file names, create stim wave, fix run times etc
					postFixList = paramArg
					break
				default:
					PrintAdv("Warning: Unknown param: " + param, type="warning")
					break
			endswitch
		endfor
	endif
	//// INDEXING
	NewPath/O/Q systemSymPath, systemPath
	if (V_Flag != 0)
		PrintAdv("Error: Could not create symbolic path from systemPath. Check or delete SVAR", type="error")
		return ""
	endif
	// TBD: Add in function that creates a list of files to ignore import on, via Warning selection.these are skipped during import
	variable loadWhatVar = 0
	if(StringMatch(loadFile, "all"))
		string listOfDataFiles = IndexedFile(systemSymPath, -1, referenceFileExt) 
		loadWhatVar = ItemsInList(listOfDataFiles)
		string listOfDataFilesPrint = ReplaceString(referenceFileExt,listOfDataFiles,"")
		PrintAdv("Found " + num2str(loadWhatVar) + " files: " + StringFromList(0, listOfDataFilesPrint) + "..." + StringFromList(ItemsInList(listOfDataFiles) - 1, listOfDataFilesPrint), type="search", beSilent=beSilent)	
	elseif(StrLen(loadFile) > 0) // Load specific file
		loadWhatVar = 1
		listOfDataFiles = loadFile	
		PrintAdv("Loading specific file: " + listOfDataFiles, type="search", beSilent=beSilent)
	else
		PrintAdv("No files to load", type="warning")
		return ""	
	endif
	//// IMPORTING
	variable importListCount = ItemsInList(importList), v_files = 0, v_imports = 0, refNum = 0
	variable failedToImport = 0, importedFiles = 0, successfulImports = 0, partialImports = 0, skippedFolders = 0
	if(importListCount == 0)
		PrintAdv("File Types: Import all files", type="link")
	else
		PrintAdv("File Types: Import " + importList + " (" + num2str(importListCount) + " items)", type="link")
	endif
	for(v_files=0; v_files<loadWhatVar; v_files++) // LOOP THROUGH FILES (e.g datafile001, datafile002 etc)
		variable importStartTime = ticks, importTime = 0
		fileBase = StringFromList(v_files, listOfDataFiles) // From list, still has reference file tag
		fileName = ModifyString(fileBase, rules="extractBefore", ruleMods=".") // Remove extension
		saveFilePath = saveFolderPath + fileName
		saveFilePath = ModifyString(saveFilePath, rules="removeText;replace", ruleMods=" ;::|:")
		if(overwrite < 1 && DataFolderExists(saveFilePath)) // dont overwrite existing datafolder, just skip
			skippedFolders += 1
			continue
		endif
		if(DataFolderExists(saveFilePath) && overwrite == 1)
			KillDataFolder $saveFilePath
		endif
		SetCreateDataFolder(saveFilePath)
		string importResult = ImportFile(systemPath, fileName, igorPath=saveFilePath)
		if(GrepString(importResult, "files imported"))
			importedFiles = str2num(StringFromList(0, importResult, " "))
		else
			PrintAdv("Import error: " + importResult, type="error")
			failedToImport += 1
		endif
		if(GrepString(importResult, "legacy"))
			usedLegacy = " (via legacy LoadNSxFile)"
		endif
		if(importedFiles >= importListCount)
			successfulImports += 1
		elseif(importedFiles < importListCount && importedFiles > 0)
			partialImports += 1
		else
			failedToImport += 1
		endif
		//// FILE IMPORT POSTFIXES - Apply postprocessing fixes to imported files
		string postFixMessage = ""
		if(strlen(postFixList) > 0 )
			variable totalPostfixes = 0, postFixCount = ItemsInList(postFixList, ",")
			for(paramIndex=0; paramIndex<postFixCount; paramIndex++)
			fullParam = StringFromList(paramIndex, postFixList, ","); variable fixStartTime = ticks, fixTime = 0
			param = ModifyString(fullParam, rules="extractBeforeAny", ruleMods="[~;~(~|~")
			paramArg = ModifyString(fullParam, rules="extractBetweenDelim", ruleMods=param+"[|]", returnType="strict")
			strswitch(param)
				// BASIC POSTFIXES	
				case "cleanWaveNames": // Standardise wave names, rename X to Y etc
					string nameFixList = paramArg
					variable wavesRenamed = CleanWaveNames(nameFixList=nameFixList, beSilent=beSilent); fixTime = (ticks - fixStartTime) * 1000 / 60
					postFixMessage += "Renamed " + num2str(wavesRenamed) + " waves (spaces replaced with underscores) | In " + num2str(fixTime) + "ms\n"
					totalPostfixes += 1
					break
				case "bandpassFilter": // bandpass filter wave. still WIP
					string filterWaveList = ExtractByDelimiter(paramArg, "|", "before"), filterParams = ExtractByDelimiter(paramArg, "|", "after")
					variable lowPassHz = str2num(StringFromList(0, filterParams, "-")), highPassHz = str2num(StringFromList(1, filterParams, "-"))
					#ifdef CustomFilters //If you want to just use def for filterlevel
						lowPassHz = k_HP // these are reversed, should change BP to match
						highPassHz = k_LP
					#endif
					if(lowPassHz == NaN || lowPassHz <= 0 || highPassHz == NaN || highPassHz <= 0)
						PrintAdv("Error: Bad bandpass filter params: " + filterParams + " from " + fileName, type="error", state="debug;indented")
					else
						for(i=0; i<ItemsInList(filterWaveList, "&"); i+=1)
							string filterWaveName = StringFromList(i, filterWaveList, "&")
							Wave/Z filterWave = $(filterWaveName)
							if(WaveExists(filterWave))
								BandpassFilter(filterWave, lowPassHz, highPassHz, fast=1, notch=1, overwrite=1, removeDC=1, order=-4); fixTime = (ticks - fixStartTime) * 1000 / 60
								if(i==0)
									postFixMessage += "BandpassFiltered["+filterParams+"Hz]: "
								endif
								postFixMessage += filterWaveName + "(" + num2str(fixTime) + "ms);"
								totalPostfixes += 1
							else
								PrintAdv("Error: Could create bandpass filter for: " + filterWaveName + " from " + fileName, type="error", state="debug;indented")
							endif
						endfor
					endif
					break
				case "copyScales": // Copy Scales of wave to target others. E.g Proximal|Target1,Target2
					Wave/Z sourceWave = $(StringFromList(0, paramArg, "|"))
					string targetWaves = ExtractByDelimiter(paramArg, "|", "after"); variable targetCount = ItemsInList(targetWaves, ",")
					if(targetCount > 0)
						for(i=0; i<targetCount; i+=1)
							Wave/Z targetWave = $(StringFromList(i, targetWaves, ","))
							CopyScales/I sourceWave, targetWave
						endfor
						fixTime = (ticks - fixStartTime) * 1000 / 60
						postFixMessage += "Copied scales of " + num2str(targetCount) + " waves | In " + num2str(fixTime) + "ms\n"
						totalPostfixes += 1
					else
						PrintAdv("Error: Could not find wave to copy scales to: " + StringFromList(0, paramArg, ","), type="error", state="indented")
					endif
					break
				case "mergeWaves": // Merge waves, or specific columns of waves into a single wave
					string mergeList = ExtractByDelimiter(paramArg, "|", "before"), mergeParams = ExtractByDelimiter(paramArg, "|", "after")
					MergeWaves(mergeList, params=mergeParams, beSilent=1); fixTime = (ticks - fixStartTime) * 1000 / 60
					postFixMessage += "Merged " + num2str(wavesRenamed) + " waves (spaces replaced with underscores) | In " + num2str(fixTime) + "ms\n"
					totalPostfixes += 1
					break
				case "modifyWaves": // Apply modifications to targetWave(S). E.g Proximal,Distal|invert
					string waveList = ExtractByDelimiter(paramArg, "|", "before"), modifications = ExtractByDelimiter(paramArg, "|", "after")
					for(i=0; i<ItemsInList(waveList); i+=1)
						Wave/Z targetModWave = $(StringFromList(i, waveList))
						ModifyWave(targetModWave, modifications, beSilent=1); fixTime = (ticks - fixStartTime) * 1000 / 60
					endfor
					postFixMessage += "Modified " + num2str(wavesRenamed) + " waves (spaces replaced with underscores) | In " + num2str(fixTime) + "ms\n"
					totalPostfixes += 1
					break
				default:
					break
			endswitch
			endfor
			if(totalPostfixes > 0)
				postFixMessage = " | " + num2str(totalPostfixes) + " PostFixes Applied\n" + postFixMessage
			endif
		endif
		WaveInformation("all", "all", beSilent=1)
		importTime = (ticks - importStartTime) / 60
		importListCount = (importListCount == 0 ? importedFiles : importListCount)
		PrintAdv("Finished Importing " + fileName + " | " + num2str(importedFiles) + "/" + num2str(importListCount) + " imported files in " + num2str(importTime) + "s " + usedLegacy + postFixMessage , type="info", state="indented", beSilent=beSilent)
		importedFiles = 0 // reset to 0
		SetDataFolder $saveFolderPath
	endfor
	//// PROCESS POSTFIXES - Things to do after importing done
	CloseAllFiles(beSilent=1) // Ensures all files closed
	variable elapsedTime = (ticks - timeStart) * 1000 / 60; string timeUnit = "ms" // Convert ticks to milliseconds (60 ticks/sec)
	if(elapsedTime > 1000 ) // report in seconds instead of ms
		elapsedTime = round2decimals(elapsedTime / 1000, 2)
		timeUnit = "s"
	endif
	//// RETURN	
	if(partialImports > 0)
		PrintAdv("Partial Imports: " + num2str(partialImports) + " files (missing at least 1 subfile)", type="warning", state="indented", beSilent=beSilent)
	endif
	if(failedToImport > 0)
		PrintAdv("Failed to import " + num2str(failedToImport) + " files (missing all files)", type="error", state="indented", beSilent=beSilent)
	endif
	if(skippedFolders > 0)
		PrintAdv("Skipped " + num2str(skippedFolders) + " existing folders. Parse 'overwrite=1' to force re-import", type="skip", state="indented", beSilent=beSilent)
	endif
	if(successfulImports > 0)
		PrintAdv("Imported " + num2str(successfulImports) + " full fileset (" + importList + ") in " + num2str(elapsedTime) + timeUnit, type="success", state="indented", beSilent=beSilent)
	endif
	PrintAdv("Finished Importing Files", type="process", beSilent=beSilent)
	SetCreateDataFolder(saveDF) //SetDataFolder $saveDF
	return saveFilePath
End
//--------------------------------------------------------------------------------------
Function/S ImportFile(string systemPath, string fileName, [string igorPath])
// What: Import all files matching fileName from systemPath into Igor
	// systemPath: System path to folder containing files (e.g. "C:Experiment:Datafolder")
	// fileName: Base filename without extension (e.g. "datafile001"). [igorPath]: Igor data folder path (e.g. "root:Data:"). If empty, uses current folder
	string saveDF = GetDataFolder(1), targetPath = "", fileToLoad = "", fileExt = "", fullFileName = "", usedLegacy = ""
	variable importedCount = 0, refNum
	if(ParamIsDefault(igorPath) || strlen(igorPath) == 0)
		targetPath = saveDF
	else
		targetPath = igorPath
		SetDataFolder $targetPath
	endif
	NewPath/O/Q tempPath, systemPath
	if(V_Flag != 0)
		SetDataFolder $saveDF
		return "Error: Invalid system path"
	endif
	string fileList = IndexedFile(tempPath, -1, "????")
	variable fileIndex = 0, totalFiles = ItemsInList(fileList)
	for(fileIndex = 0; fileIndex < totalFiles; fileIndex += 1)
		fullFileName = StringFromList(fileIndex, fileList)
		if(GrepString(fullFileName, "^" + fileName + "\\."))
			fileExt = "." + StringFromList(1, fullFileName, ".")
			fileToLoad = systemPath + fullFileName
			GetFileFolderInfo/Z/Q fileToLoad
			if(V_Flag == 0 && V_isFile == 1)
				Wave/Z wave0
				strswitch(fileExt)
					case ".nev":
						//loadNevFile(fileToLoad)
						ImportNEVFile(fileToLoad, mergeOutput=1)
						importedCount += 1
						break
					case ".csv":
						KillWaves/Z wave0, LogfileCSV
						LoadWave/Q/O/J/D/A/M/K=0/P=folderPath fileToLoad   //M will make it one file
						if(WaveExists(wave0))
							Rename wave0, LogfileCSV
						endif
						importedCount += 1
						break
					case ".log":
						KillWaves/Z wave0, Logfile
						LoadWave/Q/O/J/D/A/M/K=0/P=tempPath fullFileName
						if(WaveExists(wave0))
							Rename wave0, Logfile
						endif
						importedCount += 1
						break
					case ".txt":
						LoadWave/P=tempPath fullFileName
						importedCount += 1
						break
					case ".h5": // Import *.H5 files.
						string h5Result = ImportHDF5File(fileToLoad, igorPath=targetPath)
						if(GrepString(h5Result, "successfully"))
							importedCount += 1
						else
							PrintAdv("Error importing HDF5 file: " + h5Result, type="error")
						endif
						break
					case ".bin": // Import *.BIN files.
						PrintAdv(".BIN file type not yet implemented", type="error")
						importedCount += 1
						break
					default: // Multiextension file types
						if(GrepString(fileExt, "\\.ns[1-5]"))
							#ifdef useLegacyNSX
								LoadNSxFile(fileToLoad, beSilent=1)
								usedLegacy = " (via legacy LoadNSxFile)"
							#else
								ImportNSXFile(fileToLoad, beSilent=1)
							#endif
							importedCount += 1
						endif
						break
				endswitch
			endif
		endif
	endfor
	KillPath/Z tempPath
	SetDataFolder $saveDF
	return num2str(importedCount) + " files imported" + usedLegacy
End
//--------------------------------------------------------------------------------------
//==============================================================================
//// SPECIAL FILE IMPORT FUNCTIONS
//==============================================================================
// Structure definitions for NSX file loading
static Structure NSX_Header
	uint32 dwTimeIndex			// Time index of the first entry of the data point that follows
	uint32 cnNumofDataPoints	// How many data points follow
EndStructure
//--------------------------------------------------------------------------------------
Function/S ImportHDF5File(string filename, [string channels, variable StartTime, variable StopTime, string igorPath])
// What: Import a .h5 file into Igor
	string saveDF = GetDataFolder(1)
	variable fileID, i
	if(!ParamIsDefault(igorPath) && strlen(igorPath) > 0)
		SetCreateDataFolder(igorPath)
	endif
	HDF5openFile fileID as filename
	if(!V_Flag)
		if(ParamIsDefault(channels))
			HDF5LoadGroup/O/R/IGOR=-1 :, fileID, "."
		else
			for(i = 0; i < ItemsInList(channels); i += 1)
				HDF5LoadData/Q/O/IGOR=-1 fileID, StringFromList(i, channels)
			endfor
		endif
		HDF5closeFile fileID
		if(!ParamIsDefault(startTime) && !ParamIsDefault(channels))
			for(i = 0; i < ItemsInList(channels); i += 1)
				string waveName = StringFromList(i, channels)
				Wave/Z usewave = $waveName
				if(WaveExists(usewave))
					Duplicate/O/R=(StartTime, StopTime) usewave, $(waveName + "_temp")
					Wave tempWave = $(waveName + "_temp")
					Redimension/N=(numpnts(tempWave)) usewave
					SetScale/P x StartTime, deltax(tempWave), "s", usewave
					usewave = tempWave
					KillWaves/Z tempWave
				endif
			endfor
		endif
		SetDataFolder $saveDF
		return "HDF5 file imported successfully"
	else
		SetDataFolder $saveDF
		return "Error: Could not open HDF5 file"
	endif
End
//--------------------------------------------------------------------------------------
Function/S ImportNEVFile(string fileName, [variable timesOnly, string channels, variable mergeOutput, variable beSilent])
// What: Streamlined version of NEV file loader
	string loaded = "", saveDF = GetDataFolder(1), noteStr = ""
	variable fileRef, count, numChannels = 0, success = 0
	beSilent = ParamIsDefault(beSilent) ? 0 : beSilent
	timesOnly = ParamIsDefault(timesOnly) ? 0 : timesOnly
	channels = SelectString(ParamIsDefault(channels), channels, "")
	if(strlen(fileName) == 0) // File validation
		Open/D/R/T=".NEV"/M="Select NEV file to import..." fileRef
		if(strlen(S_fileName) == 0)
			return ""
		endif
		fileName = S_fileName
	endif
	GetFileFolderInfo/Z/Q fileName
	if(V_Flag != 0 || V_isFile != 1)
		PrintAdv("Error: NEV file not found: " + fileName, type="error")
		return ""
	endif
	// Open file and read basic header
	Open/R/Z fileRef as fileName
	if(V_Flag)
		PrintAdv("Error: Cannot open NEV file: " + fileName, type="error")
		return ""
	endif
	// Read NEV header (simplified - first 336 bytes contain essential info)
	string headerID = PadString("", 8, 0) // Pre-allocate 8 bytes
	variable fileSpec, format, headerBytes, dataBytes, timeRes, sampleRes
	FBinRead/B=3/F=1/U fileRef, headerID // File type identifier
	if(!StringMatch(headerID, "NEURALEV"))
		Close fileRef
		PrintAdv("Error: Invalid NEV file format", type="error")
		return ""
	endif
	// NEV header loader
	FSetPos fileRef, 8 // Skip FileID, start from file spec  
	FBinRead/B=3/F=2/U fileRef, fileSpec // File spec (2 bytes)
	FBinRead/B=3/F=2/U fileRef, format // Format (2 bytes)
	FBinRead/B=3/F=3/U fileRef, headerBytes // Header bytes (4 bytes)
	FBinRead/B=3/F=3/U fileRef, dataBytes // Data packet bytes (4 bytes)
	FBinRead/B=3/F=3/U fileRef, timeRes // Time resolution (4 bytes)
	FBinRead/B=3/F=3/U fileRef, sampleRes // Sample resolution (4 bytes)
	// Validate header values
	if(headerBytes < 336 || headerBytes > 100000 || dataBytes < 8 || dataBytes > 1000)
		Close fileRef
		PrintAdv("Error: Invalid NEV header values - headerBytes=" + num2str(headerBytes) + " dataBytes=" + num2str(dataBytes), type="error")
		return ""
	endif
	// Skip to extended headers (at byte 336)
	FSetPos fileRef, 336
	variable extHeaderCount = (headerBytes - 336) / 32
	if(extHeaderCount < 0 || extHeaderCount > 1000)
		Close fileRef
		PrintAdv("Error: Invalid extended header count: " + num2str(extHeaderCount), type="error")
		return ""
	endif
	Make/O/T/N=(extHeaderCount) NEV_ChannelLabels = ""
	Make/O/N=(extHeaderCount) NEV_ChannelIDs = 0
	for(count=0; count<extHeaderCount; count+=1) // Read extended headers to get channel info
		string headerType = PadString("", 8, 0)
		FBinRead/B=3/F=1/U fileRef, headerType
		if(StringMatch(headerType, "NEUEVWAV"))
			variable channelID
			FBinRead/B=3/F=2/U fileRef, channelID
			NEV_ChannelIDs[count] = channelID
			string channelLabel = PadString("", 16, 0)
			FBinRead/B=3/F=1/U fileRef, channelLabel
			NEV_ChannelLabels[count] = channelLabel
			numChannels += 1
		endif
		FSetPos fileRef, 336 + (count+1)*32 // Move to next header
	endfor
	for(count=0; count<numChannels; count+=1) // Create waves for each channel
		if(strlen(NEV_ChannelLabels[count]) > 0)
			string waveName = CleanupName(NEV_ChannelLabels[count], 0)
			if(strlen(channels) == 0 || WhichListItem(waveName, channels) != -1)
				if(timesOnly)
					Make/O/N=0 $(waveName + "_Times")
				else
					Make/O/N=0 $waveName
					SetScale d 0,0,"V", $waveName
				endif
				loaded = AddListItem(waveName, loaded, ";", Inf)
			endif
		endif
	endfor
	// Read data packets (simplified - just create placeholder data)
	FStatus fileRef
	variable dataStart = headerBytes, fileSize = V_logEOF
	variable numPackets = (fileSize - dataStart) / dataBytes
	// create basic timing information
	if(numPackets > 0)
		Make/O/N=(numPackets) Run_Number = p + 1
		Make/O/N=(numPackets) Run_Number_Times = p * (1/timeRes)
		SetScale d 0,0,"s", Run_Number_Times
		loaded = AddListItem("Run_Number;Run_Number_Times", loaded, ";", Inf)
		if(mergeOutput)
			MergeWaves("Run_Number;Run_Number_Times", params="expand;targetwave(NEV_RunInfo);kill")
		endif
	endif
	// Cleanup
	KillWaves/Z X___, NEV_ChannelLabels, NEV_ChannelIDs
	Close fileRef
	SetDataFolder saveDF
	success = ItemsInList(loaded) > 0 ? 1 : 0
	if(success)
		PrintAdv("Imported NEV file", type="info", beSilent=beSilent)
	else
		PrintAdv("Failed to import NEV file", type="error")
	endif
	return loaded
End
//--------------------------------------------------------------------------------------
Function/S ImportNSXFile(string fileName, [string channels, variable startTime, variable stopTime, variable beSilent])
// What: Streamlined NSX file loader for both 2.1 and 2.2+ formats
	string loaded = "", saveDF = GetDataFolder(1), waveNameStr = ""; variable fileRef, success = 0
	beSilent = ParamIsDefault(beSilent) ? 0 : beSilent
	channels = SelectString(ParamIsDefault(channels), channels, "")
	startTime = ParamIsDefault(startTime) ? 0 : startTime
	stopTime = ParamIsDefault(stopTime) ? inf : stopTime
	if(strlen(fileName) == 0)
		Open/D/R/T=".NS5;.NS2;.NS3;.NS4;.NS1"/M="Select NSX file..." fileRef
		if(strlen(S_fileName) == 0)
			return ""
		endif
		fileName = S_fileName
	endif
	GetFileFolderInfo/Z/Q fileName
	if(V_Flag || !V_isFile)
		PrintAdv("Error: NSX file not found: " + fileName, type="error")
		return ""
	endif
	Open/R/Z fileRef as fileName
	if(V_Flag)
		PrintAdv("Error: Cannot open NSX file: " + fileName, type="error")
		return ""
	endif
	// Read file format and basic header
	string fileID = PadString("", 8, 0)
	FBinRead/B=3/F=1/U fileRef, fileID
	variable channelCount, sampleRate, numSamples = 1000 // Default minimal load
	Make/O/T/N=128 NSX_ChannelNames = ""
	variable count = 0, period
	if(StringMatch(fileID, "NEURALSG")) // NSX 2.1
		string label = PadString("", 16, 0)	
		FBinRead/B=3/F=1/U fileRef, label
		FBinRead/B=3/F=3/U fileRef, period
		FBinRead/B=3/F=3/U fileRef, channelCount
		sampleRate = 30000 / period
		Make/U/I/O/N=(channelCount) tempIDs
		FBinRead/B=3/F=2/U fileRef, tempIDs
		for(count=0; count<channelCount; count+=1)
			NSX_ChannelNames[count] = num2str(tempIDs[count]) + "_" + label
		endfor
		KillWaves/Z tempIDs
	elseif(StringMatch(fileID, "NEURALCD")) // NSX 2.2+
		variable major, minor, headerBytes, timeRes
		FBinRead/B=3/F=1/U fileRef, major
		FBinRead/B=3/F=1/U fileRef, minor
		FBinRead/B=3/F=3/U fileRef, headerBytes
		FStatus fileRef
		FSetPos fileRef, V_filePos + 272 // Skip label+comment
		FBinRead/B=3/F=3/U fileRef, period
		FBinRead/B=3/F=3/U fileRef, timeRes
		FStatus fileRef
		FSetPos fileRef, V_filePos + 16 // Skip time origin
		FBinRead/B=3/F=3/U fileRef, channelCount
		sampleRate = timeRes / period
		// Read complete extended headers with calibration data (following NSxExtendedHeader structure)
		Make/O/N=(channelCount) NSX_ElectrodeIDs = 0, NSX_MinDigital = 0, NSX_MaxDigital = 0, NSX_MinAnalog = 0, NSX_MaxAnalog = 0
		Make/O/T/N=(channelCount) NSX_RawChannelNames = "", NSX_Units = ""
		for(count=0; count<channelCount; count+=1)
			// Read complete 66-byte extended header as per NSxExtendedHeader structure
			Make/U/B/O/N=66 tempHeaderBytes
			FBinRead/B=3/F=1/U fileRef, tempHeaderBytes
			// Parse header type (2 bytes)
			string headerType = num2char(tempHeaderBytes[0]) + num2char(tempHeaderBytes[1])
			// Parse electrode ID (2 bytes, little-endian uint16)
			variable electrodeID = tempHeaderBytes[2] + tempHeaderBytes[3]*256
			NSX_ElectrodeIDs[count] = electrodeID
			// Parse channel label (16 bytes)
			string channelLabel = ""; variable byteIndex
			for(byteIndex=4; byteIndex<20; byteIndex+=1)
				if(tempHeaderBytes[byteIndex] != 0)
					channelLabel += num2char(tempHeaderBytes[byteIndex])
				endif
			endfor
			NSX_RawChannelNames[count] = TrimString(channelLabel)
			// Skip physical connector/pin (2 bytes at positions 20-21)
			// Parse digital min/max (4 bytes at positions 22-25, signed 16-bit little-endian)
			variable minDigital = tempHeaderBytes[22] + tempHeaderBytes[23]*256
			if(minDigital > 32767)
				minDigital -= 65536 // Convert to signed
			endif
			variable maxDigital = tempHeaderBytes[24] + tempHeaderBytes[25]*256
			if(maxDigital > 32767)
				maxDigital -= 65536 // Convert to signed
			endif
			NSX_MinDigital[count] = minDigital
			NSX_MaxDigital[count] = maxDigital
			// Parse analog min/max (4 bytes at positions 26-29, signed 16-bit little-endian)
			variable minAnalog = tempHeaderBytes[26] + tempHeaderBytes[27]*256
			if(minAnalog > 32767)
				minAnalog -= 65536 // Convert to signed
			endif
			variable maxAnalog = tempHeaderBytes[28] + tempHeaderBytes[29]*256
			if(maxAnalog > 32767)
				maxAnalog -= 65536 // Convert to signed
			endif
			NSX_MinAnalog[count] = minAnalog
			NSX_MaxAnalog[count] = maxAnalog	
			string units = "" // Parse units (16 bytes at positions 30-45)
			for(byteIndex=30; byteIndex<46; byteIndex+=1)
				if(tempHeaderBytes[byteIndex] != 0)
					units += num2char(tempHeaderBytes[byteIndex])
				endif
			endfor
			NSX_Units[count] = TrimString(units)
			KillWaves/Z tempHeaderBytes
		endfor
		for(count=0; count<channelCount; count+=1) // Create channel names
			NSX_ChannelNames[count] = NSX_RawChannelNames[count]
		endfor
	else
		Close fileRef
		return ""
	endif
	// Check for data section and read Entry header
	variable dataType
	FBinRead/B=3/F=1 fileRef, dataType
	if(dataType != 0x01)
		Close fileRef
		return ""
	endif
	// Read Entry header to get data range
	struct NSX_Header Entry
	FBinRead/B=3/F=1 fileRef, Entry
	variable dataStartTime, dataStopTime 	// Calculate data range
	if(startTime < Entry.dwTimeIndex/sampleRate)
		dataStartTime = Entry.dwTimeIndex
	else
		dataStartTime = floor(startTime * sampleRate) - Entry.dwTimeIndex
	endif
	if(stopTime > Entry.cnNumofDataPoints/sampleRate)
		dataStopTime = Entry.cnNumofDataPoints
	else
		dataStopTime = ceil(stopTime * sampleRate) - Entry.dwTimeIndex
	endif
	numSamples = dataStopTime - dataStartTime
	FStatus fileRef // Position file pointer
	FSetPos fileRef, V_filePos + dataStartTime * 2 * channelCount
	Make/W/O/N=(numSamples * channelCount) NSX_DataBuffer // Read the data 
	FBinRead/B=3 fileRef, NSX_DataBuffer
	variable actualSamples = numpnts(NSX_DataBuffer) / channelCount // Use buffer size for wave creation
	for(count=0; count<channelCount; count+=1) // Create waves with channel names
		if(strlen(NSX_ChannelNames[count]) > 0)
			waveNameStr = CleanupName(NSX_ChannelNames[count], 0)
			if(StringMatch(waveNameStr, "X") || StringMatch(waveNameStr, "Y") || StringMatch(waveNameStr, "Z"))
				waveNameStr = "NSX_" + waveNameStr
			endif
			if(strlen(channels) == 0 || WhichListItem(waveNameStr, channels) != -1)			
				variable dataChannelIndex = count // Use direct channel index
				variable scaleFactor = 1; string finalUnits = "V"
				string channelUnits = NSX_Units[dataChannelIndex]
				variable digitalRange = NSX_MaxDigital[dataChannelIndex] - NSX_MinDigital[dataChannelIndex]
				variable analogRange = NSX_MaxAnalog[dataChannelIndex] - NSX_MinAnalog[dataChannelIndex]		
				if(abs(digitalRange) > 100 && abs(analogRange) > 0) // Check for valid calibration data
					// scaling method
					scaleFactor = 1 / (NSX_MaxDigital[dataChannelIndex] / NSX_MaxAnalog[dataChannelIndex])
					strswitch(channelUnits)
						case "uV":
							scaleFactor /= 1000000 // Convert uV to V
							finalUnits = "V"
							break
						case "mV":
							scaleFactor /= 1000 // Convert mV to V
							finalUnits = "V"
							break
						default:
							finalUnits = channelUnits
					endswitch
				else
					// fallback scaling for invalid calibration data
					scaleFactor = 5 / 32767
					finalUnits = "V"
				endif
				Duplicate/O NSX_DataBuffer, tempDataMatrix
				Redimension/N=(channelCount, actualSamples) tempDataMatrix
				// Extract channel data using matrix row op
				MatrixOP/O/NTHR=1 tempChannel = row(tempDataMatrix, dataChannelIndex)^t * scaleFactor		
				Duplicate/O/D tempChannel, $waveNameStr // Create final wave with proper name (double precision)
				Wave channelWave = $waveNameStr
				SetScale/P x, (dataStartTime + Entry.dwTimeIndex)/sampleRate, 1/sampleRate, "s", channelWave // time scaling
				SetScale d, 0, 0, finalUnits, channelWave
				loaded = AddListItem(waveNameStr, loaded, ";", Inf)
				KillWaves/Z tempChannel, tempDataMatrix
			endif
		endif
	endfor
	KillWaves/Z NSX_DataBuffer, NSX_ChannelNames, NSX_ElectrodeIDs, NSX_RawChannelNames, NSX_MinDigital, NSX_MaxDigital, NSX_MinAnalog, NSX_MaxAnalog, NSX_Units
	Close fileRef
	SetDataFolder saveDF
	success = ItemsInList(loaded) > 0 ? 1 : 0
	if(success)
		PrintAdv("Imported NSX: " + ParseFilePath(0, fileName, ":", 1, 0) + " (" + num2str(ItemsInList(loaded)) + " channels)", type="info", beSilent=beSilent)
	endif
	return loaded
End
//--------------------------------------------------------------------------------------
//==============================================================================
//// POSTFIX UTILITY FUNCTIONS
//==============================================================================
//--------------------------------------------------------------------------------------
Function CleanWaveNames([string nameFixList, variable beSilent])
// What: Fixes wave names by replacing spaces with underscores. Also Handles specific wave renaming via nameFixList
	// e.g nameFixList = "Red_Button|EMG;Stim Trigger|Stim_Trigger"
	beSilent = ParamIsDefault(beSilent) ? 0 : beSilent
	nameFixList = SelectString(ParamIsDefault(nameFixList), nameFixList, "")
	variable w_count2 = 0, wavesRenamed = 0
	string wavesInFolder = WaveList("*", ";", "")
	for(w_count2=0; w_count2<ItemsInList(wavesInFolder, ";"); w_count2+=1) // Loop through all waves in current folder
		string waveNameStr = StringFromList(w_count2, wavesInFolder, ";")
		if(strlen(waveNameStr) == 0) // Skip empty names
			continue
		endif
		string finalWaveName = waveNameStr	
		if(strlen(nameFixList) > 0) // Apply nameFixList replacements first
			variable fixIndex
			for(fixIndex=0; fixIndex<ItemsInList(nameFixList, ";"); fixIndex+=1)
				string fixRule = StringFromList(fixIndex, nameFixList, ";")
				string oldName = StringFromList(0, fixRule, "|")
				string newName = StringFromList(1, fixRule, "|")
				if(strlen(oldName) > 0 && strlen(newName) > 0 && StringMatch(finalWaveName, oldName))
					finalWaveName = newName
					break
				endif
			endfor
		endif
		finalWaveName = ReplaceString(" ", finalWaveName, "_")
		if(!StringMatch(waveNameStr, finalWaveName))
			Wave/Z originalWave = $waveNameStr
			if(WaveExists(originalWave) && !WaveExists($finalWaveName))
				Duplicate/O originalWave, $finalWaveName
				KillWaves/Z originalWave
				wavesRenamed += 1
			endif
		endif
	endfor
	if(wavesRenamed > 0 && !beSilent)
		PrintAdv("Fixed " + num2str(wavesRenamed) + " wave names", type="info", state="indented")
	endif
	return wavesRenamed
End
//--------------------------------------------------------------------------------------