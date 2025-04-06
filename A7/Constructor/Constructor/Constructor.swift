//
//  Constructor.swift
//  Constructor
//
//  Created by Wilf Lalonde on 2023-01-24.
//

import Foundation

typealias treeClosure = (VirtualTree) -> Any //Ultimately FSM

public final class Constructor : Translator {
    var debug = true
    var parser: Parser?
    var tree: VirtualTree? = nil
    var fsmMap: Dictionary<String,Any> = [:] //Ultimately FSM
    var readaheadStates: [ReadaheadState] = []
    var readbackStates: [ReadbackState] = []
    var reduceStates: Dictionary<String, ReduceState> = [:] // key is a nonterminal
    var semanticStates: [SemanticState] = []
    var acceptState: AcceptState?
    var right: Relation<FiniteStateMachineState, Label>?
    var down: Relation<FiniteStateMachineState, String>?
    var left: Relation<Pairing, Pairing>?
    var up: Relation<Pairing, String>?
    var invisibleLeft: Relation<Pairing, Pairing>?
    var visibleLeft: Relation<Pairing, Pairing>?
    var stackableStates: Set<FiniteStateMachineState> = Set()
    var treeWalker = TreeWalker()
    
    init() {
        parser = Parser(sponsor: self, parserTables: parserTables, scannerTables: scannerTables)
    }
    
    func process (_ text: String) -> Void {
        print("Tree type: \(Grammar.activeGrammar!.type)")
        if let tree = parser!.parse(text) as? Tree {
            print("tree from parser:")
            print(tree)
            _ = treeWalker.walkTree(tree)
        } else {
            print("Failed to parse the text into a Tree")
        }
    }
    
    func renumber () {
        var count = 1
        Grammar.activeGrammar?.renumber()
        
        for raState in readaheadStates {
            raState.stateNumber = count
            count += 1
        }
        for rbState in readbackStates {
            rbState.stateNumber = count
            count += 1
        }
        for reduceState in reduceStates.values {
            reduceState.stateNumber = count
            count += 1
        }
        for s in semanticStates {
            s.stateNumber = count
            count += 1
        }
        acceptState?.stateNumber = count
    }
    
  public func canPerformAction(_ action: String) -> Bool {
      print("can perform action: \(action)")
      if (action == "processTypeNow") {return true;}
      if (action == "processAndDiscardDefaultsNow") {return true}
      if (action == "walkAttributeTerminalDefaults") {return true}
      if (action == "walkAttributeNonterminalDefaults") {return true}
      if (action == "walkOutput") {return true}
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
            8: "toyParserGrammarToTestFollowSets",
            9: "LISPGrammarWithInvisibles",
            10: "parserGrammar",
            11: "realParserGrammar",
            12: "realScannerGrammer"
        ]
        
        let numberToTest = 11
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
        builder.createTables()
        return "Done"
    }
    
    
    func createTables() {
        guard let grammar = Grammar.activeGrammar else {
            return
        }
        
        // create reduce state(s) for parser
        if grammar.isParser() {
            for nonterminal in grammar.nonterminals {
                let reduceState = ReduceState()
                reduceState.nonterminal = nonterminal
                reduceStates[nonterminal] = reduceState
            }
            renumber()
        }
        
        // create the right and down relations from the grammar's productions
        self.createRightAndDownRelations()
        
        // build ra states and semantic states
        self.buildReadaheadStates()
        self.attachReadaheadFollowSets()
        self.buildSemanticStates()
        
        // for scanners, bridge readaheads back to the initial ra state
        // for parers, we have reduce/readback tables
        if grammar.isScanner() {
            self.buildScannerBridges()
        } else {
            // create a collection of stackable states
            self.recordStackableStates()
            
            // split the left relation into invisible/visible relations
            self.splitLeftRelation()
            
            // build readback state bridges
            self.buildReadbackStateBridges()
            
            // finalize reduce states with alternates
            self.addReduceStateTransitions()
            self.finalizeReduceStates()
            
            self.finishReadbackStates()
            self.removeFirstParserState()
        }
        
        self.checkConflicts()
        
        if grammar.isScanner() {
            printScannerTables()
            outputScannerTablesToFile()
        } else {
            printParserTables()
            self.outputParserTablesToFile()
        }
    }

    
    func createRightAndDownRelations() {
        guard let grammar = Grammar.activeGrammar else {
            return
        }
        
        right = Relation()
        grammar.allRightTriplesDo { (state, transitionLabel, goto) in
            right!.add(from: state, relationship: transitionLabel, to: goto)
        }
        
        down = Relation()
        grammar.allDownTriplesDo { (state, nonterminal, initialState) in
            down!.add(from: state, relationship: nonterminal, to: initialState)
        }
    }
    
    
    func buildReadaheadStates () {
        self.up = Relation ()
        self.left = Relation ()
        
        // set initial items in the first RA state to the initial right part states of the goal production
        for goalProduction in Grammar.activeGrammar!.goalProductions() {
            let readaheadState = ReadaheadState()
            readaheadState.initialItems = goalProduction.fsm.getInitialStates()
            readaheadStates.append(readaheadState)
        }
        renumber()
        
        var index = 0
        while index < readaheadStates.count {
            let raState = readaheadStates[index]
            let localDown = down?.performRelationStar(items: raState.initialItems)
            
            // add reverse of triples from localDown to the up relation
            for triple in localDown!.triples {
                let relationship = triple.relationship
                let firstPairing = Pairing(triple.to, raState)
                let secondPairing = Pairing(triple.from, raState)
                up!.add(Triple(from: firstPairing, relationship: relationship, to: secondPairing))
            }
            
            // get successors
            raState.finalItems = raState.initialItems + localDown!.allTo()
            right?.from(raState.finalItems) { (relationship: Label, localRight: Relation<FiniteStateMachineState, Label>) in
                let candidateItems = localRight.allTo()
                let candidate = ReadaheadState()
                candidate.initialItems = candidateItems
                
                // Match candidate with existing readahead states
                var successor = self.match(candidate, readaheadStates)
                if successor == nil {
                    readaheadStates.append(candidate)
                    successor = candidate
                    renumber()
                }
                raState.transitions.append(Transition(relationship, successor!))
                
                // add reverse of triples in right relation to left
                for triple in localRight.triples {
                    let labelPairing = Pairing(triple.relationship, successor! as ReadaheadState)
                    let pairing1 = Pairing(triple.to, successor! as ReadaheadState)
                    let pairing2 = Pairing(triple.from, raState)
                    left?.add(Triple(from: pairing1, relationship: labelPairing, to: pairing2))
                }
            }
            
            index += 1
        }
    }
    
    
    /*
        iterate over readaheads, find all semantic transitions
        for every semantic transiton, compute the followset of the goto (a ra state) and attach it to it
     */
    func attachReadaheadFollowSets () {
        for raState in readaheadStates {
            raState.transitionsDo { transition in
                if transition.label?.hasAction() == true { // Semantic transition
                    let goto = transition.goto as! ReadaheadState
                    goto.follow = Grammar.activeGrammar?.computeReadaheadFollowSet(raState: goto) ?? []
                }
            }
        }
    }
    
    
    /* for every semantic transiiton, build a semantic state where the label is the semantic
       transition label and the goto is the original transition's goto state
       set the goto of the 'from' readahead state to the semantic state
     */
    func buildSemanticStates () {
        for raState in readaheadStates {
            var transitionsToRemove: [Transition] = []

            raState.transitionsDo { transition in
                if transition.label?.hasAction() == true { // Semantic transition
                    let semState = SemanticState(transition.label!, transition.goto!)
                    if let gotoFollowSet = Grammar.activeGrammar?.computeReadaheadFollowSet(raState: transition.goto as! ReadaheadState) {
                        for lookahead in gotoFollowSet {
                            raState.transitions.append(Transition(Label(lookahead, AttributeList().set(Grammar.lookDefaults())), semState))
                        }
                        transitionsToRemove.append(transition)
                    }
                    semanticStates.append(semState)
                    renumber()
                }
            }
            
            // remove old transitions
            for transition in transitionsToRemove {
                if let index = raState.transitions.firstIndex(where: { $0 === transition }) {
                    raState.transitions.remove(at: index)
                }
            }
        }
    }
    
    
    func recordStackableStates() {
        // go thru RA states, add to the collection any state where there’s a read terminal
        // or nonterminal transition to that state
        for state in readaheadStates {
            for t in state.transitions {
                let label = t.label!
                if label.hasAttributes() && label.attributes.isRead {
                    stackableStates.insert(t.goto!)
                }
            }
        }
    }
    
    
    // bridge lookahead transition back to the initial readahead state (instead of to an initial readback state).
    func buildScannerBridges() {
        for raState in readaheadStates {
            let finalItems = raState.finalItems.filter({ $0.isFinal })
            let partition = Dictionary(grouping: finalItems, by: { $0.leftPart })
            
            for (nonterminal, _) in partition {
                if let production = Grammar.activeGrammar?.productions[nonterminal] {
                    let followSet = production.followSet
                    for lookahead in followSet {
                        raState.transitions.append(Transition(Label(lookahead, AttributeList().set(Grammar.lookDefaults())), raState))
                    }
                }
            }
        }
    }
    
    
    func buildReadbackStateBridges() {
        readbackStates = []
        
        for raState in readaheadStates {
            let finalStates = raState.finalItems.filter({ $0.isFinal })
            let partition = Dictionary(grouping: finalStates, by: { $0.leftPart })
            
            for (nonterminal, finalStates) in partition {
                var newReadbackState:ReadbackState
                var newState:FiniteStateMachineState
                
                if let production = Grammar.activeGrammar?.productions[nonterminal] {
                    if production.isGoal() {
                        acceptState = AcceptState()
                        newState = acceptState!
                        let firstRaState = readaheadStates[1]
                        firstRaState.transitions.append(Transition(Label(production.leftPart, AttributeList().set(Grammar.lookDefaults())), newState))
                    } else {
                        newState = ReadbackState()
                        newReadbackState = newState as! ReadbackState
                        let finalStatePairs = finalStates.map { finalState in
                            return Pairing(finalState, raState)
                        }
                        newReadbackState.initialItems = finalStatePairs
                        readbackStates.append(newReadbackState)
                    }
                    
                    // make transitions from the readahead state to the new state, using the followset of the nonterminal's production as look labels
                    let followSet = production.followSet
                    for lookahead in followSet {
                        raState.transitions.append(Transition(Label(lookahead, AttributeList().set(Grammar.lookDefaults())), newState))
                    }
                    renumber()
                }
            }
        }
    }
    
    func finishReadbackStates() {
        var index = 0
                
        while index < readbackStates.count {
            let rbState = readbackStates[index]
            let moreItems: [Pairing] = (invisibleLeft?.performStar(items: rbState.initialItems))!
            rbState.finalItems = moreItems

            // go over visible left relation from the items/finalItems in the current readback
            // get all the 'to' states for the localLeft relation and add them to the initial items of the candidate readback state
            // check if that readback state exists already
            visibleLeft!.from(rbState.finalItems) { (relationship: Pairing, localLeft: Relation<Pairing, Pairing>) in
                let candidate = ReadbackState()
                let candidateItems = localLeft.allTo()
                candidate.initialItems = candidateItems
                
                var successor = self.match(candidate, readbackStates)
                if successor == nil {
                    readbackStates.append(candidate)
                    successor = candidate
                    renumber()
                }
                
                rbState.transitions.append(Transition(relationship, successor!))
            }
            
            let initialStateItems: [Pairing] = rbState.finalItems.filter{($0.isInitial())} // might be empty
            
            // item1 in rb state items is a right part state, who's left part is a non terminal
            // initialStateItems here is a Pairing of right part states and their readahead state gotos
            if !initialStateItems.isEmpty {
                let lookbacks = lookbackFor(initialStateItems)
                
                for lookback in lookbacks {
                    if let initialState = initialStateItems.first?.item1 as? FiniteStateMachineState {
                        let reduceStateNonTerminal = initialState.leftPart
                        if let reduceState = reduceStates[reduceStateNonTerminal] {
                            let lookbackAsLook = lookback.asLook()
                            rbState.transitions.append(Transition(lookbackAsLook, reduceState))
                        }
                    }
                }
                
            }
            
            index += 1
        }
    }
    
    
    func removeFirstParserState() {
        self.renumber()
        readaheadStates.remove(at: 0)
        self.renumber()
    }
    
    
    // Receives a collection of pairings, where item1 is an initial right part state and item2 is a readahead state
    // lookbackFor should return a pairing of labels and right part states
    func lookbackFor(_ items: [Pairing]) -> [Pairing]{
        var result: [Pairing] = []
        
        if let singleUpItems = up?.performOnce(items: items) {
            result.append(contentsOf: singleUpItems)
        }

        // make a new collection from the result, process items in newItems whie
        var newItems: [Pairing] = result
        var additionalItems: [Pairing] = []
        
        // Continue processing while there are new items to evaluate
        while !newItems.isEmpty {
            // Clear additionalItems to store new findings in this iteration
            additionalItems.removeAll()
            
            for item in newItems {
                // Get 'tos' pairings from 'up' relation based on the current item pairing, add any new items found to additionalItems collection
                if let upItems = up?.performStar(items: [item]) {
                    additionalItems.append(contentsOf: upItems.filter { !result.contains($0) && !additionalItems.contains($0) })
                }
                // Get 'tos' pairings from 'left' relation based on the current item pairing, add any new items found to additionalItems collection
                if let leftItems = invisibleLeft?.performStar(items: [item]) {
                    additionalItems.append(contentsOf: leftItems.filter { !result.contains($0) && !additionalItems.contains($0) })
                }
            }
            
            // If we found new items, add them to result and continue the loop
            if !additionalItems.isEmpty {
                result.append(contentsOf: additionalItems)
                newItems = additionalItems
            } else {
                break
            }
        }
        
        // visible left is a relation where pairs of right part states and ra states are connected by a label pair,
        var lookbacks: [Pairing] = []
        visibleLeft!.from(result) { (relationship: Pairing, relation: Relation<Pairing, Pairing>) in
            // relationship is a label pair b/w the label and the readahead 
            let lookback = relationship.asLook()

            // Check if the lookback already exists in the lookbacks array
            if !lookbacks.contains(where: {
                if let label1 = $0.item1 as? Label, let label2 = lookback.item1 as? Label {
                    if label1 == label2 {
                        if let state1 = $0.item2 as? FiniteStateMachineState, let state2 = lookback.item2 as? FiniteStateMachineState {
                            return state1.stateNumber == state2.stateNumber
                        }
                    }
                }
                return false
            }) {
                lookbacks.append(lookback)
            }
        }
        
        return lookbacks
    }
    
    
    func addReduceStateTransitions() {
        // move all ra state nonterminal transitions into the appropriate reduce state
        for raState in readaheadStates {
            print(raState.description)
            raState.transitionsDo { transition in
                if Grammar.activeGrammar!.isNonterminal(transition.label!.name) && !transition.goto!.isReadback() {
                    if let reduceState = reduceStates[transition.label!.name] {
                        let transitionAttrributes = transition.label?.attributes.description
                        reduceState.reduceTransitions.append(Triple(from: raState, relationship: transitionAttrributes!, to: transition.goto!))
                    }
                }
            }
        }
    }
    

    func finalizeReduceStates() {
        // make an invisible left ra state relation
        // for any transition that's a semantic action transition or a look transition, add the inverse
        let readAheadInvisibleLeft = Relation<FiniteStateMachineState, Label>()
        for raState in readaheadStates {
            for t in raState.transitions {
                if !t.goto!.isReadback() {
                    if t.label!.hasAction() || !t.label!.attributes.isRead {
                        readAheadInvisibleLeft.add(from: t.goto!, relationship: t.label!, to: raState)
                    }
                }
            }
        }
        
        // get alternates
        for (_, reduceState) in reduceStates {
            for transition in reduceState.reduceTransitions {
                let fromState = transition.from
                let gotoState = transition.to
                let attributes = transition.relationship
                
                let alternates = Set(readAheadInvisibleLeft.performStar(items: [fromState]))
                let stackableAlternates = alternates.intersection(stackableStates)
                
                // add transitions to reduce state for stackable alternates
                for stackableAlt in stackableAlternates {
                    let readaheadStackable = stackableAlt as! ReadaheadState
                    reduceState.reduceTransitions.appendIfAbsent(Triple(from: readaheadStackable, relationship: attributes, to: gotoState))
                }
            }
        }

    }

    
    // tells you the kind of fsm you're building
    func processTypeNow (_ parameters:[Any]) -> Void {
        let type = parameters [0] as? String;
        Grammar.activeGrammar?.type = type!
    }
    
    func printParserTables() {
        print("\nReadahead Tables\n")
        for raState in readaheadStates {
            raState.printOn()
            print("\n")
        }
        
        print("Readback Tables\n")
        for rbState in readbackStates {
                rbState.printOn()
        }
        
        print("\nReduce Tables\n")
        for redState in reduceStates.values {
            redState.printOn()
        }
        
        print("\nSemantic Tables\n")
        for semState in semanticStates {
            semState.printOn()
        }
        
        print("\nAccept Table\n")
        acceptState?.printOn()
    }
    
    func printScannerTables() {
        print("ScannerReadaheadTables\n")
        for raState in readaheadStates {
            raState.printOn()
            print("\n")
        }
        
        print("\nSemantic Tables\n")
        for semState in semanticStates {
            semState.printOn()
        }
    }

    
    func splitLeftRelation() {
        let visibleTriples = left!.triples.filter { $0.relationship.isVisible() }
        visibleLeft = Relation(triples: Set(visibleTriples))
        
        let invisibleTriples = left!.triples.filter { !$0.relationship.isVisible() }
        invisibleLeft = Relation(triples: Set(invisibleTriples))
    }
    
    
    func match(_ candidate: ReadaheadState, _ readaheadStates: [ReadaheadState]) -> ReadaheadState? {
        for state in readaheadStates {
            if state.initialItems == candidate.initialItems {
                return state
            }
        }
        return nil  
    }
    
    
    func match(_ candidate: ReadbackState, _ readbackStates: [ReadbackState]) -> ReadbackState? {
        for state in readbackStates {
            if state.initialItems == candidate.initialItems {
                return state
            }
        }
        return nil
    }
    
    func processAndDiscardDefaultsNow() {
        //Pick up the tree just built containing either the attributes, keywords, optimize, and output tree,
        //process it with walkTree, and remove it from the tree stack... by replacing the entry by nil..."
        let tree: Tree = self.parser!.treeStack.last as! Tree
        treeWalker.process(tree: tree)
        self.parser!.treeStack.removeLast()
        self.parser!.treeStack.append(nil)
    }
    
    
    func checkConflicts() {
        print("Checking attribute conflicts...")
        // Attribute conflicts
        // go thru readahead states transitions and partition by label name, if partition has >1 entry for the RA state, there's a conflict
        for raState in readaheadStates {
            // group transitions by label name
            let partition = Dictionary(grouping: raState.transitions, by: { $0.label!.name })
            
            for (labelName, transitions) in partition {
                if transitions.count > 1 {
                    print("Conflict detected in readahead state \(raState.stateNumber) for label: \(labelName) with transitions: \(transitions)")
                }
            }
        }
        
        print("Checking restart conflicts...")
        // reduce alternate conflicts (parsers)
        // partition reduce state's restarts by 'from' state numbers --> should only be one entry per reduce state
        for (_, reduceState) in reduceStates {
            let partition = Dictionary(grouping: reduceState.restarts) { $0.0.stateNumber }
            for (stateNumber, entries) in partition {
                if entries.count > 1 {
                    print("Conflict detected in reduce state for state number: \(stateNumber) with entries: \(entries)")
                }
            }
        }
    }
    
    
    func outputScannerTablesToFile() {
        var outputFile: FileHandle?
        let fileName = "scannerOutput.txt"
        open(&outputFile, fileName)
        
        // Scanner Readahead tables
        var raTableLines: [String] = []
        for raState in readaheadStates {
            raTableLines.append(raState.getFormattedScannerTable())
        }
        
        for line in raTableLines {
            print(line)
            write(&outputFile, line)
        }
        
        // Semantic Tables
        var semTableLines: [String] = []
        for (index, semState) in semanticStates.enumerated() {
            var line = semState.getFormmatedTableLine()
            if index == (semanticStates.count - 1) {
                line.removeLast(2)
            }
            semTableLines.append(line)
        }
        
        for line in semTableLines {
            print(line)
            write(&outputFile, line)
        }
        write(&outputFile, "]")
    }
    
    
    func outputParserTablesToFile() {
        var outputFile: FileHandle?
        let fileName = "output.txt"
        open(&outputFile, fileName)
        
        // keywords
        let keywords = Grammar.activeGrammar!.keywords
        let keywordsLine = "[\"keywords\", " + keywords.map { "\"\($0)\"" }.joined(separator: ", ") + "],"
        write(&outputFile, keywordsLine + "\n")
        
        // Parer Readahead tables
        var raTableLines: [String] = []
        for raState in readaheadStates {
            raTableLines.append(raState.getFormattedParserTable())
        }
        
        for line in raTableLines {
            print(line)
            write(&outputFile, line)
        }
        
        // Readback tables
        var rbTableLines: [String] = []
        for rbState in readbackStates {
            rbTableLines.append(rbState.getFormmatedTableLine())
        }
        
        for line in rbTableLines {
            print(line)
            write(&outputFile, line)
        }
        
        // Reduce tables
        var reduceTableLines: [String] = []
        for redState in reduceStates.values {
            reduceTableLines.append(redState.getFormmatedTableLine())
        }
        
        for line in reduceTableLines {
            print(line)
            write(&outputFile, line)
        }
        
        // Semantic Tables
        var semTableLines: [String] = []
        for st in semanticStates {
            semTableLines.append(st.getFormmatedTableLine())
        }
        
        for line in semTableLines {
            print(line)
            write(&outputFile, line)
        }
        
        // Accept Table
        let acceptLine = "[\"AcceptTable\", \(acceptState!.stateNumber)]"
        write(&outputFile, acceptLine + "]")
        close(&outputFile)
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
//        ["keywords", "stack", "noStack", "read", "look", "node", "noNode", "keep", "noKeep", "parser", "scanner", "super", "superScanner", "attribute", "defaults", "keywords", "output", "optimize", "terminal", "nonterminal"],
//        ["ReadaheadTable", 1, ("scanner", "RS", 2), ("parser", "RS", 3), ("GrammarType", "RSN", 4), ("super", "RS", 5), ("superScanner", "RS", 6)],
//        ["ReadaheadTable", 2, ("attribute", "L", 403), ("keywords", "L", 403), ("output", "L", 403), ("optimize", "L", 403), ("walkIdentifier", "L", 403), ("walkString", "L", 403)],
//        ["ReadaheadTable", 3, ("attribute", "L", 404), ("keywords", "L", 404), ("output", "L", 404), ("optimize", "L", 404), ("walkIdentifier", "L", 404), ("walkString", "L", 404)],
//        ["ReadaheadTable", 4, ("Macro", "RSN", 9), ("keywords", "RS", 10), ("walkIdentifier", "RSN", 11), ("optimize", "RS", 12), ("Rules", "RSN", 13), ("Name", "RSN", 14), ("Production", "RSN", 15), ("Defaults", "RSN", 16), ("attribute", "RS", 17), ("LeftPart", "RSN", 18), ("walkString", "RSN", 19), ("output", "RS", 20)],
//        ["ReadaheadTable", 5, ("scanner", "RS", 21)],
//        ["ReadaheadTable", 6, ("attribute", "L", 405), ("keywords", "L", 405), ("output", "L", 405), ("optimize", "L", 405), ("walkIdentifier", "L", 405), ("walkString", "L", 405)],
//        ["ReadaheadTable", 7, ("attribute", "L", 152), ("keywords", "L", 152), ("output", "L", 152), ("optimize", "L", 152), ("walkIdentifier", "L", 152), ("walkString", "L", 152)],
//        ["ReadaheadTable", 8, ("attribute", "L", 153), ("keywords", "L", 153), ("output", "L", 153), ("optimize", "L", 153), ("walkIdentifier", "L", 153), ("walkString", "L", 153)],
//        ["ReadaheadTable", 9, ("Production", "RSN", 15), ("Name", "RSN", 24), ("LeftPart", "RSN", 18), ("walkIdentifier", "RSN", 11), ("walkString", "RSN", 19), ("Macro", "RSN", 9), ("-|", "L", 406)],
//        ["ReadaheadTable", 10, ("Name", "RSN", 25), ("walkIdentifier", "RSN", 11), ("walkString", "RSN", 19)],
//        ["ReadaheadTable", 11, ("OpenCurly", "L", 154), ("walkCharacter", "L", 154), ("walkInteger", "L", 154), ("walkSymbol", "L", 154), ("walkIdentifier", "L", 154), ("walkString", "L", 154), ("CloseSquare", "L", 154), ("Equals", "L", 154), ("Dot", "L", 154), ("RightArrow", "L", 154), ("And", "L", 154), ("Or", "L", 154), ("OpenRound", "L", 154), ("Star", "L", 154), ("QuestionMark", "L", 154), ("Plus", "L", 154), ("OpenSquare", "L", 154), ("CloseCurly", "L", 154), ("CloseRound", "L", 154), ("Minus", "L", 154), ("FatRightArrow", "L", 154)],
//        ["ReadaheadTable", 12, ("walkIdentifier", "RSN", 11), ("Name", "RSN", 26), ("walkString", "RSN", 19)],
//        ["ReadaheadTable", 13, ("-|", "L", 450)],
//        ["ReadaheadTable", 14, ("OpenCurly", "RS", 27), ("Equals", "RS", 28), ("RightArrow", "L", 407)],
//        ["ReadaheadTable", 15, ("Production", "RSN", 15), ("Name", "RSN", 30), ("LeftPart", "RSN", 18), ("walkIdentifier", "RSN", 11), ("Macro", "RSN", 9), ("walkString", "RSN", 19), ("-|", "L", 408)],
//        ["ReadaheadTable", 16, ("walkString", "L", 409), ("walkIdentifier", "L", 409), ("attribute", "L", 409), ("keywords", "L", 409), ("output", "L", 409), ("optimize", "L", 409)],
//        ["ReadaheadTable", 17, ("nonterminal", "RS", 32), ("terminal", "RS", 33), ("defaults", "RS", 34)],
//        ["ReadaheadTable", 18, ("RightArrow", "RS", 35), ("RightPart", "RSN", 36), ("RightParts", "RSN", 37)],
//        ["ReadaheadTable", 19, ("OpenCurly", "L", 155), ("walkCharacter", "L", 155), ("walkInteger", "L", 155), ("walkSymbol", "L", 155), ("walkIdentifier", "L", 155), ("walkString", "L", 155), ("CloseSquare", "L", 155), ("Equals", "L", 155), ("Dot", "L", 155), ("RightArrow", "L", 155), ("And", "L", 155), ("Or", "L", 155), ("OpenRound", "L", 155), ("Star", "L", 155), ("QuestionMark", "L", 155), ("Plus", "L", 155), ("OpenSquare", "L", 155), ("CloseCurly", "L", 155), ("CloseRound", "L", 155), ("Minus", "L", 155), ("FatRightArrow", "L", 155)],
//        ["ReadaheadTable", 20, ("walkIdentifier", "RSN", 11), ("Name", "RSN", 38), ("walkString", "RSN", 19)],
//        ["ReadaheadTable", 21, ("attribute", "L", 410), ("keywords", "L", 410), ("output", "L", 410), ("optimize", "L", 410), ("walkIdentifier", "L", 410), ("walkString", "L", 410)],
//        ["ReadaheadTable", 22, ("attribute", "L", 156), ("keywords", "L", 156), ("output", "L", 156), ("optimize", "L", 156), ("walkIdentifier", "L", 156), ("walkString", "L", 156)],
//        ["ReadaheadTable", 23, ("-|", "L", 157)],
//        ["ReadaheadTable", 24, ("OpenCurly", "RS", 27), ("Equals", "RS", 28), ("RightArrow", "L", 411)],
//        ["ReadaheadTable", 25, ("walkIdentifier", "RSN", 11), ("Name", "RSN", 25), ("Dot", "RS", 40), ("walkString", "RSN", 19)],
//        ["ReadaheadTable", 26, ("Dot", "RS", 41)],
//        ["ReadaheadTable", 27, ("Alternation", "RSN", 42), ("SemanticAction", "RSN", 43), ("Primary", "RSN", 44), ("Expression", "RSN", 45), ("OpenCurly", "RS", 46), ("walkIdentifier", "RSN", 11), ("walkSymbol", "RSN", 47), ("walkCharacter", "RSN", 48), ("OpenRound", "RS", 49), ("walkString", "RSN", 19), ("walkInteger", "RSN", 50), ("RepetitionOption", "RSN", 51), ("Concatenation", "RSN", 53), ("Byte", "RSN", 54), ("AndExpression", "RSN", 55), ("Secondary", "RSN", 56), ("Name", "RSN", 57), ("And", "L", 412), ("CloseCurly", "L", 412), ("CloseRound", "L", 412), ("Minus", "L", 412), ("Dot", "L", 412), ("FatRightArrow", "L", 412), ("RightArrow", "L", 412)],
//        ["ReadaheadTable", 28, ("Primary", "RSN", 44), ("walkInteger", "RSN", 50), ("Alternation", "RSN", 58), ("walkSymbol", "RSN", 59), ("Name", "RSN", 57), ("walkIdentifier", "RSN", 11), ("RepetitionOption", "RSN", 60), ("OpenRound", "RS", 49), ("OpenCurly", "RS", 46), ("Byte", "RSN", 61), ("walkString", "RSN", 19), ("AndExpression", "RSN", 55), ("Secondary", "RSN", 62), ("SemanticAction", "RSN", 43), ("Concatenation", "RSN", 53), ("Expression", "RSN", 63), ("walkCharacter", "RSN", 48), ("And", "L", 413), ("CloseCurly", "L", 413), ("CloseRound", "L", 413), ("Minus", "L", 413), ("Dot", "L", 413), ("FatRightArrow", "L", 413), ("RightArrow", "L", 413)],
//        ["ReadaheadTable", 29, ("RightArrow", "L", 158)],
//        ["ReadaheadTable", 30, ("Equals", "RS", 28), ("OpenCurly", "RS", 27), ("RightArrow", "L", 414)],
//        ["ReadaheadTable", 31, ("walkString", "RSN", 19), ("Name", "RSN", 64), ("Defaults", "RSN", 16), ("Rules", "RSN", 13), ("attribute", "RS", 65), ("output", "RS", 20), ("optimize", "RS", 12), ("Production", "RSN", 15), ("Macro", "RSN", 9), ("walkIdentifier", "RSN", 11), ("LeftPart", "RSN", 18), ("keywords", "RS", 10)],
//        ["ReadaheadTable", 32, ("defaults", "RS", 66)],
//        ["ReadaheadTable", 33, ("defaults", "RS", 67)],
//        ["ReadaheadTable", 34, ("walkString", "RSN", 19), ("walkIdentifier", "RSN", 11), ("Name", "RSN", 68)],
//        ["ReadaheadTable", 35, ("Alternation", "RSN", 58), ("Expression", "RSN", 69), ("walkInteger", "RSN", 50), ("Name", "RSN", 57), ("walkCharacter", "RSN", 48), ("walkSymbol", "RSN", 47), ("Concatenation", "RSN", 70), ("RepetitionOption", "RSN", 60), ("Secondary", "RSN", 62), ("walkIdentifier", "RSN", 11), ("Primary", "RSN", 71), ("walkString", "RSN", 19), ("OpenCurly", "RS", 46), ("Byte", "RSN", 61), ("AndExpression", "RSN", 72), ("SemanticAction", "RSN", 43), ("OpenRound", "RS", 49), ("And", "L", 415), ("CloseCurly", "L", 415), ("CloseRound", "L", 415), ("Minus", "L", 415), ("Dot", "L", 415), ("FatRightArrow", "L", 415), ("RightArrow", "L", 415)],
//        ["ReadaheadTable", 36, ("RightArrow", "RS", 35), ("RightPart", "RSN", 36), ("Dot", "L", 416)],
//        ["ReadaheadTable", 37, ("Dot", "RS", 74)],
//        ["ReadaheadTable", 38, ("Dot", "RS", 75)],
//        ["ReadaheadTable", 39, ("attribute", "L", 159), ("keywords", "L", 159), ("output", "L", 159), ("optimize", "L", 159), ("walkIdentifier", "L", 159), ("walkString", "L", 159)],
//        ["ReadaheadTable", 40, ("attribute", "L", 417), ("keywords", "L", 417), ("output", "L", 417), ("optimize", "L", 417), ("walkIdentifier", "L", 417), ("walkString", "L", 417)],
//        ["ReadaheadTable", 41, ("attribute", "L", 418), ("keywords", "L", 418), ("output", "L", 418), ("optimize", "L", 418), ("walkIdentifier", "L", 418), ("walkString", "L", 418)],
//        ["ReadaheadTable", 42, ("And", "RS", 78), ("CloseCurly", "L", 160), ("CloseRound", "L", 160), ("Minus", "L", 160), ("Dot", "L", 160), ("FatRightArrow", "L", 160), ("RightArrow", "L", 160)],
//        ["ReadaheadTable", 43, ("And", "L", 419), ("Or", "L", 419), ("OpenRound", "L", 419), ("OpenCurly", "L", 419), ("walkCharacter", "L", 419), ("walkInteger", "L", 419), ("walkSymbol", "L", 419), ("walkIdentifier", "L", 419), ("walkString", "L", 419), ("Star", "L", 419), ("QuestionMark", "L", 419), ("Plus", "L", 419), ("CloseCurly", "L", 419), ("CloseRound", "L", 419), ("Minus", "L", 419), ("Dot", "L", 419), ("FatRightArrow", "L", 419), ("RightArrow", "L", 419)],
//        ["ReadaheadTable", 44, ("Plus", "RS", 80), ("QuestionMark", "RS", 81), ("Star", "RS", 82), ("And", "L", 161), ("Or", "L", 161), ("OpenRound", "L", 161), ("OpenCurly", "L", 161), ("walkCharacter", "L", 161), ("walkInteger", "L", 161), ("walkSymbol", "L", 161), ("walkIdentifier", "L", 161), ("walkString", "L", 161), ("CloseCurly", "L", 161), ("CloseRound", "L", 161), ("Minus", "L", 161), ("Dot", "L", 161), ("FatRightArrow", "L", 161), ("RightArrow", "L", 161)],
//        ["ReadaheadTable", 45, ("CloseCurly", "RS", 83)],
//        ["ReadaheadTable", 46, ("AndExpression", "RSN", 72), ("Name", "RSN", 57), ("OpenRound", "RS", 49), ("Alternation", "RSN", 58), ("walkSymbol", "RSN", 59), ("walkString", "RSN", 19), ("SemanticAction", "RSN", 43), ("RepetitionOption", "RSN", 51), ("OpenCurly", "RS", 46), ("Primary", "RSN", 71), ("Byte", "RSN", 61), ("walkCharacter", "RSN", 48), ("Expression", "RSN", 84), ("walkIdentifier", "RSN", 11), ("walkInteger", "RSN", 50), ("Secondary", "RSN", 56), ("Concatenation", "RSN", 53), ("And", "L", 420), ("CloseCurly", "L", 420), ("CloseRound", "L", 420), ("Minus", "L", 420), ("Dot", "L", 420), ("FatRightArrow", "L", 420), ("RightArrow", "L", 420)],
//        ["ReadaheadTable", 47, ("OpenSquare", "RS", 85), ("And", "L", 421), ("Or", "L", 421), ("OpenRound", "L", 421), ("OpenCurly", "L", 421), ("walkCharacter", "L", 421), ("walkInteger", "L", 421), ("walkSymbol", "L", 421), ("walkIdentifier", "L", 421), ("walkString", "L", 421), ("Star", "L", 421), ("QuestionMark", "L", 421), ("Plus", "L", 421), ("CloseCurly", "L", 421), ("CloseRound", "L", 421), ("Minus", "L", 421), ("RightArrow", "L", 421), ("Dot", "L", 421), ("FatRightArrow", "L", 421)],
//        ["ReadaheadTable", 48, ("DotDot", "L", 162), ("walkCharacter", "L", 162), ("walkInteger", "L", 162), ("walkSymbol", "L", 162), ("walkIdentifier", "L", 162), ("walkString", "L", 162), ("CloseSquare", "L", 162), ("And", "L", 162), ("Or", "L", 162), ("OpenRound", "L", 162), ("OpenCurly", "L", 162), ("Star", "L", 162), ("QuestionMark", "L", 162), ("Plus", "L", 162), ("OpenSquare", "L", 162), ("CloseCurly", "L", 162), ("CloseRound", "L", 162), ("Minus", "L", 162), ("Dot", "L", 162), ("FatRightArrow", "L", 162), ("RightArrow", "L", 162)],
//        ["ReadaheadTable", 49, ("walkCharacter", "RSN", 48), ("SemanticAction", "RSN", 43), ("walkInteger", "RSN", 50), ("walkSymbol", "RSN", 47), ("RepetitionOption", "RSN", 60), ("Expression", "RSN", 87), ("Name", "RSN", 57), ("Concatenation", "RSN", 53), ("Primary", "RSN", 71), ("walkString", "RSN", 19), ("OpenRound", "RS", 49), ("Byte", "RSN", 54), ("AndExpression", "RSN", 72), ("walkIdentifier", "RSN", 11), ("Alternation", "RSN", 58), ("Secondary", "RSN", 56), ("OpenCurly", "RS", 46), ("And", "L", 422), ("CloseCurly", "L", 422), ("CloseRound", "L", 422), ("Minus", "L", 422), ("Dot", "L", 422), ("FatRightArrow", "L", 422), ("RightArrow", "L", 422)],
//        ["ReadaheadTable", 50, ("DotDot", "L", 163), ("walkCharacter", "L", 163), ("walkInteger", "L", 163), ("walkSymbol", "L", 163), ("walkIdentifier", "L", 163), ("walkString", "L", 163), ("CloseSquare", "L", 163), ("And", "L", 163), ("Or", "L", 163), ("OpenRound", "L", 163), ("OpenCurly", "L", 163), ("Star", "L", 163), ("QuestionMark", "L", 163), ("Plus", "L", 163), ("OpenSquare", "L", 163), ("CloseCurly", "L", 163), ("CloseRound", "L", 163), ("Minus", "L", 163), ("Dot", "L", 163), ("FatRightArrow", "L", 163), ("RightArrow", "L", 163)],
//        ["ReadaheadTable", 51, ("RepetitionOption", "RSN", 88), ("OpenRound", "RS", 49), ("walkString", "RSN", 19), ("Secondary", "RSN", 56), ("walkSymbol", "RSN", 47), ("Primary", "RSN", 44), ("walkCharacter", "RSN", 48), ("SemanticAction", "RSN", 43), ("walkInteger", "RSN", 50), ("Name", "RSN", 57), ("OpenCurly", "RS", 46), ("walkIdentifier", "RSN", 11), ("Byte", "RSN", 54), ("And", "L", 164), ("Or", "L", 164), ("CloseCurly", "L", 164), ("CloseRound", "L", 164), ("Minus", "L", 164), ("Dot", "L", 164), ("FatRightArrow", "L", 164), ("RightArrow", "L", 164)],
//        ["ReadaheadTable", 52, ("And", "L", 165), ("CloseCurly", "L", 165), ("CloseRound", "L", 165), ("Minus", "L", 165), ("Dot", "L", 165), ("FatRightArrow", "L", 165), ("RightArrow", "L", 165)],
//        ["ReadaheadTable", 53, ("Or", "RS", 89), ("And", "L", 166), ("CloseCurly", "L", 166), ("CloseRound", "L", 166), ("Minus", "L", 166), ("Dot", "L", 166), ("FatRightArrow", "L", 166), ("RightArrow", "L", 166)],
//        ["ReadaheadTable", 54, ("DotDot", "RS", 90), ("And", "L", 167), ("Or", "L", 167), ("OpenRound", "L", 167), ("OpenCurly", "L", 167), ("walkCharacter", "L", 167), ("walkInteger", "L", 167), ("walkSymbol", "L", 167), ("walkIdentifier", "L", 167), ("walkString", "L", 167), ("Star", "L", 167), ("QuestionMark", "L", 167), ("Plus", "L", 167), ("OpenSquare", "L", 167), ("CloseCurly", "L", 167), ("CloseRound", "L", 167), ("Minus", "L", 167), ("Dot", "L", 167), ("FatRightArrow", "L", 167), ("RightArrow", "L", 167)],
//        ["ReadaheadTable", 55, ("Minus", "RS", 91), ("CloseCurly", "L", 168), ("CloseRound", "L", 168), ("Dot", "L", 168), ("FatRightArrow", "L", 168), ("RightArrow", "L", 168)],
//        ["ReadaheadTable", 56, ("OpenSquare", "RS", 92), ("And", "L", 169), ("Or", "L", 169), ("OpenRound", "L", 169), ("OpenCurly", "L", 169), ("walkCharacter", "L", 169), ("walkInteger", "L", 169), ("walkSymbol", "L", 169), ("walkIdentifier", "L", 169), ("walkString", "L", 169), ("Star", "L", 169), ("QuestionMark", "L", 169), ("Plus", "L", 169), ("CloseCurly", "L", 169), ("CloseRound", "L", 169), ("Minus", "L", 169), ("Dot", "L", 169), ("FatRightArrow", "L", 169), ("RightArrow", "L", 169)],
//        ["ReadaheadTable", 57, ("And", "L", 170), ("Or", "L", 170), ("OpenRound", "L", 170), ("OpenCurly", "L", 170), ("walkCharacter", "L", 170), ("walkInteger", "L", 170), ("walkSymbol", "L", 170), ("walkIdentifier", "L", 170), ("walkString", "L", 170), ("Star", "L", 170), ("QuestionMark", "L", 170), ("Plus", "L", 170), ("OpenSquare", "L", 170), ("CloseCurly", "L", 170), ("CloseRound", "L", 170), ("Minus", "L", 170), ("Dot", "L", 170), ("FatRightArrow", "L", 170), ("RightArrow", "L", 170)],
//        ["ReadaheadTable", 58, ("And", "RS", 78), ("CloseCurly", "L", 171), ("CloseRound", "L", 171), ("Minus", "L", 171), ("Dot", "L", 171), ("FatRightArrow", "L", 171), ("RightArrow", "L", 171)],
//        ["ReadaheadTable", 59, ("OpenSquare", "RS", 85), ("And", "L", 423), ("Or", "L", 423), ("OpenRound", "L", 423), ("OpenCurly", "L", 423), ("walkCharacter", "L", 423), ("walkInteger", "L", 423), ("walkSymbol", "L", 423), ("walkIdentifier", "L", 423), ("walkString", "L", 423), ("Star", "L", 423), ("QuestionMark", "L", 423), ("Plus", "L", 423), ("CloseCurly", "L", 423), ("CloseRound", "L", 423), ("Minus", "L", 423), ("RightArrow", "L", 423), ("Dot", "L", 423), ("FatRightArrow", "L", 423)],
//        ["ReadaheadTable", 60, ("RepetitionOption", "RSN", 88), ("OpenRound", "RS", 49), ("walkString", "RSN", 19), ("Secondary", "RSN", 56), ("walkSymbol", "RSN", 47), ("Primary", "RSN", 71), ("walkCharacter", "RSN", 48), ("SemanticAction", "RSN", 43), ("walkInteger", "RSN", 50), ("Name", "RSN", 57), ("OpenCurly", "RS", 46), ("walkIdentifier", "RSN", 11), ("Byte", "RSN", 61), ("And", "L", 172), ("Or", "L", 172), ("CloseCurly", "L", 172), ("CloseRound", "L", 172), ("Minus", "L", 172), ("Dot", "L", 172), ("FatRightArrow", "L", 172), ("RightArrow", "L", 172)],
//        ["ReadaheadTable", 61, ("DotDot", "RS", 90), ("And", "L", 173), ("Or", "L", 173), ("OpenRound", "L", 173), ("OpenCurly", "L", 173), ("walkCharacter", "L", 173), ("walkInteger", "L", 173), ("walkSymbol", "L", 173), ("walkIdentifier", "L", 173), ("walkString", "L", 173), ("Star", "L", 173), ("QuestionMark", "L", 173), ("Plus", "L", 173), ("OpenSquare", "L", 173), ("CloseCurly", "L", 173), ("CloseRound", "L", 173), ("Minus", "L", 173), ("Dot", "L", 173), ("FatRightArrow", "L", 173), ("RightArrow", "L", 173)],
//        ["ReadaheadTable", 62, ("OpenSquare", "RS", 92), ("And", "L", 174), ("Or", "L", 174), ("OpenRound", "L", 174), ("OpenCurly", "L", 174), ("walkCharacter", "L", 174), ("walkInteger", "L", 174), ("walkSymbol", "L", 174), ("walkIdentifier", "L", 174), ("walkString", "L", 174), ("Star", "L", 174), ("QuestionMark", "L", 174), ("Plus", "L", 174), ("CloseCurly", "L", 174), ("CloseRound", "L", 174), ("Minus", "L", 174), ("Dot", "L", 174), ("FatRightArrow", "L", 174), ("RightArrow", "L", 174)],
//        ["ReadaheadTable", 63, ("Dot", "RS", 93)],
//        ["ReadaheadTable", 64, ("Equals", "RS", 28), ("OpenCurly", "RS", 27), ("RightArrow", "L", 424)],
//        ["ReadaheadTable", 65, ("nonterminal", "RS", 32), ("terminal", "RS", 33), ("defaults", "RS", 34)],
//        ["ReadaheadTable", 66, ("walkIdentifier", "RSN", 11), ("walkString", "RSN", 19), ("Name", "RSN", 94)],
//        ["ReadaheadTable", 67, ("walkIdentifier", "RSN", 11), ("walkString", "RSN", 19), ("Name", "RSN", 95)],
//        ["ReadaheadTable", 68, ("walkIdentifier", "RSN", 11), ("Name", "RSN", 68), ("Dot", "RS", 96), ("walkString", "RSN", 19)],
//        ["ReadaheadTable", 69, ("FatRightArrow", "RS", 97), ("RightArrow", "L", 175), ("Dot", "L", 175)],
//        ["ReadaheadTable", 70, ("Or", "RS", 89), ("And", "L", 176), ("CloseCurly", "L", 176), ("CloseRound", "L", 176), ("Minus", "L", 176), ("Dot", "L", 176), ("FatRightArrow", "L", 176), ("RightArrow", "L", 176)],
//        ["ReadaheadTable", 71, ("Plus", "RS", 80), ("QuestionMark", "RS", 81), ("Star", "RS", 82), ("And", "L", 177), ("Or", "L", 177), ("OpenRound", "L", 177), ("OpenCurly", "L", 177), ("walkCharacter", "L", 177), ("walkInteger", "L", 177), ("walkSymbol", "L", 177), ("walkIdentifier", "L", 177), ("walkString", "L", 177), ("CloseCurly", "L", 177), ("CloseRound", "L", 177), ("Minus", "L", 177), ("Dot", "L", 177), ("FatRightArrow", "L", 177), ("RightArrow", "L", 177)],
//        ["ReadaheadTable", 72, ("Minus", "RS", 91), ("CloseCurly", "L", 178), ("CloseRound", "L", 178), ("Dot", "L", 178), ("FatRightArrow", "L", 178), ("RightArrow", "L", 178)],
//        ["ReadaheadTable", 73, ("Dot", "L", 179)],
//        ["ReadaheadTable", 74, ("walkIdentifier", "L", 425), ("walkString", "L", 425), ("-|", "L", 425)],
//        ["ReadaheadTable", 75, ("attribute", "L", 426), ("keywords", "L", 426), ("output", "L", 426), ("optimize", "L", 426), ("walkIdentifier", "L", 426), ("walkString", "L", 426)],
//        ["ReadaheadTable", 76, ("attribute", "L", 180), ("keywords", "L", 180), ("output", "L", 180), ("optimize", "L", 180), ("walkIdentifier", "L", 180), ("walkString", "L", 180)],
//        ["ReadaheadTable", 77, ("attribute", "L", 181), ("keywords", "L", 181), ("output", "L", 181), ("optimize", "L", 181), ("walkIdentifier", "L", 181), ("walkString", "L", 181)],
//        ["ReadaheadTable", 78, ("OpenCurly", "RS", 46), ("walkSymbol", "RSN", 47), ("walkInteger", "RSN", 50), ("Name", "RSN", 57), ("Byte", "RSN", 54), ("Concatenation", "RSN", 70), ("OpenRound", "RS", 49), ("RepetitionOption", "RSN", 60), ("walkString", "RSN", 19), ("Alternation", "RSN", 100), ("walkCharacter", "RSN", 48), ("SemanticAction", "RSN", 43), ("walkIdentifier", "RSN", 11), ("Primary", "RSN", 44), ("Secondary", "RSN", 62), ("And", "L", 427), ("CloseCurly", "L", 427), ("CloseRound", "L", 427), ("Minus", "L", 427), ("Dot", "L", 427), ("FatRightArrow", "L", 427), ("RightArrow", "L", 427)],
//        ["ReadaheadTable", 79, ("And", "L", 182), ("Or", "L", 182), ("OpenRound", "L", 182), ("OpenCurly", "L", 182), ("walkCharacter", "L", 182), ("walkInteger", "L", 182), ("walkSymbol", "L", 182), ("walkIdentifier", "L", 182), ("walkString", "L", 182), ("Star", "L", 182), ("QuestionMark", "L", 182), ("Plus", "L", 182), ("CloseCurly", "L", 182), ("CloseRound", "L", 182), ("Minus", "L", 182), ("Dot", "L", 182), ("FatRightArrow", "L", 182), ("RightArrow", "L", 182)],
//        ["ReadaheadTable", 80, ("And", "L", 428), ("Or", "L", 428), ("OpenRound", "L", 428), ("OpenCurly", "L", 428), ("walkCharacter", "L", 428), ("walkInteger", "L", 428), ("walkSymbol", "L", 428), ("walkIdentifier", "L", 428), ("walkString", "L", 428), ("CloseCurly", "L", 428), ("CloseRound", "L", 428), ("Minus", "L", 428), ("Dot", "L", 428), ("FatRightArrow", "L", 428), ("RightArrow", "L", 428)],
//        ["ReadaheadTable", 81, ("And", "L", 429), ("Or", "L", 429), ("OpenRound", "L", 429), ("OpenCurly", "L", 429), ("walkCharacter", "L", 429), ("walkInteger", "L", 429), ("walkSymbol", "L", 429), ("walkIdentifier", "L", 429), ("walkString", "L", 429), ("CloseCurly", "L", 429), ("CloseRound", "L", 429), ("Minus", "L", 429), ("Dot", "L", 429), ("FatRightArrow", "L", 429), ("RightArrow", "L", 429)],
//        ["ReadaheadTable", 82, ("And", "L", 430), ("Or", "L", 430), ("OpenRound", "L", 430), ("OpenCurly", "L", 430), ("walkCharacter", "L", 430), ("walkInteger", "L", 430), ("walkSymbol", "L", 430), ("walkIdentifier", "L", 430), ("walkString", "L", 430), ("CloseCurly", "L", 430), ("CloseRound", "L", 430), ("Minus", "L", 430), ("Dot", "L", 430), ("FatRightArrow", "L", 430), ("RightArrow", "L", 430)],
//        ["ReadaheadTable", 83, ("RightArrow", "L", 431)],
//        ["ReadaheadTable", 84, ("CloseCurly", "RS", 105)],
//        ["ReadaheadTable", 85, ("walkString", "RSN", 19), ("CloseSquare", "RS", 106), ("walkInteger", "RSN", 50), ("walkCharacter", "RSN", 48), ("walkIdentifier", "RSN", 11), ("SemanticActionParameter", "RSN", 107), ("Byte", "RSN", 108), ("walkSymbol", "RSN", 109), ("Name", "RSN", 110)],
//        ["ReadaheadTable", 86, ("And", "L", 183), ("Or", "L", 183), ("OpenRound", "L", 183), ("OpenCurly", "L", 183), ("walkCharacter", "L", 183), ("walkInteger", "L", 183), ("walkSymbol", "L", 183), ("walkIdentifier", "L", 183), ("walkString", "L", 183), ("Star", "L", 183), ("QuestionMark", "L", 183), ("Plus", "L", 183), ("CloseCurly", "L", 183), ("CloseRound", "L", 183), ("Minus", "L", 183), ("RightArrow", "L", 183), ("Dot", "L", 183), ("FatRightArrow", "L", 183)],
//        ["ReadaheadTable", 87, ("CloseRound", "RS", 111)],
//        ["ReadaheadTable", 88, ("RepetitionOption", "RSN", 88), ("OpenRound", "RS", 49), ("walkString", "RSN", 19), ("Secondary", "RSN", 62), ("walkSymbol", "RSN", 47), ("Primary", "RSN", 44), ("walkCharacter", "RSN", 48), ("SemanticAction", "RSN", 43), ("walkInteger", "RSN", 50), ("Name", "RSN", 57), ("OpenCurly", "RS", 46), ("walkIdentifier", "RSN", 11), ("Byte", "RSN", 61), ("And", "L", 432), ("Or", "L", 432), ("CloseCurly", "L", 432), ("CloseRound", "L", 432), ("Minus", "L", 432), ("Dot", "L", 432), ("FatRightArrow", "L", 432), ("RightArrow", "L", 432)],
//        ["ReadaheadTable", 89, ("RepetitionOption", "RSN", 51), ("OpenRound", "RS", 49), ("walkString", "RSN", 19), ("Secondary", "RSN", 62), ("walkSymbol", "RSN", 59), ("Primary", "RSN", 113), ("walkCharacter", "RSN", 48), ("SemanticAction", "RSN", 43), ("walkInteger", "RSN", 50), ("Name", "RSN", 57), ("OpenCurly", "RS", 46), ("walkIdentifier", "RSN", 11), ("Byte", "RSN", 61), ("Concatenation", "RSN", 114)],
//        ["ReadaheadTable", 90, ("Byte", "RSN", 115), ("walkInteger", "RSN", 50), ("walkCharacter", "RSN", 48)],
//        ["ReadaheadTable", 91, ("AndExpression", "RSN", 116), ("walkSymbol", "RSN", 47), ("OpenCurly", "RS", 46), ("walkInteger", "RSN", 50), ("Name", "RSN", 57), ("OpenRound", "RS", 49), ("Concatenation", "RSN", 53), ("RepetitionOption", "RSN", 60), ("Byte", "RSN", 61), ("walkString", "RSN", 19), ("Alternation", "RSN", 42), ("walkCharacter", "RSN", 48), ("SemanticAction", "RSN", 43), ("walkIdentifier", "RSN", 11), ("Primary", "RSN", 44), ("Secondary", "RSN", 56), ("And", "L", 433), ("CloseCurly", "L", 433), ("CloseRound", "L", 433), ("Minus", "L", 433), ("Dot", "L", 433), ("FatRightArrow", "L", 433), ("RightArrow", "L", 433)],
//        ["ReadaheadTable", 92, ("noStack", "RSN", 117), ("node", "RSN", 118), ("noNode", "RSN", 119), ("read", "RSN", 120), ("look", "RSN", 121), ("stack", "RSN", 122), ("Attribute", "RSN", 123), ("CloseSquare", "RS", 124), ("noKeep", "RSN", 125), ("keep", "RSN", 126)],
//        ["ReadaheadTable", 93, ("walkIdentifier", "L", 434), ("walkString", "L", 434), ("-|", "L", 434)],
//        ["ReadaheadTable", 94, ("walkIdentifier", "RSN", 11), ("Dot", "RS", 128), ("walkString", "RSN", 19), ("Name", "RSN", 94)],
//        ["ReadaheadTable", 95, ("walkIdentifier", "RSN", 11), ("Dot", "RS", 129), ("walkString", "RSN", 19), ("Name", "RSN", 95)],
//        ["ReadaheadTable", 96, ("attribute", "L", 435), ("keywords", "L", 435), ("output", "L", 435), ("optimize", "L", 435), ("walkIdentifier", "L", 435), ("walkString", "L", 435)],
//        ["ReadaheadTable", 97, ("walkString", "RSN", 19), ("TreeBuildingOptions", "RSN", 131), ("Minus", "RS", 132), ("walkSymbol", "RSN", 59), ("walkIdentifier", "RSN", 11), ("Name", "RSN", 133), ("walkInteger", "RSN", 134), ("SemanticAction", "RSN", 135), ("Plus", "RS", 136)],
//        ["ReadaheadTable", 98, ("walkIdentifier", "L", 184), ("walkString", "L", 184), ("-|", "L", 184)],
//        ["ReadaheadTable", 99, ("attribute", "L", 185), ("keywords", "L", 185), ("output", "L", 185), ("optimize", "L", 185), ("walkIdentifier", "L", 185), ("walkString", "L", 185)],
//        ["ReadaheadTable", 100, ("CloseCurly", "L", 436), ("CloseRound", "L", 436), ("Minus", "L", 436), ("Dot", "L", 436), ("FatRightArrow", "L", 436), ("RightArrow", "L", 436)],
//        ["ReadaheadTable", 101, ("And", "L", 186), ("Or", "L", 186), ("OpenRound", "L", 186), ("OpenCurly", "L", 186), ("walkCharacter", "L", 186), ("walkInteger", "L", 186), ("walkSymbol", "L", 186), ("walkIdentifier", "L", 186), ("walkString", "L", 186), ("CloseCurly", "L", 186), ("CloseRound", "L", 186), ("Minus", "L", 186), ("Dot", "L", 186), ("FatRightArrow", "L", 186), ("RightArrow", "L", 186)],
//        ["ReadaheadTable", 102, ("And", "L", 187), ("Or", "L", 187), ("OpenRound", "L", 187), ("OpenCurly", "L", 187), ("walkCharacter", "L", 187), ("walkInteger", "L", 187), ("walkSymbol", "L", 187), ("walkIdentifier", "L", 187), ("walkString", "L", 187), ("CloseCurly", "L", 187), ("CloseRound", "L", 187), ("Minus", "L", 187), ("Dot", "L", 187), ("FatRightArrow", "L", 187), ("RightArrow", "L", 187)],
//        ["ReadaheadTable", 103, ("And", "L", 188), ("Or", "L", 188), ("OpenRound", "L", 188), ("OpenCurly", "L", 188), ("walkCharacter", "L", 188), ("walkInteger", "L", 188), ("walkSymbol", "L", 188), ("walkIdentifier", "L", 188), ("walkString", "L", 188), ("CloseCurly", "L", 188), ("CloseRound", "L", 188), ("Minus", "L", 188), ("Dot", "L", 188), ("FatRightArrow", "L", 188), ("RightArrow", "L", 188)],
//        ["ReadaheadTable", 104, ("RightArrow", "L", 189)],
//        ["ReadaheadTable", 105, ("And", "L", 437), ("Or", "L", 437), ("OpenRound", "L", 437), ("OpenCurly", "L", 437), ("walkCharacter", "L", 437), ("walkInteger", "L", 437), ("walkSymbol", "L", 437), ("walkIdentifier", "L", 437), ("walkString", "L", 437), ("Star", "L", 437), ("QuestionMark", "L", 437), ("Plus", "L", 437), ("OpenSquare", "L", 437), ("CloseCurly", "L", 437), ("CloseRound", "L", 437), ("Minus", "L", 437), ("Dot", "L", 437), ("FatRightArrow", "L", 437), ("RightArrow", "L", 437)],
//        ["ReadaheadTable", 106, ("And", "L", 438), ("Or", "L", 438), ("OpenRound", "L", 438), ("OpenCurly", "L", 438), ("walkCharacter", "L", 438), ("walkInteger", "L", 438), ("walkSymbol", "L", 438), ("walkIdentifier", "L", 438), ("walkString", "L", 438), ("Star", "L", 438), ("QuestionMark", "L", 438), ("Plus", "L", 438), ("CloseCurly", "L", 438), ("CloseRound", "L", 438), ("Minus", "L", 438), ("RightArrow", "L", 438), ("Dot", "L", 438), ("FatRightArrow", "L", 438)],
//        ["ReadaheadTable", 107, ("walkInteger", "RSN", 50), ("walkCharacter", "RSN", 48), ("CloseSquare", "RS", 106), ("Name", "RSN", 110), ("walkSymbol", "RSN", 109), ("Byte", "RSN", 108), ("walkString", "RSN", 19), ("walkIdentifier", "RSN", 11), ("SemanticActionParameter", "RSN", 107)],
//        ["ReadaheadTable", 108, ("walkCharacter", "L", 190), ("walkInteger", "L", 190), ("walkSymbol", "L", 190), ("walkIdentifier", "L", 190), ("walkString", "L", 190), ("CloseSquare", "L", 190)],
//        ["ReadaheadTable", 109, ("walkCharacter", "L", 191), ("walkInteger", "L", 191), ("walkSymbol", "L", 191), ("walkIdentifier", "L", 191), ("walkString", "L", 191), ("CloseSquare", "L", 191)],
//        ["ReadaheadTable", 110, ("walkCharacter", "L", 192), ("walkInteger", "L", 192), ("walkSymbol", "L", 192), ("walkIdentifier", "L", 192), ("walkString", "L", 192), ("CloseSquare", "L", 192)],
//        ["ReadaheadTable", 111, ("And", "L", 193), ("Or", "L", 193), ("OpenRound", "L", 193), ("OpenCurly", "L", 193), ("walkCharacter", "L", 193), ("walkInteger", "L", 193), ("walkSymbol", "L", 193), ("walkIdentifier", "L", 193), ("walkString", "L", 193), ("Star", "L", 193), ("QuestionMark", "L", 193), ("Plus", "L", 193), ("OpenSquare", "L", 193), ("CloseCurly", "L", 193), ("CloseRound", "L", 193), ("Minus", "L", 193), ("Dot", "L", 193), ("FatRightArrow", "L", 193), ("RightArrow", "L", 193)],
//        ["ReadaheadTable", 112, ("And", "L", 194), ("Or", "L", 194), ("CloseCurly", "L", 194), ("CloseRound", "L", 194), ("Minus", "L", 194), ("Dot", "L", 194), ("FatRightArrow", "L", 194), ("RightArrow", "L", 194)],
//        ["ReadaheadTable", 113, ("Plus", "RS", 80), ("QuestionMark", "RS", 81), ("Star", "RS", 82), ("And", "L", 195), ("Or", "L", 195), ("OpenRound", "L", 195), ("OpenCurly", "L", 195), ("walkCharacter", "L", 195), ("walkInteger", "L", 195), ("walkSymbol", "L", 195), ("walkIdentifier", "L", 195), ("walkString", "L", 195), ("CloseCurly", "L", 195), ("CloseRound", "L", 195), ("Minus", "L", 195), ("Dot", "L", 195), ("FatRightArrow", "L", 195), ("RightArrow", "L", 195)],
//        ["ReadaheadTable", 114, ("Or", "RS", 89), ("And", "L", 439), ("CloseCurly", "L", 439), ("CloseRound", "L", 439), ("Minus", "L", 439), ("Dot", "L", 439), ("FatRightArrow", "L", 439), ("RightArrow", "L", 439)],
//        ["ReadaheadTable", 115, ("And", "L", 440), ("Or", "L", 440), ("OpenRound", "L", 440), ("OpenCurly", "L", 440), ("walkCharacter", "L", 440), ("walkInteger", "L", 440), ("walkSymbol", "L", 440), ("walkIdentifier", "L", 440), ("walkString", "L", 440), ("Star", "L", 440), ("QuestionMark", "L", 440), ("Plus", "L", 440), ("OpenSquare", "L", 440), ("CloseCurly", "L", 440), ("CloseRound", "L", 440), ("Minus", "L", 440), ("Dot", "L", 440), ("FatRightArrow", "L", 440), ("RightArrow", "L", 440)],
//        ["ReadaheadTable", 116, ("CloseCurly", "L", 441), ("CloseRound", "L", 441), ("Dot", "L", 441), ("FatRightArrow", "L", 441), ("RightArrow", "L", 441)],
//        ["ReadaheadTable", 117, ("stack", "L", 196), ("noStack", "L", 196), ("read", "L", 196), ("look", "L", 196), ("node", "L", 196), ("noNode", "L", 196), ("keep", "L", 196), ("noKeep", "L", 196), ("CloseSquare", "L", 196)],
//        ["ReadaheadTable", 118, ("stack", "L", 197), ("noStack", "L", 197), ("read", "L", 197), ("look", "L", 197), ("node", "L", 197), ("noNode", "L", 197), ("keep", "L", 197), ("noKeep", "L", 197), ("CloseSquare", "L", 197)],
//        ["ReadaheadTable", 119, ("stack", "L", 198), ("noStack", "L", 198), ("read", "L", 198), ("look", "L", 198), ("node", "L", 198), ("noNode", "L", 198), ("keep", "L", 198), ("noKeep", "L", 198), ("CloseSquare", "L", 198)],
//        ["ReadaheadTable", 120, ("stack", "L", 199), ("noStack", "L", 199), ("read", "L", 199), ("look", "L", 199), ("node", "L", 199), ("noNode", "L", 199), ("keep", "L", 199), ("noKeep", "L", 199), ("CloseSquare", "L", 199)],
//        ["ReadaheadTable", 121, ("stack", "L", 200), ("noStack", "L", 200), ("read", "L", 200), ("look", "L", 200), ("node", "L", 200), ("noNode", "L", 200), ("keep", "L", 200), ("noKeep", "L", 200), ("CloseSquare", "L", 200)],
//        ["ReadaheadTable", 122, ("stack", "L", 201), ("noStack", "L", 201), ("read", "L", 201), ("look", "L", 201), ("node", "L", 201), ("noNode", "L", 201), ("keep", "L", 201), ("noKeep", "L", 201), ("CloseSquare", "L", 201)],
//        ["ReadaheadTable", 123, ("noStack", "RSN", 117), ("node", "RSN", 118), ("read", "RSN", 120), ("noNode", "RSN", 119), ("look", "RSN", 121), ("stack", "RSN", 122), ("CloseSquare", "RS", 124), ("Attribute", "RSN", 123), ("noKeep", "RSN", 125), ("keep", "RSN", 126)],
//        ["ReadaheadTable", 124, ("And", "L", 442), ("Or", "L", 442), ("OpenRound", "L", 442), ("OpenCurly", "L", 442), ("walkCharacter", "L", 442), ("walkInteger", "L", 442), ("walkSymbol", "L", 442), ("walkIdentifier", "L", 442), ("walkString", "L", 442), ("Star", "L", 442), ("QuestionMark", "L", 442), ("Plus", "L", 442), ("CloseCurly", "L", 442), ("CloseRound", "L", 442), ("Minus", "L", 442), ("Dot", "L", 442), ("FatRightArrow", "L", 442), ("RightArrow", "L", 442)],
//        ["ReadaheadTable", 125, ("stack", "L", 202), ("noStack", "L", 202), ("read", "L", 202), ("look", "L", 202), ("node", "L", 202), ("noNode", "L", 202), ("keep", "L", 202), ("noKeep", "L", 202), ("CloseSquare", "L", 202)],
//        ["ReadaheadTable", 126, ("stack", "L", 203), ("noStack", "L", 203), ("read", "L", 203), ("look", "L", 203), ("node", "L", 203), ("noNode", "L", 203), ("keep", "L", 203), ("noKeep", "L", 203), ("CloseSquare", "L", 203)],
//        ["ReadaheadTable", 127, ("walkIdentifier", "L", 204), ("walkString", "L", 204), ("-|", "L", 204)],
//        ["ReadaheadTable", 128, ("attribute", "L", 443), ("keywords", "L", 443), ("output", "L", 443), ("optimize", "L", 443), ("walkIdentifier", "L", 443), ("walkString", "L", 443)],
//        ["ReadaheadTable", 129, ("attribute", "L", 444), ("keywords", "L", 444), ("output", "L", 444), ("optimize", "L", 444), ("walkIdentifier", "L", 444), ("walkString", "L", 444)],
//        ["ReadaheadTable", 130, ("attribute", "L", 205), ("keywords", "L", 205), ("output", "L", 205), ("optimize", "L", 205), ("walkIdentifier", "L", 205), ("walkString", "L", 205)],
//        ["ReadaheadTable", 131, ("RightArrow", "L", 445), ("Dot", "L", 445)],
//        ["ReadaheadTable", 132, ("walkInteger", "RSN", 147)],
//        ["ReadaheadTable", 133, ("RightArrow", "L", 446), ("Dot", "L", 446)],
//        ["ReadaheadTable", 134, ("RightArrow", "L", 447), ("Dot", "L", 447)],
//        ["ReadaheadTable", 135, ("RightArrow", "L", 448), ("Dot", "L", 448)],
//        ["ReadaheadTable", 136, ("walkInteger", "RSN", 134)],
//        ["ReadaheadTable", 137, ("CloseCurly", "L", 206), ("CloseRound", "L", 206), ("Minus", "L", 206), ("Dot", "L", 206), ("FatRightArrow", "L", 206), ("RightArrow", "L", 206)],
//        ["ReadaheadTable", 138, ("And", "L", 207), ("Or", "L", 207), ("OpenRound", "L", 207), ("OpenCurly", "L", 207), ("walkCharacter", "L", 207), ("walkInteger", "L", 207), ("walkSymbol", "L", 207), ("walkIdentifier", "L", 207), ("walkString", "L", 207), ("Star", "L", 207), ("QuestionMark", "L", 207), ("Plus", "L", 207), ("OpenSquare", "L", 207), ("CloseCurly", "L", 207), ("CloseRound", "L", 207), ("Minus", "L", 207), ("Dot", "L", 207), ("FatRightArrow", "L", 207), ("RightArrow", "L", 207)],
//        ["ReadaheadTable", 139, ("And", "L", 208), ("Or", "L", 208), ("OpenRound", "L", 208), ("OpenCurly", "L", 208), ("walkCharacter", "L", 208), ("walkInteger", "L", 208), ("walkSymbol", "L", 208), ("walkIdentifier", "L", 208), ("walkString", "L", 208), ("Star", "L", 208), ("QuestionMark", "L", 208), ("Plus", "L", 208), ("CloseCurly", "L", 208), ("CloseRound", "L", 208), ("Minus", "L", 208), ("RightArrow", "L", 208), ("Dot", "L", 208), ("FatRightArrow", "L", 208)],
//        ["ReadaheadTable", 140, ("And", "L", 209), ("CloseCurly", "L", 209), ("CloseRound", "L", 209), ("Minus", "L", 209), ("Dot", "L", 209), ("FatRightArrow", "L", 209), ("RightArrow", "L", 209)],
//        ["ReadaheadTable", 141, ("And", "L", 210), ("Or", "L", 210), ("OpenRound", "L", 210), ("OpenCurly", "L", 210), ("walkCharacter", "L", 210), ("walkInteger", "L", 210), ("walkSymbol", "L", 210), ("walkIdentifier", "L", 210), ("walkString", "L", 210), ("Star", "L", 210), ("QuestionMark", "L", 210), ("Plus", "L", 210), ("OpenSquare", "L", 210), ("CloseCurly", "L", 210), ("CloseRound", "L", 210), ("Minus", "L", 210), ("Dot", "L", 210), ("FatRightArrow", "L", 210), ("RightArrow", "L", 210)],
//        ["ReadaheadTable", 142, ("CloseCurly", "L", 211), ("CloseRound", "L", 211), ("Dot", "L", 211), ("FatRightArrow", "L", 211), ("RightArrow", "L", 211)],
//        ["ReadaheadTable", 143, ("And", "L", 212), ("Or", "L", 212), ("OpenRound", "L", 212), ("OpenCurly", "L", 212), ("walkCharacter", "L", 212), ("walkInteger", "L", 212), ("walkSymbol", "L", 212), ("walkIdentifier", "L", 212), ("walkString", "L", 212), ("Star", "L", 212), ("QuestionMark", "L", 212), ("Plus", "L", 212), ("CloseCurly", "L", 212), ("CloseRound", "L", 212), ("Minus", "L", 212), ("Dot", "L", 212), ("FatRightArrow", "L", 212), ("RightArrow", "L", 212)],
//        ["ReadaheadTable", 144, ("attribute", "L", 213), ("keywords", "L", 213), ("output", "L", 213), ("optimize", "L", 213), ("walkIdentifier", "L", 213), ("walkString", "L", 213)],
//        ["ReadaheadTable", 145, ("attribute", "L", 214), ("keywords", "L", 214), ("output", "L", 214), ("optimize", "L", 214), ("walkIdentifier", "L", 214), ("walkString", "L", 214)],
//        ["ReadaheadTable", 146, ("RightArrow", "L", 215), ("Dot", "L", 215)],
//        ["ReadaheadTable", 147, ("RightArrow", "L", 449), ("Dot", "L", 449)],
//        ["ReadaheadTable", 148, ("RightArrow", "L", 216), ("Dot", "L", 216)],
//        ["ReadaheadTable", 149, ("RightArrow", "L", 217), ("Dot", "L", 217)],
//        ["ReadaheadTable", 150, ("RightArrow", "L", 218), ("Dot", "L", 218)],
//        ["ReadaheadTable", 151, ("RightArrow", "L", 219), ("Dot", "L", 219)],
//        ["ReadbackTable", 152, (("scanner", 2), "RS", 220)],
//        ["ReadbackTable", 153, (("parser", 3), "RS", 221)],
//        ["ReadbackTable", 154, (("walkIdentifier", 11), "RSN", 222)],
//        ["ReadbackTable", 155, (("walkString", 19), "RSN", 223)],
//        ["ReadbackTable", 156, (("superScanner", 6), "RS", 224)],
//        ["ReadbackTable", 157, (("Macro", 9), "RSN", 225), (("Production", 15), "RSN", 226)],
//        ["ReadbackTable", 158, (("Name", 24), "RSN", 227), (("Name", 30), "RSN", 228), (("Name", 14), "RSN", 229), (("Name", 64), "RSN", 230)],
//        ["ReadbackTable", 159, (("scanner", 21), "RS", 231)],
//        ["ReadbackTable", 160, (("Alternation", 42), "RSN", 232)],
//        ["ReadbackTable", 161, (("Primary", 44), "RSN", 233)],
//        ["ReadbackTable", 162, (("walkCharacter", 48), "RSN", 234)],
//        ["ReadbackTable", 163, (("walkInteger", 50), "RSN", 235)],
//        ["ReadbackTable", 164, (("RepetitionOption", 51), "RSN", 236)],
//        ["ReadbackTable", 165, (("OpenCurly", 46), "L", 400), (("RightArrow", 35), "L", 400), (("And", 78), "L", 400), (("Minus", 91), "L", 400), (("OpenRound", 49), "L", 400), (("Equals", 28), "L", 400), (("OpenCurly", 27), "L", 400)],
//        ["ReadbackTable", 166, (("Concatenation", 53), "RSN", 237)],
//        ["ReadbackTable", 167, (("Byte", 54), "RSN", 238)],
//        ["ReadbackTable", 168, (("AndExpression", 55), "RSN", 239)],
//        ["ReadbackTable", 169, (("Secondary", 56), "RSN", 240)],
//        ["ReadbackTable", 170, (("Name", 57), "RSN", 241)],
//        ["ReadbackTable", 171, (("Alternation", 58), "RSN", 242)],
//        ["ReadbackTable", 172, (("RepetitionOption", 60), "RSN", 243)],
//        ["ReadbackTable", 173, (("Byte", 61), "RSN", 244)],
//        ["ReadbackTable", 174, (("Secondary", 62), "RSN", 245)],
//        ["ReadbackTable", 175, (("Expression", 69), "RSN", 246)],
//        ["ReadbackTable", 176, (("Concatenation", 70), "RSN", 247)],
//        ["ReadbackTable", 177, (("Primary", 71), "RSN", 248)],
//        ["ReadbackTable", 178, (("AndExpression", 72), "RSN", 249)],
//        ["ReadbackTable", 179, (("RightPart", 36), "RSN", 250)],
//        ["ReadbackTable", 180, (("Dot", 40), "RS", 251)],
//        ["ReadbackTable", 181, (("Dot", 41), "RS", 252)],
//        ["ReadbackTable", 182, (("SemanticAction", 43), "RSN", 253)],
//        ["ReadbackTable", 183, (("walkSymbol", 47), "RSN", 254), (("walkSymbol", 59), "RSN", 255)],
//        ["ReadbackTable", 184, (("Dot", 74), "RS", 256)],
//        ["ReadbackTable", 185, (("Dot", 75), "RS", 257)],
//        ["ReadbackTable", 186, (("Plus", 80), "RS", 258)],
//        ["ReadbackTable", 187, (("QuestionMark", 81), "RS", 259)],
//        ["ReadbackTable", 188, (("Star", 82), "RS", 260)],
//        ["ReadbackTable", 189, (("CloseCurly", 83), "RS", 261)],
//        ["ReadbackTable", 190, (("Byte", 108), "RSN", 262)],
//        ["ReadbackTable", 191, (("walkSymbol", 109), "RSN", 263)],
//        ["ReadbackTable", 192, (("Name", 110), "RSN", 264)],
//        ["ReadbackTable", 193, (("CloseRound", 111), "RS", 265)],
//        ["ReadbackTable", 194, (("RepetitionOption", 88), "RSN", 266)],
//        ["ReadbackTable", 195, (("Primary", 113), "RSN", 267)],
//        ["ReadbackTable", 196, (("noStack", 117), "RSN", 268)],
//        ["ReadbackTable", 197, (("node", 118), "RSN", 269)],
//        ["ReadbackTable", 198, (("noNode", 119), "RSN", 270)],
//        ["ReadbackTable", 199, (("read", 120), "RSN", 271)],
//        ["ReadbackTable", 200, (("look", 121), "RSN", 272)],
//        ["ReadbackTable", 201, (("stack", 122), "RSN", 273)],
//        ["ReadbackTable", 202, (("noKeep", 125), "RSN", 274)],
//        ["ReadbackTable", 203, (("keep", 126), "RSN", 275)],
//        ["ReadbackTable", 204, (("Dot", 93), "RS", 276)],
//        ["ReadbackTable", 205, (("Dot", 96), "RS", 277)],
//        ["ReadbackTable", 206, (("Alternation", 100), "RSN", 278)],
//        ["ReadbackTable", 207, (("CloseCurly", 105), "RS", 279)],
//        ["ReadbackTable", 208, (("CloseSquare", 106), "RS", 280)],
//        ["ReadbackTable", 209, (("Concatenation", 114), "RSN", 281)],
//        ["ReadbackTable", 210, (("Byte", 115), "RSN", 282)],
//        ["ReadbackTable", 211, (("AndExpression", 116), "RSN", 283)],
//        ["ReadbackTable", 212, (("CloseSquare", 124), "RS", 284)],
//        ["ReadbackTable", 213, (("Dot", 128), "RS", 285)],
//        ["ReadbackTable", 214, (("Dot", 129), "RS", 286)],
//        ["ReadbackTable", 215, (("TreeBuildingOptions", 131), "RSN", 287)],
//        ["ReadbackTable", 216, (("Name", 133), "RSN", 288)],
//        ["ReadbackTable", 217, (("walkInteger", 134), "RSN", 289)],
//        ["ReadbackTable", 218, (("SemanticAction", 135), "RSN", 290)],
//        ["ReadbackTable", 219, (("walkInteger", 147), "RSN", 291)],
//        ["ReadbackTable", 220, (("|-", 1), "L", 391)],
//        ["ReadbackTable", 221, (("|-", 1), "L", 391)],
//        ["ReadbackTable", 222, (("Macro", 9), "L", 402), (("defaults", 66), "L", 402), (("Name", 25), "L", 402), (("OpenRound", 49), "L", 402), (("defaults", 67), "L", 402), (("Name", 94), "L", 402), (("RightArrow", 35), "L", 402), (("keywords", 10), "L", 402), (("FatRightArrow", 97), "L", 402), (("Name", 95), "L", 402), (("SemanticActionParameter", 107), "L", 402), (("Or", 89), "L", 402), (("Minus", 91), "L", 402), (("defaults", 34), "L", 402), (("OpenCurly", 46), "L", 402), (("OpenCurly", 27), "L", 402), (("OpenSquare", 85), "L", 402), (("Equals", 28), "L", 402), (("optimize", 12), "L", 402), (("Production", 15), "L", 402), (("RepetitionOption", 88), "L", 402), (("GrammarType", 4), "L", 402), (("RepetitionOption", 60), "L", 402), (("Defaults", 16), "L", 402), (("RepetitionOption", 51), "L", 402), (("And", 78), "L", 402), (("output", 20), "L", 402), (("Name", 68), "L", 402)],
//        ["ReadbackTable", 223, (("OpenCurly", 27), "L", 402), (("OpenRound", 49), "L", 402), (("Production", 15), "L", 402), (("SemanticActionParameter", 107), "L", 402), (("OpenSquare", 85), "L", 402), (("RepetitionOption", 60), "L", 402), (("GrammarType", 4), "L", 402), (("Name", 94), "L", 402), (("RepetitionOption", 51), "L", 402), (("Name", 25), "L", 402), (("OpenCurly", 46), "L", 402), (("output", 20), "L", 402), (("Defaults", 16), "L", 402), (("RightArrow", 35), "L", 402), (("Or", 89), "L", 402), (("Name", 95), "L", 402), (("defaults", 67), "L", 402), (("Minus", 91), "L", 402), (("defaults", 66), "L", 402), (("Name", 68), "L", 402), (("And", 78), "L", 402), (("optimize", 12), "L", 402), (("defaults", 34), "L", 402), (("FatRightArrow", 97), "L", 402), (("RepetitionOption", 88), "L", 402), (("Macro", 9), "L", 402), (("keywords", 10), "L", 402), (("Equals", 28), "L", 402)],
//        ["ReadbackTable", 224, (("|-", 1), "L", 391)],
//        ["ReadbackTable", 225, (("Production", 15), "RSN", 292), (("Macro", 9), "RSN", 293), (("Defaults", 16), "L", 401), (("GrammarType", 4), "L", 401)],
//        ["ReadbackTable", 226, (("Production", 15), "RSN", 292), (("Macro", 9), "RSN", 293), (("Defaults", 16), "L", 401), (("GrammarType", 4), "L", 401)],
//        ["ReadbackTable", 227, (("Macro", 9), "L", 393)],
//        ["ReadbackTable", 228, (("Production", 15), "L", 393)],
//        ["ReadbackTable", 229, (("GrammarType", 4), "L", 393)],
//        ["ReadbackTable", 230, (("Defaults", 16), "L", 393)],
//        ["ReadbackTable", 231, (("super", 5), "RS", 294)],
//        ["ReadbackTable", 232, (("OpenCurly", 27), "L", 388), (("Minus", 91), "L", 388)],
//        ["ReadbackTable", 233, (("RepetitionOption", 51), "L", 392), (("RepetitionOption", 88), "L", 392), (("OpenCurly", 27), "L", 392), (("Equals", 28), "L", 392), (("Minus", 91), "L", 392), (("And", 78), "L", 392)],
//        ["ReadbackTable", 234, (("OpenSquare", 85), "L", 385), (("DotDot", 90), "L", 385), (("Equals", 28), "L", 385), (("RepetitionOption", 51), "L", 385), (("RepetitionOption", 88), "L", 385), (("And", 78), "L", 385), (("RepetitionOption", 60), "L", 385), (("OpenRound", 49), "L", 385), (("SemanticActionParameter", 107), "L", 385), (("Minus", 91), "L", 385), (("OpenCurly", 27), "L", 385), (("Or", 89), "L", 385), (("OpenCurly", 46), "L", 385), (("RightArrow", 35), "L", 385)],
//        ["ReadbackTable", 235, (("OpenSquare", 85), "L", 385), (("DotDot", 90), "L", 385), (("Equals", 28), "L", 385), (("RepetitionOption", 51), "L", 385), (("RepetitionOption", 88), "L", 385), (("And", 78), "L", 385), (("RepetitionOption", 60), "L", 385), (("OpenRound", 49), "L", 385), (("SemanticActionParameter", 107), "L", 385), (("Minus", 91), "L", 385), (("OpenCurly", 27), "L", 385), (("Or", 89), "L", 385), (("OpenCurly", 46), "L", 385), (("RightArrow", 35), "L", 385)],
//        ["ReadbackTable", 236, (("OpenCurly", 27), "L", 386), (("OpenCurly", 46), "L", 386), (("Or", 89), "L", 386)],
//        ["ReadbackTable", 237, (("OpenCurly", 46), "L", 400), (("OpenRound", 49), "L", 400), (("OpenCurly", 27), "L", 400), (("Equals", 28), "L", 400), (("Minus", 91), "L", 400)],
//        ["ReadbackTable", 238, (("RepetitionOption", 51), "L", 396), (("OpenRound", 49), "L", 396), (("OpenCurly", 27), "L", 396), (("And", 78), "L", 396)],
//        ["ReadbackTable", 239, (("Equals", 28), "L", 383), (("OpenCurly", 27), "L", 383)],
//        ["ReadbackTable", 240, (("RepetitionOption", 60), "L", 387), (("OpenCurly", 46), "L", 387), (("OpenRound", 49), "L", 387), (("OpenCurly", 27), "L", 387), (("RepetitionOption", 51), "L", 387), (("Minus", 91), "L", 387)],
//        ["ReadbackTable", 241, (("Minus", 91), "L", 396), (("Or", 89), "L", 396), (("OpenRound", 49), "L", 396), (("OpenCurly", 46), "L", 396), (("RepetitionOption", 60), "L", 396), (("OpenCurly", 27), "L", 396), (("RepetitionOption", 88), "L", 396), (("Equals", 28), "L", 396), (("RightArrow", 35), "L", 396), (("And", 78), "L", 396), (("RepetitionOption", 51), "L", 396)],
//        ["ReadbackTable", 242, (("RightArrow", 35), "L", 388), (("OpenCurly", 46), "L", 388), (("OpenRound", 49), "L", 388), (("Equals", 28), "L", 388)],
//        ["ReadbackTable", 243, (("RightArrow", 35), "L", 386), (("Minus", 91), "L", 386), (("OpenRound", 49), "L", 386), (("And", 78), "L", 386), (("Equals", 28), "L", 386)],
//        ["ReadbackTable", 244, (("Or", 89), "L", 396), (("OpenCurly", 46), "L", 396), (("RepetitionOption", 60), "L", 396), (("RepetitionOption", 88), "L", 396), (("Equals", 28), "L", 396), (("RightArrow", 35), "L", 396), (("Minus", 91), "L", 396)],
//        ["ReadbackTable", 245, (("RightArrow", 35), "L", 387), (("RepetitionOption", 88), "L", 387), (("And", 78), "L", 387), (("Or", 89), "L", 387), (("Equals", 28), "L", 387)],
//        ["ReadbackTable", 246, (("RightArrow", 35), "RS", 295)],
//        ["ReadbackTable", 247, (("And", 78), "L", 400), (("RightArrow", 35), "L", 400)],
//        ["ReadbackTable", 248, (("RightArrow", 35), "L", 392), (("OpenCurly", 46), "L", 392), (("OpenRound", 49), "L", 392), (("RepetitionOption", 60), "L", 392)],
//        ["ReadbackTable", 249, (("OpenCurly", 46), "L", 383), (("RightArrow", 35), "L", 383), (("OpenRound", 49), "L", 383)],
//        ["ReadbackTable", 250, (("RightPart", 36), "RSN", 296), (("LeftPart", 18), "L", 390)],
//        ["ReadbackTable", 251, (("Name", 25), "RSN", 297)],
//        ["ReadbackTable", 252, (("Name", 26), "RSN", 298)],
//        ["ReadbackTable", 253, (("RepetitionOption", 60), "L", 387), (("OpenRound", 49), "L", 387), (("And", 78), "L", 387), (("Minus", 91), "L", 387), (("OpenCurly", 27), "L", 387), (("Or", 89), "L", 387), (("Equals", 28), "L", 387), (("RepetitionOption", 51), "L", 387), (("OpenCurly", 46), "L", 387), (("RightArrow", 35), "L", 387), (("RepetitionOption", 88), "L", 387)],
//        ["ReadbackTable", 254, (("RepetitionOption", 51), "L", 382), (("OpenRound", 49), "L", 382), (("RepetitionOption", 60), "L", 382), (("OpenCurly", 27), "L", 382), (("RepetitionOption", 88), "L", 382), (("RightArrow", 35), "L", 382), (("Minus", 91), "L", 382), (("And", 78), "L", 382)],
//        ["ReadbackTable", 255, (("FatRightArrow", 97), "L", 382), (("OpenCurly", 46), "L", 382), (("Or", 89), "L", 382), (("Equals", 28), "L", 382)],
//        ["ReadbackTable", 256, (("RightParts", 37), "RSN", 299)],
//        ["ReadbackTable", 257, (("Name", 38), "RSN", 300)],
//        ["ReadbackTable", 258, (("Primary", 44), "RSN", 301), (("Primary", 71), "RSN", 302), (("Primary", 113), "RSN", 303)],
//        ["ReadbackTable", 259, (("Primary", 44), "RSN", 304), (("Primary", 71), "RSN", 305), (("Primary", 113), "RSN", 306)],
//        ["ReadbackTable", 260, (("Primary", 44), "RSN", 307), (("Primary", 71), "RSN", 308), (("Primary", 113), "RSN", 309)],
//        ["ReadbackTable", 261, (("Expression", 45), "RSN", 310)],
//        ["ReadbackTable", 262, (("SemanticActionParameter", 107), "L", 397), (("OpenSquare", 85), "L", 397)],
//        ["ReadbackTable", 263, (("SemanticActionParameter", 107), "L", 397), (("OpenSquare", 85), "L", 397)],
//        ["ReadbackTable", 264, (("SemanticActionParameter", 107), "L", 397), (("OpenSquare", 85), "L", 397)],
//        ["ReadbackTable", 265, (("Expression", 87), "RSN", 311)],
//        ["ReadbackTable", 266, (("RepetitionOption", 60), "RSN", 312), (("RepetitionOption", 88), "RSN", 313), (("RepetitionOption", 51), "RSN", 314)],
//        ["ReadbackTable", 267, (("Or", 89), "L", 392)],
//        ["ReadbackTable", 268, (("OpenSquare", 92), "L", 384), (("Attribute", 123), "L", 384)],
//        ["ReadbackTable", 269, (("OpenSquare", 92), "L", 384), (("Attribute", 123), "L", 384)],
//        ["ReadbackTable", 270, (("OpenSquare", 92), "L", 384), (("Attribute", 123), "L", 384)],
//        ["ReadbackTable", 271, (("OpenSquare", 92), "L", 384), (("Attribute", 123), "L", 384)],
//        ["ReadbackTable", 272, (("OpenSquare", 92), "L", 384), (("Attribute", 123), "L", 384)],
//        ["ReadbackTable", 273, (("OpenSquare", 92), "L", 384), (("Attribute", 123), "L", 384)],
//        ["ReadbackTable", 274, (("OpenSquare", 92), "L", 384), (("Attribute", 123), "L", 384)],
//        ["ReadbackTable", 275, (("OpenSquare", 92), "L", 384), (("Attribute", 123), "L", 384)],
//        ["ReadbackTable", 276, (("Expression", 63), "RSN", 315)],
//        ["ReadbackTable", 277, (("Name", 68), "RSN", 316)],
//        ["ReadbackTable", 278, (("And", 78), "RS", 317)],
//        ["ReadbackTable", 279, (("Expression", 84), "RSN", 318)],
//        ["ReadbackTable", 280, (("SemanticActionParameter", 107), "RSN", 280), (("OpenSquare", 85), "RS", 319)],
//        ["ReadbackTable", 281, (("Or", 89), "RS", 320)],
//        ["ReadbackTable", 282, (("DotDot", 90), "RS", 321)],
//        ["ReadbackTable", 283, (("Minus", 91), "RS", 322)],
//        ["ReadbackTable", 284, (("OpenSquare", 92), "RS", 323), (("Attribute", 123), "RSN", 324)],
//        ["ReadbackTable", 285, (("Name", 94), "RSN", 325)],
//        ["ReadbackTable", 286, (("Name", 95), "RSN", 326)],
//        ["ReadbackTable", 287, (("FatRightArrow", 97), "RS", 327)],
//        ["ReadbackTable", 288, (("FatRightArrow", 97), "L", 399)],
//        ["ReadbackTable", 289, (("Plus", 136), "RS", 328), (("FatRightArrow", 97), "L", 399)],
//        ["ReadbackTable", 290, (("FatRightArrow", 97), "L", 399)],
//        ["ReadbackTable", 291, (("Minus", 132), "RS", 329)],
//        ["ReadbackTable", 292, (("Production", 15), "RSN", 330), (("Macro", 9), "RSN", 331), (("Defaults", 16), "L", 401), (("GrammarType", 4), "L", 401)],
//        ["ReadbackTable", 293, (("Production", 15), "RSN", 330), (("Macro", 9), "RSN", 331), (("Defaults", 16), "L", 401), (("GrammarType", 4), "L", 401)],
//        ["ReadbackTable", 294, (("|-", 1), "L", 391)],
//        ["ReadbackTable", 295, (("LeftPart", 18), "L", 398), (("RightPart", 36), "L", 398)],
//        ["ReadbackTable", 296, (("RightPart", 36), "RSN", 296), (("LeftPart", 18), "L", 390)],
//        ["ReadbackTable", 297, (("keywords", 10), "RS", 332), (("Name", 25), "RSN", 297)],
//        ["ReadbackTable", 298, (("optimize", 12), "RS", 333)],
//        ["ReadbackTable", 299, (("LeftPart", 18), "RSN", 334)],
//        ["ReadbackTable", 300, (("output", 20), "RS", 335)],
//        ["ReadbackTable", 301, (("Minus", 91), "L", 392), (("And", 78), "L", 392), (("OpenCurly", 27), "L", 392), (("RepetitionOption", 51), "L", 392), (("RepetitionOption", 88), "L", 392), (("Equals", 28), "L", 392)],
//        ["ReadbackTable", 302, (("RightArrow", 35), "L", 392), (("OpenCurly", 46), "L", 392), (("OpenRound", 49), "L", 392), (("RepetitionOption", 60), "L", 392)],
//        ["ReadbackTable", 303, (("Or", 89), "L", 392)],
//        ["ReadbackTable", 304, (("Minus", 91), "L", 392), (("And", 78), "L", 392), (("OpenCurly", 27), "L", 392), (("RepetitionOption", 51), "L", 392), (("RepetitionOption", 88), "L", 392), (("Equals", 28), "L", 392)],
//        ["ReadbackTable", 305, (("RightArrow", 35), "L", 392), (("OpenCurly", 46), "L", 392), (("OpenRound", 49), "L", 392), (("RepetitionOption", 60), "L", 392)],
//        ["ReadbackTable", 306, (("Or", 89), "L", 392)],
//        ["ReadbackTable", 307, (("Minus", 91), "L", 392), (("And", 78), "L", 392), (("OpenCurly", 27), "L", 392), (("RepetitionOption", 51), "L", 392), (("RepetitionOption", 88), "L", 392), (("Equals", 28), "L", 392)],
//        ["ReadbackTable", 308, (("RightArrow", 35), "L", 392), (("OpenCurly", 46), "L", 392), (("OpenRound", 49), "L", 392), (("RepetitionOption", 60), "L", 392)],
//        ["ReadbackTable", 309, (("Or", 89), "L", 392)],
//        ["ReadbackTable", 310, (("OpenCurly", 27), "RS", 336)],
//        ["ReadbackTable", 311, (("OpenRound", 49), "RS", 337)],
//        ["ReadbackTable", 312, (("RightArrow", 35), "L", 386), (("OpenRound", 49), "L", 386), (("Minus", 91), "L", 386), (("And", 78), "L", 386), (("Equals", 28), "L", 386)],
//        ["ReadbackTable", 313, (("RepetitionOption", 60), "RSN", 338), (("RepetitionOption", 88), "RSN", 339), (("RepetitionOption", 51), "RSN", 340)],
//        ["ReadbackTable", 314, (("Or", 89), "L", 386), (("OpenCurly", 46), "L", 386), (("OpenCurly", 27), "L", 386)],
//        ["ReadbackTable", 315, (("Equals", 28), "RS", 341)],
//        ["ReadbackTable", 316, (("Name", 68), "RSN", 316), (("defaults", 34), "RS", 342)],
//        ["ReadbackTable", 317, (("Alternation", 58), "RSN", 343), (("Alternation", 42), "RSN", 344)],
//        ["ReadbackTable", 318, (("OpenCurly", 46), "RS", 345)],
//        ["ReadbackTable", 319, (("walkSymbol", 47), "RSN", 346), (("walkSymbol", 59), "RSN", 347)],
//        ["ReadbackTable", 320, (("Concatenation", 114), "RSN", 281), (("Concatenation", 53), "RSN", 348), (("Concatenation", 70), "RSN", 349)],
//        ["ReadbackTable", 321, (("Byte", 61), "RSN", 350), (("Byte", 54), "RSN", 351)],
//        ["ReadbackTable", 322, (("AndExpression", 55), "RSN", 352), (("AndExpression", 72), "RSN", 353)],
//        ["ReadbackTable", 323, (("Secondary", 62), "RSN", 354), (("Secondary", 56), "RSN", 355)],
//        ["ReadbackTable", 324, (("OpenSquare", 92), "RS", 323), (("Attribute", 123), "RSN", 284)],
//        ["ReadbackTable", 325, (("Name", 94), "RSN", 325), (("defaults", 66), "RS", 356)],
//        ["ReadbackTable", 326, (("defaults", 67), "RS", 357), (("Name", 95), "RSN", 358)],
//        ["ReadbackTable", 327, (("Expression", 69), "RSN", 359)],
//        ["ReadbackTable", 328, (("FatRightArrow", 97), "L", 399)],
//        ["ReadbackTable", 329, (("FatRightArrow", 97), "L", 399)],
//        ["ReadbackTable", 330, (("Production", 15), "RSN", 360), (("Macro", 9), "RSN", 361), (("Defaults", 16), "L", 401), (("GrammarType", 4), "L", 401)],
//        ["ReadbackTable", 331, (("Production", 15), "RSN", 360), (("Macro", 9), "RSN", 361), (("Defaults", 16), "L", 401), (("GrammarType", 4), "L", 401)],
//        ["ReadbackTable", 332, (("Defaults", 16), "L", 395), (("GrammarType", 4), "L", 395)],
//        ["ReadbackTable", 333, (("Defaults", 16), "L", 395), (("GrammarType", 4), "L", 395)],
//        ["ReadbackTable", 334, (("GrammarType", 4), "L", 389), (("Defaults", 16), "L", 389), (("Macro", 9), "L", 389), (("Production", 15), "L", 389)],
//        ["ReadbackTable", 335, (("Defaults", 16), "L", 395), (("GrammarType", 4), "L", 395)],
//        ["ReadbackTable", 336, (("Name", 24), "RSN", 362), (("Name", 14), "RSN", 363), (("Name", 30), "RSN", 364), (("Name", 64), "RSN", 365)],
//        ["ReadbackTable", 337, (("RepetitionOption", 51), "L", 396), (("Or", 89), "L", 396), (("OpenRound", 49), "L", 396), (("OpenCurly", 46), "L", 396), (("RepetitionOption", 60), "L", 396), (("OpenCurly", 27), "L", 396), (("RepetitionOption", 88), "L", 396), (("Equals", 28), "L", 396), (("And", 78), "L", 396), (("Minus", 91), "L", 396), (("RightArrow", 35), "L", 396)],
//        ["ReadbackTable", 338, (("RightArrow", 35), "L", 386), (("OpenRound", 49), "L", 386), (("Equals", 28), "L", 386), (("Minus", 91), "L", 386), (("And", 78), "L", 386)],
//        ["ReadbackTable", 339, (("RepetitionOption", 60), "RSN", 366), (("RepetitionOption", 88), "RSN", 339), (("RepetitionOption", 51), "RSN", 340)],
//        ["ReadbackTable", 340, (("Or", 89), "L", 386), (("OpenCurly", 46), "L", 386), (("OpenCurly", 27), "L", 386)],
//        ["ReadbackTable", 341, (("Name", 24), "RSN", 367), (("Name", 30), "RSN", 368), (("Name", 14), "RSN", 369), (("Name", 64), "RSN", 370)],
//        ["ReadbackTable", 342, (("attribute", 17), "RS", 371), (("attribute", 65), "RS", 372)],
//        ["ReadbackTable", 343, (("RightArrow", 35), "L", 388), (("OpenCurly", 46), "L", 388), (("OpenRound", 49), "L", 388), (("Equals", 28), "L", 388)],
//        ["ReadbackTable", 344, (("Minus", 91), "L", 388), (("OpenCurly", 27), "L", 388)],
//        ["ReadbackTable", 345, (("RepetitionOption", 51), "L", 396), (("Or", 89), "L", 396), (("OpenRound", 49), "L", 396), (("OpenCurly", 46), "L", 396), (("RepetitionOption", 60), "L", 396), (("OpenCurly", 27), "L", 396), (("RepetitionOption", 88), "L", 396), (("Equals", 28), "L", 396), (("And", 78), "L", 396), (("Minus", 91), "L", 396), (("RightArrow", 35), "L", 396)],
//        ["ReadbackTable", 346, (("RepetitionOption", 51), "L", 382), (("OpenRound", 49), "L", 382), (("RepetitionOption", 60), "L", 382), (("OpenCurly", 27), "L", 382), (("RepetitionOption", 88), "L", 382), (("RightArrow", 35), "L", 382), (("Minus", 91), "L", 382), (("And", 78), "L", 382)],
//        ["ReadbackTable", 347, (("FatRightArrow", 97), "L", 382), (("OpenCurly", 46), "L", 382), (("Or", 89), "L", 382), (("Equals", 28), "L", 382)],
//        ["ReadbackTable", 348, (("OpenCurly", 46), "L", 400), (("Minus", 91), "L", 400), (("OpenRound", 49), "L", 400), (("OpenCurly", 27), "L", 400), (("Equals", 28), "L", 400)],
//        ["ReadbackTable", 349, (("And", 78), "L", 400), (("RightArrow", 35), "L", 400)],
//        ["ReadbackTable", 350, (("Or", 89), "L", 396), (("OpenCurly", 46), "L", 396), (("RepetitionOption", 60), "L", 396), (("RepetitionOption", 88), "L", 396), (("Equals", 28), "L", 396), (("RightArrow", 35), "L", 396), (("Minus", 91), "L", 396)],
//        ["ReadbackTable", 351, (("OpenRound", 49), "L", 396), (("OpenCurly", 27), "L", 396), (("And", 78), "L", 396), (("RepetitionOption", 51), "L", 396)],
//        ["ReadbackTable", 352, (("Equals", 28), "L", 383), (("OpenCurly", 27), "L", 383)],
//        ["ReadbackTable", 353, (("OpenRound", 49), "L", 383), (("OpenCurly", 46), "L", 383), (("RightArrow", 35), "L", 383)],
//        ["ReadbackTable", 354, (("RightArrow", 35), "L", 387), (("RepetitionOption", 88), "L", 387), (("And", 78), "L", 387), (("Or", 89), "L", 387), (("Equals", 28), "L", 387)],
//        ["ReadbackTable", 355, (("OpenRound", 49), "L", 387), (("OpenCurly", 46), "L", 387), (("Minus", 91), "L", 387), (("OpenCurly", 27), "L", 387), (("RepetitionOption", 51), "L", 387), (("RepetitionOption", 60), "L", 387)],
//        ["ReadbackTable", 356, (("nonterminal", 32), "RS", 373)],
//        ["ReadbackTable", 357, (("terminal", 33), "RS", 374)],
//        ["ReadbackTable", 358, (("defaults", 67), "RS", 357), (("Name", 95), "RSN", 326)],
//        ["ReadbackTable", 359, (("RightArrow", 35), "RS", 375)],
//        ["ReadbackTable", 360, (("Production", 15), "RSN", 376), (("Macro", 9), "RSN", 377), (("GrammarType", 4), "L", 401), (("Defaults", 16), "L", 401)],
//        ["ReadbackTable", 361, (("Production", 15), "RSN", 376), (("Macro", 9), "RSN", 377), (("GrammarType", 4), "L", 401), (("Defaults", 16), "L", 401)],
//        ["ReadbackTable", 362, (("Macro", 9), "L", 393)],
//        ["ReadbackTable", 363, (("GrammarType", 4), "L", 393)],
//        ["ReadbackTable", 364, (("Production", 15), "L", 393)],
//        ["ReadbackTable", 365, (("Defaults", 16), "L", 393)],
//        ["ReadbackTable", 366, (("RightArrow", 35), "L", 386), (("Minus", 91), "L", 386), (("OpenRound", 49), "L", 386), (("And", 78), "L", 386), (("Equals", 28), "L", 386)],
//        ["ReadbackTable", 367, (("Macro", 9), "L", 394)],
//        ["ReadbackTable", 368, (("Production", 15), "L", 394)],
//        ["ReadbackTable", 369, (("GrammarType", 4), "L", 394)],
//        ["ReadbackTable", 370, (("Defaults", 16), "L", 394)],
//        ["ReadbackTable", 371, (("GrammarType", 4), "L", 395)],
//        ["ReadbackTable", 372, (("Defaults", 16), "L", 395)],
//        ["ReadbackTable", 373, (("attribute", 17), "RS", 378), (("attribute", 65), "RS", 379)],
//        ["ReadbackTable", 374, (("attribute", 17), "RS", 380), (("attribute", 65), "RS", 381)],
//        ["ReadbackTable", 375, (("RightPart", 36), "L", 398), (("LeftPart", 18), "L", 398)],
//        ["ReadbackTable", 376, (("Production", 15), "RSN", 376), (("Macro", 9), "RSN", 377), (("GrammarType", 4), "L", 401), (("Defaults", 16), "L", 401)],
//        ["ReadbackTable", 377, (("Production", 15), "RSN", 376), (("Macro", 9), "RSN", 377), (("GrammarType", 4), "L", 401), (("Defaults", 16), "L", 401)],
//        ["ReadbackTable", 378, (("GrammarType", 4), "L", 395)],
//        ["ReadbackTable", 379, (("Defaults", 16), "L", 395)],
//        ["ReadbackTable", 380, (("GrammarType", 4), "L", 395)],
//        ["ReadbackTable", 381, (("Defaults", 16), "L", 395)],
//        ["ReduceTable", 382, "SemanticAction", (27, "RSN", 43), (28, "RSN", 43), (35, "RSN", 43), (46, "RSN", 43), (49, "RSN", 43), (51, "RSN", 43), (60, "RSN", 43), (78, "RSN", 43), (88, "RSN", 43), (89, "RSN", 43), (91, "RSN", 43), (97, "RSN", 135)],
//        ["ReduceTable", 383, "Expression", (27, "RSN", 45), (28, "RSN", 63), (35, "RSN", 69), (46, "RSN", 84), (49, "RSN", 87)],
//        ["ReduceTable", 384, "Attribute", (92, "RSN", 123), (123, "RSN", 123)],
//        ["ReduceTable", 385, "Byte", (27, "RSN", 54), (28, "RSN", 61), (35, "RSN", 61), (46, "RSN", 61), (49, "RSN", 54), (51, "RSN", 54), (60, "RSN", 61), (78, "RSN", 54), (85, "RSN", 108), (88, "RSN", 61), (89, "RSN", 61), (90, "RSN", 115), (91, "RSN", 61), (107, "RSN", 108)],
//        ["ReduceTable", 386, "Concatenation", (27, "RSN", 53), (28, "RSN", 53), (35, "RSN", 70), (46, "RSN", 53), (49, "RSN", 53), (78, "RSN", 70), (89, "RSN", 114), (91, "RSN", 53)],
//        ["ReduceTable", 387, "Primary", (27, "RSN", 44), (28, "RSN", 44), (35, "RSN", 71), (46, "RSN", 71), (49, "RSN", 71), (51, "RSN", 44), (60, "RSN", 71), (78, "RSN", 44), (88, "RSN", 44), (89, "RSN", 113), (91, "RSN", 44)],
//        ["ReduceTable", 388, "AndExpression", (27, "RSN", 55), (28, "RSN", 55), (35, "RSN", 72), (46, "RSN", 72), (49, "RSN", 72), (91, "RSN", 116)],
//        ["ReduceTable", 389, "Production", (4, "RSN", 15), (9, "RSN", 15), (15, "RSN", 15), (31, "RSN", 15)],
//        ["ReduceTable", 390, "RightParts", (18, "RSN", 37)],
//        ["ReduceTable", 391, "GrammarType", (1, "RSN", 4)],
//        ["ReduceTable", 392, "RepetitionOption", (27, "RSN", 51), (28, "RSN", 60), (35, "RSN", 60), (46, "RSN", 51), (49, "RSN", 60), (51, "RSN", 88), (60, "RSN", 88), (78, "RSN", 60), (88, "RSN", 88), (89, "RSN", 51), (91, "RSN", 60)],
//        ["ReduceTable", 393, "LeftPart", (4, "RSN", 18), (9, "RSN", 18), (15, "RSN", 18), (31, "RSN", 18)],
//        ["ReduceTable", 394, "Macro", (4, "RSN", 9), (9, "RSN", 9), (15, "RSN", 9), (31, "RSN", 9)],
//        ["ReduceTable", 395, "Defaults", (4, "RSN", 16), (31, "RSN", 16)],
//        ["ReduceTable", 396, "Secondary", (27, "RSN", 56), (28, "RSN", 62), (35, "RSN", 62), (46, "RSN", 56), (49, "RSN", 56), (51, "RSN", 56), (60, "RSN", 56), (78, "RSN", 62), (88, "RSN", 62), (89, "RSN", 62), (91, "RSN", 56)],
//        ["ReduceTable", 397, "SemanticActionParameter", (85, "RSN", 107), (107, "RSN", 107)],
//        ["ReduceTable", 398, "RightPart", (18, "RSN", 36), (36, "RSN", 36)],
//        ["ReduceTable", 399, "TreeBuildingOptions", (97, "RSN", 131)],
//        ["ReduceTable", 400, "Alternation", (27, "RSN", 42), (28, "RSN", 58), (35, "RSN", 58), (46, "RSN", 58), (49, "RSN", 58), (78, "RSN", 100), (91, "RSN", 42)],
//        ["ReduceTable", 401, "Rules", (4, "RSN", 13), (31, "RSN", 13)],
//        ["ReduceTable", 402, "Name", (4, "RSN", 14), (9, "RSN", 24), (10, "RSN", 25), (12, "RSN", 26), (15, "RSN", 30), (20, "RSN", 38), (25, "RSN", 25), (27, "RSN", 57), (28, "RSN", 57), (31, "RSN", 64), (34, "RSN", 68), (35, "RSN", 57), (46, "RSN", 57), (49, "RSN", 57), (51, "RSN", 57), (60, "RSN", 57), (66, "RSN", 94), (67, "RSN", 95), (68, "RSN", 68), (78, "RSN", 57), (85, "RSN", 110), (88, "RSN", 57), (89, "RSN", 57), (91, "RSN", 57), (94, "RSN", 94), (95, "RSN", 95), (97, "RSN", 133), (107, "RSN", 110)],
//        ["SemanticTable", 403, "processTypeNow", ["scanner"], 7],
//        ["SemanticTable", 404, "processTypeNow", ["parser"], 8],
//        ["SemanticTable", 405, "processTypeNow", ["superScanner"], 22],
//        ["SemanticTable", 406, "buildTree", ["walkGrammar"], 23],
//        ["SemanticTable", 407, "buildTree", ["walkLeftPart"], 29],
//        ["SemanticTable", 408, "buildTree", ["walkGrammar"], 23],
//        ["SemanticTable", 409, "processAndDiscardDefaultsNow", [], 31],
//        ["SemanticTable", 410, "processTypeNow", ["superScanner"], 39],
//        ["SemanticTable", 411, "buildTree", ["walkLeftPart"], 29],
//        ["SemanticTable", 412, "buildTree", ["walkEpsilon"], 52],
//        ["SemanticTable", 413, "buildTree", ["walkEpsilon"], 52],
//        ["SemanticTable", 414, "buildTree", ["walkLeftPart"], 29],
//        ["SemanticTable", 415, "buildTree", ["walkEpsilon"], 52],
//        ["SemanticTable", 416, "buildTree", ["walkOr"], 73],
//        ["SemanticTable", 417, "buildTree", ["walkKeywords"], 76],
//        ["SemanticTable", 418, "buildTree", ["walkOptimize"], 77],
//        ["SemanticTable", 419, "buildTree", ["walkNonTreeBuildingSemanticAction"], 79],
//        ["SemanticTable", 420, "buildTree", ["walkEpsilon"], 52],
//        ["SemanticTable", 421, "buildTree", ["walkSemanticAction"], 86],
//        ["SemanticTable", 422, "buildTree", ["walkEpsilon"], 52],
//        ["SemanticTable", 423, "buildTree", ["walkSemanticAction"], 86],
//        ["SemanticTable", 424, "buildTree", ["walkLeftPart"], 29],
//        ["SemanticTable", 425, "buildTree", ["walkProduction"], 98],
//        ["SemanticTable", 426, "buildTree", ["walkOutput"], 99],
//        ["SemanticTable", 427, "buildTree", ["walkEpsilon"], 52],
//        ["SemanticTable", 428, "buildTree", ["walkPlus"], 101],
//        ["SemanticTable", 429, "buildTree", ["walkQuestionMark"], 102],
//        ["SemanticTable", 430, "buildTree", ["walkStar"], 103],
//        ["SemanticTable", 431, "buildTree", ["walkLeftPartWithLookahead"], 104],
//        ["SemanticTable", 432, "buildTree", ["walkConcatenation"], 112],
//        ["SemanticTable", 433, "buildTree", ["walkEpsilon"], 52],
//        ["SemanticTable", 434, "buildTree", ["walkMacro"], 127],
//        ["SemanticTable", 435, "buildTree", ["walkAttributeDefaults"], 130],
//        ["SemanticTable", 436, "buildTree", ["walkAnd"], 137],
//        ["SemanticTable", 437, "buildTree", ["walkLook"], 138],
//        ["SemanticTable", 438, "buildTree", ["walkSemanticAction"], 139],
//        ["SemanticTable", 439, "buildTree", ["walkOr"], 140],
//        ["SemanticTable", 440, "buildTree", ["walkDotDot"], 141],
//        ["SemanticTable", 441, "buildTree", ["walkMinus"], 142],
//        ["SemanticTable", 442, "buildTree", ["walkAttributes"], 143],
//        ["SemanticTable", 443, "buildTree", ["walkAttributeNonterminalDefaults"], 144],
//        ["SemanticTable", 444, "buildTree", ["walkAttributeTerminalDefaults"], 145],
//        ["SemanticTable", 445, "buildTree", ["walkConcatenation"], 146],
//        ["SemanticTable", 446, "buildTree", ["walkBuildTreeOrTokenFromName"], 148],
//        ["SemanticTable", 447, "buildTree", ["walkBuildTreeFromLeftIndex"], 149],
//        ["SemanticTable", 448, "buildTree", ["walkTreeBuildingSemanticAction"], 150],
//        ["SemanticTable", 449, "buildTree", ["walkBuildTreeFromRightIndex"], 151],
//        ["AcceptTable", 450]]
}
