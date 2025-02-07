//
//  Constructor.swift
//  Constructor
//
//  Created by Wilf Lalonde on 2023-01-24.
//

import Foundation

typealias treeClosure = (VirtualTree) -> Any //Ultimately FSM

public final class Constructor : Translator {
    
    var parser: Parser?
    var tree: VirtualTree? = nil
    var fsmMap: Dictionary<String,Any> = [:] //Ultimately FSM
    
    init() {
        parser = Parser(sponsor: self, parserTables: parserTables, scannerTables: scannerTables)
    }
    
    func process (_ text: String) -> Void {
        if let tree = parser!.parse(text) as? Tree {
            print("tree from parser:")
            print(tree)
            walkTree(tree)
        } else {
            print("Failed to parse the text into a Tree")
        }
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
        default:
            error ("Attempt to perform unknown walkTree routine \(action)")
            return 0
        }
    }
    
  public func canPerformAction(_ action: String) -> Bool {
      if (action == "processTypeNow") {return true;}
      if (action == "processAndDiscardDefaultsNow") {return true}
      return false
    }
          
  public func performAction(_ action :String, _ parameters:[Any]) -> Void {
      if (action == "processTypeNow") {
          processTypeNow (parameters)
      }
      if (action == "processAndDiscardDefaultsNow") {
          processAndDiscardDefaultsNow()
      }
  }
    
    static public func example () -> String {
        let grammar = Grammar  ()
        Grammar.activeGrammar = grammar
        
        let exampleFiles: [Int: String] = [
            0: "toyLispGrammar",
            1: "toyScannerGrammar",
            2: "toyParserGrammarWithMacros",
            3: "toyArithmeticExpressionGrammar Version 1",
            4: "toyArithmeticExpressionGrammar Version 2",
            5: "toyParserGrammarLeftRecursive",
            6: "toyParserGrammarRightRecursive",
            7: "toyParserGrammarNonRecursive",
            8: "toyParserGrammarToTestFollowSets"
        ]
        
        let numberToTest = 5
        let fileName = exampleFiles[numberToTest]
        var fileContent = ""

        if let filePath = Bundle.main.path(forResource: fileName, ofType: "txt") {
            let fileURL = URL(fileURLWithPath: filePath)
            do {
                fileContent = try String(contentsOf: fileURL, encoding: .utf8)
            } catch {
                print("Error reading the file: \(error)")
            }
        } else {
            print("File not found in the app bundle.")
        }
        
        let builder = Constructor ();
        builder.process (fileContent)
        builder.printOn(fsmMap: builder.fsmMap)
        return "Done"
    }
    
    // tells you the kind of fsm you're building
    func processTypeNow (_ parameters:[Any]) -> Void {
        let type = parameters [0] as? String;
        Grammar.activeGrammar?.type = type!
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
            walkTree(child)
        }
        
        if let description = Grammar.activeGrammar?.description {
            print(description)
        }
        Grammar.activeGrammar?.finalize()
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
    
    // for printing the fsm nice like
    func printOn (fsmMap: Dictionary<String,Any>) {
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
        let action = Grammar.activeGrammar?.type == "scanner" ? "#buildToken" : "#buildTree"
        return FiniteStateMachine.forAction([symbol], isRootBuilding: true, actionName: action)
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
            return FiniteStateMachine.forAction([value], isRootBuilding: true, actionName: "#buildTreeFromIndex")
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
        let actionSymbol = "#" + actionToken.symbol

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
    
    func processAndDiscardDefaultsNow() {
        //Pick up the tree just built containing either the attributes, keywords, optimize, and output tree,
        //process it with walkTree, and remove it from the tree stack... by replacing the entry by nil..."
        let tree: Tree = self.parser!.treeStack.last as! Tree
        self.walkTree(tree)
        self.parser!.treeStack.removeLast()
        self.parser!.treeStack.append(nil)
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
    
    
        
var scannerTables: Array<Any> = [
    ["ScannerReadaheadTable", 1, ("]", "RK", 35), ("/", "R", 10), ("{", "RK", 36), ("}", "RK", 37), ("\"", "R", 11), ("$", "R", 12), ([256], "L", 21), ("ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz", "RK", 6), ("[", "RK", 33), ("(", "RK", 23), (")", "RK", 24), ("*", "RK", 25), ("+", "RK", 26), ("-", "RK", 2), ("&", "RK", 22), (".", "RK", 3), ([9,10,12,13,32], "R", 7), ("0123456789", "RK", 4), ("=", "RK", 5), ("?", "RK", 31), ("#", "R", 8), ("|", "RK", 34), ("'", "R", 9)],
    ["ScannerReadaheadTable", 2, ([9,10,12,13,32,96,147,148,256], "L", 27), ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789!,+-/\\*~=@%&?|<[]{}()^;#:.$'\"", "L", 27), (">", "RK", 38)],
    ["ScannerReadaheadTable", 3, ([9,10,12,13,32,96,147,148,256], "L", 28), ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789!,+-/\\*~=@%&?|<>[]{}()^;#:$'\"", "L", 28), (".", "RK", 39)],
    ["ScannerReadaheadTable", 4, ([9,10,12,13,32,96,147,148,256], "L", 29), ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_!,+-/\\*~=@%&?|<>[]{}()^;#:.$'\"", "L", 29), ("0123456789", "RK", 4)],
    ["ScannerReadaheadTable", 5, ([9,10,12,13,32,96,147,148,256], "L", 30), ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789!,+-/\\*~=@%&?|<[]{}()^;#:.$'\"", "L", 30), (">", "RK", 40)],
    ["ScannerReadaheadTable", 6, ([9,10,12,13,32,96,147,148,256], "L", 32), ("!,+-/\\*~=@%&?|<>[]{}()^;#.$'\"", "L", 32), ("0123456789:ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz", "RK", 6)],
    ["ScannerReadaheadTable", 7, ([96,147,148,256], "L", 1), ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789!,+-/\\*~=@%&?|<>[]{}()^;#:.$'\"", "L", 1), ([9,10,12,13,32], "R", 7)],
    ["ScannerReadaheadTable", 8, ("\"", "R", 14), ("'", "R", 15), ("ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz", "RK", 13)],
    ["ScannerReadaheadTable", 9, ([256], "LK", 42), ("'", "R", 16), ([9,10,12,13,32,96,147,148], "RK", 9), ("!\"#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_abcdefghijklmnopqrstuvwxyz{|}~", "RK", 9)],
    ["ScannerReadaheadTable", 10, ([9,10,12,13,32], "L", 44), ([96,147,148,256], "LK", 44), ("=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[]^_\\abcdefghijklmnopqrstuvwxyz{|}~!\"#$%&'()*+,-.0123456789:;<", "LK", 44), ("/", "R", 17)],
    ["ScannerReadaheadTable", 11, ([256], "LK", 45), ("\"", "R", 18), ([9,10,12,13,32,96,147,148], "RK", 11), ("!#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_abcdefghijklmnopqrstuvwxyz{|}~", "RK", 11)],
    ["ScannerReadaheadTable", 12, ([9,10,12,13,32,96,147,148], "RK", 46), ("!\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_abcdefghijklmnopqrstuvwxyz{|}~", "RK", 46)],
    ["ScannerReadaheadTable", 13, ([9,10,12,13,32,96,147,148,256], "L", 41), ("!,+-/\\*~=@%&?|<>[]{}()^;#.$'\"", "L", 41), ("0123456789:ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz", "RK", 13)],
    ["ScannerReadaheadTable", 14, ([256], "LK", 47), ("\"", "R", 19), ([9,10,12,13,32,96,147,148], "RK", 14), ("!#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_abcdefghijklmnopqrstuvwxyz{|}~", "RK", 14)],
    ["ScannerReadaheadTable", 15, ([256], "LK", 48), ("'", "R", 20), ([9,10,12,13,32,96,147,148], "RK", 15), ("!\"#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_abcdefghijklmnopqrstuvwxyz{|}~", "RK", 15)],
    ["ScannerReadaheadTable", 16, ([9,10,12,13,32,96,147,148,256], "L", 43), ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789!,+-/\\*~=@%&?|<>[]{}()^;#:.$\"", "L", 43), ("'", "RK", 9)],
    ["ScannerReadaheadTable", 17, ([9,32,96,147,148], "R", 17), ("=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_abcdefghijklmnopqrstuvwxyz{|}~!\"#$%&'()*+,-./0123456789:;<", "R", 17), ([256], "LK", 1), ([10,12,13], "R", 1)],
    ["ScannerReadaheadTable", 18, ([9,10,12,13,32,96,147,148,256], "L", 43), ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789!,+-/\\*~=@%&?|<>[]{}()^;#:.$'", "L", 43), ("\"", "RK", 11)],
    ["ScannerReadaheadTable", 19, ([9,10,12,13,32,96,147,148,256], "L", 41), ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789!,+-/\\*~=@%&?|<>[]{}()^;#:.$'", "L", 41), ("\"", "RK", 14)],
    ["ScannerReadaheadTable", 20, ([9,10,12,13,32,96,147,148,256], "L", 41), ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789!,+-/\\*~=@%&?|<>[]{}()^;#:.$\"", "L", 41), ("'", "RK", 15)],
    ["SemanticTable", 21, "buildToken", ["-|"], 1],
    ["SemanticTable", 22, "buildToken", ["And"], 1],
    ["SemanticTable", 23, "buildToken", ["OpenRound"], 1],
    ["SemanticTable", 24, "buildToken", ["CloseRound"], 1],
    ["SemanticTable", 25, "buildToken", ["Star"], 1],
    ["SemanticTable", 26, "buildToken", ["Plus"], 1],
    ["SemanticTable", 27, "buildToken", ["Minus"], 1],
    ["SemanticTable", 28, "buildToken", ["Dot"], 1],
    ["SemanticTable", 29, "buildToken", ["walkInteger"], 1],
    ["SemanticTable", 30, "buildToken", ["Equals"], 1],
    ["SemanticTable", 31, "buildToken", ["QuestionMark"], 1],
    ["SemanticTable", 32, "buildToken", ["walkIdentifier"], 1],
    ["SemanticTable", 33, "buildToken", ["OpenSquare"], 1],
    ["SemanticTable", 34, "buildToken", ["Or"], 1],
    ["SemanticTable", 35, "buildToken", ["CloseSquare"], 1],
    ["SemanticTable", 36, "buildToken", ["OpenCurly"], 1],
    ["SemanticTable", 37, "buildToken", ["CloseCurly"], 1],
    ["SemanticTable", 38, "buildToken", ["RightArrow"], 1],
    ["SemanticTable", 39, "buildToken", ["DotDot"], 1],
    ["SemanticTable", 40, "buildToken", ["FatRightArrow"], 1],
    ["SemanticTable", 41, "buildToken", ["walkSymbol"], 1],
    ["SemanticTable", 42, "syntaxError", ["missing end quote for single quoted string"], 43],
    ["SemanticTable", 43, "buildToken", ["walkString"], 1],
    ["SemanticTable", 44, "syntaxError", ["// is a comment, / alone is not valid"], 1],
    ["SemanticTable", 45, "syntaxError", ["missing end quote for double quoted string"], 43],
    ["SemanticTable", 46, "buildToken", ["walkCharacter"], 1],
    ["SemanticTable", 47, "syntaxError", ["missing end quote for double quoted string"], 41],
    ["SemanticTable", 48, "syntaxError", ["missing end quote for single quoted string"], 41]]

var parserTables: Array<Any> =
    [
       ["keywords", "stack", "noStack", "read", "look", "node", "noNode", "keep", "noKeep", "parser", "scanner", "super", "superScanner", "attribute", "defaults", "keywords", "output", "optimize", "terminal", "nonterminal"],
       ["ReadaheadTable", 1, ("GrammarType", "RSN", 2), ("scanner", "RS", 172), ("superScanner", "RS", 173), ("super", "RS", 3), ("parser", "RS", 174), ("Grammar", "RSN", 177)],
       ["ReadaheadTable", 2, ("walkString", "RSN", 69), ("Macro", "RSN", 4), ("keywords", "RS", 5), ("attribute", "RS", 6), ("optimize", "RS", 7), ("Name", "RSN", 8), ("output", "RS", 9), ("Rules", "RSN", 70), ("walkIdentifier", "RSN", 69), ("LeftPart", "RSN", 10), ("Defaults", "RSN", 175), ("Production", "RSN", 11)],
       ["ReadaheadTable", 3, ("scanner", "RS", 176)],
       ["ReadaheadTable", 4, ("walkString", "RSN", 69), ("Macro", "RSN", 4), ("Name", "RSN", 8), ("walkIdentifier", "RSN", 69), ("LeftPart", "RSN", 10), ("Production", "RSN", 11), ("-|", "L", 72)],
       ["ReadaheadTable", 5, ("walkString", "RSN", 69), ("Name", "RSN", 12), ("walkIdentifier", "RSN", 69)],
       ["ReadaheadTable", 6, ("defaults", "RS", 13), ("terminal", "RS", 14), ("nonterminal", "RS", 15)],
       ["ReadaheadTable", 7, ("walkString", "RSN", 69), ("Name", "RSN", 16), ("walkIdentifier", "RSN", 69)],
       ["ReadaheadTable", 8, ("OpenCurly", "RS", 17), ("Equals", "RS", 18), ("RightArrow", "L", 73)],
       ["ReadaheadTable", 9, ("walkString", "RSN", 69), ("Name", "RSN", 19), ("walkIdentifier", "RSN", 69)],
       ["ReadaheadTable", 10, ("RightArrow", "RS", 20), ("RightParts", "RSN", 21), ("RightPart", "RSN", 22)],
       ["ReadaheadTable", 11, ("walkString", "RSN", 69), ("Macro", "RSN", 4), ("Name", "RSN", 8), ("walkIdentifier", "RSN", 69), ("LeftPart", "RSN", 10), ("Production", "RSN", 11), ("-|", "L", 72)],
       ["ReadaheadTable", 12, ("walkString", "RSN", 69), ("Name", "RSN", 12), ("Dot", "RS", 85), ("walkIdentifier", "RSN", 69)],
       ["ReadaheadTable", 13, ("walkString", "RSN", 69), ("Name", "RSN", 24), ("walkIdentifier", "RSN", 69)],
       ["ReadaheadTable", 14, ("defaults", "RS", 25)],
       ["ReadaheadTable", 15, ("defaults", "RS", 26)],
       ["ReadaheadTable", 16, ("Dot", "RS", 86)],
       ["ReadaheadTable", 17, ("AndExpression", "RSN", 27), ("Primary", "RSN", 28), ("Alternation", "RSN", 29), ("Secondary", "RSN", 30), ("Byte", "RSN", 31), ("OpenCurly", "RS", 32), ("walkString", "RSN", 69), ("walkSymbol", "RSN", 33), ("walkInteger", "RSN", 80), ("SemanticAction", "RSN", 88), ("walkCharacter", "RSN", 80), ("walkIdentifier", "RSN", 69), ("Expression", "RSN", 34), ("Concatenation", "RSN", 35), ("RepetitionOption", "RSN", 36), ("Name", "RSN", 79), ("OpenRound", "RS", 37), ("And", "L", 144), ("Minus", "L", 144), ("CloseCurly", "L", 144), ("Dot", "L", 144), ("CloseRound", "L", 144), ("FatRightArrow", "L", 144), ("RightArrow", "L", 144)],
       ["ReadaheadTable", 18, ("AndExpression", "RSN", 27), ("Primary", "RSN", 28), ("Alternation", "RSN", 29), ("Secondary", "RSN", 30), ("Byte", "RSN", 31), ("OpenCurly", "RS", 32), ("walkString", "RSN", 69), ("walkSymbol", "RSN", 33), ("walkInteger", "RSN", 80), ("SemanticAction", "RSN", 88), ("walkCharacter", "RSN", 80), ("walkIdentifier", "RSN", 69), ("Expression", "RSN", 38), ("Concatenation", "RSN", 35), ("RepetitionOption", "RSN", 36), ("Name", "RSN", 79), ("OpenRound", "RS", 37), ("And", "L", 144), ("Minus", "L", 144), ("CloseCurly", "L", 144), ("Dot", "L", 144), ("CloseRound", "L", 144), ("FatRightArrow", "L", 144), ("RightArrow", "L", 144)],
       ["ReadaheadTable", 19, ("Dot", "RS", 89)],
       ["ReadaheadTable", 20, ("AndExpression", "RSN", 27), ("Primary", "RSN", 28), ("walkString", "RSN", 69), ("Alternation", "RSN", 29), ("Secondary", "RSN", 30), ("Byte", "RSN", 31), ("OpenCurly", "RS", 32), ("walkSymbol", "RSN", 33), ("walkInteger", "RSN", 80), ("SemanticAction", "RSN", 88), ("walkCharacter", "RSN", 80), ("walkIdentifier", "RSN", 69), ("Expression", "RSN", 39), ("Concatenation", "RSN", 35), ("RepetitionOption", "RSN", 36), ("OpenRound", "RS", 37), ("Name", "RSN", 79), ("And", "L", 144), ("Minus", "L", 144), ("CloseCurly", "L", 144), ("Dot", "L", 144), ("CloseRound", "L", 144), ("FatRightArrow", "L", 144), ("RightArrow", "L", 144)],
       ["ReadaheadTable", 21, ("Dot", "RS", 90)],
       ["ReadaheadTable", 22, ("RightArrow", "RS", 20), ("RightPart", "RSN", 22), ("Dot", "L", 84)],
       ["ReadaheadTable", 23, ("walkString", "RSN", 69), ("Macro", "RSN", 4), ("keywords", "RS", 5), ("attribute", "RS", 6), ("Name", "RSN", 8), ("walkIdentifier", "RSN", 69), ("Rules", "RSN", 70), ("optimize", "RS", 7), ("output", "RS", 9), ("LeftPart", "RSN", 10), ("Defaults", "RSN", 175), ("Production", "RSN", 11)],
       ["ReadaheadTable", 24, ("walkString", "RSN", 69), ("Name", "RSN", 24), ("Dot", "RS", 91), ("walkIdentifier", "RSN", 69)],
       ["ReadaheadTable", 25, ("walkString", "RSN", 69), ("Name", "RSN", 40), ("walkIdentifier", "RSN", 69)],
       ["ReadaheadTable", 26, ("walkString", "RSN", 69), ("Name", "RSN", 41), ("walkIdentifier", "RSN", 69)],
       ["ReadaheadTable", 27, ("Minus", "RS", 42), ("CloseCurly", "L", 75), ("Dot", "L", 75), ("CloseRound", "L", 75), ("FatRightArrow", "L", 75), ("RightArrow", "L", 75)],
       ["ReadaheadTable", 28, ("QuestionMark", "RS", 92), ("Star", "RS", 93), ("Plus", "RS", 94), ("walkSymbol", "L", 76), ("OpenRound", "L", 76), ("OpenCurly", "L", 76), ("walkIdentifier", "L", 76), ("walkString", "L", 76), ("walkCharacter", "L", 76), ("walkInteger", "L", 76), ("Or", "L", 76), ("And", "L", 76), ("Minus", "L", 76), ("CloseCurly", "L", 76), ("Dot", "L", 76), ("CloseRound", "L", 76), ("FatRightArrow", "L", 76), ("RightArrow", "L", 76)],
       ["ReadaheadTable", 29, ("And", "RS", 43), ("Minus", "L", 77), ("CloseCurly", "L", 77), ("Dot", "L", 77), ("CloseRound", "L", 77), ("FatRightArrow", "L", 77), ("RightArrow", "L", 77)],
       ["ReadaheadTable", 30, ("OpenSquare", "RS", 44), ("Star", "L", 78), ("QuestionMark", "L", 78), ("Plus", "L", 78), ("walkSymbol", "L", 78), ("OpenRound", "L", 78), ("OpenCurly", "L", 78), ("walkIdentifier", "L", 78), ("walkString", "L", 78), ("walkCharacter", "L", 78), ("walkInteger", "L", 78), ("Or", "L", 78), ("And", "L", 78), ("Minus", "L", 78), ("CloseCurly", "L", 78), ("Dot", "L", 78), ("CloseRound", "L", 78), ("FatRightArrow", "L", 78), ("RightArrow", "L", 78)],
       ["ReadaheadTable", 31, ("DotDot", "RS", 45), ("OpenSquare", "L", 79), ("Star", "L", 79), ("QuestionMark", "L", 79), ("Plus", "L", 79), ("walkSymbol", "L", 79), ("OpenRound", "L", 79), ("OpenCurly", "L", 79), ("walkIdentifier", "L", 79), ("walkString", "L", 79), ("walkCharacter", "L", 79), ("walkInteger", "L", 79), ("Or", "L", 79), ("And", "L", 79), ("Minus", "L", 79), ("CloseCurly", "L", 79), ("Dot", "L", 79), ("CloseRound", "L", 79), ("FatRightArrow", "L", 79), ("RightArrow", "L", 79)],
       ["ReadaheadTable", 32, ("AndExpression", "RSN", 27), ("Primary", "RSN", 28), ("Alternation", "RSN", 29), ("Secondary", "RSN", 30), ("Byte", "RSN", 31), ("OpenCurly", "RS", 32), ("walkString", "RSN", 69), ("walkSymbol", "RSN", 33), ("walkInteger", "RSN", 80), ("SemanticAction", "RSN", 88), ("walkCharacter", "RSN", 80), ("walkIdentifier", "RSN", 69), ("Expression", "RSN", 46), ("Concatenation", "RSN", 35), ("RepetitionOption", "RSN", 36), ("Name", "RSN", 79), ("OpenRound", "RS", 37), ("And", "L", 144), ("Minus", "L", 144), ("CloseCurly", "L", 144), ("Dot", "L", 144), ("CloseRound", "L", 144), ("FatRightArrow", "L", 144), ("RightArrow", "L", 144)],
       ["ReadaheadTable", 33, ("OpenSquare", "RS", 47), ("Star", "L", 87), ("QuestionMark", "L", 87), ("Plus", "L", 87), ("walkSymbol", "L", 87), ("OpenRound", "L", 87), ("OpenCurly", "L", 87), ("walkIdentifier", "L", 87), ("walkString", "L", 87), ("walkCharacter", "L", 87), ("walkInteger", "L", 87), ("Or", "L", 87), ("And", "L", 87), ("Minus", "L", 87), ("RightArrow", "L", 87), ("Dot", "L", 87), ("CloseCurly", "L", 87), ("CloseRound", "L", 87), ("FatRightArrow", "L", 87)],
       ["ReadaheadTable", 34, ("CloseCurly", "RS", 97)],
       ["ReadaheadTable", 35, ("Or", "RS", 48), ("And", "L", 81), ("Minus", "L", 81), ("CloseCurly", "L", 81), ("Dot", "L", 81), ("CloseRound", "L", 81), ("FatRightArrow", "L", 81), ("RightArrow", "L", 81)],
       ["ReadaheadTable", 36, ("Primary", "RSN", 28), ("walkString", "RSN", 69), ("Secondary", "RSN", 30), ("Byte", "RSN", 31), ("OpenCurly", "RS", 32), ("walkSymbol", "RSN", 33), ("walkInteger", "RSN", 80), ("SemanticAction", "RSN", 88), ("walkCharacter", "RSN", 80), ("walkIdentifier", "RSN", 69), ("RepetitionOption", "RSN", 49), ("Name", "RSN", 79), ("OpenRound", "RS", 37), ("Or", "L", 82), ("And", "L", 82), ("Minus", "L", 82), ("CloseCurly", "L", 82), ("Dot", "L", 82), ("CloseRound", "L", 82), ("FatRightArrow", "L", 82), ("RightArrow", "L", 82)],
       ["ReadaheadTable", 37, ("AndExpression", "RSN", 27), ("Primary", "RSN", 28), ("walkString", "RSN", 69), ("Secondary", "RSN", 30), ("Byte", "RSN", 31), ("OpenCurly", "RS", 32), ("Alternation", "RSN", 29), ("walkSymbol", "RSN", 33), ("walkInteger", "RSN", 80), ("SemanticAction", "RSN", 88), ("walkCharacter", "RSN", 80), ("walkIdentifier", "RSN", 69), ("Expression", "RSN", 50), ("Concatenation", "RSN", 35), ("OpenRound", "RS", 37), ("Name", "RSN", 79), ("RepetitionOption", "RSN", 36), ("And", "L", 144), ("Minus", "L", 144), ("CloseCurly", "L", 144), ("Dot", "L", 144), ("CloseRound", "L", 144), ("FatRightArrow", "L", 144), ("RightArrow", "L", 144)],
       ["ReadaheadTable", 38, ("Dot", "RS", 100)],
       ["ReadaheadTable", 39, ("FatRightArrow", "RS", 51), ("RightArrow", "L", 83), ("Dot", "L", 83)],
       ["ReadaheadTable", 40, ("walkString", "RSN", 69), ("Name", "RSN", 40), ("Dot", "RS", 101), ("walkIdentifier", "RSN", 69)],
       ["ReadaheadTable", 41, ("walkString", "RSN", 69), ("Name", "RSN", 41), ("Dot", "RS", 102), ("walkIdentifier", "RSN", 69)],
       ["ReadaheadTable", 42, ("AndExpression", "RSN", 103), ("Primary", "RSN", 28), ("walkString", "RSN", 69), ("Alternation", "RSN", 29), ("Byte", "RSN", 31), ("OpenCurly", "RS", 32), ("Secondary", "RSN", 30), ("walkSymbol", "RSN", 33), ("walkInteger", "RSN", 80), ("SemanticAction", "RSN", 88), ("walkCharacter", "RSN", 80), ("walkIdentifier", "RSN", 69), ("Concatenation", "RSN", 35), ("OpenRound", "RS", 37), ("Name", "RSN", 79), ("RepetitionOption", "RSN", 36), ("And", "L", 144), ("Minus", "L", 144), ("CloseCurly", "L", 144), ("Dot", "L", 144), ("CloseRound", "L", 144), ("FatRightArrow", "L", 144), ("RightArrow", "L", 144)],
       ["ReadaheadTable", 43, ("Primary", "RSN", 28), ("Alternation", "RSN", 104), ("walkString", "RSN", 69), ("Byte", "RSN", 31), ("OpenCurly", "RS", 32), ("Secondary", "RSN", 30), ("walkSymbol", "RSN", 33), ("walkInteger", "RSN", 80), ("SemanticAction", "RSN", 88), ("walkCharacter", "RSN", 80), ("walkIdentifier", "RSN", 69), ("Concatenation", "RSN", 35), ("RepetitionOption", "RSN", 36), ("Name", "RSN", 79), ("OpenRound", "RS", 37), ("And", "L", 144), ("Minus", "L", 144), ("CloseCurly", "L", 144), ("Dot", "L", 144), ("CloseRound", "L", 144), ("FatRightArrow", "L", 144), ("RightArrow", "L", 144)],
       ["ReadaheadTable", 44, ("Attribute", "RSN", 52), ("keep", "RSN", 95), ("noNode", "RSN", 95), ("noStack", "RSN", 95), ("CloseSquare", "RS", 105), ("read", "RSN", 95), ("look", "RSN", 95), ("stack", "RSN", 95), ("node", "RSN", 95), ("noKeep", "RSN", 95)],
       ["ReadaheadTable", 45, ("Byte", "RSN", 106), ("walkInteger", "RSN", 80), ("walkCharacter", "RSN", 80)],
       ["ReadaheadTable", 46, ("CloseCurly", "RS", 107)],
       ["ReadaheadTable", 47, ("walkString", "RSN", 69), ("walkSymbol", "RSN", 96), ("SemanticActionParameter", "RSN", 53), ("walkCharacter", "RSN", 80), ("walkIdentifier", "RSN", 69), ("CloseSquare", "RS", 108), ("Byte", "RSN", 96), ("Name", "RSN", 96), ("walkInteger", "RSN", 80)],
       ["ReadaheadTable", 48, ("Primary", "RSN", 28), ("walkString", "RSN", 69), ("Secondary", "RSN", 30), ("Byte", "RSN", 31), ("OpenCurly", "RS", 32), ("walkSymbol", "RSN", 33), ("walkInteger", "RSN", 80), ("SemanticAction", "RSN", 88), ("walkCharacter", "RSN", 80), ("walkIdentifier", "RSN", 69), ("Concatenation", "RSN", 54), ("RepetitionOption", "RSN", 36), ("Name", "RSN", 79), ("OpenRound", "RS", 37)],
       ["ReadaheadTable", 49, ("Primary", "RSN", 28), ("walkString", "RSN", 69), ("Secondary", "RSN", 30), ("Byte", "RSN", 31), ("OpenCurly", "RS", 32), ("walkSymbol", "RSN", 33), ("walkInteger", "RSN", 80), ("SemanticAction", "RSN", 88), ("walkCharacter", "RSN", 80), ("walkIdentifier", "RSN", 69), ("RepetitionOption", "RSN", 49), ("Name", "RSN", 79), ("OpenRound", "RS", 37), ("Or", "L", 98), ("And", "L", 98), ("Minus", "L", 98), ("CloseCurly", "L", 98), ("Dot", "L", 98), ("CloseRound", "L", 98), ("FatRightArrow", "L", 98), ("RightArrow", "L", 98)],
       ["ReadaheadTable", 50, ("CloseRound", "RS", 99)],
       ["ReadaheadTable", 51, ("Minus", "RS", 55), ("walkSymbol", "RSN", 33), ("walkString", "RSN", 69), ("Name", "RSN", 110), ("walkIdentifier", "RSN", 69), ("Plus", "RS", 56), ("TreeBuildingOptions", "RSN", 111), ("SemanticAction", "RSN", 112), ("walkInteger", "RSN", 113)],
       ["ReadaheadTable", 52, ("Attribute", "RSN", 52), ("keep", "RSN", 95), ("noNode", "RSN", 95), ("noStack", "RSN", 95), ("CloseSquare", "RS", 105), ("read", "RSN", 95), ("look", "RSN", 95), ("stack", "RSN", 95), ("node", "RSN", 95), ("noKeep", "RSN", 95)],
       ["ReadaheadTable", 53, ("walkString", "RSN", 69), ("walkSymbol", "RSN", 96), ("Name", "RSN", 96), ("walkIdentifier", "RSN", 69), ("Byte", "RSN", 96), ("walkCharacter", "RSN", 80), ("CloseSquare", "RS", 108), ("SemanticActionParameter", "RSN", 53), ("walkInteger", "RSN", 80)],
       ["ReadaheadTable", 54, ("Or", "RS", 48), ("And", "L", 109), ("Minus", "L", 109), ("CloseCurly", "L", 109), ("Dot", "L", 109), ("CloseRound", "L", 109), ("FatRightArrow", "L", 109), ("RightArrow", "L", 109)],
       ["ReadaheadTable", 55, ("walkInteger", "RSN", 114)],
       ["ReadaheadTable", 56, ("walkInteger", "RSN", 113)],
       ["ReadbackTable", 57, (("GrammarType", 2), "RSN", 129), (("Defaults", 175), "RSN", 57)],
       ["ReadbackTable", 58, (("Macro", 4), "RSN", 58), (("Production", 11), "RSN", 58), (("GrammarType", 2), "L", 142), (("Defaults", 175), "L", 142)],
       ["ReadbackTable", 59, (("RightPart", 22), "RSN", 59), (("LeftPart", 10), "L", 145)],
       ["ReadbackTable", 60, (("RepetitionOption", 49), "RSN", 60), (("RepetitionOption", 36), "RSN", 157)],
       ["ReadbackTable", 61, (("Attribute", 52), "RSN", 61), (("OpenSquare", 44), "RS", 116)],
       ["ReadbackTable", 62, (("SemanticActionParameter", 53), "RSN", 62), (("OpenSquare", 47), "RS", 87)],
       ["ReadbackTable", 63, (("Plus", 56), "RS", 170), (("FatRightArrow", 51), "L", 170)],
       ["ReadbackTable", 64, (("keywords", 5), "RS", 146), (("Name", 12), "RSN", 64)],
       ["ReadbackTable", 65, (("defaults", 13), "RS", 117), (("Name", 24), "RSN", 65)],
       ["ReadbackTable", 66, (("defaults", 25), "RS", 118), (("Name", 40), "RSN", 66)],
       ["ReadbackTable", 67, (("defaults", 26), "RS", 119), (("Name", 41), "RSN", 67)],
       ["ReadbackTable", 68, (("Concatenation", 54), "RSN", 115), (("Concatenation", 35), "RSN", 166)],
       ["ShiftbackTable", 69, 1, 126],
       ["ShiftbackTable", 70, 1, 57],
       ["ShiftbackTable", 71, 1, 133],
       ["ShiftbackTable", 72, 1, 58],
       ["ShiftbackTable", 73, 1, 143],
       ["ShiftbackTable", 74, 2, 133],
       ["ShiftbackTable", 75, 1, 121],
       ["ShiftbackTable", 76, 1, 125],
       ["ShiftbackTable", 77, 1, 131],
       ["ShiftbackTable", 78, 1, 135],
       ["ShiftbackTable", 79, 1, 138],
       ["ShiftbackTable", 80, 1, 139],
       ["ShiftbackTable", 81, 1, 137],
       ["ShiftbackTable", 82, 1, 122],
       ["ShiftbackTable", 83, 2, 140],
       ["ShiftbackTable", 84, 1, 59],
       ["ShiftbackTable", 85, 2, 64],
       ["ShiftbackTable", 86, 3, 147],
       ["ShiftbackTable", 87, 1, 148],
       ["ShiftbackTable", 88, 1, 149],
       ["ShiftbackTable", 89, 3, 150],
       ["ShiftbackTable", 90, 3, 151],
       ["ShiftbackTable", 91, 2, 65],
       ["ShiftbackTable", 92, 2, 153],
       ["ShiftbackTable", 93, 2, 154],
       ["ShiftbackTable", 94, 2, 155],
       ["ShiftbackTable", 95, 1, 136],
       ["ShiftbackTable", 96, 1, 128],
       ["ShiftbackTable", 97, 4, 156],
       ["ShiftbackTable", 98, 1, 60],
       ["ShiftbackTable", 99, 3, 138],
       ["ShiftbackTable", 100, 4, 158],
       ["ShiftbackTable", 101, 2, 66],
       ["ShiftbackTable", 102, 2, 67],
       ["ShiftbackTable", 103, 3, 161],
       ["ShiftbackTable", 104, 3, 162],
       ["ShiftbackTable", 105, 1, 61],
       ["ShiftbackTable", 106, 3, 164],
       ["ShiftbackTable", 107, 3, 165],
       ["ShiftbackTable", 108, 1, 62],
       ["ShiftbackTable", 109, 2, 68],
       ["ShiftbackTable", 110, 1, 167],
       ["ShiftbackTable", 111, 4, 168],
       ["ShiftbackTable", 112, 1, 169],
       ["ShiftbackTable", 113, 1, 63],
       ["ShiftbackTable", 114, 2, 171],
       ["ShiftbackTable", 115, 1, 68],
       ["ShiftbackTable", 116, 1, 163],
       ["ShiftbackTable", 117, 1, 152],
       ["ShiftbackTable", 118, 2, 159],
       ["ShiftbackTable", 119, 2, 160],
       ["ReduceTable", 120, "SemanticAction", (17, "RSN", 88), (18, "RSN", 88), (20, "RSN", 88), (32, "RSN", 88), (36, "RSN", 88), (37, "RSN", 88), (42, "RSN", 88), (43, "RSN", 88), (48, "RSN", 88), (49, "RSN", 88), (51, "RSN", 112)],
       ["ReduceTable", 121, "Expression", (17, "RSN", 34), (18, "RSN", 38), (20, "RSN", 39), (32, "RSN", 46), (37, "RSN", 50)],
       ["ReduceTable", 122, "Concatenation", (17, "RSN", 35), (18, "RSN", 35), (20, "RSN", 35), (32, "RSN", 35), (37, "RSN", 35), (42, "RSN", 35), (43, "RSN", 35), (48, "RSN", 54)],
       ["ReduceTable", 123, "LeftPart", (2, "RSN", 10), (4, "RSN", 10), (11, "RSN", 10), (175, "RSN", 10)],
       ["ReduceTable", 124, "Macro", (2, "RSN", 4), (4, "RSN", 4), (11, "RSN", 4), (175, "RSN", 4)],
       ["ReduceTable", 125, "RepetitionOption", (17, "RSN", 36), (18, "RSN", 36), (20, "RSN", 36), (32, "RSN", 36), (36, "RSN", 49), (37, "RSN", 36), (42, "RSN", 36), (43, "RSN", 36), (48, "RSN", 36), (49, "RSN", 49)],
       ["ReduceTable", 126, "Name", (2, "RSN", 8), (4, "RSN", 8), (5, "RSN", 12), (7, "RSN", 16), (9, "RSN", 19), (11, "RSN", 8), (12, "RSN", 12), (13, "RSN", 24), (17, "RSN", 79), (18, "RSN", 79), (20, "RSN", 79), (175, "RSN", 8), (24, "RSN", 24), (25, "RSN", 40), (26, "RSN", 41), (32, "RSN", 79), (36, "RSN", 79), (37, "RSN", 79), (40, "RSN", 40), (41, "RSN", 41), (42, "RSN", 79), (43, "RSN", 79), (47, "RSN", 96), (48, "RSN", 79), (49, "RSN", 79), (51, "RSN", 110), (53, "RSN", 96)],
       ["ReduceTable", 127, "Defaults", (2, "RSN", 175), (175, "RSN", 175)],
       ["ReduceTable", 128, "SemanticActionParameter", (47, "RSN", 53), (53, "RSN", 53)],
       ["ReduceTable", 129, "Grammar", (1, "RSN", 177)],
       ["ReduceTable", 130, "TreeBuildingOptions", (51, "RSN", 111)],
       ["ReduceTable", 131, "AndExpression", (17, "RSN", 27), (18, "RSN", 27), (20, "RSN", 27), (32, "RSN", 27), (37, "RSN", 27), (42, "RSN", 103)],
       ["ReduceTable", 132, "Production", (2, "RSN", 11), (4, "RSN", 11), (11, "RSN", 11), (175, "RSN", 11)],
       ["ReduceTable", 133, "GrammarType", (1, "RSN", 2)],
       ["ReduceTable", 134, "Rules", (2, "RSN", 70), (175, "RSN", 70)],
       ["ReduceTable", 135, "Primary", (17, "RSN", 28), (18, "RSN", 28), (20, "RSN", 28), (32, "RSN", 28), (36, "RSN", 28), (37, "RSN", 28), (42, "RSN", 28), (43, "RSN", 28), (48, "RSN", 28), (49, "RSN", 28)],
       ["ReduceTable", 136, "Attribute", (44, "RSN", 52), (52, "RSN", 52)],
       ["ReduceTable", 137, "Alternation", (17, "RSN", 29), (18, "RSN", 29), (20, "RSN", 29), (32, "RSN", 29), (37, "RSN", 29), (42, "RSN", 29), (43, "RSN", 104)],
       ["ReduceTable", 138, "Secondary", (17, "RSN", 30), (18, "RSN", 30), (20, "RSN", 30), (32, "RSN", 30), (36, "RSN", 30), (37, "RSN", 30), (42, "RSN", 30), (43, "RSN", 30), (48, "RSN", 30), (49, "RSN", 30)],
       ["ReduceTable", 139, "Byte", (17, "RSN", 31), (18, "RSN", 31), (20, "RSN", 31), (32, "RSN", 31), (36, "RSN", 31), (37, "RSN", 31), (42, "RSN", 31), (43, "RSN", 31), (45, "RSN", 106), (47, "RSN", 96), (48, "RSN", 31), (49, "RSN", 31), (53, "RSN", 96)],
       ["ReduceTable", 140, "RightPart", (10, "RSN", 22), (22, "RSN", 22)],
       ["ReduceTable", 141, "RightParts", (10, "RSN", 21)],
       ["SemanticTable", 142, "buildTree", ["walkGrammar"], 134],
       ["SemanticTable", 143, "buildTree", ["walkLeftPart"], 123],
       ["SemanticTable", 144, "buildTree", ["walkEpsilon"], 137],
       ["SemanticTable", 145, "buildTree", ["walkOr"], 141],
       ["SemanticTable", 146, "buildTree", ["walkKeywords"], 127],
       ["SemanticTable", 147, "buildTree", ["walkOptimize"], 127],
       ["SemanticTable", 148, "buildTree", ["walkSemanticAction"], 120],
       ["SemanticTable", 149, "buildTree", ["walkNonTreeBuildingSemanticAction"], 135],
       ["SemanticTable", 150, "buildTree", ["walkOutput"], 127],
       ["SemanticTable", 151, "buildTree", ["walkProduction"], 132],
       ["SemanticTable", 152, "buildTree", ["walkAttributeDefaults"], 127],
       ["SemanticTable", 153, "buildTree", ["walkQuestionMark"], 125],
       ["SemanticTable", 154, "buildTree", ["walkStar"], 125],
       ["SemanticTable", 155, "buildTree", ["walkPlus"], 125],
       ["SemanticTable", 156, "buildTree", ["walkLeftPartWithLookahead"], 123],
       ["SemanticTable", 157, "buildTree", ["walkConcatenation"], 122],
       ["SemanticTable", 158, "buildTree", ["walkMacro"], 124],
       ["SemanticTable", 159, "buildTree", ["walkAttributeTerminalDefaults"], 127],
       ["SemanticTable", 160, "buildTree", ["walkAttributeNonterminalDefaults"], 127],
       ["SemanticTable", 161, "buildTree", ["walkMinus"], 121],
       ["SemanticTable", 162, "buildTree", ["walkAnd"], 131],
       ["SemanticTable", 163, "buildTree", ["walkAttributes"], 135],
       ["SemanticTable", 164, "buildTree", ["walkDotDot"], 138],
       ["SemanticTable", 165, "buildTree", ["walkLook"], 138],
       ["SemanticTable", 166, "buildTree", ["walkOr"], 137],
       ["SemanticTable", 167, "buildTree", ["walkBuildTreeOrTokenFromName"], 130],
       ["SemanticTable", 168, "buildTree", ["walkConcatenation"], 140],
       ["SemanticTable", 169, "buildTree", ["walkTreeBuildingSemanticAction"], 130],
       ["SemanticTable", 170, "buildTree", ["walkBuildTreeFromLeftIndex"], 130],
       ["SemanticTable", 171, "buildTree", ["walkBuildTreeFromRightIndex"], 130],
       ["SemanticTable", 172, "processTypeNow", ["scanner"], 71],
       ["SemanticTable", 173, "processTypeNow", ["superScanner"], 71],
       ["SemanticTable", 174, "processTypeNow", ["parser"], 71],
       ["SemanticTable", 175, "processAndDiscardDefaultsNow", [], 23],
       ["SemanticTable", 176, "processTypeNow", ["superScanner"], 74],
       ["AcceptTable", 177]]
}
