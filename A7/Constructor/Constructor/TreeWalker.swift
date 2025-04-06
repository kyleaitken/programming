//
//  TreeWalker.swift
//  Constructor
//
//  Created by Kyle Aitken on 2025-04-06.
//

import Foundation

public class TreeWalker {
    var fsmMap: Dictionary<String,Any> = [:] //Ultimately FSM
    
    func process (tree: VirtualTree) -> Void {
        _ = walkTree(tree)
    }
    
    func walkTree (_ tree: VirtualTree) -> Any {
        let action = tree.label as String
        switch (action) {
        case "walkList":
            return walkList (tree)
        case "walkCharacter":
            return walkCharacter (tree)
        case "walkString":
            return walkString (tree)
        case "walkIdentifier":
            return walkIdentifier(tree)
        case "walkSymbol":
            return walkSymbol (tree)
        case "walkInteger":
            return walkInteger (tree)
        case "walkAttributes":
            return walkAttributes (tree)
        case "walkBuildTreeOrTokenFromName":
            return walkbuildTreeOrTokenFromName (tree)
        case "walkbuildTreeFromRightIndex":
            return walkbuildTreeFromRightIndex (tree)
        case "walkBuildTreeFromLeftIndex":
            return walkBuildTreeFromLeftIndex (tree)
        case "walkTreeBuildingSemanticAction":
            return walkTreeBuildingSemanticAction (tree)
        case "walkNonTreeBuildingSemanticAction":
            return walkNonTreeBuildingSemanticAction (tree)
        case "walkLook":
            return walkLook (tree)
        case "walkPlus":
            return walkPlus (tree)
        case "walkEpsilon":
            return walkEpsilon (tree)
        case "walkQuestionMark":
            return walkQuestionMark (tree)
        case "walkStar":
            return walkStar (tree)
        case "walkOr":
            return walkOr (tree)
        case "walkConcatenation":
            return walkConcatentation (tree)
        case "walkAnd":
            return walkAnd (tree)
        case "walkMinus":
            return walkMinus (tree)
        case "walkDotDot":
            return walkDotDot (tree)
        case "walkGrammar":
            return walkGrammar(tree)
        case "walkProduction":
            return walkProduction(tree)
        case "walkLeftPartWithLookahead":
            return walkLeftPartWithLookahead(tree)
        case "walkLeftPart":
            return walkLeftPart(tree)
        case "walkMacro":
            return walkMacro(tree)
        case "walkAttributeDefaults":
            return walkAttributeDefaults(tree)
        case "walkKeywords":
            return walkKeywords(tree)
        case "walkOutput":
            return walkOutput(tree)
        case "walkAttributeTerminalDefaults":
            return walkAttributeTerminalDefaults(tree)
        default:
            error ("Attempt to perform unknown walkTree routine \(action)")
            return 0
        }
    }
    
    func walkGrammar (_ tree: VirtualTree) {
        guard let tree = tree as? Tree else {
            print("Error: Expected tree to be of type Tree, but it's not.")
            return
        }
        // do the first pass
        firstPassWalkTree(tree)
        
        // now process the tree
        for child in tree.children {
            _ = walkTree(child)
        }
        
        Grammar.activeGrammar?.finalize()
        Grammar.activeGrammar?.renumber()
        
        if let description = Grammar.activeGrammar?.description {
            print(description)
        }
    }
    
    func firstPassWalkTree(_ tree: VirtualTree) {
        // first pass should identify nonterminals
        if let tree = (tree as? Tree) {
            if tree.label == "walkLeftPartWithLookahead" || tree.label == "walkLeftPart" {
                if let firstChild = (tree.children.first as? Token) {
                    Grammar.activeGrammar?.nonterminals.append(firstChild.symbol)
                }
                return
            }
            
            for child in tree.children {
                firstPassWalkTree(child)
            }
            
        } else {
            return
        }
    }
    
      
    func walkList (_ tree: VirtualTree) -> Any {
        let treeList = (tree as? Tree)!
        var index = 0;
        while (index < treeList.children.count) {
            let child0 = treeList.children[index]
            let child1 = treeList.children[index+1]

            let name = (child0 as? Token)!.symbol
            let fsm = walkTree (child1)

            fsmMap [name] = fsm
            Grammar.activeGrammar!.addMacro (name, fsm as! FiniteStateMachine)
            index += 2;
        }
        return 0
    }
    
    // builds the production and stores it in Grammar.productions
    func walkProduction(_ tree : VirtualTree) -> Any {
        guard let tree = tree as? Tree else {
            print("Error: Expected tree to be of type Tree, but it's not.")
            return 0
        }
        
        let production = Production()
        let result = walkTree(tree.children[0])
        var nonterminalSymbol = ""
        
        switch result {
            case let tuple as (String, [String]):  // nonterminal and lookahead collection
                nonterminalSymbol = tuple.0
                production.lookahead = tuple.1
            case let nonterminal as String:  // Just a String
                nonterminalSymbol = nonterminal
            default:
                print("Unexpected result format for Production.")
                return 0
        }
        
        production.leftPart = nonterminalSymbol
        
        // get right part/FSM
        let fsm = walkTree(tree.children[1]) as! FiniteStateMachine
        production.fsm = fsm
        Grammar.activeGrammar?.productions[nonterminalSymbol] = production
        return production
    }
    
    func walkMacro(_ tree : VirtualTree) -> Any {
        // first child is a token, symbol is the name for the macro
        // second child might be a tree or a token/it's an FSM, so walkTree on that child and then add the macro/fsm
        guard let tree = tree as? Tree else {
            print("Error: Expected tree to be of type Tree, but it's not.")
            return 0
        }
        
        let child0 = tree.children[0] as! Token
        let name = child0.symbol
        
        let fsm = walkTree(tree.children[1]) as? FiniteStateMachine
        Grammar.activeGrammar?.addMacro(name, fsm!)
        return 0
    }
    
    
    func walkLeftPartWithLookahead(_ tree : VirtualTree) -> Any {
        guard let tree = tree as? Tree else {
            print("Error: Expected tree to be of type Tree, but it's not.")
            return 0
        }
        
        // first child is nonterminal
        let child0 = tree.children[0] as! Token
        let nonterminal = child0.symbol
        
        // second child is lookahead fsm, but it needs to go to walkTree
        let child1 = tree.children[1]
        let lookaheadFSM = walkTree(child1) as! FiniteStateMachine
        
        // get transitions from lookahead FSM
        var lookaheadSymbols: [String] = []
        lookaheadFSM.transitionsDo { (transition: Transition) in
            if !transition.label!.hasAction() {
                lookaheadSymbols.append(transition.label!.name)
            }
        }
        
        return (nonterminal, lookaheadSymbols)
    }
    
    func walkLeftPart(_ tree : VirtualTree) -> Any {
        guard let tree = tree as? Tree else {
            print("Error: Expected tree to be of type Tree, but it's not.")
            return 0
        }
            
        // first child is nonterminal
        let child0 = tree.children[0] as! Token
        return child0.symbol
    }
    
    
    // Helper function to extract the numeric part from FSM name
    func extractNumber(from string: String) -> Int {
        // Use a regular expression to find the numeric part of the string
        if let match = string.range(of: "\\d+", options: .regularExpression) {
            let numberString = string[match]
            return Int(numberString) ?? 0 // Default to 0 if no number is found
        }
        return 0
    }
    
    func walkKeywords (_ tree: VirtualTree) {
//        "Note: This walk routine is initiated by #processAndDiscardDefaultsNow which subsequently
        //All it does is give the grammar the keywords and prints them..."
        if let tree = tree as? Tree {
            let keywords = tree.children.compactMap { ($0 as? Token)?.symbol }
            Grammar.activeGrammar?.keywords = keywords
        }
     }
    
    
    // create an empty FSM
    func walkEpsilon (_ tree : VirtualTree) -> Any {
        return FiniteStateMachine.empty()
    }
    
    
    func walkCharacter (_ tree : VirtualTree) -> Any {
        let token = tree as! Token
        return FiniteStateMachine.forCharacter(token.symbol)
    }
    
    
    func walkPlus (_ tree : VirtualTree) -> Any {
        guard let tree = tree as? Tree else {
            print("Error: Expected tree to be of type Tree, but it's not.")
            return 0
        }
        // should build an fsm with +
        let child = tree.children[0]
        let fsm = walkTree(child) as? FiniteStateMachine
        return fsm!.plus()
    }
    
    
    func walkQuestionMark (_ tree : VirtualTree) -> Any {
        guard let tree = tree as? Tree else {
            print("Error: Expected tree to be of type Tree, but it's not.")
            return 0
        }
        let child = tree.children[0]
        let fsm = walkTree(child) as? FiniteStateMachine
        return fsm?.or(otherFSM: FiniteStateMachine.empty()) as Any
    }
    
    func walkStar (_ tree : VirtualTree) -> Any {
        guard let child = extractFirstChild(tree) else {
            print("No child found")
            return 0
        }
        
        if let fsm = walkTree(child) as? FiniteStateMachine {
            return fsm.plus().or(otherFSM: FiniteStateMachine.empty())
        } else {
            print("walkTree did not return a FiniteStateMachine")
            return 0
        }
    }
    
    
    func walkDotDot (_ tree : VirtualTree) -> Any {
        guard let tree = tree as? Tree else {
            print("Error: Expected tree to be of type Tree, but it's not.")
            return 0
        }
        
        let startToken = tree.children[0] as! Token
        let endToken = tree.children[1] as! Token
        
        if startToken.label == "walkInteger" {
            return FiniteStateMachine.forIntegers(startToken.symbol, endToken.symbol)
        } else {
            return FiniteStateMachine.forCharacters(startToken.symbol, endToken.symbol)
        }
    }
    
    func walkOr (_ tree : VirtualTree) -> Any {
        // loop over children, which could be a list of trees or tokens
        var fsmsToOr: [FiniteStateMachine] = []
        guard let tree = tree as? Tree else {
            print("Error: Expected tree to be of type Tree, but it's not.")
            return 0
        }
        
        for child in tree.children {
            guard let fsm = walkTree(child) as? FiniteStateMachine else {
                print("ERROR: did not get an FSM back from walkTree")
                return 0
            }
            fsmsToOr.append(fsm)
        }
        
        return FiniteStateMachine.orAll(FSMCollection: fsmsToOr)
    }
    
    func walkAnd (_ tree : VirtualTree) -> Any {
        guard let tree = tree as? Tree else {
            print("Error: Expected tree to be of type Tree, but it's not.")
            return 0
        }
        
        guard let fsm1 = walkTree(tree.children[0]) as? FiniteStateMachine else {
            print("Error: fsm1 in walkAnd is not an FSM")
            return 0
        }
        guard let fsm2 = walkTree(tree.children[1]) as? FiniteStateMachine else {
            print("Error: fsm2 in walkAnd is not an FSM")
            return 0
        }
        
        return fsm1.andAnFSM(otherFSM: fsm2)
    }
    
    
    func walkMinus (_ tree : VirtualTree) -> Any {
        guard let tree = tree as? Tree else {
            print("Error: Expected tree to be of type Tree, but it's not.")
            return 0
        }
        
        guard let fsm1 = walkTree(tree.children[0]) as? FiniteStateMachine else {
            print("Error: fsm1 in walkMinus is not an FSM")
            return 0
        }
        guard let fsm2 = walkTree(tree.children[1]) as? FiniteStateMachine else {
            print("Error: fsm2 in walkMinus is not an FSM")
            return 0
        }
        
        return fsm1.minusAnFSM(otherFSM: fsm2)
    }
    
    func walkConcatentation (_ tree : VirtualTree) -> Any {
        var fsmsToConcat: [FiniteStateMachine] = []
        guard let tree = tree as? Tree else {
            print("Error: Expected tree to be of type Tree, but it's not.")
            return 0
        }
        
        for child in tree.children {
            guard let fsm = walkTree(child) as? FiniteStateMachine else {
                print("ERROR: did not get an FSM back from walkTree")
                return 0
            }
            fsmsToConcat.append(fsm)
        }
        
        return FiniteStateMachine.concatenateAll(fsms: fsmsToConcat)
    }
    
    
    func extractFirstChild (_ tree : VirtualTree) -> VirtualTree? {
        guard let tree = tree as? Tree else {
            print("Error: Expected tree to be of type Tree, but it's not.")
            return nil
        }
        return tree.children[0]
    }
    
    
    func walkString (_ tree : VirtualTree) -> Any {
        let token = tree as! Token
        return FiniteStateMachine.forString(token.symbol)
    }
    
    
    func walkSymbol (_ tree : VirtualTree) -> Any {
        let token = tree as! Token
        return FiniteStateMachine.forString(token.symbol)
    }
    
    
    func walkInteger (_ tree : VirtualTree) -> Any {
        let token = tree as! Token
        return FiniteStateMachine.forInteger(token.symbol)
    }
    
    func walkIdentifier (_ tree: VirtualTree) -> Any {
        // Ensure tree is a valid Tree instance
        let token = tree as! Token
        
        if let fsm = Grammar.activeGrammar?.macros[token.symbol] {
            return FiniteStateMachine.forIdentifier(fsm)
        } else {
            // if it's not an fsm, it's a char
            if token.symbol.last == ":" {
                token.symbol.removeLast()
            }
            if ((Grammar.activeGrammar?.isParser()) == true) {
                return FiniteStateMachine.forString(token.symbol)
            } else {
                return FiniteStateMachine.forCharacter(token.symbol)
            }
        }
    }
    
    func walkAttributes (_ tree : VirtualTree) -> Any {
        guard let tree = tree as? Tree else {
            print("Error: Expected tree to be of type Tree, but it's not.")
            return 0
        }
        
        // build fsm from first child, other children will be attributes
        let child0 = tree.children[0]
        let fsm = walkTree(child0)
        
        guard let finiteStateMachine = fsm as? FiniteStateMachine else {
            print("Error: The FSM returned by walkTree is not of type FiniteStateMachine")
            return 0
        }
        
        // get attributes
        var attributes: [String] = []
        for index in 1..<tree.children.count {
            if let attributeToken = tree.children[index] as? Token {
                let symbol = attributeToken.symbol
                attributes.append(symbol)
            } else {
                print("ERROR: Expected child to be a token, but it isn't")
            }
        }
        
        // override attributes for FSM
        finiteStateMachine.override(attributes)
        return finiteStateMachine
    }
    
    func walkbuildTreeOrTokenFromName (_ tree : VirtualTree) -> Any {
        guard let tree = tree as? Tree else {
            print("Error: Expected tree to be of type Tree, but it's not.")
            return 0
        }
        
        let child0 = tree.children[0]
        let symbol = (child0 as? Token)!.symbol
        let action = Grammar.activeGrammar?.type == "scanner" ? "buildToken" : "buildTree"
        let strippedSymbol = symbol.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        return FiniteStateMachine.forAction([strippedSymbol], isRootBuilding: true, actionName: action)
    }
    
    func walkBuildTreeFromLeftIndex(_ tree: VirtualTree) -> Any {
        return walkbuildTreeFromIndex(tree, negate: false)
    }
    
    func walkbuildTreeFromRightIndex(_ tree: VirtualTree) -> Any {
        return walkbuildTreeFromIndex(tree, negate: true)
    }
    
    func walkbuildTreeFromIndex(_ tree: VirtualTree, negate: Bool) -> Any {
        guard let tree = tree as? Tree else {
            print("Error: Expected tree to be of type Tree, but it's not.")
            return 0
        }
        let child0 = tree.children[0]
        let symbol = (child0 as? Token)!.symbol
        
        // Convert symbol to an integer
        if let integerValue = Int(symbol) {
            let value = negate ? -integerValue : integerValue
            return FiniteStateMachine.forAction([value], isRootBuilding: true, actionName: "buildTreeFromIndex")
        } else {
            print("Error: Unable to convert symbol \(symbol) to an integer.")
            return 0
        }
    }
    
    func walkTreeBuildingSemanticAction (_ tree : VirtualTree) -> Any {
        guard let tree = tree as? Tree else {
            print("Error: Expected tree to be of type Tree.")
            return 0
        }
        let child0 = tree.children[0]
        return walkSemanticAction(child0, isRootBuilding: true)
    }
    
    func walkNonTreeBuildingSemanticAction (_ tree : VirtualTree) -> Any {
        guard let tree = tree as? Tree else {
            print("Error: Expected tree to be of type Tree.")
            return 0
        }
        let child0 = tree.children[0]
        return walkSemanticAction(child0, isRootBuilding: false)
    }
    
    func walkSemanticAction (_ tree: VirtualTree, isRootBuilding: Bool) -> Any {
        guard let tree = tree as? Tree else {
            print("Error: Expected tree to be of type Tree.")
            return 0
        }

        // Extract the action from the first child (assuming it's a token)
        let actionToken = tree.children[0] as! Token
        var actionSymbol = actionToken.symbol
        
        if !actionSymbol.isEmpty, actionSymbol.last == ":" {
            actionSymbol.removeLast()
        }
        
        // Extract parameters from the remaining children
        var parameters: [Any] = []
        for i in 1..<tree.children.count {
            if let token = tree.children[i] as? Token {
                let param = token.asConstant()
                parameters.append(param)
            }
        }
        return FiniteStateMachine.forAction(parameters, isRootBuilding: isRootBuilding, actionName: actionSymbol)
    }
    
    func walkLook (_ tree : VirtualTree) -> Any {
        guard let tree = tree as? Tree else {
            print("Error: Expected tree to be of type Tree, but it's not.")
            return 0
        }
        
        // build fsm from first child, other children will be attributes
        let child0 = tree.children[0]
        let fsm = walkTree(child0)
        
        guard let fsmCopy = fsm as? FiniteStateMachine else {
            print("Error: The FSM returned by walkTree is not of type FiniteStateMachine")
            return 0
        }
        
        // need to override attributes to "L"
        fsmCopy.override(["look"])
        return fsmCopy
    }
    
    func walkAttributeDefaults (_ tree: VirtualTree) {
        //Note: This walk routine is initiated by #processAndDiscardDefaultsNow which subsequently
        //eliminates the tree to prevent generic tree walking later...
     }
    
    func walkOutput (_ tree: VirtualTree) {
        //Note: This walk routine is initiated by #processAndDiscardDefaultsNow which subsequently
        //eliminates the tree to prevent generic tree walking later...
        
//        "All it does is print the output language. We commented out code that records the
//        output language in the grammar since the student version will currently output
//        in the format their tool is written in; i.e., Smalltalk for Smalltalk users versus
//        Swift for Swift users."
        print("Output Language: Swift")
     }
    
    func walkAttributeTerminalDefaults (_ tree: VirtualTree) {
         //Note: This walk routine is initiated by #processAndDiscardDefaultsNow which subsequently
         //eliminates the tree to prevent generic tree walking later...
    }

    func walkAttributeNonterminalDefaults (_ tree: VirtualTree) {
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
    
    // for printing the fsm nice like
    func printFSMs (fsmMap: Dictionary<String,Any>) {
        let sortedDict = fsmMap.sorted { (item1, item2) -> Bool in
            let number1 = extractNumber(from: item1.key)
            let number2 = extractNumber(from: item2.key)

            return number1 < number2
        }

        for (key, value) in sortedDict {
            if let fsm = value as? FiniteStateMachine {
                print(key)
                fsm.printOn()
                print()
            }
        }
    }
}
