//
//  Grammar.swift
//  FSMBuilder
//
//  Created by Wilf Lalonde on 2023-01-24.
//

import Foundation
    
public final class Grammar {
    var type: String;
    var nonterminals: Array <String>
    var macros: Dictionary <String,Any>
    
    init () {
        type = "scanner"
        nonterminals = ["A", "B", "C"];
        macros = [:]
    }
    //finiteStateMachine:
    func addMacro (_ macro: String, _ fsm: Any) -> Void {
        macros [macro] = fsm
    }
    
    func addNonterminal (_ name: String) -> Void {
        nonterminals.append (name)
    }
    
    func isNonterminal (_ symbol: String) -> Bool {
        return nonterminals.contains (symbol)
    }
    
    func isParser () -> Bool {
        return type == "parser"
    }
    
    func isScanner () -> Bool {
        return type == "scanner"
    }
    
    // This function would print out the attributes based on the symbol type.
    func printAttributes(for symbol: String) {
        let defaults = Grammar.defaultsFor(symbol)
        
        // Get the attribute shorthand from the AttributeList
        let attributeString = defaults.description
        
        // Print the result
        print("\(symbol): \(attributeString)")
    }
    
    static var activeGrammar: Grammar?
    
    static func lookDefaults () -> [String] {
        return ["look"]
    }
    
    static func scannerDefaults () -> AttributeList {
        return AttributeList ().set (["read", "keep", "noStack", "noNode"])
    }
    
    static func parserTerminalDefaults () -> AttributeList {
        return AttributeList ().set(["read", "noKeep", "stack", "noNode"])
    }
    
    static func parserNonterminalDefaults () -> AttributeList {
        return AttributeList ().set (["read", "noKeep", "stack", "node"])
    }
    
    static func defaultsFor (_ name: String) -> AttributeList {
        let grammar = activeGrammar
        if (grammar == nil) {return scannerDefaults()}
        if (grammar!.isScanner()) {return scannerDefaults ()}
        if (grammar!.isNonterminal (name)) {
            return parserNonterminalDefaults()
        } else {
            return parserTerminalDefaults()
        }
    }
    
//    static func isPrintable (_ anInteger: Int) -> Bool {
//        //Grammar isPrintable (Int ("a"))
//        //Grammar isPrintable (10")
//        //Grammar isPrintable (256)|
//        if (anInteger < 0) || (anInteger >= 256) {return false}
//        let printables = //Note: contains one single quote (quoted twice) and one double quote (quoted once)..."
//        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!,+-/\\*~=@%&?|<>'[]{}()^;#:.$_\" "
//        return printables.contains(Character(UnicodeScalar(anInteger)!))
//    }
    
    
    static func isPrintable(_ value: Int) -> Bool {
        // Printable ASCII characters range from 32 (space) to 126 (~)
        // Grammar isPrintable (Int ("a")) //In ascii, "a" is 97.
        // Grammar isPrintable (10")
        // Grammar isPrintable (256)
        // The actual conversion can be done as Character(UnicodeScalar(97)!
        // but if you want a string, further say String (character).
         return (32...126).contains(value)
    }
    
    
    
}
