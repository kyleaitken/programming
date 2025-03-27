//
//  DualFiniteStateMachineState.swift
//  Constructor
//
//  Created by Kyle Aitken on 2025-02-06.
//

public class FiniteStateMachineState: Relatable {
    var stateNumber: Int = 0
    var isInitial: Bool = false
    var isFinal: Bool = false
    var transitions: Array<Transition>
    var leftPart: String = ""
    var debug = false
    
    func isReadahead() -> Bool {
        return false
    }
    
    func isReadback() -> Bool {
        return false
    }
    
    init () {transitions = []}
    
    init (final: Bool) {
        transitions = []
        isFinal = final
        isInitial = !isFinal
    }
    
    func printOn() {
        var stateDescription = "State \(stateNumber)"
        if isInitial {
            stateDescription += " initial"
        }
        if isFinal {
            stateDescription += " final"
        }
        print(stateDescription)
        
        for transition in transitions {
            transition.printOn()
        }
    }
    
    // Conformance to CustomStringConvertible for the `description` property
    public var description: String {
        let isReadahead = isReadahead()
        var stateDescription = "State \(stateNumber)"
        if isInitial {
            stateDescription += " initial"
        }
        if isFinal {
            stateDescription += " final"
        }
        stateDescription += "\n"
        
        for transition in transitions {
            stateDescription += transition.description + "\n"
        }
        
        return stateDescription
    }
    
    func copy() -> FiniteStateMachineState {
        let newFsmState = FiniteStateMachineState()
        newFsmState.stateNumber = self.stateNumber
        newFsmState.isInitial = self.isInitial
        newFsmState.isFinal = self.isFinal
        
        for transition in self.transitions {
            newFsmState.transitions.append(transition.copy())
        }
        
        return newFsmState
    }
    
    var terseDescription: String {
        return "State \(stateNumber) \(isInitial ? "(initial)" : "") \(isFinal ? "(final)" : "")"
    }
    
    // not really using this, but it's in here to supress errors about relatable/hashable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(stateNumber)
        hasher.combine(isInitial)
        hasher.combine(isFinal)
    }
    
    public static func < (lhs: FiniteStateMachineState, rhs: FiniteStateMachineState) -> Bool {
        return lhs.stateNumber < rhs.stateNumber
    }
    
    public static func == (lhs: FiniteStateMachineState, rhs: FiniteStateMachineState) -> Bool {
        return lhs === rhs
    }
    
    func createTuplesFromTransitions (transitions: [Transition]) -> [(FiniteStateMachineState, Label, FiniteStateMachineState)] {
        var tuples: [(FiniteStateMachineState, Label, FiniteStateMachineState)] = []
        for transition in transitions {
            guard let label = transition.label, let gotoState = transition.goto else {
                continue
            }
            tuples.append((self, label, gotoState))
        }
        return tuples
    }
    
    func transitionsDo(_ closure: (Transition) -> Void) {
        for transition in self.transitions {
            closure(transition)
        }
    }
}


public class DualFiniteStateMachineState: FiniteStateMachineState {
    var stateSet1: Set<FiniteStateMachineState> = Set()
    var stateSet2: Set<FiniteStateMachineState> = Set()
        
    func match(_ otherState: DualFiniteStateMachineState) -> Bool {
        // Compare stateSet1 and stateSet2 in both dual states
        return self.stateSet1 == otherState.stateSet1 && self.stateSet2 == otherState.stateSet2
    }
    
    func getAllTransitionLabels() -> Set<Label> {
        let labelsSet1 = stateSet1.flatMap { $0.transitions.compactMap { $0.label } }
        let labelsSet2 = stateSet2.flatMap { $0.transitions.compactMap { $0.label } }
        return Set(labelsSet1).union(labelsSet2)
    }
    
    func debugPrintOn() {
        print("Dual FSM State Sets:")
        print("State set 1:")
        for state in stateSet1 {
            state.printOn()
        }
        print("State set 2:")
        for state in stateSet2 {
            state.printOn()
        }
        print("Dual state characteristics:")
        super.printOn()
    }
    
    // with this label, builds a new DualFSMState and add a transition to this new DualFSMState with this label
    func buildSuccessorFor(_ label: Label) -> DualFiniteStateMachineState {
        let successorDualFSM = DualFiniteStateMachineState()
        
        // for states in stateSet1, get goto states in its transitions (successor states) that match the label, add those to the stateSet1 of the new DualFSMState
        let state1Successors = stateSet1.flatMap { state in
            state.transitions.filter { $0.label == label }.map { $0.goto }
        }
        successorDualFSM.stateSet1 = Set(state1Successors.compactMap { $0 })

        // for states in stateSet2, get successor states with the label "label", add those to the stateSet2 of the new DualFSMState
        let state2Successors = stateSet2.flatMap { state in
            state.transitions.filter { $0.label == label }.map { $0.goto }
        }
        successorDualFSM.stateSet2 = Set(state2Successors.compactMap { $0 })
        
        return successorDualFSM
    }
    
    static func buildInitialDualStateFrom(_ fsm1: FiniteStateMachine, _ fsm2: FiniteStateMachine) -> DualFiniteStateMachineState {
        let dualFSM = DualFiniteStateMachineState()
        dualFSM.stateSet1 = Set(fsm1.getInitialStates())
        dualFSM.stateSet2 = Set(fsm2.getInitialStates())
        dualFSM.isInitial = true
        dualFSM.transitions = []
        
        return dualFSM
    }
    
    static func dualFSMFor(_ fsm1: FiniteStateMachine, _ fsm2: FiniteStateMachine) -> FiniteStateMachine {
        var dualStates: [DualFiniteStateMachineState] = []

        // set up initial dual state with initial states of each FSM and add it to the collection
        dualStates.append(self.buildInitialDualStateFrom(fsm1, fsm2))
        
        var index = 0
        while (index < dualStates.count) {
            let currDualState = dualStates[index]
            
            // get all transition labels for this dual state (set of labels)
            let allLabels = currDualState.getAllTransitionLabels()
            
            // make new dual states for each label, add a transition from original dualState to the new one with that label
            for label in allLabels {
                let candidateSuccessor = currDualState.buildSuccessorFor(label)
                
                // look for candidate successor in the dualStates collection
                if let existingSuccessor = self.searchFor(candidateSuccessor, dualStates) {
                    currDualState.transitions.append(Transition(label, existingSuccessor))
                } else {
                    let newSuccessor = candidateSuccessor
                    newSuccessor.stateNumber = dualStates.count
                    currDualState.transitions.append(Transition(label, newSuccessor))
                    dualStates.append(newSuccessor)
                }
            }
            index += 1
        }
        
        // Make an FSM where the states are the dual states
        let newFSM = FiniteStateMachine()
        newFSM.addAll(fsmStates: dualStates)
        return newFSM
    }
    
    static func searchFor(_ candidate: DualFiniteStateMachineState, _ dualStates: [DualFiniteStateMachineState]) -> DualFiniteStateMachineState? {
        for state in dualStates {
            if state.match(candidate) {
                return state
            }
        }
        return nil
    }
    
}


public class ReadaheadState: FiniteStateMachineState {
    var finalItems: [FiniteStateMachineState] = []
    var initialItems: [FiniteStateMachineState] = []
    var follow: [String] = []
    
    func hasFollow () -> Bool {
        return self.follow.count > 0
    }
    
    override func isReadahead() -> Bool {
        return true
    }
    
    override func printOn() {
//        let itemStateNumbers = finalItems.map { String($0.stateNumber) }.joined(separator: " ")
//        print("ReadaheadTable \(self.stateNumber) {\(itemStateNumbers)}")
        print("ReadaheadTable \(self.stateNumber)")

        for transition in self.transitions {
            transition.printOn()
        }
    }
    
    // Conformance to CustomStringConvertible for the `description` property
    public override var description: String {
        var stateDescription = "Readahead "
        stateDescription += super.description
        
        if self.debug {
            stateDescription += "\nRA state follow set: \(self.follow)\n"

            stateDescription += "\nRA state initial items\n"
            for item in initialItems {
                stateDescription += item.description
            }
            stateDescription += "\n"
            
            stateDescription += "\nRA state final items\n"
            for item in finalItems {
                stateDescription += item.description
            }
            stateDescription += "\n"
        }
        
        return stateDescription
    }
    
    func getFormattedParserTable() -> String {
        var transitions = ""

        for transition in self.transitions {
            if let label = transition.label {
                let attributesString = label.attributes.description
                let gotoStateNumber = (transition.goto)!.stateNumber
                let tuple = "(\"\(label.name)\", \"\(attributesString)\", \(gotoStateNumber))"
                transitions += "\(tuple), "
            }
        }

        // Remove trailing comma and space
        if !transitions.isEmpty {
            transitions.removeLast(2)
        }
        return "[\"ReadaheadTable\", \(self.stateNumber), \(transitions)],\n"
    }
    

    func getFormattedScannerTable() -> String {
        var transitions = ""
        let transitionsGotoPartition = Dictionary(grouping: self.transitions) { $0.goto!.stateNumber }
                
        for (gotoStateNumber, groupedTransitions) in transitionsGotoPartition {
            // partition grouped transitions by attributes now
            let transitionsByAttributes = Dictionary(grouping: groupedTransitions) { $0.label?.attributes.description }

            for (attributeString, attributeGroupedTransitions) in transitionsByAttributes {
                var printableLabels = ""
                var nonPrintableLabels: [Int] = []
                
                for transition in attributeGroupedTransitions {
                    let intSymbol = Int(transition.label!.name)
                    if Grammar.isPrintable(intSymbol!) {
                        let labelNameAsUnicode = String(Character(UnicodeScalar(intSymbol!)!))
                        printableLabels += labelNameAsUnicode
                    } else {
                        nonPrintableLabels.append(intSymbol!)
                    }
                }
                
                // add two transition tuples
                if printableLabels != "" {
                    let printableTransition = "(\"\(printableLabels)\", \"\(attributeString!)\", \(gotoStateNumber))"
                    transitions += "\(printableTransition), "
                }
                
                if !nonPrintableLabels.isEmpty {
                    let nonPrintableTransition = "(\(nonPrintableLabels), \"\(attributeString!)\", \(gotoStateNumber))"
                    transitions += "\(nonPrintableTransition), "
                }
            }
         }

        // Remove trailing comma and space
        if !transitions.isEmpty {
            transitions.removeLast(2)
        }
        
        return "[\"ScannerReadaheadTable\", \(self.stateNumber), \(transitions)],\n"
    }
    
}


public class ReadbackState: FiniteStateMachineState {
    var finalItems: [Pairing] = []
    var initialItems: [Pairing] = []
    
    override func isReadback() -> Bool {
        return true
    }
    
    override func printOn() {
        let itemPairs = finalItems.map { $0.terseDescription }.joined(separator: " ")
//        print("ReadbackTable: \(self.stateNumber) {\(itemPairs)}")
        print("ReadbackTable: \(self.stateNumber)")
        for transition in self.transitions {
            transition.printOn()
        }
    }
    
    public override var description: String {
        var stateDescription = "Readback "
        stateDescription += super.description
        if self.debug {
            stateDescription += "\nRB state initial items\n"
            for item in initialItems {
                stateDescription += "\n-------RB PAIRING--------\n"
                stateDescription += item.description
            }
            stateDescription += "\n"
            
            stateDescription += "\nRB state final items\n"
            for item in finalItems {
                stateDescription += "\n-------RB PAIRING--------\n"
                stateDescription += item.description
            }
            stateDescription += "\n"
        }
        return stateDescription
    }
    
    // Readback tables have the form:
    //  ["ReadbackTable", 58, (("Macro", 4), "RSN", 58), (("Production", 11), "RSN", 58), (("GrammarType", 2), "L", 142), (("Defaults", 175), "L", 142)]
    // ie "ReadbackTable", rb state#, (transition: (pair item1.label.name, pair item2.stateNumber), label attributes, goto state number)
    func getFormmatedTableLine() -> String {
        var transitions = ""

        for transition in self.transitions {
            if let pairing = transition.pairingLabel {
                if let label = pairing.item1 as? Label, let state = pairing.item2 as? FiniteStateMachineState {
                    let labelName = label.name
                    let attributes = label.attributes.description
                    let fromStateNumber = state.stateNumber
                    let gotoStateNumber = transition.goto!.stateNumber
                    
                    let tuple = "((\"\(labelName)\", \(fromStateNumber)), \"\(attributes)\", \(gotoStateNumber))"
                    transitions += "\(tuple), "
                }
            }
        }

        // Remove trailing comma and space
        if !transitions.isEmpty {
            transitions.removeLast(2)
        }
        return "[\"ReadbackTable\", \(self.stateNumber), \(transitions)],\n"
    }
    
}


public class ReduceState: FiniteStateMachineState {
    var nonterminal: String = ""
    var reduceTransitions: Array<Triple<ReadaheadState, String>> = []
//    var transitions: Array<Triple<Int, String>> = []
    var restarts: Array<(ReadaheadState, String, ReadaheadState)> = []

    override func printOn() {
        print("ReduceTable \(self.stateNumber), \(nonterminal)")
        for t in reduceTransitions {
            print(t.description)
        }
    }
    
    func addRestartsIfAbsent(_ combination: (ReadaheadState, String, ReadaheadState)) {
        if !restarts.contains(where: {
            $0.0 === combination.0 && $0.1 == combination.1 && $0.2 === combination.2
        }) {
            restarts.append(combination)
        }
    }
    
    
    // Reduce tables have the form:
   // ["ReduceTable", 131, "AndExpression", (17, "RSN", 27), (18, "RSN", 27), (20, "RSN", 27), (32, "RSN", 27), (37, "RSN", 27), (42, "RSN", 103)],
    // ie ["ReduceTable, redState.stateNumber, redState.nonterminal, (redState.restarts[0].first.stateNumber, rs.restarts[0].second, rs.restarts[0].third.stateNumber)
    func getFormmatedTableLine() -> String {
        var transitions = ""

        for restart in self.restarts {
            let fromStateNumber = restart.0.stateNumber
            let attributes = restart.1
            let gotoStateNumber = restart.2.stateNumber
            
            let tuple = "(\(fromStateNumber), \"\(attributes)\", \(gotoStateNumber))"
            transitions += "\(tuple), "
        }

        // Remove trailing comma and space
        if !transitions.isEmpty {
            transitions.removeLast(2)
        }
        return "[\"ReduceTable\", \(self.stateNumber), \"\(self.nonterminal)\", \(transitions)],\n"
    }
}


public class SemanticState: FiniteStateMachineState {
    var label: Label?
    var goto: FiniteStateMachineState?
        
    init(_ label: Label, _ goto: FiniteStateMachineState) {
        super.init()
        self.label = label
        self.goto = goto
    }
    
    override func printOn() {
        print("\(label!.printOn()) goto State \(goto!.stateNumber)")
    }
    
    // Semantic Tables have the form:
    // ["SemanticTable", 159, "buildTree", ["walkAttributeTerminalDefaults"], 127],
    // ["SemanticTable", semState.stateNumber, semState.label.action, [semState.label.parameters], semstate.goto.stateNumber],
    func getFormmatedTableLine() -> String {
        return "[\"SemanticTable\", \(self.stateNumber), \"\(self.label!.action)\", \(self.label!.parameters), \(self.goto!.stateNumber)],\n"
    }
}


public class AcceptState: FiniteStateMachineState {
    override func printOn() {
        print("Accept State \(self.stateNumber)")
    }
}
