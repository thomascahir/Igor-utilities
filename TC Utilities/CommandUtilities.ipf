#pragma rtGlobals= 3				// Use modern global access method.
#pragma version= 2.01				
#pragma IgorVersion= 9.00			// Requires Igor 5.03 or newer.
#pragma ModuleName= CommandUtilities
#pragma version= 1.0
// ===========================================================================
//                           COMMAND UTILITIES
// ===========================================================================
// Description: Utility functions for the command window and console. Also acts as a catch all import other utils
// Author: Thomas Cahir
// Created: 22-05-2025
// ============================================================================
//	Updated: 22-05-2025 - Initial commit
//*********************************************************************************************************************
#include "WaveUtilities" // Utilities for waves
#include "IndexingUtilities" // Utilities for indexing files
#include "VariableUtilities" // Utilities for variables
//--------------------------------------------------------------------------------------
strConstant dev_icon = "💻 DevMode: "
strConstant debug_icon = "🐞 Debug: " 
strConstant warning_icon = "⚠️ " 
strConstant error_icon = "❌ " 
strConstant success_icon = "✅ " 
strConstant process_icon = "⚙️ " 
strConstant search_icon = "🔍 "
strConstant display_icon = "📊 "
strConstant folder_icon = "📂 "
strConstant experiment_icon = "📦 "
strConstant time_icon = "⏱️ "
strConstant logfiles_icon = "📑 "
strConstant neural_icon = "⚡ "
strConstant merge_icon = "➕"
strConstant ICO_TYPE_1 = "devMode;debug;warning;error;success;process;search;display;folder;experiment;time;config;neural;start;stop;testrun;burst;info;skip;dot;blank;"
strConstant ICO_TYPE_2 = "reset;cleanup;stars;repeat;slider;parent;rules;variables;add;remove;write;magic;data;dataset;segment;noise;link;tool;toolkit;window;target;"
strConstant ICO_1 = "💻 ;🐞 Debug: ;⚠️ ;❌ ;✅ ;⚙️ ;🔍 ;📊 ;📂 ;📦 ;⏱️ ;📑 ;⚡ ;🟢 ;🔴 ;🟣 ;🔵 ;ℹ️ ;⏩ ;- ;• ;"	
strConstant ICO_2 = "🔄 ;🧹 ;✨ ;🔁 ;🎚️ ;🖧 ;📏 ;🔢 ;➕ ;➖ ;✏️ ;🧙 ;📈 ;🗂️ ;✂️ ;🔇 ;🔗 ;🛠️ ;🧰 ;🪟 ;🎯 ;"
strConstant inset = "	 ", inset2 = "	 	 ", inset3 = "	 	 	 " inset4 = "	 	 	 	 " inset5 = "	 	 	 	 	 "
strConstant seperator = "/////////////////////////////////////////////////////////////////////////////////////////////"
//--------------------------------------------------------------------------------------
constant kHz = 1000
constant MHz = 1000000
constant GHz = 1000000000
////////////////////////////////////////////////////////////////////////////////////////
//// ADVANCED PRINT, OUTPUT AND DEBUG FUNCTIONS
////////////////////////////////////////////////////////////////////////////////////////
Menu "Help"
	"❌ Close Tables", /q, KillAllWindows("tables")
	"❌ Close Graphs", /q, KillAllWindows("graphs")
	"❌ Close Panels", /q, KillAllWindows("panels")
	"❌ Close All", /q, KillAllWindows("all")
End	//	Data
//--------------------------------------------------------------------------------------
Function PrintAdv(string message, [string state, string type, string failState, string callFunc, variable debugThis, variable beSilent])
// What: Advanced version of 'print' function with call-stack tracking, debug mode, and optional logging. Allows you to dynamically trace path of functions for debugging or nicer visual output, log outputs etc.
	// Input: message - text to print (same as Print), [state] - optional semicolon-separated list of function state/info (debug, logging, silentetc), [type] (for icons and formatting), [callFunc] - optional name of function called from, [silent] - optional flag to suppress console output, but keeps count of callchain
	// [State]: Internal commands or information relavent to function. "silent" - no console output, "debug" - only print if #define DevMode active, "log" - save to log, start/end - sets that function as start/end of a call chain,
	// [Type]: Iconised prefix for formatting  / visual outputs
	// [callFunc]: Optional name of function called from for tracking purposes. [debugThis]: Optional flag that highlights this print in log for easy reference. [beSilent]: Optional flag to suppress console output, but keeps count of callchain
	// ToDo: Change global vars to reference wave table. Improve performance. Shrink code/optimise length.
	if(ParamIsDefault(state))
		state = ""
	endif
	if(ParamIsDefault(type))
		type = ""
	endif
	//// DEV MODE CHECK. If #Define DevMode will display debug of mainline functions. if #Define DevModeFull will display debug of misc/utility functions. Else will end function early to save time.
	variable devMode = 0, showStackInfo = 0
	string testState = "(?i)" + state + type 
	#ifdef DevMode
		devMode = 1
	#endif
	#ifdef DevModeFull
		devMode = 2
	#endif
	#ifdef DebugPrintAdv // debugging self
		showStackInfo = 1
	#endif
	if(GrepString(testState, "debug") == 1 && devMode == 0) // Quick exit if only for debug purposes
		return 0
	elseif(GrepString(testState, "debugFull") && devMode != 2) // DebugFull only displays if in #define DevModeFull (debugging subprocess / utilities)
		return 0
	endif
	//// INIT SETUP
	variable debugMode = 0, silentMode = 0, logMode = 0, timeMode = 0, stackMode = 1, startMode = 0, endMode = 0, i, stackDepth, devModeVar = 0
	string prefix = "", indentation = "", divider = "", timestamp = "", functionInfo = "", fullMessage = "", typeIcon = "", logPath = "", logFileName = "", dateTimeStr = "", callChainNum = "", devCallFunc = ""
	// Create package folder if it doesn't exist
	if(!DataFolderExists("root:Packages:PrintAdv") || !Exists("root:Packages:PrintAdv:callCounter") || !Exists("root:Packages:PrintAdv:backgroundParent") || !Exists("root:Packages:PrintAdv:monitorTaskRunning"))
		PrintAdvInit()
	endif
	NVAR/Z callCounterVar = root:Packages:PrintAdv:callCounter // Initialize or access call counter variable
	NVAR/Z backgroundParentVar = root:Packages:PrintAdv:backgroundParent // Initialize or access background parent depth counter
	NVAR/Z inBackgroundTaskVar = root:Packages:PrintAdv:inBackgroundTask // Initialize or access background flag
	NVAR/Z monitorTaskRunning = root:Packages:PrintAdv:monitorTaskRunning
	// Check if this is a top-level call (stack depth of 1 or 0)
	string stackList = GetRTStackInfo(3)
	variable actualStackDepth = ItemsInList(stackList, ";") - 1  // Count items minus PrintAdv itself
	// Adjust depth for background tasks (else they are considered to be a new callstack trace)
	variable backgroundMode = StringMatch(state, "background")
	if(backgroundMode)
		inBackgroundTaskVar += 1 // Set background task flag
		backgroundParentVar = actualStackDepth // Store the parent depth for this background task
		actualStackDepth = backgroundParentVar + 1 // Make background tasks appear as +1 depth from their initiating function
	elseif(inBackgroundTaskVar)// This is a child function of a background task
		actualStackDepth = backgroundParentVar + (actualStackDepth - backgroundParentVar) // Adjust depth to be relative to the background parent depth
	endif
	// If this is a top-level call, reset counter
	startMode = StringMatch(state, "start")
	endMode = StringMatch(state, "end")
	// Only reset counter for top-level calls that aren't background tasks
	if(actualStackDepth <= 1 && !backgroundMode)
		callCounterVar = 0
	endif
	if(beSilent==1)
		silentMode = 1
	endif
	//// STATE HANDLING - Parse each state from semicolon-separated list
	variable stateCount = ItemsInList(state, ";")
	for(i=0; i<stateCount; i+=1)
		string currentState = StringFromList(i, state, ";")	
		// Set modes based on state
		if(StringMatch(currentState, "silent") || beSilent == 1) // can also be passed directly via param beSilent = 1
			silentMode = 1
		elseif(StringMatch(currentState, "debug")) // only show on debugging mode (#define DevMode)
			debugMode = 1
		elseif(StringMatch(currentState, "showStackInfo")) //
			showStackInfo = 1
		elseif(StringMatch(currentState, "log")) // save print, callFunc and other info to a logfile in IGOR
			logMode = 1
		elseif(StringMatch(currentState, "logSys")) // save print, callFunc and other info to a logfile on system
			logMode = 1
		elseif(StringMatch(currentState, "time")) // add timestamp to print outside of debug
			timeMode = 1
		elseif(StringMatch(currentState, "start")) // specifies start of a function/call chain directly. resetting count to 0
			startMode = 1
		elseif(StringMatch(currentState, "end")) // specifies end of a function/call chain directly. resetting count to 0
			endMode = 1
		elseif(StringMatch(currentState, "indented")) // If you want a little extra indentation inside func
			indentation += "  "
		elseif(StringMatch(currentState, "divider")) // If you want a subdivider
			divider += "-----------------------------------------------------------"
		endif
	endfor
	if(startMode) // Handle start mode - reset counter and start monitoring
		callCounterVar = 0
		if(!monitorTaskRunning)
			monitorTaskRunning = 1
			CtrlNamedBackground PrintAdvMonitor, period=5, proc=PrintAdvMonitorTask
			CtrlNamedBackground PrintAdvMonitor, start
		endif
		print seperator
	endif
	if(endMode) // Handle end mode - reset counter and stop monitoring
		callCounterVar = 0
		// Reset background task flag if we're ending a background task
		if(backgroundMode || inBackgroundTaskVar)
			inBackgroundTaskVar = 0
			backgroundParentVar = 0
		endif
		if(monitorTaskRunning)
			CtrlNamedBackground PrintAdvMonitor, stop
			monitorTaskRunning = 0
		endif
	endif
	if(!monitorTaskRunning) // Start monitoring if not already running
		monitorTaskRunning = 1
		CtrlNamedBackground PrintAdvMonitor, period=5, proc=PrintAdvMonitorTask
		CtrlNamedBackground PrintAdvMonitor, start
	endif
	callCounterVar += 1 // Increment counter (very important)
	//// STACK DEPTH TRACKING
	stackList = GetRTStackInfo(0)  // Get semicolon-separated list of routines
	actualStackDepth = ItemsInList(stackList, ";") - 1  // Count items minus PrintAdv itself
	string callingFuncName = GetRTStackInfo(2)  // Calling function name
	// Prepare the prefix based on mode
	#ifdef DevMode
		// DevMode: Show [depth/counter] format
		prefix = "["+num2str(actualStackDepth)+"/"+num2str(callCounterVar)+"] "
		variable shouldPrint = 1  // Always print in DevMode
		devModeVar = 1
	#else
		variable shouldPrint = !debugMode  // Only print non-debug messages if not in DevMode
		if(debugMode || showStackInfo) // If other reason to show it
			//prefix = "["+num2str(callCounterVar)+"] "
			prefix = "["+num2str(actualStackDepth)+"/"+num2str(callCounterVar)+"] "
		endif
	#endif
	// If callFunc wasn't provided, use the automatically detected function name
	if(ParamIsDefault(callFunc))
		// Strip module name if present (everything before #)
		variable hashPos = strsearch(callingFuncName, "#", 0)
		if(hashPos >= 0)
			callingFuncName = callingFuncName[hashPos+1,inf]
		endif
		callFunc = callingFuncName
		#ifdef DevMode
			devCallFunc = " (" + callFunc + ") "
		#endif
	endif
	if(strlen(type) == 0)
		if(debugMode)
			typeIcon = "🐞 Debug: "
		endif
	else // TYPE: For iconised prefixes via parallel input and output lists for type match
		//string typeList1 = "devMode;debug;warning;error;success;process;search;display;folder;experiment;time;config;neural;start;stop;testrun;burst;info;skip;dot;blank;"
		//string typeList2 = "reset;cleanup;stars;repeat;slider;parent;rules;variables;add;write;magic;data;dataset;segment;noise;correlate"
		//string iconList1 = "💻 DevMode: ;🐞 Debug: ;⚠️ ;❌ ;✅ ;⚙️ ;🔍 ;📊 ;📂 ;📦 ;⏱️ ;📑 ;⚡ ;🟢 ;🔴 ;🟣 ;🔵 ;ℹ️ ;⏩ ;- ;• ;"	
		//string iconList2 = "🔄 ;🧹 ;✨ ;🔁 ;🎚️ ;🖧 ;📏 ;🔢 ;➕ ;✏️ ;🧙 ;📈 ;🗂️ ;✂️ ;🔇 ;🔗 "
		string typeList = ICO_TYPE_1 + ICO_TYPE_2, iconList = ICO_1 + ICO_2
		typeIcon = GetMatchingListItem(typeList, iconList, type, failedReturn="- ")
	endif
	if(!ParamIsDefault(callFunc)) // Handle function call tracking if provided
		functionInfo = callFunc + ": "
	endif	
	if(stackMode) // Create indentation based on actual stack depth from GetRTStackInfo
		if(actualStackDepth > 1) // Only indent if we're nested
			for(i=0; i<actualStackDepth; i+=1)
				indentation += "  "  // Two spaces per stack level
			endfor
		endif
	endif	
	if(timeMode || devModeVar == 1) // Add timestamp if requested
		timestamp = time() + " "
	endif
	///// THE MAIN PRINT MESSAGE
	////////////////////////////////////////////////////////////////////////////////////////////// 
	fullMessage = timestamp + indentation + prefix + typeIcon + functionInfo + message // Build Message
	if(shouldPrint == 1 && silentMode == 0 ) // Print to console if not silent
		if(!ParamIsDefault(debugThis)) // If you're debugging a specific part, parse special=1 and that will be highlighted
			print indentation + "🔽🔽🔽 --- TARGET DEBUG --- 🔽🔽🔽"
		endif
		if(strlen(divider) > 1)
			print divider
		endif
		// Handle multiline messages with proper indentation
		if(strsearch(message, "\n", 0) >= 0) // Check if message contains newlines
			variable lineIndex, lineCount = ItemsInList(message, "\n")
			for(lineIndex=0; lineIndex<lineCount; lineIndex+=1) // Process each line separately
				string currentLine = StringFromList(lineIndex, message, "\n")
				if(lineIndex == 0) // First line gets full prefix
					print timestamp + prefix + indentation + typeIcon + functionInfo + currentLine + devCallFunc
				else // Subsequent lines get indentation only
					print timestamp + prefix + indentation + "- " + currentLine
				endif
			endfor
		else // Single line message
			print timestamp + prefix + indentation + typeIcon + functionInfo + message + devCallFunc
		endif
	endif
	//////////////////////////////////////////////////////////////////////////////////////////////
	if(logMode) // Log to file if requested
		// Get current date/time for log filename
		string dateStr = date()
		string expr="([[:alpha:]]+), ([[:alpha:]]+) ([[:digit:]]+), ([[:digit:]]+)"
		string dayOfWeek, monthName, dayNumStr, yearStr
		SplitString/E=(expr) dateStr, dayOfWeek, monthName, dayNumStr, yearStr
		dateTimeStr = yearStr + monthName + dayNumStr
		// Create log directory if it doesn't exist
		logPath = SpecialDirPath("Desktop", 0, 0, 0) + "IgorLogs"
		NewPath/C/O/Q LogPath, logPath
		// Create or append to log file
		logFileName = logPath + ":" + dateTimeStr + "_IgorLog.txt"
		Variable fileRef
		Open/A/P=LogPath fileRef as dateTimeStr + "_IgorLog.txt"
		fprintf fileRef, "%s\r", fullMessage
		Close fileRef
	endif
End
//--------------------------------------------------------------------------------------
Function PrintAdvMonitorTask(s)
// What: Background task that monitors the function stack for PrintAdv.
	STRUCT WMBackgroundStruct &s		
	NVAR/Z callCounterVar = root:Packages:PrintAdv:callCounter // Access counter variable
	NVAR/Z inBackgroundTaskVar = root:Packages:PrintAdv:inBackgroundTask // Access background task variables
	NVAR/Z backgroundParentVar = root:Packages:PrintAdv:backgroundParent
	NVAR/Z previousCallNil = root:Packages:PrintAdv:previousCallNil // How many times before reset
	NVAR/Z previousStackNil = root:Packages:PrintAdv:previousStackNil // How many times before reset
	string currentStack = GetRTStackInfo(0) // Check current stack (excluding this background task)
	variable currentStackDepth = ItemsInList(currentStack, ";") - GrepString(currentStack, "PrintAdvMonitorTask") //This task
	if(currentStackDepth <= 1) 	// If stack is empty (only contains this background task or nothing), reset counter and background flags
		if(callCounterVar > 0)		// Only reset if counter is not already 0
			previousCallNil += 1
			if(previousCallNil >= 2) //Check twice before reset
				callCounterVar = 0
				previousCallNil = 0
			endif
		endif		
		if(NVAR_Exists(inBackgroundTaskVar) && callCounterVar == 0) // Reset background task flags if set
			inBackgroundTaskVar = 0
			backgroundParentVar = 0
		endif
	endif	
	if(currentStackDepth == 0)
		previousStackNil += 1
		if(previousStackNil >= 2)
			previousStackNil = 0
			Execute "ctrlnamedbackground PrintAdvMonitor, kill"
			return 1 // Done?
		endif
	else 
		//print "Staying Alive"
		return 0  // Keep running
	endif
End
//--------------------------------------------------------------------------------------
Function PrintAdvInit([variable rebuildReference])
//What: Initialise PrintAdv package references. Shouldnt need to be activated 
	if(!DataFolderExists("root:Packages"))
		NewDataFolder root:Packages
	endif
	if(!DataFolderExists("root:Packages:PrintAdv"))
		NewDataFolder root:Packages:PrintAdv
	endif
	if(!exists("root:Packages:PrintAdv:inBackgroundTask"))
		Variable/G root:Packages:PrintAdv:inBackgroundTask = 0
		NVAR inBackgroundTaskVar = root:Packages:PrintAdv:inBackgroundTask
	endif
	// Initialize background task status variable
	if(!exists("root:Packages:PrintAdv:monitorTaskRunning"))
		Variable/G root:Packages:PrintAdv:monitorTaskRunning = 0
	endif
	if(!exists("root:Packages:PrintAdv:backgroundParent"))
		Variable/G root:Packages:PrintAdv:backgroundParent = 0
		NVAR backgroundParentVar = root:Packages:PrintAdv:backgroundParent
	endif
	if(!exists("root:Packages:PrintAdv:previousCallNil"))
		Variable/G root:Packages:PrintAdv:previousCallNil = 0
		NVAR previousCallNil = root:Packages:PrintAdv:previousCallNil
	endif
	if(!exists("root:Packages:PrintAdv:callCounter"))
		Variable/G root:Packages:PrintAdv:callCounter = 0
		NVAR callCounterVar = root:Packages:PrintAdv:callCounter
	endif
	if(!exists("root:Packages:PrintAdv:previousStackNil"))
		Variable/G root:Packages:PrintAdv:previousStackNil = 0
		NVAR previousStackNil = root:Packages:PrintAdv:previousStackNil
	endif
End
//--------------------------------------------------------------------------------------
////////////////////////////////////////////////////////////////////////////////////////
//// IGOR ENVIRONMENT 
////////////////////////////////////////////////////////////////////////////////////////
Function KillAllWindows(string type)
// What: Closes all windows of specified type. type: "tables", "graphs", "panels", "procedures", or "all"
	string windowList = "", windowName; variable numWindows, i, killCount = 0
	strswitch(type)
		case "tables":
			windowList = WinList("*", ";", "WIN:2")  // Tables
			break
		case "graphs":
			windowList = WinList("*", ";", "WIN:1")  // Graphs
			break
		case "panels":
			windowList = WinList("*", ";", "WIN:64") // Panels
			break
		case "help":
			windowList = WinList("*", ";", "WIN:512")  // Help
			break
		case "procedures":
			windowList = WinList("*", ";", "WIN:128") // Procedure windows
			break
		case "all":
			windowList = WinList("*", ";", "VISIBLE:1")       // All windows
			break
		default:
			PrintAdv(error_icon + "Invalid window type: " + type + ". Valid types: tables, graphs, panels, procedures, all", type="error")
			return -1
	endswitch
	numWindows = ItemsInList(windowList, ";")
	if(numWindows == 0)
		return 0
	endif
	// Kill each window
	for(i = 0; i < numWindows; i += 1)
		windowName = StringFromList(i, windowList, ";")
		if(strlen(windowName) > 0)
			KillWindow/Z $windowName
			killCount += 1
		endif
	endfor	
	return killCount
End
//--------------------------------------------------------------------------------------
Function/S GetCustomMenuItem(string menuText, string showCondition, variable location, variable selectionType, [string hideCondition])
// Return menu text when showCondition(s) are met, empty string otherwise.
    // showCondition: Formatted string of what to check. e.g WaveExists;V_Exists;S_Exists;currentDF. location: 0 for right clicked DF, 1 for currentDF only.
    // E.g WaveExists(w) for any select wave, or WaveExist(wave1) for specific wave. Can be multiple e.g WaveExists(wave1, wave2) 
    // selectionType: 0 for any selection, 1 for selecting datafolder only, 2 for selecting wave(s) only 
	if(strlen(GetBrowserSelection(-1)) == 0)
		return ""
	endif
	String selStr = GetBrowserSelection(0), currentDF = GetDataFolder(0), targetDF = ""
    if(location == 0)
        //targetDF = selStr
    elseif(location == 1)
        targetDF = currentDF
    endif
    if(strlen(selStr) == 0)
        return ""
    endif
	if(paramisdefault(hideCondition))
		hideCondition = ""
	endif
    //// SHOW CONDITION CHECK
    variable sCondCount = ItemsInList(showCondition, ";"), sCondIter = 0, passedCheck = 0
	for(sCondIter=0; sCondIter<sCondCount; sCondIter+=1)
		string sCond = StringFromList(sCondIter, showCondition, ";")
        string sCondType = ModifyString(sCond, rules="extractBefore", ruleMods="(")
		string hCond = StringFromList(sCondIter, hideCondition, ";")
		strswitch(sCondType)
			case "WaveExists": // Duplicate wave
                String waveNameList = ModifyString(sCond, rules="extractBetweenDelim", ruleMods="(|)")
                if(StringMatch(waveNameList, "w"))
                    waveNameList = selStr
                endif
                Variable waveCheckCount = ItemsInList(waveNameList, ","), waveCheckIter = 0
                for(waveCheckIter=0; waveCheckIter<waveCheckCount; waveCheckIter+=1)
                    string waveName = StringFromList(waveCheckIter, waveNameList, ","), wavePath = targetDF + waveName
                    Wave/Z checkWave = $wavePath
                    if(!WaveExists(checkWave))
                        PrintAdv("Debug: Wave " + NameOfWave(checkWave) + " not exist: " + wavePath, state="debug", type="error")
                        return ""
					endif
                    if(CheckString(hCond, "noText") && WaveType(checkWave) == 2)
                        PrintAdv("Debug: Wave " + NameOfWave(checkWave) + " is a textWave " + wavePath, state="debug", type="error")
                        return ""
                    endif
                endfor
                passedCheck +=1 
				break
		endswitch
	endfor
    //// CHECK IF PASSED ALL SHOW CONDITIONS ////
    if(passedCheck == sCondCount)
        PrintAdv("Debug: " + menuText + "(" + waveNameList + ") passed all show conditions)", state="debug", type="success")
        return menuText
    else
        return ""
    endif
End
//--------------------------------------------------------------------------------------
Function HandleMenuSelection(string menuText)
// Handle the menu selection
	if(strlen(GetBrowserSelection(-1)) == 0)
		return -1 // databrowser not open
	endif
    String selStr = ""
    Variable i, numSelected = 0
    // Build complete selection list 
    do
        String nextItem = GetBrowserSelection(numSelected)
        if(strlen(nextItem) == 0)
            break
        endif
        selStr = AddListItem(nextItem, selStr, ";", inf)
        numSelected += 1
    while(1)
    PrintAdv("Selected waves:" + selStr + "Count:" + num2str(numSelected), state="debug", type="info")
    // If we have at least one wave, make a stacked graph
    if(numSelected == 1 && StringMatch(menuText, "SaveWaveToSystem"))
		Wave/Z selWave = $(StringFromList(0, selStr)); variable saved = -1
        saved = SaveWaveToSystem(selWave, "", "csv")
		if(saved == 1)
		elseif(saved == 0) // User cancelled folder selection
		endif
		KillVariables/Z tmp
    endif
End
//--------------------------------------------------------------------------------------
////////////////////////////////////////////////////////////////////////////////////////
//// PROGRESS WINDOW
////////////////////////////////////////////////////////////////////////////////////////
Function ShowProgressWindow(string title, variable max)
// What: Create a panel with a progress tracker when running analysis. Universal/generic.
// Ideas: Creates a dynamic list of steps you can input as a manifest which are ticked off via green ticks next to names and progress bars.
// has its own logging or other features. Gives a better idea of progress and timeframe than command window, plus can always be bought to front.
// use modular panel system
	
End

////////////////////////////////////////////////////////////////////////////////////////
//// WIP
////////////////////////////////////////////////////////////////////////////////////////