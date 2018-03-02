//
//  SourceEditorCommand.swift
//  Localizer
//
//  Created by Shawn Roller on 3/2/18.
//  Copyright © 2018 Shawn Roller. All rights reserved.
//

import Foundation
import XcodeKit

// Extend string with convenience functions
extension String {
    func index(of string: String, options: CompareOptions = .literal) -> Index? {
        return range(of: string, options: options)?.lowerBound
    }
    func endIndex(of string: String, options: CompareOptions = .literal) -> Index? {
        return range(of: string, options: options)?.upperBound
    }
    func slice(from: String, to: String) -> String? {
        return (range(of: from)?.upperBound).flatMap { substringFrom in
            (range(of: to, range: substringFrom..<endIndex)?.lowerBound).map { substringTo in
                String(self[substringFrom..<substringTo])
            }
        }
    }
}

class SourceEditorCommand: NSObject, XCSourceEditorCommand {
    
    let PLIST_LINES = 5
    
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        
        createPListFrom(invocation)
        
        completionHandler(nil)
    }
    
    private func createPListFrom(_ invocation: XCSourceEditorCommandInvocation) {
        var localizedStrings = Set<String>()
        var endIndex = invocation.buffer.lines.count
        
        // Find the localized strings
        for line in invocation.buffer.lines {
            guard let theLine = line as? String, theLine.count > 0 else { continue }
            if lineContainsLocalizedString(theLine) {
                let strings = getLocalizedStrings(from: theLine)
                localizedStrings = localizedStrings.union(Set(strings))
            }
        }
        
        // Insert the new entries at the end of the file
        let entries = getPListEntries(for: localizedStrings)
        for entry in entries {
            invocation.buffer.lines.insert(entry, at: endIndex)
            endIndex += PLIST_LINES
        }
    }
    
    private func lineContainsLocalizedString(_ line: String) -> Bool {
        var containsLocalizedString = false
        
        do {
            let pattern = "\".localized"
            let regex = try NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)
            let range = NSMakeRange(0, line.count)
            let matches = regex.matches(in: line, options: [], range: range)
            containsLocalizedString = matches.count > 0
        }
        catch {
            fatalError(error.localizedDescription)
        }
        
        return containsLocalizedString
    }
    
    private func getLocalizedStrings(from line: String) -> [String] {
        var strings = [String]()
        
        do {
            let pattern = "\"([^\"]*?[^\"]*?)\".localized"
            let regex = try NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)
            let range = NSMakeRange(0, line.count)
            let matches = regex.matches(in: line, options: [], range: range)
            for match in matches {
                let matchRange = match.range
                if let matchString = (line as NSString).substring(with: matchRange).slice(from: "\"", to: "\"") {
                    strings.append(matchString)
                }
            }
        }
        catch {
            fatalError(error.localizedDescription)
        }
        
        return strings
    }
    private func getPListEntries(for strings: Set<String>) -> [String] {
        let stringArray = Array(strings)
        var entries = [String]()
        
        // Create PList entries for each string
        for string in stringArray {
            let entry = """
            <key>\(string)</key>
            <dict>
                <key>value</key>
                <string><#T##Translation#></string>
            </dict>
            """
            entries.append(entry)
        }
        
        return entries
    }
    
}
