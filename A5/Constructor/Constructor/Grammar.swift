//
//  Grammar.swift
//  Constructor
//
//  Created by Wilf Lalonde on 2023-01-24.
//

import Foundation
    
public final class Grammar {
    var type: String = ""
    var nonterminals: [String] = []
    var macros : [String: FiniteStateMachine] = [:]
    var productions : [String: Production] = [:]
    var keywords: [String] = []
    
    init () {
        type = ""
        nonterminals = [];
        macros = [:]
    }
    //finiteStateMachine:
    func addMacro (_ macro: String, _ fsm: FiniteStateMachine) -> Void {
        macros [macro] = fsm
    }
    
    public var description: String {
        var string = "Grammar nonterminals:\n\n"
        for item in self.nonterminals {
            string += "\(item)\n"
        }
        
        string += "\nGrammar macros: \n\n"
        for (name, macro) in self.macros {
            string += "\(name):\n"
            string += macro.description + "\n"
        }
        
        string += "\nGrammar Productions: \n\n"
        for (name, production) in self.productions {
            string += production.description + "\n"
        }
        
        return string
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
    
    func productionFor (_ name: String) -> Production {
        return (productions [name])!
    }
    
    func isReadTerminalTransition (_ transition: Transition) -> Bool {
        if transition.label!.hasAction () {return false} //Otherwise, it has attributes"
        if self.isNonterminal (transition.label!.name) {return false}
        return transition.label!.attributes.isRead
    }
    
    func isNonterminalTransition (_ transition: Transition) -> Bool {
        if transition.label!.hasAction () {return false} //Otherwise, it has attributes"
        if self.isNonterminal (transition.label!.name) {return true}
        return false
    }
    
    func isETransitionLabel (_ label: Label) -> Bool {
        if (label.hasAction ()) {return true}
        //So it must be a name with attributes...
        let name = label.name
        if self.isNonterminal (name) {return productionFor (name).generatesE}
        //So it must be a nonterminal.
        if !label.attributes.isRead {return true} //because its a look
        //None of the 3 cases apply, so...
        return false
    }
    
    func goalProductions () -> Array<Production> {
        var goalProductions: Array<Production> = []
        for (_, production) in productions {
            if production.isGoal () {goalProductions.append (production)}
        }
        return goalProductions;
    }
    
    
    func eSuccessors (_ fsmStates: Array<FiniteStateMachineState>) -> Array<FiniteStateMachineState> {
        var result: Array<FiniteStateMachineState> = []
        for state in fsmStates {result.append (state)}
        for state in result {
            for transition in state.transitions {
                if isETransitionLabel (transition.label!) {result.append (transition.goto!)}
            }
        }
        return result
    }
    
    func computeEGeneratingNonterminals () -> Void {
        var changed: Bool = true
        while (changed) {
            changed = false
            for (_, production) in productions {//A is left part (for information only)
                if (!production.generatesE) {
                    for state in self.eSuccessors (production.fsm.getInitialStates ()) {//of A
                        if state.isFinal {production.generatesE = true; changed = true}
                    }
                }
            }
        }
    }
    
    func computeFirstSets () -> Void {
        //Need to invent a method so I can say 'aCollection addIfAbsentAdded (anObject) and addAllIf...'.
        
        var changed: Bool = true
        while (changed) {
            changed = false
            for (_, production) in productions {//A is for information only
                for state in eSuccessors (production.fsm.getInitialStates ()) {
                    for transition in state.transitions {
                        if self.isReadTerminalTransition (transition) {
                            if production.firstSet.addIfAbsentAdded (transition.label!.name) {changed = true}
                            //if (!production.firstSet.contains)
                        }
                        if self.isNonterminalTransition (transition) {
                            let M = transition.label!.name //NOT for information only
                            if production.firstSet.addAllIfAbsentAdded (self.productionFor (M).firstSet) {changed = true}
                        }
                    }
                }
            }
        }
    }


    func computeFollowSets () -> Void {
        //    A copy of the diagram in text form that the notes used as an aid to build follow sets...
        //
        //    A -> ... p via B to q ... e-successor ... r via a or C
        //        a => add a to Follow(B)
        //        C => add First(C) to Follow(B)
        //        if r is final => add Follow(A) to Follow(B)
        //
        //Needed to invent a method so I can say 'if anArray.addAllIfAbsentAdded (collection) {... do something ...}.
        //Note: added variable names match the diagram in the notes (replicated in text up above).
        
        var changed: Bool = false
        
        //Start off by adding the lookahead to the follow set of the goal...
        for (_, production) in productions {
            if (production.lookahead != nil) {
                production.followSet.append (contentsOf: production.lookahead!) //Shouldn't have duplicates
            }
        }
        
        changed = true
        while (changed) {
            changed = false
            for (A, production) in productions {//A is for information only not to be confuxed with B or C
                production.fsm.transitionsDo {(_ transition: Transition) -> Void in
                    if self.isNonterminalTransition (transition) {
                        let B = transition.label!.name;
                        let Bproduction = self.productionFor (B);
                        let q = transition.goto
                        
                        if let qState = q {
                            for r in self.eSuccessors([qState]) {  // Now passing a non-optional array
                                for rTransition in r.transitions {
                                    if self.isReadTerminalTransition(rTransition) {
                                        let a = rTransition.label!.name
                                        if Bproduction.followSet.addIfAbsentAdded(a) {
                                            changed = true
                                        }
                                    }
                                    if self.isNonterminalTransition(rTransition) {
                                        let C = rTransition.label!.name
                                        if Bproduction.followSet.addAllIfAbsentAdded(self.productionFor(C).firstSet) {
                                            changed = true
                                        }
                                    }
                                }
                                if r.isFinal {
                                    if Bproduction.followSet.addAllIfAbsentAdded(self.productionFor(A).followSet) {
                                        changed = true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func printEGeneratingFirstAndFollowSets () -> Void {
        //Should really print to output...
        print ("For grammar...")
        
        print ("")
        for nonterminal in nonterminals.sorted (by: <) {
            print ("//e-Generating(\(nonterminal)) = \((self.productionFor (nonterminal)).generatesE)")
        }
        
        print ("")
        for nonterminal in nonterminals.sorted (by: <) {
            print ("//First(\(nonterminal) = \((self.productionFor (nonterminal)).firstSet.sorted (by: <))")
        }
        
        print ("")
        for nonterminal in nonterminals.sorted (by: <) {
            print ("//Follow(\(nonterminal) = \((self.productionFor (nonterminal)).followSet.sorted (by: <))")
        }
    }

    func finalize () -> Void {
        computeEGeneratingNonterminals ()
        computeFirstSets ()
        computeFollowSets ()
        printEGeneratingFirstAndFollowSets ()
    }
    
    
}


class Production : CustomStringConvertible {
    var leftPart: String = ""
    var lookahead: [String]? = []
    var fsm: FiniteStateMachine = FiniteStateMachine ()
    var generatesE: Bool = false
    var firstSet: [String] = []
    var followSet: [String] = []
    
    func name (_ newName: String) {leftPart = newName}
    func rightPart () -> FiniteStateMachine {return fsm}
    func getFsm () -> FiniteStateMachine {return fsm}
    
    public var description: String {
        var string = leftPart
        if lookahead != nil {
                string += " {"
            var index = 0
            for symbol in lookahead! {
                if index > 0 {string += " "}; index += 1
                if (Grammar.activeGrammar?.isScanner() == true) {
                    // print ascii as a string
                    if let intSymbol = Int(symbol) {
                        if Grammar.isPrintable(intSymbol) {
                            if intSymbol == 32 {
                                string += "\" \""
                            } else {
                                string += String(Character(UnicodeScalar(intSymbol)!))
                            }
                        }
                    }
                } else {
                    string += symbol
                }
            }
            string += "}"
        }
        string += " -> " + rightPart().description
        return string
    }
    
    func isGoal () -> Bool {return lookahead != nil}
    
}


extension Array where Element: Equatable {
    mutating func addIfAbsentAdded (_ object: Element) -> Bool {
        if self.contains (object) {return false}
        self.append (object)
    return true
    }
    mutating func addAllIfAbsentAdded (_ collection: [Element]) -> Bool {
        var changed: Bool = false
        for item in collection {
            if (addIfAbsentAdded (item)) {changed = true}
        }
        return changed
    }
}
