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
//            print("Tree from parser: ", tree)
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
        grammar.type = "parser"
        
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
        let givenUp = false
        if (givenUp) {
            let text = """

            """
            builder.process (text)
        } else {
            let text = fileContent
            builder.process (text)
        }
        
        print ("Finished building \(grammar.type) FSMs")
        builder.printOn(fsmMap: builder.fsmMap)
        
        return "Done"
    }
    
    //Walk routines...
    // tells you the kind of fsm you're building
    func processTypeNow (_ parameters:[Any]) -> Void {
          //The child will be a walkString with "scanner" or "parser"
        let type = parameters [0] as? String;
        //Tell the grammar what type it is ...
//        if (type) {
//            Grammar.type = type
//        }
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
    
    func walkCharacter (_ tree : VirtualTree) -> Any {
        //Build an FSM for this tree and return it...
        let token = tree as! Token
        let symbol = token.symbol
        return FiniteStateMachine.forCharacter(symbol)
    }
    
    func walkString (_ tree : VirtualTree) -> Any {
        //Build an FSM for this tree and return it...
        let token = tree as! Token
        let symbol = token.symbol
        return FiniteStateMachine.forCharacter(symbol)
    }
    
    func walkSymbol (_ tree : VirtualTree) -> Any {
      //Build an FSM for this tree and return it...
        let token = tree as! Token
        let symbol = token.symbol
        return FiniteStateMachine.forSymbol(symbol)
    }
    
    func walkInteger (_ tree : VirtualTree) -> Any {
      //Build an FSM for this tree and return it...
        let token = tree as! Token
        let symbol = token.symbol
        return FiniteStateMachine.forInteger(symbol)
    }
    
    func walkIdentifier (_ tree: VirtualTree) -> Any {
        // Ensure tree is a valid Tree instance
        let fsmNameToken = tree as! Token
        let fsmName = fsmNameToken.symbol
        
        // Retrieve the FSM to copy
        guard let fsm = fsmMap[fsmName] as? FiniteStateMachine else {
            print("Error: FSM named \(fsmName) not found.")
            return 0
        }
        
        let fsmCopy = FiniteStateMachine.forIdentifier(fsm)
        return fsmCopy
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
        
        if let child0Token = child0 as? Token {
            if (child0Token.label == "walkIdentifier") {
                let originalFSMName = child0Token.symbol
                if let originalFSM = fsmMap[originalFSMName] as? FiniteStateMachine {
                    originalFSM.printOn()
                    finiteStateMachine.printOn()
                }
            }
        }
        
        return finiteStateMachine
    }
    
    func walkbuildTreeOrTokenFromName (_ tree : VirtualTree) -> Any {
        guard let tree = tree as? Tree else {
            print("Error: Expected tree to be of type Tree, but it's not.")
            return 0
        }
        
        let child0 = tree.child(0)
        let symbol = (child0 as? Token)!.symbol

        let transition = Transition()
        if Grammar.activeGrammar?.type == "scanner" {
            transition.action = "#buildToken"
        } else {
            transition.action = "#buildTree"
        }
        
        transition.parameters = [symbol]
        transition.isRootBuilding = true
        
        let fsm = FiniteStateMachine.fromTransition(transition)
        return fsm
    }
    
    func walkbuildTreeFromLeftIndex (_ tree: VirtualTree) -> Any {
        guard let tree = tree as? Tree else {
            print("Error: Expected tree to be of type Tree, but it's not.")
            return 0
        }
        let child0 = tree.child(0)
        let symbol = (child0 as? Token)!.symbol

        // Convert symbol to an integer and negate it
        if let integerValue = Int(symbol) {
            // Create the transition
            let transition = Transition()
            transition.action = "#buildTreeFromIndex"
            transition.parameters = [integerValue]
            transition.isRootBuilding = true

            return FiniteStateMachine.fromTransition(transition)
        } else {
            print("Error: Unable to convert symbol \(symbol) to an integer.")
            return 0
        }
    }
    
    func walkbuildTreeFromRightIndex (_ tree: VirtualTree) -> Any {
        guard let tree = tree as? Tree else {
            print("Error: Expected tree to be of type Tree, but it's not.")
            return 0
        }
        let child0 = tree.child(0)
        let symbol = (child0 as? Token)!.symbol
        
        // Convert symbol to an integer and negate it
        if let integerValue = Int(symbol) {
            let negatedValue = -integerValue
            
            // Create the transition
            let transition = Transition()
            transition.action = "#buildTreeFromIndex"
            transition.parameters = [negatedValue]
            transition.isRootBuilding = true

            return FiniteStateMachine.fromTransition(transition)
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

        // Create the transition
        let transition = Transition()
        transition.action = actionSymbol
        transition.parameters = parameters
        transition.isRootBuilding = isRootBuilding
        
        return FiniteStateMachine.fromTransition(transition)
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
       ["ReadaheadTable", 1, ("parser", "RS", 104), ("scanner", "RS", 105), ("GrammarType", "RSN", 2), ("ListOfFiniteStateMachines", "RSN", 106)],
       ["ReadaheadTable", 2, ("walkString", "RSN", 40), ("Name", "RSN", 3), ("walkIdentifier", "RSN", 40), ("EndOfFile", "L", 32)],
       ["ReadaheadTable", 3, ("=", "RS", 4)],
       ["ReadaheadTable", 4, ("Primary", "RSN", 5), ("walkString", "RSN", 40), ("Alternation", "RSN", 6), ("Byte", "RSN", 7), ("FiniteStateMachine", "RSN", 8), ("walkSymbol", "RSN", 9), ("walkInteger", "RSN", 44), ("SemanticAction", "RSN", 49), ("(", "RS", 10), ("walkCharacter", "RSN", 44), ("{", "RS", 11), ("walkIdentifier", "RSN", 40), ("=>", "RS", 12), ("Expression", "RSN", 13), ("Concatenation", "RSN", 14), ("RepetitionOption", "RSN", 15), ("Name", "RSN", 43)],
       ["ReadaheadTable", 5, ("[", "RS", 16), ("*", "L", 41), ("?", "L", 41), ("+", "L", 41), ("&", "L", 41), ("-", "L", 41), ("(", "L", 41), ("{", "L", 41), ("walkIdentifier", "L", 41), ("walkString", "L", 41), ("walkSymbol", "L", 41), ("walkCharacter", "L", 41), ("walkInteger", "L", 41), ("|", "L", 41), (")", "L", 41), ("}", "L", 41), ("=>", "L", 41), (";", "L", 41)],
       ["ReadaheadTable", 6, ("=>", "RS", 17), (";", "L", 42)],
       ["ReadaheadTable", 7, ("..", "RS", 18), ("[", "L", 43), ("*", "L", 43), ("?", "L", 43), ("+", "L", 43), ("&", "L", 43), ("-", "L", 43), ("(", "L", 43), ("{", "L", 43), ("walkIdentifier", "L", 43), ("walkString", "L", 43), ("walkSymbol", "L", 43), ("walkCharacter", "L", 43), ("walkInteger", "L", 43), ("|", "L", 43), (")", "L", 43), ("}", "L", 43), ("=>", "L", 43), (";", "L", 43)],
       ["ReadaheadTable", 8, (";", "RS", 19)],
       ["ReadaheadTable", 9, ("[", "RS", 20), ("*", "L", 48), ("?", "L", 48), ("+", "L", 48), ("&", "L", 48), ("-", "L", 48), ("(", "L", 48), ("{", "L", 48), ("walkIdentifier", "L", 48), ("walkString", "L", 48), ("walkSymbol", "L", 48), ("walkCharacter", "L", 48), ("walkInteger", "L", 48), (";", "L", 48), ("|", "L", 48), (")", "L", 48), ("}", "L", 48), ("=>", "L", 48)],
       ["ReadaheadTable", 10, ("Primary", "RSN", 5), ("walkString", "RSN", 40), ("Alternation", "RSN", 21), ("Byte", "RSN", 7), ("walkSymbol", "RSN", 9), ("walkInteger", "RSN", 44), ("SemanticAction", "RSN", 49), ("(", "RS", 10), ("walkCharacter", "RSN", 44), ("{", "RS", 11), ("walkIdentifier", "RSN", 40), ("Expression", "RSN", 13), ("Concatenation", "RSN", 14), ("RepetitionOption", "RSN", 15), ("Name", "RSN", 43)],
       ["ReadaheadTable", 11, ("Primary", "RSN", 5), ("Alternation", "RSN", 22), ("walkString", "RSN", 40), ("Byte", "RSN", 7), ("walkSymbol", "RSN", 9), ("walkInteger", "RSN", 44), ("(", "RS", 10), ("SemanticAction", "RSN", 49), ("walkCharacter", "RSN", 44), ("{", "RS", 11), ("walkIdentifier", "RSN", 40), ("Expression", "RSN", 13), ("Concatenation", "RSN", 14), ("RepetitionOption", "RSN", 15), ("Name", "RSN", 43)],
       ["ReadaheadTable", 12, ("walkSymbol", "RSN", 9), ("-", "RS", 23), ("walkString", "RSN", 40), ("Name", "RSN", 54), ("walkIdentifier", "RSN", 40), ("TreeBuildingOptions", "RSN", 50), ("+", "RS", 24), ("walkInteger", "RSN", 55), ("SemanticAction", "RSN", 56)],
       ["ReadaheadTable", 13, ("*", "RS", 57), ("?", "RS", 58), ("+", "RS", 59), ("&", "RS", 25), ("-", "RS", 26), ("(", "L", 45), ("{", "L", 45), ("walkIdentifier", "L", 45), ("walkString", "L", 45), ("walkSymbol", "L", 45), ("walkCharacter", "L", 45), ("walkInteger", "L", 45), ("|", "L", 45), (")", "L", 45), ("}", "L", 45), ("=>", "L", 45), (";", "L", 45)],
       ["ReadaheadTable", 14, ("|", "RS", 27), (")", "L", 46), ("}", "L", 46), ("=>", "L", 46), (";", "L", 46)],
       ["ReadaheadTable", 15, ("Primary", "RSN", 5), ("walkString", "RSN", 40), ("Byte", "RSN", 7), ("walkSymbol", "RSN", 9), ("walkInteger", "RSN", 44), ("SemanticAction", "RSN", 49), ("(", "RS", 10), ("walkCharacter", "RSN", 44), ("{", "RS", 11), ("walkIdentifier", "RSN", 40), ("Expression", "RSN", 13), ("RepetitionOption", "RSN", 28), ("Name", "RSN", 43), ("|", "L", 47), (")", "L", 47), ("}", "L", 47), ("=>", "L", 47), (";", "L", 47)],
       ["ReadaheadTable", 16, ("Attribute", "RSN", 29), ("keep", "RSN", 51), ("noNode", "RSN", 51), ("noStack", "RSN", 51), ("]", "RS", 61), ("read", "RSN", 51), ("look", "RSN", 51), ("stack", "RSN", 51), ("node", "RSN", 51), ("noKeep", "RSN", 51)],
       ["ReadaheadTable", 17, ("walkString", "RSN", 40), ("-", "RS", 23), ("walkSymbol", "RSN", 9), ("Name", "RSN", 54), ("walkIdentifier", "RSN", 40), ("TreeBuildingOptions", "RSN", 62), ("+", "RS", 24), ("walkInteger", "RSN", 55), ("SemanticAction", "RSN", 56)],
       ["ReadaheadTable", 18, ("Byte", "RSN", 63), ("walkInteger", "RSN", 44), ("walkCharacter", "RSN", 44)],
       ["ReadaheadTable", 19, ("walkString", "RSN", 40), ("Name", "RSN", 3), ("walkIdentifier", "RSN", 40), ("EndOfFile", "L", 32)],
       ["ReadaheadTable", 20, ("walkString", "RSN", 40), ("walkSymbol", "RSN", 52), ("Name", "RSN", 52), ("walkIdentifier", "RSN", 40), ("Byte", "RSN", 52), ("walkCharacter", "RSN", 44), ("]", "RS", 64), ("SemanticActionParameter", "RSN", 30), ("walkInteger", "RSN", 44)],
       ["ReadaheadTable", 21, (")", "RS", 53)],
       ["ReadaheadTable", 22, ("}", "RS", 65)],
       ["ReadaheadTable", 23, ("walkInteger", "RSN", 66)],
       ["ReadaheadTable", 24, ("walkInteger", "RSN", 55)],
       ["ReadaheadTable", 25, ("walkSymbol", "RSN", 9), ("Expression", "RSN", 67), ("Primary", "RSN", 5), ("walkString", "RSN", 40), ("Name", "RSN", 43), ("Byte", "RSN", 7), ("walkIdentifier", "RSN", 40), ("{", "RS", 11), ("walkCharacter", "RSN", 44), ("SemanticAction", "RSN", 49), ("walkInteger", "RSN", 44), ("(", "RS", 10)],
       ["ReadaheadTable", 26, ("walkString", "RSN", 40), ("Expression", "RSN", 68), ("Primary", "RSN", 5), ("walkSymbol", "RSN", 9), ("Name", "RSN", 43), ("walkCharacter", "RSN", 44), ("walkIdentifier", "RSN", 40), ("{", "RS", 11), ("Byte", "RSN", 7), ("walkInteger", "RSN", 44), ("SemanticAction", "RSN", 49), ("(", "RS", 10)],
       ["ReadaheadTable", 27, ("Primary", "RSN", 5), ("walkString", "RSN", 40), ("Byte", "RSN", 7), ("walkSymbol", "RSN", 9), ("walkInteger", "RSN", 44), ("SemanticAction", "RSN", 49), ("(", "RS", 10), ("walkCharacter", "RSN", 44), ("{", "RS", 11), ("walkIdentifier", "RSN", 40), ("Expression", "RSN", 13), ("Concatenation", "RSN", 31), ("RepetitionOption", "RSN", 15), ("Name", "RSN", 43)],
       ["ReadaheadTable", 28, ("Primary", "RSN", 5), ("walkString", "RSN", 40), ("Byte", "RSN", 7), ("walkSymbol", "RSN", 9), ("walkInteger", "RSN", 44), ("SemanticAction", "RSN", 49), ("(", "RS", 10), ("walkCharacter", "RSN", 44), ("{", "RS", 11), ("walkIdentifier", "RSN", 40), ("Expression", "RSN", 13), ("RepetitionOption", "RSN", 28), ("Name", "RSN", 43), ("|", "L", 60), (")", "L", 60), ("}", "L", 60), ("=>", "L", 60), (";", "L", 60)],
       ["ReadaheadTable", 29, ("Attribute", "RSN", 29), ("keep", "RSN", 51), ("noNode", "RSN", 51), ("noStack", "RSN", 51), ("]", "RS", 61), ("read", "RSN", 51), ("look", "RSN", 51), ("stack", "RSN", 51), ("node", "RSN", 51), ("noKeep", "RSN", 51)],
       ["ReadaheadTable", 30, ("walkString", "RSN", 40), ("walkSymbol", "RSN", 52), ("SemanticActionParameter", "RSN", 30), ("walkCharacter", "RSN", 44), ("]", "RS", 64), ("walkIdentifier", "RSN", 40), ("Byte", "RSN", 52), ("Name", "RSN", 52), ("walkInteger", "RSN", 44)],
       ["ReadaheadTable", 31, ("|", "RS", 27), (")", "L", 69), ("}", "L", 69), ("=>", "L", 69), (";", "L", 69)],
       ["ReadbackTable", 32, (("GrammarType", 2), "RSN", 87), ((";", 19), "RS", 70)],
       ["ReadbackTable", 33, (("+", 24), "RS", 91), (("=>", 12), "L", 91), (("=>", 17), "L", 91)],
       ["ReadbackTable", 34, (("RepetitionOption", 28), "RSN", 34), (("RepetitionOption", 15), "RSN", 96)],
       ["ReadbackTable", 35, (("Attribute", 29), "RSN", 35), (("[", 16), "RS", 72)],
       ["ReadbackTable", 36, (("[", 20), "RS", 48), (("SemanticActionParameter", 30), "RSN", 36)],
       ["ReadbackTable", 37, (("Concatenation", 14), "RSN", 103), (("Concatenation", 31), "RSN", 71)],
       ["ReadbackTable", 38, (("GrammarType", 2), "RSN", 87), ((";", 19), "RS", 70)],
       ["ShiftbackTable", 39, 1, 81],
       ["ShiftbackTable", 40, 1, 77],
       ["ShiftbackTable", 41, 1, 73],
       ["ShiftbackTable", 42, 1, 85],
       ["ShiftbackTable", 43, 1, 82],
       ["ShiftbackTable", 44, 1, 84],
       ["ShiftbackTable", 45, 1, 76],
       ["ShiftbackTable", 46, 1, 83],
       ["ShiftbackTable", 47, 1, 74],
       ["ShiftbackTable", 48, 1, 88],
       ["ShiftbackTable", 49, 1, 89],
       ["ShiftbackTable", 50, 2, 85],
       ["ShiftbackTable", 51, 1, 79],
       ["ShiftbackTable", 52, 1, 78],
       ["ShiftbackTable", 53, 3, 82],
       ["ShiftbackTable", 54, 1, 90],
       ["ShiftbackTable", 55, 1, 33],
       ["ShiftbackTable", 56, 1, 92],
       ["ShiftbackTable", 57, 2, 93],
       ["ShiftbackTable", 58, 2, 94],
       ["ShiftbackTable", 59, 2, 95],
       ["ShiftbackTable", 60, 1, 34],
       ["ShiftbackTable", 61, 1, 35],
       ["ShiftbackTable", 62, 3, 96],
       ["ShiftbackTable", 63, 3, 98],
       ["ShiftbackTable", 64, 1, 36],
       ["ShiftbackTable", 65, 3, 99],
       ["ShiftbackTable", 66, 2, 100],
       ["ShiftbackTable", 67, 3, 101],
       ["ShiftbackTable", 68, 3, 102],
       ["ShiftbackTable", 69, 2, 37],
       ["ShiftbackTable", 70, 3, 38],
       ["ShiftbackTable", 71, 1, 37],
       ["ShiftbackTable", 72, 1, 97],
       ["ReduceTable", 73, "Expression", (4, "RSN", 13), (10, "RSN", 13), (11, "RSN", 13), (15, "RSN", 13), (25, "RSN", 67), (26, "RSN", 68), (27, "RSN", 13), (28, "RSN", 13)],
       ["ReduceTable", 74, "Concatenation", (4, "RSN", 14), (10, "RSN", 14), (11, "RSN", 14), (27, "RSN", 31)],
       ["ReduceTable", 75, "ListOfFiniteStateMachines", (1, "RSN", 106)],
       ["ReduceTable", 76, "RepetitionOption", (4, "RSN", 15), (10, "RSN", 15), (11, "RSN", 15), (15, "RSN", 28), (27, "RSN", 15), (28, "RSN", 28)],
       ["ReduceTable", 77, "Name", (2, "RSN", 3), (4, "RSN", 43), (10, "RSN", 43), (11, "RSN", 43), (12, "RSN", 54), (15, "RSN", 43), (17, "RSN", 54), (19, "RSN", 3), (20, "RSN", 52), (25, "RSN", 43), (26, "RSN", 43), (27, "RSN", 43), (28, "RSN", 43), (30, "RSN", 52)],
       ["ReduceTable", 78, "SemanticActionParameter", (20, "RSN", 30), (30, "RSN", 30)],
       ["ReduceTable", 79, "Attribute", (16, "RSN", 29), (29, "RSN", 29)],
       ["ReduceTable", 80, "TreeBuildingOptions", (12, "RSN", 50), (17, "RSN", 62)],
       ["ReduceTable", 81, "GrammarType", (1, "RSN", 2)],
       ["ReduceTable", 82, "Primary", (4, "RSN", 5), (10, "RSN", 5), (11, "RSN", 5), (15, "RSN", 5), (25, "RSN", 5), (26, "RSN", 5), (27, "RSN", 5), (28, "RSN", 5)],
       ["ReduceTable", 83, "Alternation", (4, "RSN", 6), (10, "RSN", 21), (11, "RSN", 22)],
       ["ReduceTable", 84, "Byte", (4, "RSN", 7), (10, "RSN", 7), (11, "RSN", 7), (15, "RSN", 7), (18, "RSN", 63), (20, "RSN", 52), (25, "RSN", 7), (26, "RSN", 7), (27, "RSN", 7), (28, "RSN", 7), (30, "RSN", 52)],
       ["ReduceTable", 85, "FiniteStateMachine", (4, "RSN", 8)],
       ["ReduceTable", 86, "SemanticAction", (4, "RSN", 49), (10, "RSN", 49), (11, "RSN", 49), (12, "RSN", 56), (15, "RSN", 49), (17, "RSN", 56), (25, "RSN", 49), (26, "RSN", 49), (27, "RSN", 49), (28, "RSN", 49)],
       ["SemanticTable", 87, "buildTree", ["walkList"], 75],
       ["SemanticTable", 88, "buildTree", ["walkSemanticAction"], 86],
       ["SemanticTable", 89, "buildTree", ["walkNonTreeBuildingSemanticAction"], 73],
       ["SemanticTable", 90, "buildTree", ["walkbuildTreeOrTokenFromName"], 80],
       ["SemanticTable", 91, "buildTree", ["walkbuildTreeFromLeftIndex"], 80],
       ["SemanticTable", 92, "buildTree", ["walkTreeBuildingSemanticAction"], 80],
       ["SemanticTable", 93, "buildTree", ["walkStar"], 76],
       ["SemanticTable", 94, "buildTree", ["walkQuestionMark"], 76],
       ["SemanticTable", 95, "buildTree", ["walkPlus"], 76],
       ["SemanticTable", 96, "buildTree", ["walkConcatenation"], 74],
       ["SemanticTable", 97, "buildTree", ["walkAttributes"], 73],
       ["SemanticTable", 98, "buildTree", ["walkDotDot"], 82],
       ["SemanticTable", 99, "buildTree", ["walkLook"], 82],
       ["SemanticTable", 100, "buildTree", ["walkbuildTreeFromRightIndex"], 80],
       ["SemanticTable", 101, "buildTree", ["walkAnd"], 76],
       ["SemanticTable", 102, "buildTree", ["walkMinus"], 76],
       ["SemanticTable", 103, "buildTree", ["walkOr"], 83],
       ["SemanticTable", 104, "processTypeNow", ["parser"], 39],
       ["SemanticTable", 105, "processTypeNow", ["scanner"], 39],
       ["AcceptTable", 106]]


}
