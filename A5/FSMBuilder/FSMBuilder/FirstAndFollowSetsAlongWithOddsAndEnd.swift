

//Start by creating a copy of FSMBuilder and call it GrammarBuilder

//
// CODE YOU WILL HAVE TO ADD TO YOUR EXISTING CODE.
//


import Foundation

//My code uses these routines.
extension Array where Element: Equatable {
    mutating func addIfAbsentAdded (_ object: Element) -> Bool {
        if self.contains (object) {return false}
        self.append (object)
	return true
    }
    mutating func addAllIfAbsentAdded (_ collection: Element) -> Bool {
        var changed: Bool = false
        for item in collection {
            if (addIfAbsentAdded (item)) {changed = true}
        }
        return changed
    }
}


class Production : CustomStringConvertable {
    var leftPart: String = ""
    var lookahead: [String]? = []
    var fsm: FiniteStateMachine = FiniteStateMachine ()
    var generatesE: Bool = false
    var firstSet: [String] = []
    var followSet: [String] = []
    
    func name (_ newName: String) {leftPart = newName}
    func rightPart () -> FiniteStateMachine {return fsm}
    func fsm () -> FiniteStateMachine {return fsm}
    public var description: String {
        var string = leftPart
        if lookahead != nil {
                string += " {"
            var index = 0
            for symbol in lookahead! {
                if index > 0 {string += " "}; index += 1
                string += symbol
            }
            string += "}"
        }
        string += " -> " + rightPart ().description
    }
    
    func isGoal () -> Bool {return lookahead != nil}
    
}

//For the following, just add the code you are missing...

class Grammar {
    var type: String = ""
    var nonterminals: [String] = []
    var macros : [String: FiniteStateMachine] = [:]
    var productions : [String: Production] = [:]
    var keywords: [String] = []
    
    func productionFor (_ name: String) -> Production {
        return (productions [name])!
    }
    func isNonterminal (_ name: String) -> Bool {
        return nonterminals.contains (name)
    }
    
    func isReadTerminalTransition (_ transition: Transition) -> Bool {
        if transition.label.isAction () {return false} //Otherwise, it has attributes"
        if self.isNonterminal (transition.label.name) {return false}
        return transition.label.attributes.isRead
    }
    
    func isNonterminalTransition (_ transition: Transition) -> Bool {
        if transition.label.isAction () {return false} //Otherwise, it has attributes"
        if self.isNonterminal (transition.label.name) {return true}
        return false
    }
    
    func isETransitionLabel (_ label: Label) -> Bool {
        if (label.isAction ()) {return true}
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
                if isETransitionLabel (transition.label) {result.append (transition.goto)}
            }
        }
        return result
    }
    
    func computeEGeneratingNonterminals () -> Void {
        var changed: Bool = true
        while (changed) {
            changed = false
            for (A, production) in productions {//A is left part (for information only)
                if (!production.generatesE) {
                    for state in self.eSuccessors (production.fsm.initialStates ()) {//of A
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
            for (A, production) in productions {//A is for information only
                for state in eSuccessors (production.fsm.initialStates ()) {
                    for transition in state.transitions {
                        if self.isReadTerminalTransition (transition) {
                            if production.firstSet.addIfAbsentAdded (transition.label.name) {changed = true}
                            //if (!production.firstSet.contains)
                        }
                        if self.isNonterminalTransition (transition) {
                            var M = transition.label.name //NOT for information only
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
                        let B = transition.label.name;
                        let Bproduction = self.productionFor (B);
                        let q = transition.goto
                        
                        for r in self.eSuccessors ([q]) {
                            for rTransition in r.transitions {
                                if (self.isReadTerminalTransition (rTransition)) {
                                    let a = rTransition.label.name
                                    if Bproduction.followSet.addIfAbsentAdded (a) {changed = true}
                                }
                                if (self.isNonterminalTransition (rTransition)) {
                                    let C = rTransition.label.name
                                    if Bproduction.followSet.addAllIfAbsentAdded (self.productionFor (C).firstSet) {changed = true}
                                }
                            }
                            if (r.isFinal) {
                                if Bproduction.followSet.addAllIfAbsentAdded (self.productionFor (A).followSet) {changed = true}
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
            print ("//e-Generating(/(nonterminal)) = \((self.productionFor (nonterminal)).generatesE)")
        }
        
        print ("")
        for nonterminal in nonterminals.sorted (by: <) {
            print ("//First(/(nonterminal) = \((self.productionFor (nonterminal)).followSet.sorted (by: <))")
        }
        
        print ("")
        for nonterminal in nonterminals.sorted (by: <) {
            print ("//Follow(/(nonterminal) = \((self.productionFor (nonterminal)).firstSet.sorted (by: <))")
        }
    }

    func finalize () -> Void {
    	computeEGeneratingNonterminals ()
    	computeFirstSets ()
    	computeFollowSets ()
    	printEGeneratingFirstAndFollowSets ()
    }
}
                                                                                                                   
      
//======================= THESE ARE CONSTRUCTOR WALK ROUTINES THAT MOSTLY DO NOTHING ====
//Only the first 2 do something. However, they must be in your constructor and in the 
//canPerformAction and performAction routines.
/*

func processAndDiscardDefaultsNow (_ tree: VirtualTree) {
    //Pick up the tree just built containing either the attributes, keywords, optimize, and output tree,
    //process it with walkTree, and remove it from the tree stack... by replacing the entry by nil..."
    var tree: Tree = parser.treeStack.last; self.walkTree (tree)
    parser.treeStack.removeLast; parser.treeStack.addLast: nil
}
 
 func walkKeywords (_ tree: VirtualTree) {
     "Note: This walk routine is initiated by #processAndDiscardDefaultsNow which subsequently
     //eliminates the tree to prevent generic tree walking later...|
     //All it does is give the grammar the keywords and prints them..."
     keywords := aTree children collect: [:child | child symbol].
     Grammar activeGrammar keywordsForParser: keywords.
  }

  
func walkAttributeTerminalDefaults (_ tree: VirtualTree) {
     //Note: This walk routine is initiated by #processAndDiscardDefaultsNow which subsequently
     //eliminates the tree to prevent generic tree walking later...
}

func walkAttributeNonterminalDefaults (_ tree: VirtualTree) {
    //Note: This walk routine is initiated by #processAndDiscardDefaultsNow which subsequently
    //eliminates the tree to prevent generic tree walking later...
 }

func walkOutput (_ tree: VirtualTree) {
    //Note: This walk routine is initiated by #processAndDiscardDefaultsNow which subsequently
    //eliminates the tree to prevent generic tree walking later...
    
    "All it does is print the output language. We commented out code that records the
    output language in the grammar since the student version will currently output
    in the format their tool is written in; i.e., Smalltalk for Smalltalk users versus
    Swift for Swift users."
 }
   
func walkAttributeDefaults (_ tree: VirtualTree) {
    //Note: This walk routine is initiated by #processAndDiscardDefaultsNow which subsequently
    //eliminates the tree to prevent generic tree walking later...
 }

func walkOptimize (_ tree: VirtualTree) {
    //Note: This walk routine is initiated by #processAndDiscardDefaultsNow which subsequently
    //eliminates the tree to prevent generic tree walking later...
    
    //All it does is allow 'chain reductions' and 'keep nonterminal transitions' to be used
    //by Wilf's parser constructor. It does so by telling the grammar what the optimization is
    //and the more advanced constructor he has to perform the optimizations. They are
    //of no concern to the student constructor... so that code is commented out..."
 }
 */


