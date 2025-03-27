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
    
    init() {
        parser = Parser(sponsor: self, parserTables: parserTables, scannerTables: scannerTables)
    }
    
    func process (_ text: String) -> Void {
        print("Tree type: \(Grammar.activeGrammar!.type)")
        if let tree = parser!.parse(text) as? Tree {
            print("tree from parser:")
            print(tree)
            _ = walkTree(tree)
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
        
        let numberToTest = 0
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
        
        // create reduce and accept state(s) for parser
        if grammar.isParser() {
            // create reduce states and accept state
            for nonterminal in grammar.nonterminals {
                if nonterminal.contains("'") {
                    acceptState = AcceptState()
                } else {
                    let reduceState = ReduceState()
                    reduceState.nonterminal = nonterminal
                    reduceStates[nonterminal] = reduceState
                }
            }
            renumber()
        }
        
        // create the right and down relations from the grammar's productions
        self.createRightAndDownRelations()
        
        // build our ra states and semantic states
        self.buildReadaheadStates()
        self.attachReadaheadFollowSets()
        self.buildSemanticStates()
        
        // split the left relation into invisible/visible relations
        self.splitLeftRelation()
        
        // for scanners, bridge readaheads back to the initial ra state
        // for parers, we have reduce/readback tables
        if grammar.isScanner() {
            self.buildScannerBridges()
        } else {
            // alternates for reduce tables
            self.finalizeReadaheadAndReduceStates()
            self.buildAlternateRestarts()
            
            // build readback state bridges - not needed for scanners
            self.buildReadbackStateBridges()
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
    
    
    func removeFirstParserState() {
        self.renumber()
        readaheadStates.remove(at: 0)
        self.renumber()
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
            
            for triple in localDown!.triples {
                let relationship = triple.relationship
                let firstPairing = Pairing(triple.to, raState)
                let secondPairing = Pairing(triple.from, raState)
                up?.add(Triple(from: firstPairing, relationship: relationship, to: secondPairing))
            }
            
            // compute successors
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
                    renumber() // renumber for new RA state
                }
                raState.transitions.append(Transition(relationship, successor!))
                
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
    
    func attachReadaheadFollowSets () {
        // iterate over readaheads, find all semantic transitions
        // for every semantic transiton, compute the followset of the goto (a ra state) and attach it to it
        for raState in readaheadStates {
            raState.transitionsDo { transition in
                if transition.label?.hasAction() == true { // Semantic transition
                    let goto = transition.goto as! ReadaheadState
                    goto.follow = Grammar.activeGrammar?.computeReadaheadFollowSet(raState: goto) ?? []
                }
            }
        }
    }
    
    func buildSemanticStates () {
        /* for every semantic transiiton, build a semantic state where the label is the semantic
           transition label and the goto is the original transition's goto state
           set the goto of the 'from' readahead state to the semantic state
         */
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
            
            // remove the old semantic transitions
            for transition in transitionsToRemove {
                if let index = raState.transitions.firstIndex(where: { $0 === transition }) {
                    raState.transitions.remove(at: index)
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
                
                if let production = Grammar.activeGrammar?.productions[nonterminal] {
                    if production.isGoal() {
                        acceptState = AcceptState()
                    } else {
                        newReadbackState = ReadbackState()
                        let finalStatePairs = finalStates.map { finalState in
                            return Pairing(finalState, raState)
                        }
                        newReadbackState.initialItems = finalStatePairs
                        readbackStates.append(newReadbackState)
                        
                        // make transitions from the readahead state to the readback state, using the followset of the nonterminal's production as look labels
                        let followSet = production.followSet
                        for lookahead in followSet {
                            raState.transitions.append(Transition(Label(lookahead, AttributeList().set(Grammar.lookDefaults())), newReadbackState))
                        }
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
                
                // Match candidate with existing readahead states
                var successor = self.match(candidate, readbackStates)
                if successor == nil {
                    readbackStates.append(candidate)
                    successor = candidate
                    renumber()
                }
                
                // add transition to successor
                rbState.transitions.append(Transition(relationship, successor!)) // label pair
            }
            
            let initialStateItems: [Pairing] = rbState.finalItems.filter{($0.isInitial())} // might be empty
            
            // item1 in rb state items is a right part state, who's left part is a non terminal
            // initialStateItems here is a Pairing of right part states and their readahead state gotos
            if !initialStateItems.isEmpty {
                // get lookbacks for the initial state pairings 
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
    
    
    func finalizeReadaheadAndReduceStates() {
        // move all ra state nonterminal transitions into the appropriate reduce state as an array of triples where the from is an integer w/ the original ra state state number
        for raState in readaheadStates {
            raState.transitionsDo { transition in
                if Grammar.activeGrammar?.isNonterminal(transition.label!.name) == true {
                    if let reduceState = reduceStates[transition.label!.name] {
                        let transitionAttrributes = transition.label?.attributes.description
                        reduceState.reduceTransitions.append(Triple(from: raState, relationship: transitionAttrributes!, to: transition.goto! as! ReadaheadState))
                    }
                }
            }
        }
    }
    
    
    // get the nonterminal transitions of readahead states, make a reduce triple (tuple) and get the alternates for it
    // then for each alternate readahead state found, add it with the attributes and goto readahead to the restarts of the
    // corresponding reduce state for that non terminal
    func buildAlternateRestarts() {
        for raState in readaheadStates {
            for transition in raState.transitions {
                let label = transition.label
                if Grammar.activeGrammar?.isNonterminal(label!.name) == true {
                    let gotoReadahead = transition.goto as! ReadaheadState
                    let nonterm = label?.name
                    let reduceTuple = (first: raState, second: label!, third: gotoReadahead)
                    let alternates = alternateRestartsFor(reduceTuple)
                    let reduceState = reduceStates[nonterm!]
                    
                    for alternate in alternates {
                        let combination: (ReadaheadState, String, ReadaheadState) = (alternate, label!.attributes.description, gotoReadahead)
                        reduceState?.addRestartsIfAbsent(combination)
                    }
                }
            }
        }
        // add original restarts to alternate restarts (should be no duplicates)
        for reduceState in reduceStates.values {
            for triple in reduceState.reduceTransitions {
                // add to restarts if there's not already a triple in reduceState.restarts where the first object is the same RA state as the from in the triple
                let raState = triple.from
                let label = triple.relationship
                let goto = triple.to
                let combo = (raState, label, goto)
                reduceState.addRestartsIfAbsent(combo)
            }
        }
    }
    
    
    func alternateRestartsFor(_ reduceTuple: (first: ReadaheadState, second: Label, third: ReadaheadState)) -> [ReadaheadState] {
        let from = reduceTuple.first
        let label = reduceTuple.second
        let to = reduceTuple.third
        
        let candidates = visibleLeft!.triples.filter({ triple in
            let a = triple.from
            let b = triple.relationship
            let c = triple.to
            
            return a.item2 as! ReadaheadState == to && b.item1 as! Label == label && c.item2 as! ReadaheadState == from
        })
        
        let pairs = candidates.map({ $0.to })
        var result: Set<Pairing> = Set(pairs)
        
        for item in result {
            let upItems = up?.performStar(items: [item])
            let leftItems = invisibleLeft?.performStar(items: [item])
            result.formUnion(upItems!)
            result.formUnion(leftItems!)
        }
        
        let resultArray = Array(result)
        
        var alternateRestarts: [ReadaheadState] = []
        visibleLeft!.from(resultArray, relationsDo: { (relationship: Pairing, relation: Relation<Pairing, Pairing>) in
            alternateRestarts.appendIfAbsent(relationship.item2 as! ReadaheadState)
        })
        return alternateRestarts
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
    
    func processAndDiscardDefaultsNow() {
        //Pick up the tree just built containing either the attributes, keywords, optimize, and output tree,
        //process it with walkTree, and remove it from the tree stack... by replacing the entry by nil..."
        let tree: Tree = self.parser!.treeStack.last as! Tree
        _ = self.walkTree(tree)
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
    
//        ["keywords", "stack", "noStack", "read", "look", "node", "noNode", "keep", "noKeep", "parser", "scanner", "super", "superScanner", "attribute", "defaults", "keywords", "output", "optimize", "terminal", "nonterminal"],
//        ["ReadaheadTable", 1, ("parser", "RS", 2), ("scanner", "RS", 3), ("superScanner", "RS", 4), ("super", "RS", 5), ("GrammarType", "RSN", 6)],
//        ["ReadaheadTable", 2, ("attribute", "L", 239), ("keywords", "L", 239), ("output", "L", 239), ("optimize", "L", 239), ("walkIdentifier", "L", 239), ("walkString", "L", 239)],
//        ["ReadaheadTable", 3, ("attribute", "L", 240), ("keywords", "L", 240), ("output", "L", 240), ("optimize", "L", 240), ("walkIdentifier", "L", 240), ("walkString", "L", 240)],
//        ["ReadaheadTable", 4, ("attribute", "L", 241), ("keywords", "L", 241), ("output", "L", 241), ("optimize", "L", 241), ("walkIdentifier", "L", 241), ("walkString", "L", 241)],
//        ["ReadaheadTable", 5, ("scanner", "RS", 10)],
//        ["ReadaheadTable", 6, ("Production", "RSN", 11), ("Rules", "RSN", 12), ("attribute", "RS", 13), ("keywords", "RS", 14), ("optimize", "RS", 15), ("output", "RS", 16), ("Macro", "RSN", 17), ("Defaults", "RSN", 18)],
//        ["ReadaheadTable", 7, ("attribute", "L", 98), ("keywords", "L", 98), ("output", "L", 98), ("optimize", "L", 98), ("walkIdentifier", "L", 98), ("walkString", "L", 98)],
//        ["ReadaheadTable", 8, ("attribute", "L", 99), ("keywords", "L", 99), ("output", "L", 99), ("optimize", "L", 99), ("walkIdentifier", "L", 99), ("walkString", "L", 99)],
//        ["ReadaheadTable", 9, ("attribute", "L", 100), ("keywords", "L", 100), ("output", "L", 100), ("optimize", "L", 100), ("walkIdentifier", "L", 100), ("walkString", "L", 100)],
//        ["ReadaheadTable", 10, ("attribute", "L", 242), ("keywords", "L", 242), ("output", "L", 242), ("optimize", "L", 242), ("walkIdentifier", "L", 242), ("walkString", "L", 242)],
//        ["ReadaheadTable", 11, ("Production", "RSN", 11), ("Macro", "RSN", 17), ("Name", "RSN", 21), ("LeftPart", "RSN", 22), ("-|", "L", 243)],
//        ["ReadaheadTable", 12, ],
//        ["ReadaheadTable", 13, ("defaults", "RS", 23), ("nonterminal", "RS", 24), ("terminal", "RS", 25)],
//        ["ReadaheadTable", 14, ("walkString", "RSN", 26), ("walkIdentifier", "RSN", 27), ("Name", "RSN", 28)],
//        ["ReadaheadTable", 15, ("Name", "RSN", 29), ("walkIdentifier", "RSN", 27), ("walkString", "RSN", 26)],
//        ["ReadaheadTable", 16, ("Name", "RSN", 30), ("walkIdentifier", "RSN", 27), ("walkString", "RSN", 26)],
//        ["ReadaheadTable", 17, ("Macro", "RSN", 17), ("Name", "RSN", 21), ("Production", "RSN", 11), ("LeftPart", "RSN", 22), ("-|", "L", 244)],
//        ["ReadaheadTable", 18, ("optimize", "L", 245), ("output", "L", 245), ("attribute", "L", 245), ("walkIdentifier", "L", 245), ("walkString", "L", 245), ("keywords", "L", 245)],
//        ["ReadaheadTable", 19, ("attribute", "L", 101), ("keywords", "L", 101), ("output", "L", 101), ("optimize", "L", 101), ("walkIdentifier", "L", 101), ("walkString", "L", 101)],
//        ["ReadaheadTable", 20, ("-|", "L", 102)],
//        ["ReadaheadTable", 21, ("Equals", "RS", 32)],
//        ["ReadaheadTable", 22, ("RightParts", "RSN", 33), ("RightPart", "RSN", 34)],
//        ["ReadaheadTable", 23, ("Name", "RSN", 35), ("walkIdentifier", "RSN", 27), ("walkString", "RSN", 26)],
//        ["ReadaheadTable", 24, ("defaults", "RS", 36)],
//        ["ReadaheadTable", 25, ("defaults", "RS", 37)],
//        ["ReadaheadTable", 26, ("Equals", "L", 103), ("RightArrow", "L", 103), ("OpenCurly", "L", 103), ("walkIdentifier", "L", 103), ("walkString", "L", 103), ("Dot", "L", 103), ("walkCharacter", "L", 103), ("walkInteger", "L", 103), ("walkSymbol", "L", 103), ("CloseSquare", "L", 103), ("OpenRound", "L", 103), ("Star", "L", 103), ("QuestionMark", "L", 103), ("Plus", "L", 103), ("OpenSquare", "L", 103), ("CloseRound", "L", 103), ("CloseCurly", "L", 103), ("Minus", "L", 103), ("And", "L", 103), ("Or", "L", 103), ("FatRightArrow", "L", 103)],
//        ["ReadaheadTable", 27, ("Equals", "L", 104), ("RightArrow", "L", 104), ("OpenCurly", "L", 104), ("walkIdentifier", "L", 104), ("walkString", "L", 104), ("Dot", "L", 104), ("walkCharacter", "L", 104), ("walkInteger", "L", 104), ("walkSymbol", "L", 104), ("CloseSquare", "L", 104), ("OpenRound", "L", 104), ("Star", "L", 104), ("QuestionMark", "L", 104), ("Plus", "L", 104), ("OpenSquare", "L", 104), ("CloseRound", "L", 104), ("CloseCurly", "L", 104), ("Minus", "L", 104), ("And", "L", 104), ("Or", "L", 104), ("FatRightArrow", "L", 104)],
//        ["ReadaheadTable", 28, ("walkString", "RSN", 26), ("Dot", "RS", 38), ("Name", "RSN", 28), ("walkIdentifier", "RSN", 27)],
//        ["ReadaheadTable", 29, ("Dot", "RS", 39)],
//        ["ReadaheadTable", 30, ("Dot", "RS", 40)],
//        ["ReadaheadTable", 31, ("optimize", "RS", 15), ("output", "RS", 16), ("attribute", "RS", 41), ("Production", "RSN", 11), ("Defaults", "RSN", 18), ("Macro", "RSN", 17), ("Rules", "RSN", 12), ("keywords", "RS", 14)],
//        ["ReadaheadTable", 32, ("AndExpression", "RSN", 42), ("Expression", "RSN", 43)],
//        ["ReadaheadTable", 33, ("Dot", "RS", 44)],
//        ["ReadaheadTable", 34, ("RightPart", "RSN", 34), ("RightArrow", "RS", 46), ("Dot", "L", 246)],
//        ["ReadaheadTable", 35, ("walkString", "RSN", 26), ("Dot", "RS", 47), ("Name", "RSN", 35), ("walkIdentifier", "RSN", 27)],
//        ["ReadaheadTable", 36, ("Name", "RSN", 48), ("walkIdentifier", "RSN", 27), ("walkString", "RSN", 26)],
//        ["ReadaheadTable", 37, ("Name", "RSN", 49), ("walkIdentifier", "RSN", 27), ("walkString", "RSN", 26)],
//        ["ReadaheadTable", 38, ("attribute", "L", 247), ("keywords", "L", 247), ("output", "L", 247), ("optimize", "L", 247), ("walkIdentifier", "L", 247), ("walkString", "L", 247)],
//        ["ReadaheadTable", 39, ("attribute", "L", 248), ("keywords", "L", 248), ("output", "L", 248), ("optimize", "L", 248), ("walkIdentifier", "L", 248), ("walkString", "L", 248)],
//        ["ReadaheadTable", 40, ("attribute", "L", 249), ("keywords", "L", 249), ("output", "L", 249), ("optimize", "L", 249), ("walkIdentifier", "L", 249), ("walkString", "L", 249)],
//        ["ReadaheadTable", 41, ("defaults", "RS", 23), ("nonterminal", "RS", 24), ("terminal", "RS", 25)],
//        ["ReadaheadTable", 42, ("Minus", "RS", 53), ("CloseRound", "L", 105), ("CloseCurly", "L", 105), ("Dot", "L", 105), ("RightArrow", "L", 105), ("FatRightArrow", "L", 105)],
//        ["ReadaheadTable", 43, ("Dot", "RS", 54)],
//        ["ReadaheadTable", 44, ("walkIdentifier", "L", 250), ("walkString", "L", 250), ("-|", "L", 250)],
//        ["ReadaheadTable", 45, ("Dot", "L", 106)],
//        ["ReadaheadTable", 46, ("AndExpression", "RSN", 42), ("Expression", "RSN", 56)],
//        ["ReadaheadTable", 47, ("attribute", "L", 251), ("keywords", "L", 251), ("output", "L", 251), ("optimize", "L", 251), ("walkIdentifier", "L", 251), ("walkString", "L", 251)],
//        ["ReadaheadTable", 48, ("walkString", "RSN", 26), ("Dot", "RS", 58), ("Name", "RSN", 48), ("walkIdentifier", "RSN", 27)],
//        ["ReadaheadTable", 49, ("walkString", "RSN", 26), ("Dot", "RS", 59), ("Name", "RSN", 49), ("walkIdentifier", "RSN", 27)],
//        ["ReadaheadTable", 50, ("attribute", "L", 107), ("keywords", "L", 107), ("output", "L", 107), ("optimize", "L", 107), ("walkIdentifier", "L", 107), ("walkString", "L", 107)],
//        ["ReadaheadTable", 51, ("attribute", "L", 108), ("keywords", "L", 108), ("output", "L", 108), ("optimize", "L", 108), ("walkIdentifier", "L", 108), ("walkString", "L", 108)],
//        ["ReadaheadTable", 52, ("attribute", "L", 109), ("keywords", "L", 109), ("output", "L", 109), ("optimize", "L", 109), ("walkIdentifier", "L", 109), ("walkString", "L", 109)],
//        ["ReadaheadTable", 53, ("AndExpression", "RSN", 60), ("Alternation", "RSN", 61)],
//        ["ReadaheadTable", 54, ("walkIdentifier", "L", 252), ("walkString", "L", 252), ("-|", "L", 252)],
//        ["ReadaheadTable", 55, ("walkIdentifier", "L", 110), ("walkString", "L", 110), ("-|", "L", 110)],
//        ["ReadaheadTable", 56, ("FatRightArrow", "RS", 63), ("RightArrow", "L", 111), ("Dot", "L", 111)],
//        ["ReadaheadTable", 57, ("attribute", "L", 112), ("keywords", "L", 112), ("output", "L", 112), ("optimize", "L", 112), ("walkIdentifier", "L", 112), ("walkString", "L", 112)],
//        ["ReadaheadTable", 58, ("attribute", "L", 253), ("keywords", "L", 253), ("output", "L", 253), ("optimize", "L", 253), ("walkIdentifier", "L", 253), ("walkString", "L", 253)],
//        ["ReadaheadTable", 59, ("attribute", "L", 254), ("keywords", "L", 254), ("output", "L", 254), ("optimize", "L", 254), ("walkIdentifier", "L", 254), ("walkString", "L", 254)],
//        ["ReadaheadTable", 60, ("CloseRound", "L", 255), ("CloseCurly", "L", 255), ("Dot", "L", 255), ("RightArrow", "L", 255), ("FatRightArrow", "L", 255)],
//        ["ReadaheadTable", 61, ("And", "RS", 67), ("CloseRound", "L", 113), ("CloseCurly", "L", 113), ("Dot", "L", 113), ("Minus", "L", 113), ("RightArrow", "L", 113), ("FatRightArrow", "L", 113)],
//        ["ReadaheadTable", 62, ("walkIdentifier", "L", 114), ("walkString", "L", 114), ("-|", "L", 114)],
//        ["ReadaheadTable", 63, ("walkInteger", "RSN", 68), ("SemanticAction", "RSN", 69), ("Minus", "RS", 70), ("Name", "RSN", 71), ("Plus", "RS", 72), ("TreeBuildingOptions", "RSN", 73)],
//        ["ReadaheadTable", 64, ("attribute", "L", 115), ("keywords", "L", 115), ("output", "L", 115), ("optimize", "L", 115), ("walkIdentifier", "L", 115), ("walkString", "L", 115)],
//        ["ReadaheadTable", 65, ("attribute", "L", 116), ("keywords", "L", 116), ("output", "L", 116), ("optimize", "L", 116), ("walkIdentifier", "L", 116), ("walkString", "L", 116)],
//        ["ReadaheadTable", 66, ("CloseRound", "L", 117), ("CloseCurly", "L", 117), ("Dot", "L", 117), ("RightArrow", "L", 117), ("FatRightArrow", "L", 117)],
//        ["ReadaheadTable", 67, ("Alternation", "RSN", 74), ("Concatenation", "RSN", 75), ("CloseRound", "L", 256), ("CloseCurly", "L", 256), ("Dot", "L", 256), ("Minus", "L", 256), ("And", "L", 256), ("RightArrow", "L", 256), ("FatRightArrow", "L", 256)],
//        ["ReadaheadTable", 68, ("RightArrow", "L", 257), ("Dot", "L", 257)],
//        ["ReadaheadTable", 69, ("RightArrow", "L", 258), ("Dot", "L", 258)],
//        ["ReadaheadTable", 70, ("walkInteger", "RSN", 79)],
//        ["ReadaheadTable", 71, ("RightArrow", "L", 259), ("Dot", "L", 259)],
//        ["ReadaheadTable", 72, ("walkInteger", "RSN", 68)],
//        ["ReadaheadTable", 73, ("RightArrow", "L", 260), ("Dot", "L", 260)],
//        ["ReadaheadTable", 74, ("CloseRound", "L", 261), ("CloseCurly", "L", 261), ("Dot", "L", 261), ("Minus", "L", 261), ("RightArrow", "L", 261), ("FatRightArrow", "L", 261)],
//        ["ReadaheadTable", 75, ("Or", "RS", 83), ("CloseRound", "L", 118), ("CloseCurly", "L", 118), ("Dot", "L", 118), ("Minus", "L", 118), ("And", "L", 118), ("RightArrow", "L", 118), ("FatRightArrow", "L", 118)],
//        ["ReadaheadTable", 76, ("CloseRound", "L", 119), ("CloseCurly", "L", 119), ("Dot", "L", 119), ("Minus", "L", 119), ("And", "L", 119), ("RightArrow", "L", 119), ("FatRightArrow", "L", 119)],
//        ["ReadaheadTable", 77, ("RightArrow", "L", 120), ("Dot", "L", 120)],
//        ["ReadaheadTable", 78, ("RightArrow", "L", 121), ("Dot", "L", 121)],
//        ["ReadaheadTable", 79, ("RightArrow", "L", 262), ("Dot", "L", 262)],
//        ["ReadaheadTable", 80, ("RightArrow", "L", 122), ("Dot", "L", 122)],
//        ["ReadaheadTable", 81, ("RightArrow", "L", 123), ("Dot", "L", 123)],
//        ["ReadaheadTable", 82, ("CloseRound", "L", 124), ("CloseCurly", "L", 124), ("Dot", "L", 124), ("Minus", "L", 124), ("RightArrow", "L", 124), ("FatRightArrow", "L", 124)],
//        ["ReadaheadTable", 83, ("Concatenation", "RSN", 85), ("RepetitionOption", "RSN", 86)],
//        ["ReadaheadTable", 84, ("RightArrow", "L", 125), ("Dot", "L", 125)],
//        ["ReadaheadTable", 85, ("Or", "RS", 83), ("CloseRound", "L", 263), ("CloseCurly", "L", 263), ("Dot", "L", 263), ("Minus", "L", 263), ("And", "L", 263), ("RightArrow", "L", 263), ("FatRightArrow", "L", 263)],
//        ["ReadaheadTable", 86, ("Primary", "RSN", 88), ("RepetitionOption", "RSN", 89), ("CloseRound", "L", 126), ("CloseCurly", "L", 126), ("Dot", "L", 126), ("Minus", "L", 126), ("And", "L", 126), ("Or", "L", 126), ("RightArrow", "L", 126), ("FatRightArrow", "L", 126)],
//        ["ReadaheadTable", 87, ("CloseRound", "L", 127), ("CloseCurly", "L", 127), ("Dot", "L", 127), ("Minus", "L", 127), ("And", "L", 127), ("RightArrow", "L", 127), ("FatRightArrow", "L", 127)],
//        ["ReadaheadTable", 88, ("Plus", "RS", 90), ("Star", "RS", 91), ("QuestionMark", "RS", 92), ("OpenRound", "L", 128), ("OpenCurly", "L", 128), ("walkSymbol", "L", 128), ("walkIdentifier", "L", 128), ("walkString", "L", 128), ("walkCharacter", "L", 128), ("walkInteger", "L", 128), ("CloseRound", "L", 128), ("CloseCurly", "L", 128), ("Dot", "L", 128), ("Minus", "L", 128), ("And", "L", 128), ("Or", "L", 128), ("RightArrow", "L", 128), ("FatRightArrow", "L", 128)],
//        ["ReadaheadTable", 89, ("Primary", "RSN", 93), ("RepetitionOption", "RSN", 89), ("CloseRound", "L", 264), ("CloseCurly", "L", 264), ("Dot", "L", 264), ("Minus", "L", 264), ("And", "L", 264), ("Or", "L", 264), ("RightArrow", "L", 264), ("FatRightArrow", "L", 264)],
//        ["ReadaheadTable", 90, ("OpenRound", "L", 265), ("OpenCurly", "L", 265), ("walkSymbol", "L", 265), ("walkIdentifier", "L", 265), ("walkString", "L", 265), ("walkCharacter", "L", 265), ("walkInteger", "L", 265), ("CloseRound", "L", 265), ("CloseCurly", "L", 265), ("Dot", "L", 265), ("Minus", "L", 265), ("And", "L", 265), ("Or", "L", 265), ("RightArrow", "L", 265), ("FatRightArrow", "L", 265)],
//        ["ReadaheadTable", 91, ("OpenRound", "L", 266), ("OpenCurly", "L", 266), ("walkSymbol", "L", 266), ("walkIdentifier", "L", 266), ("walkString", "L", 266), ("walkCharacter", "L", 266), ("walkInteger", "L", 266), ("CloseRound", "L", 266), ("CloseCurly", "L", 266), ("Dot", "L", 266), ("Minus", "L", 266), ("And", "L", 266), ("Or", "L", 266), ("RightArrow", "L", 266), ("FatRightArrow", "L", 266)],
//        ["ReadaheadTable", 92, ("OpenRound", "L", 267), ("OpenCurly", "L", 267), ("walkSymbol", "L", 267), ("walkIdentifier", "L", 267), ("walkString", "L", 267), ("walkCharacter", "L", 267), ("walkInteger", "L", 267), ("CloseRound", "L", 267), ("CloseCurly", "L", 267), ("Dot", "L", 267), ("Minus", "L", 267), ("And", "L", 267), ("Or", "L", 267), ("RightArrow", "L", 267), ("FatRightArrow", "L", 267)],
//        ["ReadaheadTable", 93, ("Plus", "RS", 90), ("Star", "RS", 91), ("QuestionMark", "RS", 92), ("OpenRound", "L", 129), ("OpenCurly", "L", 129), ("walkSymbol", "L", 129), ("walkIdentifier", "L", 129), ("walkString", "L", 129), ("walkCharacter", "L", 129), ("walkInteger", "L", 129), ("CloseRound", "L", 129), ("CloseCurly", "L", 129), ("Dot", "L", 129), ("Minus", "L", 129), ("And", "L", 129), ("Or", "L", 129), ("RightArrow", "L", 129), ("FatRightArrow", "L", 129)],
//        ["ReadaheadTable", 94, ("CloseRound", "L", 130), ("CloseCurly", "L", 130), ("Dot", "L", 130), ("Minus", "L", 130), ("And", "L", 130), ("Or", "L", 130), ("RightArrow", "L", 130), ("FatRightArrow", "L", 130)],
//        ["ReadaheadTable", 95, ("OpenRound", "L", 131), ("OpenCurly", "L", 131), ("walkSymbol", "L", 131), ("walkIdentifier", "L", 131), ("walkString", "L", 131), ("walkCharacter", "L", 131), ("walkInteger", "L", 131), ("CloseRound", "L", 131), ("CloseCurly", "L", 131), ("Dot", "L", 131), ("Minus", "L", 131), ("And", "L", 131), ("Or", "L", 131), ("RightArrow", "L", 131), ("FatRightArrow", "L", 131)],
//        ["ReadaheadTable", 96, ("OpenRound", "L", 132), ("OpenCurly", "L", 132), ("walkSymbol", "L", 132), ("walkIdentifier", "L", 132), ("walkString", "L", 132), ("walkCharacter", "L", 132), ("walkInteger", "L", 132), ("CloseRound", "L", 132), ("CloseCurly", "L", 132), ("Dot", "L", 132), ("Minus", "L", 132), ("And", "L", 132), ("Or", "L", 132), ("RightArrow", "L", 132), ("FatRightArrow", "L", 132)],
//        ["ReadaheadTable", 97, ("OpenRound", "L", 133), ("OpenCurly", "L", 133), ("walkSymbol", "L", 133), ("walkIdentifier", "L", 133), ("walkString", "L", 133), ("walkCharacter", "L", 133), ("walkInteger", "L", 133), ("CloseRound", "L", 133), ("CloseCurly", "L", 133), ("Dot", "L", 133), ("Minus", "L", 133), ("And", "L", 133), ("Or", "L", 133), ("RightArrow", "L", 133), ("FatRightArrow", "L", 133)],
//        ["ReadbackTable", 98, (("parser", 2), "RS", 134)],
//        ["ReadbackTable", 99, (("scanner", 3), "RS", 135)],
//        ["ReadbackTable", 100, (("superScanner", 4), "RS", 136)],
//        ["ReadbackTable", 101, (("scanner", 10), "RS", 137)],
//        ["ReadbackTable", 102, (("Production", 11), "RSN", 138), (("Macro", 17), "RSN", 139)],
//        ["ReadbackTable", 103, (("walkString", 26), "RSN", 140)],
//        ["ReadbackTable", 104, (("walkIdentifier", 27), "RSN", 141)],
//        ["ReadbackTable", 105, (("AndExpression", 42), "RSN", 142)],
//        ["ReadbackTable", 106, (("RightPart", 34), "RSN", 143)],
//        ["ReadbackTable", 107, (("Dot", 38), "RS", 144)],
//        ["ReadbackTable", 108, (("Dot", 39), "RS", 145)],
//        ["ReadbackTable", 109, (("Dot", 40), "RS", 146)],
//        ["ReadbackTable", 110, (("Dot", 44), "RS", 147)],
//        ["ReadbackTable", 111, (("Expression", 56), "RSN", 148)],
//        ["ReadbackTable", 112, (("Dot", 47), "RS", 149)],
//        ["ReadbackTable", 113, (("Alternation", 61), "RSN", 150)],
//        ["ReadbackTable", 114, (("Dot", 54), "RS", 151)],
//        ["ReadbackTable", 115, (("Dot", 58), "RS", 152)],
//        ["ReadbackTable", 116, (("Dot", 59), "RS", 153)],
//        ["ReadbackTable", 117, (("AndExpression", 60), "RSN", 154)],
//        ["ReadbackTable", 118, (("Concatenation", 75), "RSN", 155)],
//        ["ReadbackTable", 119, (("And", 67), "L", 226)],
//        ["ReadbackTable", 120, (("walkInteger", 68), "RSN", 156)],
//        ["ReadbackTable", 121, (("SemanticAction", 69), "RSN", 157)],
//        ["ReadbackTable", 122, (("Name", 71), "RSN", 158)],
//        ["ReadbackTable", 123, (("TreeBuildingOptions", 73), "RSN", 159)],
//        ["ReadbackTable", 124, (("Alternation", 74), "RSN", 160)],
//        ["ReadbackTable", 125, (("walkInteger", 79), "RSN", 161)],
//        ["ReadbackTable", 126, (("RepetitionOption", 86), "RSN", 162)],
//        ["ReadbackTable", 127, (("Concatenation", 85), "RSN", 163)],
//        ["ReadbackTable", 128, (("Primary", 88), "RSN", 164)],
//        ["ReadbackTable", 129, (("Primary", 93), "RSN", 165)],
//        ["ReadbackTable", 130, (("RepetitionOption", 89), "RSN", 166)],
//        ["ReadbackTable", 131, (("Plus", 90), "RS", 167)],
//        ["ReadbackTable", 132, (("Star", 91), "RS", 168)],
//        ["ReadbackTable", 133, (("QuestionMark", 92), "RS", 169)],
//        ["ReadbackTable", 134, (("|-", 1), "L", 233)],
//        ["ReadbackTable", 135, (("|-", 1), "L", 233)],
//        ["ReadbackTable", 136, (("|-", 1), "L", 233)],
//        ["ReadbackTable", 137, (("super", 5), "RS", 170)],
//        ["ReadbackTable", 138, (("Production", 11), "RSN", 138), (("Macro", 17), "RSN", 139), (("GrammarType", 6), "L", 222), (("Defaults", 18), "L", 222)],
//        ["ReadbackTable", 139, (("Production", 11), "RSN", 138), (("Macro", 17), "RSN", 139), (("GrammarType", 6), "L", 222), (("Defaults", 18), "L", 222)],
//        ["ReadbackTable", 140, (("defaults", 23), "L", 234), (("Name", 28), "L", 234), (("output", 16), "L", 234), (("Name", 35), "L", 234), (("optimize", 15), "L", 234), (("defaults", 36), "L", 234), (("Name", 48), "L", 234), (("Name", 49), "L", 234), (("keywords", 14), "L", 234), (("defaults", 37), "L", 234)],
//        ["ReadbackTable", 141, (("defaults", 23), "L", 234), (("Name", 28), "L", 234), (("output", 16), "L", 234), (("Name", 35), "L", 234), (("optimize", 15), "L", 234), (("defaults", 36), "L", 234), (("Name", 48), "L", 234), (("Name", 49), "L", 234), (("keywords", 14), "L", 234), (("defaults", 37), "L", 234)],
//        ["ReadbackTable", 142, (("Equals", 32), "L", 228), (("RightArrow", 46), "L", 228)],
//        ["ReadbackTable", 143, (("RightPart", 34), "RSN", 143), (("LeftPart", 22), "L", 231)],
//        ["ReadbackTable", 144, (("Name", 28), "RSN", 171)],
//        ["ReadbackTable", 145, (("Name", 29), "RSN", 172)],
//        ["ReadbackTable", 146, (("Name", 30), "RSN", 173)],
//        ["ReadbackTable", 147, (("RightParts", 33), "RSN", 174)],
//        ["ReadbackTable", 148, (("RightArrow", 46), "RS", 175)],
//        ["ReadbackTable", 149, (("Name", 35), "RSN", 176)],
//        ["ReadbackTable", 150, (("Minus", 53), "L", 230)],
//        ["ReadbackTable", 151, (("Expression", 43), "RSN", 177)],
//        ["ReadbackTable", 152, (("Name", 48), "RSN", 178)],
//        ["ReadbackTable", 153, (("Name", 49), "RSN", 179)],
//        ["ReadbackTable", 154, (("Minus", 53), "RS", 180)],
//        ["ReadbackTable", 155, (("And", 67), "L", 226)],
//        ["ReadbackTable", 156, (("Plus", 72), "RS", 181), (("FatRightArrow", 63), "L", 232)],
//        ["ReadbackTable", 157, (("FatRightArrow", 63), "L", 232)],
//        ["ReadbackTable", 158, (("FatRightArrow", 63), "L", 232)],
//        ["ReadbackTable", 159, (("FatRightArrow", 63), "RS", 182)],
//        ["ReadbackTable", 160, (("And", 67), "RS", 183)],
//        ["ReadbackTable", 161, (("Minus", 70), "RS", 184)],
//        ["ReadbackTable", 162, (("Or", 83), "L", 223)],
//        ["ReadbackTable", 163, (("Or", 83), "RS", 185)],
//        ["ReadbackTable", 164, (("RepetitionOption", 86), "L", 220)],
//        ["ReadbackTable", 165, (("RepetitionOption", 89), "L", 220)],
//        ["ReadbackTable", 166, (("RepetitionOption", 89), "RSN", 186), (("RepetitionOption", 86), "RSN", 187)],
//        ["ReadbackTable", 167, (("Primary", 88), "RSN", 188), (("Primary", 93), "RSN", 189)],
//        ["ReadbackTable", 168, (("Primary", 88), "RSN", 190), (("Primary", 93), "RSN", 191)],
//        ["ReadbackTable", 169, (("Primary", 88), "RSN", 192), (("Primary", 93), "RSN", 193)],
//        ["ReadbackTable", 170, (("|-", 1), "L", 233)],
//        ["ReadbackTable", 171, (("Name", 28), "RSN", 171), (("keywords", 14), "RS", 194)],
//        ["ReadbackTable", 172, (("optimize", 15), "RS", 195)],
//        ["ReadbackTable", 173, (("output", 16), "RS", 196)],
//        ["ReadbackTable", 174, (("LeftPart", 22), "RSN", 197)],
//        ["ReadbackTable", 175, (("RightPart", 34), "L", 221)],
//        ["ReadbackTable", 176, (("Name", 35), "RSN", 198), (("defaults", 23), "RS", 199)],
//        ["ReadbackTable", 177, (("Equals", 32), "RS", 200)],
//        ["ReadbackTable", 178, (("defaults", 36), "RS", 201), (("Name", 48), "RSN", 178)],
//        ["ReadbackTable", 179, (("defaults", 37), "RS", 202), (("Name", 49), "RSN", 179)],
//        ["ReadbackTable", 180, (("AndExpression", 42), "RSN", 203)],
//        ["ReadbackTable", 181, (("FatRightArrow", 63), "L", 232)],
//        ["ReadbackTable", 182, (("Expression", 56), "RSN", 204)],
//        ["ReadbackTable", 183, (("Alternation", 61), "RSN", 205)],
//        ["ReadbackTable", 184, (("FatRightArrow", 63), "L", 232)],
//        ["ReadbackTable", 185, (("Concatenation", 85), "RSN", 163), (("Concatenation", 75), "RSN", 206)],
//        ["ReadbackTable", 186, (("RepetitionOption", 89), "RSN", 186), (("RepetitionOption", 86), "RSN", 187)],
//        ["ReadbackTable", 187, (("Or", 83), "L", 223)],
//        ["ReadbackTable", 188, (("RepetitionOption", 86), "L", 220)],
//        ["ReadbackTable", 189, (("RepetitionOption", 89), "L", 220)],
//        ["ReadbackTable", 190, (("RepetitionOption", 86), "L", 220)],
//        ["ReadbackTable", 191, (("RepetitionOption", 89), "L", 220)],
//        ["ReadbackTable", 192, (("RepetitionOption", 86), "L", 220)],
//        ["ReadbackTable", 193, (("RepetitionOption", 89), "L", 220)],
//        ["ReadbackTable", 194, (("GrammarType", 6), "L", 218), (("Defaults", 18), "L", 218)],
//        ["ReadbackTable", 195, (("GrammarType", 6), "L", 218), (("Defaults", 18), "L", 218)],
//        ["ReadbackTable", 196, (("GrammarType", 6), "L", 218), (("Defaults", 18), "L", 218)],
//        ["ReadbackTable", 197, (("Production", 11), "L", 225), (("Macro", 17), "L", 225)],
//        ["ReadbackTable", 198, (("Name", 35), "RSN", 198), (("defaults", 23), "RS", 199)],
//        ["ReadbackTable", 199, (("attribute", 41), "RS", 207), (("attribute", 13), "RS", 208)],
//        ["ReadbackTable", 200, (("Name", 21), "RSN", 209)],
//        ["ReadbackTable", 201, (("nonterminal", 24), "RS", 210)],
//        ["ReadbackTable", 202, (("terminal", 25), "RS", 211)],
//        ["ReadbackTable", 203, (("Equals", 32), "L", 228), (("RightArrow", 46), "L", 228)],
//        ["ReadbackTable", 204, (("RightArrow", 46), "RS", 212)],
//        ["ReadbackTable", 205, (("Minus", 53), "L", 230)],
//        ["ReadbackTable", 206, (("And", 67), "L", 226)],
//        ["ReadbackTable", 207, (("Defaults", 18), "L", 218)],
//        ["ReadbackTable", 208, (("GrammarType", 6), "L", 218)],
//        ["ReadbackTable", 209, (("Production", 11), "L", 235), (("Macro", 17), "L", 235)],
//        ["ReadbackTable", 210, (("attribute", 41), "RS", 213), (("attribute", 13), "RS", 214)],
//        ["ReadbackTable", 211, (("attribute", 13), "RS", 215), (("attribute", 41), "RS", 216)],
//        ["ReadbackTable", 212, (("RightPart", 34), "L", 221)],
//        ["ReadbackTable", 213, (("Defaults", 18), "L", 218)],
//        ["ReadbackTable", 214, (("GrammarType", 6), "L", 218)],
//        ["ReadbackTable", 215, (("GrammarType", 6), "L", 218)],
//        ["ReadbackTable", 216, (("Defaults", 18), "L", 218)],
//        ["ReduceTable", 217, "LeftPart", (11, "RSN", 22), (17, "RSN", 22)],
//        ["ReduceTable", 218, "Defaults", (6, "RSN", 18), (18, "RSN", 18), (31, "RSN", 18)],
//        ["ReduceTable", 219, "SemanticAction", (63, "RSN", 69)],
//        ["ReduceTable", 220, "RepetitionOption", (83, "RSN", 86), (86, "RSN", 89), (89, "RSN", 89)],
//        ["ReduceTable", 221, "RightPart", (22, "RSN", 34), (34, "RSN", 34)],
//        ["ReduceTable", 222, "Rules", (6, "RSN", 12), (18, "RSN", 12), (31, "RSN", 12)],
//        ["ReduceTable", 223, "Concatenation", (67, "RSN", 75), (83, "RSN", 85)],
//        ["ReduceTable", 224, "Secondary", ],
//        ["ReduceTable", 225, "Production", (6, "RSN", 11), (11, "RSN", 11), (17, "RSN", 11), (31, "RSN", 11)],
//        ["ReduceTable", 226, "Alternation", (53, "RSN", 61), (67, "RSN", 74)],
//        ["ReduceTable", 227, "Primary", (86, "RSN", 88), (89, "RSN", 93)],
//        ["ReduceTable", 228, "Expression", (32, "RSN", 43), (46, "RSN", 56)],
//        ["ReduceTable", 229, "Attribute", ],
//        ["ReduceTable", 230, "AndExpression", (32, "RSN", 42), (46, "RSN", 42), (53, "RSN", 60)],
//        ["ReduceTable", 231, "RightParts", (22, "RSN", 33)],
//        ["ReduceTable", 232, "TreeBuildingOptions", (63, "RSN", 73)],
//        ["ReduceTable", 233, "GrammarType", (1, "RSN", 6)],
//        ["ReduceTable", 234, "Name", (11, "RSN", 21), (14, "RSN", 28), (15, "RSN", 29), (16, "RSN", 30), (17, "RSN", 21), (23, "RSN", 35), (28, "RSN", 28), (35, "RSN", 35), (36, "RSN", 48), (37, "RSN", 49), (48, "RSN", 48), (49, "RSN", 49), (63, "RSN", 71)],
//        ["ReduceTable", 235, "Macro", (6, "RSN", 17), (11, "RSN", 17), (17, "RSN", 17), (31, "RSN", 17)],
//        ["ReduceTable", 236, "Byte", ],
//        ["ReduceTable", 237, "Grammar", ],
//        ["ReduceTable", 238, "SemanticActionParameter", ],
//        ["SemanticTable", 239, "processTypeNow", ["parser"], 7],
//        ["SemanticTable", 240, "processTypeNow", ["scanner"], 8],
//        ["SemanticTable", 241, "processTypeNow", ["superScanner"], 9],
//        ["SemanticTable", 242, "processTypeNow", ["superScanner"], 19],
//        ["SemanticTable", 243, "buildTree", ["walkGrammar"], 20],
//        ["SemanticTable", 244, "buildTree", ["walkGrammar"], 20],
//        ["SemanticTable", 245, "processAndDiscardDefaultsNow", [], 31],
//        ["SemanticTable", 246, "buildTree", ["walkOr"], 45],
//        ["SemanticTable", 247, "buildTree", ["walkKeywords"], 50],
//        ["SemanticTable", 248, "buildTree", ["walkOptimize"], 51],
//        ["SemanticTable", 249, "buildTree", ["walkOutput"], 52],
//        ["SemanticTable", 250, "buildTree", ["walkProduction"], 55],
//        ["SemanticTable", 251, "buildTree", ["walkAttributeDefaults"], 57],
//        ["SemanticTable", 252, "buildTree", ["walkMacro"], 62],
//        ["SemanticTable", 253, "buildTree", ["walkAttributeNonterminalDefaults"], 64],
//        ["SemanticTable", 254, "buildTree", ["walkAttributeTerminalDefaults"], 65],
//        ["SemanticTable", 255, "buildTree", ["walkMinus"], 66],
//        ["SemanticTable", 256, "buildTree", ["walkEpsilon"], 76],
//        ["SemanticTable", 257, "buildTree", ["walkBuildTreeFromLeftIndex"], 77],
//        ["SemanticTable", 258, "buildTree", ["walkTreeBuildingSemanticAction"], 78],
//        ["SemanticTable", 259, "buildTree", ["walkBuildTreeOrTokenFromName"], 80],
//        ["SemanticTable", 260, "buildTree", ["walkConcatenation"], 81],
//        ["SemanticTable", 261, "buildTree", ["walkAnd"], 82],
//        ["SemanticTable", 262, "buildTree", ["walkBuildTreeFromRightIndex"], 84],
//        ["SemanticTable", 263, "buildTree", ["walkOr"], 87],
//        ["SemanticTable", 264, "buildTree", ["walkConcatenation"], 94],
//        ["SemanticTable", 265, "buildTree", ["walkPlus"], 95],
//        ["SemanticTable", 266, "buildTree", ["walkStar"], 96],
//        ["SemanticTable", 267, "buildTree", ["walkQuestionMark"], 97],
//        ["AcceptTable", 268]]
//        ["keywords", ],
//        ["ReadaheadTable", 1, (")", "RS", 3), ("S", "RSN", 4), ("Identifier", "RSN", 2), ("(", "RS", 1)],
//        ["ReadaheadTable", 2, ],
//        ["ReadaheadTable", 3, ("EndOfFile", "L", 7), ("(", "L", 7), ("Identifier", "L", 7), (")", "L", 7)],
//        ["ReadaheadTable", 4, (")", "RS", 3), ("S", "RSN", 4), ("Identifier", "RSN", 2), ("(", "RS", 1)],
//        ["ReadaheadTable", 5, ],
//        ["ReduceTable", 6, "S", (1, "RSN", 4), (4, "RSN", 4)],
//        ["SemanticTable", 7, "buildTree", ["list"], 5],
//        ["AcceptTable", 8]]
}
