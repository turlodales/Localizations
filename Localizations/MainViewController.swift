//
//  MainViewController.swift
//  Localizations
//
//  Created by Arnaud Thiercelin on 1/28/16.
//  Copyright © 2016 Arnaud Thiercelin. All rights reserved.
//

import Cocoa

class MainViewController: NSViewController {
	
	weak var appDelegate: AppDelegate! = NSApplication.sharedApplication().delegate as! AppDelegate
	
	@IBOutlet weak var chooseButton: NSButton!
	
	var rootDirectory: NSURL!
	// TODO: Add here a random cache directory generator
	let cacheDirectory: NSString = "/tmp/"
	
	var xibFiles = [NSString]()
	var stringFiles = [NSString]()
	
	var freshlyGeneratedFiles = [File]()
		
	override func viewDidLoad() {
		super.viewDidLoad()
	}
	
	override var representedObject: AnyObject? {
		didSet {
			// Update the view, if already loaded.
		}
	}
	
	@IBAction func chooseXcodeFolder(sender: NSButton) {
		let openPanel = NSOpenPanel()
		
		openPanel.allowsMultipleSelection = false
		openPanel.canChooseDirectories = true
		openPanel.canChooseFiles = false
		openPanel.message = NSLocalizedString("Choose a directory", comment: "Open Panel Message to choose the xcode root directory")
		openPanel.title = NSLocalizedString("Please choose a directory containing your Xcode project.", comment: "Open Panel Title to choose the xcode root directory")
		
		let returnValue = openPanel.runModal()
		
		if returnValue == NSModalResponseOK {
			guard openPanel.URL != nil else {
				// TODO: Error handling here
				return
			}
			self.rootDirectory = openPanel.URL!
			// TODO: To be used if and when this app is to be sandboxed.
			//			self.rootDirectory.startAccessingSecurityScopedResource()
			
			//			do {
			//				try self.rootDirectory.bookmarkDataWithOptions(NSURLBookmarkCreationOptions.SecurityScopeAllowOnlyReadAccess, includingResourceValuesForKeys: nil, relativeToURL: nil)
			
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), { [unowned self] () -> Void in
				
				// Browsing the existing files
				self.findStringFiles(self.rootDirectory!.path!)
				self.sortFoundStringFiles()
				
				// Get fresh generation of files
				self.generateFreshFilesUsingGenstrings()
				self.generateFreshFilesWithIBTool()
				self.produceFreshListOfStringFiles()
				
				// show detail ui
				dispatch_async(dispatch_get_main_queue(), { [unowned self] () -> Void in
					self.appDelegate.detailViewController.filesDataSource.files.appendContentsOf(self.freshlyGeneratedFiles)
					self.presentViewController(self.appDelegate.detailViewController, animator: ATBasicAnimator())
					
					})
				})
			//			} catch {
			//           // TODO: Implement error here if and when this app is sandboxed
			//			}
		}
	}
	
	// MARK: - Methods collecting existing localization data from .string files.
	func findStringFiles(startPath: NSString) {
		//NOTE: Could be replaced by fts_open from libc (man)
		
		let fileManager = NSFileManager.defaultManager()
		do {
			let content = try fileManager.contentsOfDirectoryAtPath(startPath as String)
			
			for element in content {
				let elementPath = startPath.stringByAppendingPathComponent(element)
				var isDirectory: ObjCBool = false
				
				fileManager.fileExistsAtPath(elementPath, isDirectory: &isDirectory)
				if isDirectory {
					// Skipping Directories that can't be open
					if fileManager.isExecutableFileAtPath(elementPath) {
						continue
					}
					
					// Skipping Hidden Folders
					let dotRange = element.rangeOfString(".")
					if dotRange != nil && dotRange!.first! == element.startIndex {
						continue
					}
					
					// We open the folder and continue the process.
					self.findStringFiles(elementPath)
				}
				else // files - we are only interested in localizations files.
				{
					let xibRange = element.rangeOfString(".strings")
					
					if xibRange != nil && self.stringFiles.contains(elementPath) == false {
						self.stringFiles.append(elementPath)
					}
				}
			}
		} catch {
			// TODO: error handling
		}
	}
	
	func sortFoundStringFiles() {
		
	}
	
	// MARK: - Methods building fresh localization data from source
	func generateFreshFilesUsingGenstrings() {
		let commandString = "/usr/bin/genstrings -o \(self.cacheDirectory) `find \(self.rootDirectory.path!) -name '*.[hm]'`"
		
		system(commandString)
	}
	
	func generateFreshFilesWithIBTool() {
		//find . -name '*.xib'
		// ibtool --generate-strings-file MainMenu.strings MainMenu.xib
		
		self.xibFiles.removeAll()
		self.findAllXibFiles(self.rootDirectory.path!)
		
		for filePath in self.xibFiles {
			
			//		NSArray *filePathComponents = [filePath pathComponents];
			let pathExtension = filePath.pathExtension
			let fileName = filePath.lastPathComponent
			let stringFileName = fileName.stringByReplacingOccurrencesOfString(pathExtension, withString: "strings")
			
			let commandString = "ibtool --generate-strings-file \(self.cacheDirectory)\(stringFileName) \(filePath)"
			
			system(commandString)
		}
	}
	
	func findAllXibFiles(startPath: NSString) {
		//NOTE: Could be replaced by fts_open from libc (man)
		
		let fileManager = NSFileManager.defaultManager()
		do {
			let content = try fileManager.contentsOfDirectoryAtPath(startPath as String)
			
			for element in content {
				let elementPath = startPath.stringByAppendingPathComponent(element)
				var isDirectory: ObjCBool = false
				
				fileManager.fileExistsAtPath(elementPath, isDirectory: &isDirectory)
				if isDirectory {
					// Skipping Directories that can't be open
					if fileManager.isExecutableFileAtPath(elementPath) {
						continue
					}
					
					// Skipping Hidden Folders
					let dotRange = element.rangeOfString(".")
					if dotRange != nil && dotRange!.first! == element.startIndex {
						continue
					}
					
					// We "open" the folder and continue the process.
					self.findAllXibFiles(elementPath)
				}
				else // files - we are only interested in localizations files.
				{
					let xibRange = element.rangeOfString(".xib")
					
					if xibRange != nil && self.xibFiles.contains(elementPath) == false {
						self.xibFiles.append(elementPath)
					}
				}
			}
		} catch {
			// TODO: Error Handling here
		}
	}
	
	func produceFreshListOfStringFiles() {
		//		NSString *cacheDir = LACacheDir;
		
		self.freshlyGeneratedFiles.removeAll()
		
		let fileManager = NSFileManager.defaultManager()
		do {
			let content = try fileManager.contentsOfDirectoryAtPath(self.cacheDirectory as String)
			
			for element in content {
				let elementPath = cacheDirectory.stringByAppendingPathComponent(element)
				var isDirectory:ObjCBool = false
				
				fileManager.fileExistsAtPath(elementPath, isDirectory: &isDirectory)
				
				if !isDirectory {
					let stringsRange = element.rangeOfString(".strings")
					if stringsRange != nil {
						// files - we are only interested in localizations files.
						var newFile = File()

						newFile.name = element
						var fileContent = ""
						
						do {
							fileContent = try NSString(contentsOfFile: elementPath, encoding: NSUTF8StringEncoding) as String
						} catch {
							do {
								fileContent = try NSString(contentsOfFile: elementPath, encoding: NSUTF16StringEncoding) as String
							} catch {
								//TODO: Eventually retry with even more encoding.
							}
						}
						
						newFile.rawContent = fileContent

						let lines = fileContent.componentsSeparatedByString("\n")
						var comments = ""
						
						for line in lines {
							if line.characters.count == 0 || line.characters.first !=  "\"" { // Comment line or blank lines
								comments.appendContentsOf(line)
								comments.appendContentsOf("\n")
							} else { // line with key
								let translation = self.splitStringLine(line)

								translation.comments = comments
							newFile.translations.append(translation)
							comments = ""
							}
						}
						self.freshlyGeneratedFiles.append(newFile)
					}
				}
			}
		} catch {
			// TODO: Error handling
		}
	}
	
	func splitStringLine(line: String) -> Translation {
		var foundFirstQuote = false
		var foundSecondQuote = false
		var foundThirdQuote = false
		let foundLastQuote = false
		var ignoreNextCharacter = false
		
		var key = ""
		var value = ""
		
		for index in 0..<line.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) {
			let character = line[line.startIndex.advancedBy(index)]

			if character == "\\" {
			if !ignoreNextCharacter {
			ignoreNextCharacter = true
			continue
			}
			}
			
			if !foundFirstQuote	{
				if !ignoreNextCharacter {
					if character == "\"" {
					foundFirstQuote = true
					ignoreNextCharacter = false
						continue
					}
				}
			} else {
				if !foundSecondQuote {
					if !ignoreNextCharacter {
						if character == "\"" {
							foundSecondQuote = true
							ignoreNextCharacter = false
							continue
						}
					} else {
						key += "\\"
					}
					
					key += "\(character)"
				} else {
					if !foundThirdQuote {
						if character == " " || character == "=" {
							ignoreNextCharacter = false
							continue
						}
						if character == "\"" {
							foundThirdQuote = true
							ignoreNextCharacter = false
							continue
						}
					} else {
						if !foundLastQuote {
							if !ignoreNextCharacter {
								if character == "\"" {
								foundSecondQuote = true
								ignoreNextCharacter = false
								break
								}
							} else {
								value += "\\"
							}
							
							value += "\(character)"
							
						} else {
							break
						}
					}
				}
			}
			ignoreNextCharacter = false
		}
		
		return Translation(key: key, value: value, comments: "")
	}
}

