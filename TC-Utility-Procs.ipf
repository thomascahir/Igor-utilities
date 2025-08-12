#pragma rtGlobals= 3				// Use modern global access method.
#pragma version= 2.01				
#pragma IgorVersion= 9.00			// Requires Igor 9.0 or newer.
#pragma ModuleName= TCUtilityProcs

// ===========================================================================
//                           TC UTILITY PROCEDURES
// ===========================================================================
// Description: A collection of utility procedures for Igor Pro. This file acts as 1 stop shop importer of all utils and readme file.
// Author: Thomas Cahir
// Created: 03-08-2025
// ===========================================================================
//	Updated: 
// 1.0 | 12-08-2025 - initial creation. Disabled not included ipfs stil lWIP.
//*********************************************************************************************************************
// README
// These utility procedures are designed as general purpose, non specific, non hardcoded function sets that can be applied
// to any/all operation or dataset. If creating experiment or analysis specific code do not include in these util files.

///// MAIN UTILS
#include "CommandUtilities" // Command utilities for print, kill windows, etc.
#include "CommonUtilities" // Common utilities for file operations, folder operations, etc.
#include "FileImportSystem" // File import system for importing files from disk into Igor.
#include "MathUtilities" // Math utilities for math operations, etc.
#include "IndexingUtilities" // Indexing utilities for wave indexing, wave matching, etc.
#include "VariableUtilities" // Variable utilities for variable operations, etc.

// #include "GraphingUtilities" // Graph utilities for graph operations, etc.

///// DEV UTILS - only include if DeveloperMode is defined
// #ifdef DeveloperMode
// //
// #include "TestingNDevUtilities" // Developer utilities for debugging, etc.
// #include "TestingUtils" // Testing utilities for testing, etc. 
// //
// #endif
