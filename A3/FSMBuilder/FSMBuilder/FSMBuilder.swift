//
//  FSMBuilder.swift
//  FSMBuilder
//
//  Created by Wilf Lalonde on 2023-01-24.
//

import Foundation

typealias treeClosure = (VirtualTree) -> Any //Ultimately FSM

public final class FSMBuilder : Translator {
    
    var parser: Parser?
    var tree: VirtualTree? = nil
    var fsmMap: Dictionary<String,Any> = [:] //Ultimately FSM
    
    init() {
        parser = Parser(sponsor: self, parserTables: parserTables, scannerTables: scannerTables)
    }
    
    func process (_ text: String) -> Void {
        if let tree = parser!.parse(text) as? Tree {
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
        case "walkbuildTreeOrTokenFromName":
            return walkbuildTreeOrTokenFromName (tree)
        case "walkbuildTreeFromRightIndex":
            return walkbuildTreeFromRightIndex (tree)
        case "walkbuildTreeFromLeftIndex":
            return walkbuildTreeFromLeftIndex (tree)
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
        default:
            error ("Attempt to perform unknown walkTree routine \(action)")
            return 0
        }
    }
    
  public func canPerformAction(_ action: String) -> Bool {
      if (action == "processTypeNow") {return true;}
      return false
    }
          
  public func performAction(_ action :String, _ parameters:[Any]) -> Void {
          if (action == "processTypeNow") {
              processTypeNow (parameters)
          }
  }
    
    static public func example1 () -> String {//Returns a string to please ContentView
        let grammar = Grammar  ()
        Grammar.activeGrammar = grammar
        // change the type to "parser" to use the parserFSMs file
        grammar.type = "scanner"
        
        let fileName = grammar.type == "scanner" ? "scannerFSMs" : "parserFSMs"
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
        
        let builder = FSMBuilder ();
        let text = fileContent
        let testText = """
        parser
                fsm17 = ($a*) - (($a $a)*); //Should recognize only an odd number of a's (you took away the even ones).
                fsm18 = ($a*) & (($a $a)*); //Should recognize only an even number of a's.
                complex2 = (($a $a)* | $b $c | $d) - ($a* | $b $c | $g); //Should recognize d.
        """
        builder.process (text)
        
        print ("Finished building \(grammar.type) FSMs")
        builder.printOn(fsmMap: builder.fsmMap)
        
        return "Done"
    }
    
    // tells you the kind of fsm you're building
    func processTypeNow (_ parameters:[Any]) -> Void {
          //The child will be a walkString with "scanner" or "parser"
        let type = parameters [0] as? String;
        //Tell the grammar what type it is ...
    }
      
    func walkList (_ tree: VirtualTree) -> Any {
        let treeList = (tree as? Tree)!
        var index = 0;
        while (index < treeList.children.count) {
            let child0 = treeList.child(index)
            let child1 = treeList.child(index+1)

            let name = (child0 as? Token)!.symbol
            let fsm = walkTree (child1)

            fsmMap [name] = fsm
            Grammar.activeGrammar!.addMacro (name, fsm)
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
    
    // Helper function to extract the numeric part from FSM name
    func extractNumber(from string: String) -> Int {
        // Use a regular expression to find the numeric part of the string
        if let match = string.range(of: "\\d+", options: .regularExpression) {
            let numberString = string[match]
            return Int(numberString) ?? 0 // Default to 0 if no number is found
        }
        return 0
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
        let child = tree.child(0)
        let fsm = walkTree(child) as? FiniteStateMachine
        return fsm!.plus()
    }
    
    func walkQuestionMark (_ tree : VirtualTree) -> Any {
        guard let tree = tree as? Tree else {
            print("Error: Expected tree to be of type Tree, but it's not.")
            return 0
        }
        let child = tree.child(0)
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
        
        guard let fsm1 = walkTree(tree.child(0)) as? FiniteStateMachine else {
            print("Error: fsm1 in walkAnd is not an FSM")
            return 0
        }
        guard let fsm2 = walkTree(tree.child(1)) as? FiniteStateMachine else {
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
        
        guard let fsm1 = walkTree(tree.child(0)) as? FiniteStateMachine else {
            print("Error: fsm1 in walkMinus is not an FSM")
            return 0
        }
        guard let fsm2 = walkTree(tree.child(1)) as? FiniteStateMachine else {
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
        return tree.child(0)
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
        let fsmToken = tree as! Token
        
        // Retrieve the FSM to copy
        guard let fsm = fsmMap[fsmToken.symbol] as? FiniteStateMachine else {
            print("Error: FSM named \(fsmToken.symbol) not found.")
            return 0
        }
        
        return FiniteStateMachine.forIdentifier(fsm)
    }
    
    func walkAttributes (_ tree : VirtualTree) -> Any {
        guard let tree = tree as? Tree else {
            print("Error: Expected tree to be of type Tree, but it's not.")
            return 0
        }
        
        // build fsm from first child, other children will be attributes
        let child0 = tree.child(0)
        let fsm = walkTree(child0)
        
        guard let finiteStateMachine = fsm as? FiniteStateMachine else {
            print("Error: The FSM returned by walkTree is not of type FiniteStateMachine")
            return 0
        }
        
        // get attributes
        var attributes: [String] = []
        for index in 1..<tree.children.count {
            if let attributeToken = tree.child(index) as? Token {
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
        
        let child0 = tree.child(0)
        let symbol = (child0 as? Token)!.symbol
        let action = Grammar.activeGrammar?.type == "scanner" ? "#buildToken" : "#buildTree"
        return FiniteStateMachine.forAction([symbol], isRootBuilding: true, actionName: action)
    }
    
    func walkbuildTreeFromLeftIndex(_ tree: VirtualTree) -> Any {
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
        let child0 = tree.child(0)
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
        let child0 = tree.child(0)
        return walkSemanticAction(child0, isRootBuilding: true)
    }
    
    func walkNonTreeBuildingSemanticAction (_ tree : VirtualTree) -> Any {
        guard let tree = tree as? Tree else {
            print("Error: Expected tree to be of type Tree.")
            return 0
        }
        let child0 = tree.child(0)
        return walkSemanticAction(child0, isRootBuilding: false)
    }
    
    func walkSemanticAction (_ tree: VirtualTree, isRootBuilding: Bool) -> Any {
        guard let tree = tree as? Tree else {
            print("Error: Expected tree to be of type Tree.")
            return 0
        }

        // Extract the action from the first child (assuming it's a token)
        let actionToken = tree.child(0) as! Token
        let actionSymbol = "#" + actionToken.symbol

        // Extract parameters from the remaining children
        var parameters: [Any] = []
        for i in 1..<tree.children.count {
            if let token = tree.child(i) as? Token {
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
        let child0 = tree.child(0)
        let fsm = walkTree(child0)
        
        guard let fsmCopy = fsm as? FiniteStateMachine else {
            print("Error: The FSM returned by walkTree is not of type FiniteStateMachine")
            return 0
        }
        
        // need to override attributes to "L"
        fsmCopy.override(["look"])
        return fsmCopy
    }
        
var scannerTables: Array<Any> = [
    ["ScannerReadaheadTable", 1, ("'", "R", 9), ("]", "RK", 36), ("/", "R", 10), ("{", "RK", 37), ("}", "RK", 38), ("\"", "R", 11), ("$", "R", 12), ([256], "L", 21), ("?", "RK", 32), ("ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz", "RK", 6), ("(", "RK", 23), (")", "RK", 24), ("*", "RK", 25), ("+", "RK", 26), ("-", "RK", 2), ("&", "RK", 22), (".", "RK", 3), ([9,10,12,13,32], "R", 7), ("0123456789", "RK", 4), (";", "RK", 30), ("=", "RK", 5), ("[", "RK", 34), ("#", "R", 8), ("|", "RK", 35)],
    ["ScannerReadaheadTable", 2, ([9,10,12,13,32,96,147,148,256], "L", 27), ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789!,+-/\\*~=@%&?|<[]{}()^;#:.$'\"", "L", 27), (">", "RK", 39)],
    ["ScannerReadaheadTable", 3, ([9,10,12,13,32,96,147,148,256], "L", 28), ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789!,+-/\\*~=@%&?|<>[]{}()^;#:$'\"", "L", 28), (".", "RK", 40)],
    ["ScannerReadaheadTable", 4, ([9,10,12,13,32,96,147,148,256], "L", 29), ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_!,+-/\\*~=@%&?|<>[]{}()^;#:.$'\"", "L", 29), ("0123456789", "RK", 4)],
    ["ScannerReadaheadTable", 5, ([9,10,12,13,32,96,147,148,256], "L", 31), ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789!,+-/\\*~=@%&?|<[]{}()^;#:.$'\"", "L", 31), (">", "RK", 41)],
    ["ScannerReadaheadTable", 6, ([9,10,12,13,32,96,147,148,256], "L", 33), ("!,+-/\\*~=@%&?|<>[]{}()^;#.$'\"", "L", 33), ("0123456789:ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz", "RK", 6)],
    ["ScannerReadaheadTable", 7, ([96,147,148,256], "L", 1), ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789!,+-/\\*~=@%&?|<>[]{}()^;#:.$'\"", "L", 1), ([9,10,12,13,32], "R", 7)],
    ["ScannerReadaheadTable", 8, ("\"", "R", 14), ("'", "R", 15), ("ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz", "RK", 13)],
    ["ScannerReadaheadTable", 9, ([256], "LK", 43), ("'", "R", 16), ([9,10,12,13,32,96,147,148], "RK", 9), ("!\"#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_abcdefghijklmnopqrstuvwxyz{|}~", "RK", 9)],
    ["ScannerReadaheadTable", 10, ([9,10,12,13,32], "L", 45), ([96,147,148,256], "LK", 45), ("=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[]^_\\abcdefghijklmnopqrstuvwxyz{|}~!\"#$%&'()*+,-.0123456789:;<", "LK", 45), ("/", "R", 17)],
    ["ScannerReadaheadTable", 11, ([256], "LK", 46), ("\"", "R", 18), ([9,10,12,13,32,96,147,148], "RK", 11), ("!#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_abcdefghijklmnopqrstuvwxyz{|}~", "RK", 11)],
    ["ScannerReadaheadTable", 12, ([9,10,12,13,32,96,147,148], "RK", 47), ("!\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_abcdefghijklmnopqrstuvwxyz{|}~", "RK", 47)],
    ["ScannerReadaheadTable", 13, ([9,10,12,13,32,96,147,148,256], "L", 42), ("!,+-/\\*~=@%&?|<>[]{}()^;#.$'\"", "L", 42), ("0123456789:ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz", "RK", 13)],
    ["ScannerReadaheadTable", 14, ([256], "LK", 48), ("\"", "R", 19), ([9,10,12,13,32,96,147,148], "RK", 14), ("!#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_abcdefghijklmnopqrstuvwxyz{|}~", "RK", 14)],
    ["ScannerReadaheadTable", 15, ([256], "LK", 49), ("'", "R", 20), ([9,10,12,13,32,96,147,148], "RK", 15), ("!\"#$%&()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_abcdefghijklmnopqrstuvwxyz{|}~", "RK", 15)],
    ["ScannerReadaheadTable", 16, ([9,10,12,13,32,96,147,148,256], "L", 44), ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789!,+-/\\*~=@%&?|<>[]{}()^;#:.$\"", "L", 44), ("'", "RK", 9)],
    ["ScannerReadaheadTable", 17, ([9,32,96,147,148], "R", 17), ("=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_abcdefghijklmnopqrstuvwxyz{|}~!\"#$%&'()*+,-./0123456789:;<", "R", 17), ([256], "LK", 1), ([10,12,13], "R", 1)],
    ["ScannerReadaheadTable", 18, ([9,10,12,13,32,96,147,148,256], "L", 44), ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789!,+-/\\*~=@%&?|<>[]{}()^;#:.$'", "L", 44), ("\"", "RK", 11)],
    ["ScannerReadaheadTable", 19, ([9,10,12,13,32,96,147,148,256], "L", 42), ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789!,+-/\\*~=@%&?|<>[]{}()^;#:.$'", "L", 42), ("\"", "RK", 14)],
    ["ScannerReadaheadTable", 20, ([9,10,12,13,32,96,147,148,256], "L", 42), ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789!,+-/\\*~=@%&?|<>[]{}()^;#:.$\"", "L", 42), ("'", "RK", 15)],
    ["SemanticTable", 21, "buildToken", ["EndOfFile"], 1],
    ["SemanticTable", 22, "buildToken", ["&"], 1],
    ["SemanticTable", 23, "buildToken", ["("], 1],
    ["SemanticTable", 24, "buildToken", [")"], 1],
    ["SemanticTable", 25, "buildToken", ["*"], 1],
    ["SemanticTable", 26, "buildToken", ["+"], 1],
    ["SemanticTable", 27, "buildToken", ["-"], 1],
    ["SemanticTable", 28, "buildToken", ["."], 1],
    ["SemanticTable", 29, "buildToken", ["walkInteger"], 1],
    ["SemanticTable", 30, "buildToken", [";"], 1],
    ["SemanticTable", 31, "buildToken", ["="], 1],
    ["SemanticTable", 32, "buildToken", ["?"], 1],
    ["SemanticTable", 33, "buildToken", ["walkIdentifier"], 1],
    ["SemanticTable", 34, "buildToken", ["["], 1],
    ["SemanticTable", 35, "buildToken", ["|"], 1],
    ["SemanticTable", 36, "buildToken", ["]"], 1],
    ["SemanticTable", 37, "buildToken", ["{"], 1],
    ["SemanticTable", 38, "buildToken", ["}"], 1],
    ["SemanticTable", 39, "buildToken", ["->"], 1],
    ["SemanticTable", 40, "buildToken", [".."], 1],
    ["SemanticTable", 41, "buildToken", ["=>"], 1],
    ["SemanticTable", 42, "buildToken", ["walkSymbol"], 1],
    ["SemanticTable", 43, "syntaxError", ["missing end quote for single quoted string"], 44],
    ["SemanticTable", 44, "buildToken", ["walkString"], 1],
    ["SemanticTable", 45, "syntaxError", ["// is a comment, / alone is not valid"], 1],
    ["SemanticTable", 46, "syntaxError", ["missing end quote for double quoted string"], 44],
    ["SemanticTable", 47, "buildToken", ["walkCharacter"], 1],
    ["SemanticTable", 48, "syntaxError", ["missing end quote for double quoted string"], 42],
    ["SemanticTable", 49, "syntaxError", ["missing end quote for single quoted string"], 42]]

var parserTables: Array<Any> =
    [
       ["keywords", "stack", "noStack", "read", "look", "node", "noNode", "keep", "noKeep", "parser", "scanner"],
       ["ReadaheadTable", 1, ("parser", "RS", 103), ("scanner", "RS", 104), ("GrammarType", "RSN", 2), ("ListOfFiniteStateMachines", "RSN", 105)],
       ["ReadaheadTable", 2, ("walkString", "RSN", 39), ("Name", "RSN", 3), ("walkIdentifier", "RSN", 39), ("EndOfFile", "L", 31)],
       ["ReadaheadTable", 3, ("=", "RS", 4)],
       ["ReadaheadTable", 4, ("Primary", "RSN", 5), ("walkString", "RSN", 39), ("Alternation", "RSN", 6), ("Byte", "RSN", 7), ("FiniteStateMachine", "RSN", 8), ("walkSymbol", "RSN", 9), ("walkInteger", "RSN", 43), ("SemanticAction", "RSN", 48), ("(", "RS", 10), ("walkCharacter", "RSN", 43), ("{", "RS", 11), ("walkIdentifier", "RSN", 39), ("Expression", "RSN", 12), ("Concatenation", "RSN", 13), ("RepetitionOption", "RSN", 14), ("Name", "RSN", 42), (")", "L", 86), ("}", "L", 86), ("=>", "L", 86), (";", "L", 86)],
       ["ReadaheadTable", 5, ("[", "RS", 15), ("*", "L", 40), ("?", "L", 40), ("+", "L", 40), ("&", "L", 40), ("-", "L", 40), ("(", "L", 40), ("{", "L", 40), ("walkIdentifier", "L", 40), ("walkString", "L", 40), ("walkSymbol", "L", 40), ("walkCharacter", "L", 40), ("walkInteger", "L", 40), ("|", "L", 40), (")", "L", 40), ("}", "L", 40), ("=>", "L", 40), (";", "L", 40)],
       ["ReadaheadTable", 6, ("=>", "RS", 16), (";", "L", 41)],
       ["ReadaheadTable", 7, ("..", "RS", 17), ("[", "L", 42), ("*", "L", 42), ("?", "L", 42), ("+", "L", 42), ("&", "L", 42), ("-", "L", 42), ("(", "L", 42), ("{", "L", 42), ("walkIdentifier", "L", 42), ("walkString", "L", 42), ("walkSymbol", "L", 42), ("walkCharacter", "L", 42), ("walkInteger", "L", 42), ("|", "L", 42), (")", "L", 42), ("}", "L", 42), ("=>", "L", 42), (";", "L", 42)],
       ["ReadaheadTable", 8, (";", "RS", 18)],
       ["ReadaheadTable", 9, ("[", "RS", 19), ("*", "L", 47), ("?", "L", 47), ("+", "L", 47), ("&", "L", 47), ("-", "L", 47), ("(", "L", 47), ("{", "L", 47), ("walkIdentifier", "L", 47), ("walkString", "L", 47), ("walkSymbol", "L", 47), ("walkCharacter", "L", 47), ("walkInteger", "L", 47), (";", "L", 47), ("|", "L", 47), (")", "L", 47), ("}", "L", 47), ("=>", "L", 47)],
       ["ReadaheadTable", 10, ("Primary", "RSN", 5), ("walkString", "RSN", 39), ("Alternation", "RSN", 20), ("Byte", "RSN", 7), ("walkSymbol", "RSN", 9), ("walkInteger", "RSN", 43), ("SemanticAction", "RSN", 48), ("(", "RS", 10), ("walkCharacter", "RSN", 43), ("{", "RS", 11), ("walkIdentifier", "RSN", 39), ("Expression", "RSN", 12), ("Concatenation", "RSN", 13), ("RepetitionOption", "RSN", 14), ("Name", "RSN", 42), (")", "L", 86), ("}", "L", 86), ("=>", "L", 86), (";", "L", 86)],
       ["ReadaheadTable", 11, ("Primary", "RSN", 5), ("Alternation", "RSN", 21), ("walkString", "RSN", 39), ("Byte", "RSN", 7), ("walkSymbol", "RSN", 9), ("walkInteger", "RSN", 43), ("(", "RS", 10), ("SemanticAction", "RSN", 48), ("walkCharacter", "RSN", 43), ("{", "RS", 11), ("walkIdentifier", "RSN", 39), ("Expression", "RSN", 12), ("Concatenation", "RSN", 13), ("RepetitionOption", "RSN", 14), ("Name", "RSN", 42), (")", "L", 86), ("}", "L", 86), ("=>", "L", 86), (";", "L", 86)],
       ["ReadaheadTable", 12, ("*", "RS", 52), ("?", "RS", 53), ("+", "RS", 54), ("&", "RS", 22), ("-", "RS", 23), ("(", "L", 44), ("{", "L", 44), ("walkIdentifier", "L", 44), ("walkString", "L", 44), ("walkSymbol", "L", 44), ("walkCharacter", "L", 44), ("walkInteger", "L", 44), ("|", "L", 44), (")", "L", 44), ("}", "L", 44), ("=>", "L", 44), (";", "L", 44)],
       ["ReadaheadTable", 13, ("|", "RS", 24), (")", "L", 45), ("}", "L", 45), ("=>", "L", 45), (";", "L", 45)],
       ["ReadaheadTable", 14, ("Primary", "RSN", 5), ("walkString", "RSN", 39), ("Byte", "RSN", 7), ("walkSymbol", "RSN", 9), ("walkInteger", "RSN", 43), ("SemanticAction", "RSN", 48), ("(", "RS", 10), ("walkCharacter", "RSN", 43), ("{", "RS", 11), ("walkIdentifier", "RSN", 39), ("Expression", "RSN", 12), ("RepetitionOption", "RSN", 25), ("Name", "RSN", 42), ("|", "L", 46), (")", "L", 46), ("}", "L", 46), ("=>", "L", 46), (";", "L", 46)],
       ["ReadaheadTable", 15, ("Attribute", "RSN", 26), ("keep", "RSN", 49), ("noNode", "RSN", 49), ("noStack", "RSN", 49), ("]", "RS", 56), ("read", "RSN", 49), ("look", "RSN", 49), ("stack", "RSN", 49), ("node", "RSN", 49), ("noKeep", "RSN", 49)],
       ["ReadaheadTable", 16, ("walkString", "RSN", 39), ("-", "RS", 27), ("walkSymbol", "RSN", 9), ("Name", "RSN", 57), ("walkIdentifier", "RSN", 39), ("TreeBuildingOptions", "RSN", 58), ("+", "RS", 28), ("walkInteger", "RSN", 59), ("SemanticAction", "RSN", 60)],
       ["ReadaheadTable", 17, ("Byte", "RSN", 61), ("walkInteger", "RSN", 43), ("walkCharacter", "RSN", 43)],
       ["ReadaheadTable", 18, ("walkString", "RSN", 39), ("Name", "RSN", 3), ("walkIdentifier", "RSN", 39), ("EndOfFile", "L", 31)],
       ["ReadaheadTable", 19, ("walkString", "RSN", 39), ("walkSymbol", "RSN", 50), ("Name", "RSN", 50), ("walkIdentifier", "RSN", 39), ("Byte", "RSN", 50), ("walkCharacter", "RSN", 43), ("]", "RS", 62), ("SemanticActionParameter", "RSN", 29), ("walkInteger", "RSN", 43)],
       ["ReadaheadTable", 20, (")", "RS", 51)],
       ["ReadaheadTable", 21, ("}", "RS", 63)],
       ["ReadaheadTable", 22, ("walkSymbol", "RSN", 9), ("walkString", "RSN", 39), ("Primary", "RSN", 5), ("Expression", "RSN", 64), ("Name", "RSN", 42), ("Byte", "RSN", 7), ("walkIdentifier", "RSN", 39), ("{", "RS", 11), ("walkCharacter", "RSN", 43), ("SemanticAction", "RSN", 48), ("walkInteger", "RSN", 43), ("(", "RS", 10)],
       ["ReadaheadTable", 23, ("walkSymbol", "RSN", 9), ("walkString", "RSN", 39), ("Primary", "RSN", 5), ("Expression", "RSN", 65), ("Name", "RSN", 42), ("Byte", "RSN", 7), ("walkIdentifier", "RSN", 39), ("{", "RS", 11), ("walkCharacter", "RSN", 43), ("SemanticAction", "RSN", 48), ("walkInteger", "RSN", 43), ("(", "RS", 10)],
       ["ReadaheadTable", 24, ("Primary", "RSN", 5), ("walkString", "RSN", 39), ("Byte", "RSN", 7), ("walkSymbol", "RSN", 9), ("walkInteger", "RSN", 43), ("SemanticAction", "RSN", 48), ("(", "RS", 10), ("walkCharacter", "RSN", 43), ("{", "RS", 11), ("walkIdentifier", "RSN", 39), ("Expression", "RSN", 12), ("Concatenation", "RSN", 30), ("RepetitionOption", "RSN", 14), ("Name", "RSN", 42)],
       ["ReadaheadTable", 25, ("Primary", "RSN", 5), ("walkString", "RSN", 39), ("Byte", "RSN", 7), ("walkSymbol", "RSN", 9), ("walkInteger", "RSN", 43), ("SemanticAction", "RSN", 48), ("(", "RS", 10), ("walkCharacter", "RSN", 43), ("{", "RS", 11), ("walkIdentifier", "RSN", 39), ("Expression", "RSN", 12), ("RepetitionOption", "RSN", 25), ("Name", "RSN", 42), ("|", "L", 55), (")", "L", 55), ("}", "L", 55), ("=>", "L", 55), (";", "L", 55)],
       ["ReadaheadTable", 26, ("Attribute", "RSN", 26), ("keep", "RSN", 49), ("noNode", "RSN", 49), ("noStack", "RSN", 49), ("]", "RS", 56), ("read", "RSN", 49), ("look", "RSN", 49), ("stack", "RSN", 49), ("node", "RSN", 49), ("noKeep", "RSN", 49)],
       ["ReadaheadTable", 27, ("walkInteger", "RSN", 67)],
       ["ReadaheadTable", 28, ("walkInteger", "RSN", 59)],
       ["ReadaheadTable", 29, ("walkString", "RSN", 39), ("walkSymbol", "RSN", 50), ("SemanticActionParameter", "RSN", 29), ("Byte", "RSN", 50), ("]", "RS", 62), ("Name", "RSN", 50), ("walkIdentifier", "RSN", 39), ("walkCharacter", "RSN", 43), ("walkInteger", "RSN", 43)],
       ["ReadaheadTable", 30, ("|", "RS", 24), (")", "L", 66), ("}", "L", 66), ("=>", "L", 66), (";", "L", 66)],
       ["ReadbackTable", 31, (("GrammarType", 2), "RSN", 85), ((";", 18), "RS", 68)],
       ["ReadbackTable", 32, (("RepetitionOption", 25), "RSN", 32), (("RepetitionOption", 14), "RSN", 92)],
       ["ReadbackTable", 33, (("[", 15), "RS", 70), (("Attribute", 26), "RSN", 33)],
       ["ReadbackTable", 34, (("+", 28), "RS", 95), (("=>", 16), "L", 95)],
       ["ReadbackTable", 35, (("[", 19), "RS", 47), (("SemanticActionParameter", 29), "RSN", 35)],
       ["ReadbackTable", 36, (("Concatenation", 30), "RSN", 69), (("Concatenation", 13), "RSN", 101)],
       ["ReadbackTable", 37, (("GrammarType", 2), "RSN", 85), ((";", 18), "RS", 68)],
       ["ShiftbackTable", 38, 1, 79],
       ["ShiftbackTable", 39, 1, 75],
       ["ShiftbackTable", 40, 1, 71],
       ["ShiftbackTable", 41, 1, 83],
       ["ShiftbackTable", 42, 1, 80],
       ["ShiftbackTable", 43, 1, 82],
       ["ShiftbackTable", 44, 1, 74],
       ["ShiftbackTable", 45, 1, 81],
       ["ShiftbackTable", 46, 1, 72],
       ["ShiftbackTable", 47, 1, 87],
       ["ShiftbackTable", 48, 1, 88],
       ["ShiftbackTable", 49, 1, 77],
       ["ShiftbackTable", 50, 1, 76],
       ["ShiftbackTable", 51, 3, 80],
       ["ShiftbackTable", 52, 2, 89],
       ["ShiftbackTable", 53, 2, 90],
       ["ShiftbackTable", 54, 2, 91],
       ["ShiftbackTable", 55, 1, 32],
       ["ShiftbackTable", 56, 1, 33],
       ["ShiftbackTable", 57, 1, 94],
       ["ShiftbackTable", 58, 3, 92],
       ["ShiftbackTable", 59, 1, 34],
       ["ShiftbackTable", 60, 1, 96],
       ["ShiftbackTable", 61, 3, 97],
       ["ShiftbackTable", 62, 1, 35],
       ["ShiftbackTable", 63, 3, 98],
       ["ShiftbackTable", 64, 3, 99],
       ["ShiftbackTable", 65, 3, 100],
       ["ShiftbackTable", 66, 2, 36],
       ["ShiftbackTable", 67, 2, 102],
       ["ShiftbackTable", 68, 3, 37],
       ["ShiftbackTable", 69, 1, 36],
       ["ShiftbackTable", 70, 1, 93],
       ["ReduceTable", 71, "Expression", (4, "RSN", 12), (10, "RSN", 12), (11, "RSN", 12), (14, "RSN", 12), (22, "RSN", 64), (23, "RSN", 65), (24, "RSN", 12), (25, "RSN", 12)],
       ["ReduceTable", 72, "Concatenation", (4, "RSN", 13), (10, "RSN", 13), (11, "RSN", 13), (24, "RSN", 30)],
       ["ReduceTable", 73, "ListOfFiniteStateMachines", (1, "RSN", 105)],
       ["ReduceTable", 74, "RepetitionOption", (4, "RSN", 14), (10, "RSN", 14), (11, "RSN", 14), (14, "RSN", 25), (24, "RSN", 14), (25, "RSN", 25)],
       ["ReduceTable", 75, "Name", (2, "RSN", 3), (4, "RSN", 42), (10, "RSN", 42), (11, "RSN", 42), (14, "RSN", 42), (16, "RSN", 57), (18, "RSN", 3), (19, "RSN", 50), (22, "RSN", 42), (23, "RSN", 42), (24, "RSN", 42), (25, "RSN", 42), (29, "RSN", 50)],
       ["ReduceTable", 76, "SemanticActionParameter", (19, "RSN", 29), (29, "RSN", 29)],
       ["ReduceTable", 77, "Attribute", (15, "RSN", 26), (26, "RSN", 26)],
       ["ReduceTable", 78, "TreeBuildingOptions", (16, "RSN", 58)],
       ["ReduceTable", 79, "GrammarType", (1, "RSN", 2)],
       ["ReduceTable", 80, "Primary", (4, "RSN", 5), (10, "RSN", 5), (11, "RSN", 5), (14, "RSN", 5), (22, "RSN", 5), (23, "RSN", 5), (24, "RSN", 5), (25, "RSN", 5)],
       ["ReduceTable", 81, "Alternation", (4, "RSN", 6), (10, "RSN", 20), (11, "RSN", 21)],
       ["ReduceTable", 82, "Byte", (4, "RSN", 7), (10, "RSN", 7), (11, "RSN", 7), (14, "RSN", 7), (17, "RSN", 61), (19, "RSN", 50), (22, "RSN", 7), (23, "RSN", 7), (24, "RSN", 7), (25, "RSN", 7), (29, "RSN", 50)],
       ["ReduceTable", 83, "FiniteStateMachine", (4, "RSN", 8)],
       ["ReduceTable", 84, "SemanticAction", (4, "RSN", 48), (10, "RSN", 48), (11, "RSN", 48), (14, "RSN", 48), (16, "RSN", 60), (22, "RSN", 48), (23, "RSN", 48), (24, "RSN", 48), (25, "RSN", 48)],
       ["SemanticTable", 85, "buildTree", ["walkList"], 73],
       ["SemanticTable", 86, "buildTree", ["walkEpsilon"], 81],
       ["SemanticTable", 87, "buildTree", ["walkSemanticAction"], 84],
       ["SemanticTable", 88, "buildTree", ["walkNonTreeBuildingSemanticAction"], 71],
       ["SemanticTable", 89, "buildTree", ["walkStar"], 74],
       ["SemanticTable", 90, "buildTree", ["walkQuestionMark"], 74],
       ["SemanticTable", 91, "buildTree", ["walkPlus"], 74],
       ["SemanticTable", 92, "buildTree", ["walkConcatenation"], 72],
       ["SemanticTable", 93, "buildTree", ["walkAttributes"], 71],
       ["SemanticTable", 94, "buildTree", ["walkBuildTreeOrTokenFromName"], 78],
       ["SemanticTable", 95, "buildTree", ["walkBuildTreeFromLeftIndex"], 78],
       ["SemanticTable", 96, "buildTree", ["walkTreeBuildingSemanticAction"], 78],
       ["SemanticTable", 97, "buildTree", ["walkDotDot"], 80],
       ["SemanticTable", 98, "buildTree", ["walkLook"], 80],
       ["SemanticTable", 99, "buildTree", ["walkAnd"], 74],
       ["SemanticTable", 100, "buildTree", ["walkMinus"], 74],
       ["SemanticTable", 101, "buildTree", ["walkOr"], 81],
       ["SemanticTable", 102, "buildTree", ["walkBuildTreeFromRightIndex"], 78],
       ["SemanticTable", 103, "processTypeNow", ["parser"], 38],
       ["SemanticTable", 104, "processTypeNow", ["scanner"], 38],
       ["AcceptTable", 105]]
}
