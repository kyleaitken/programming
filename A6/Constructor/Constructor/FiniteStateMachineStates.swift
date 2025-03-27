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
    var debug = true
    
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
    var items: [FiniteStateMachineState] = []
    
    override func printOn() {
        let itemStateNumbers = items.map { String($0.stateNumber) }.joined(separator: " ")
        print("ReadaheadState \(self.stateNumber) {\(itemStateNumbers)}")
        
        for transition in self.transitions {
            transition.printOn()
        }
    
    }
    
}


public class ReadbackState: FiniteStateMachineState {
    var items: [Pairing] = []
    
    override func printOn() {
        let itemPairs = items.map { $0.terseDescription }.joined(separator: " ")
        print("Readback State: \(self.stateNumber) {\(itemPairs)}")
        
        for transition in self.transitions {
            transition.printOn()
        }
    }
}


public class ReduceState: FiniteStateMachineState {
    var nonterminal: String = ""
    
    override func printOn() {
        print("Reduce \(self.stateNumber) to \(nonterminal)")
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
        print("\(label!.printOn()) goto State \(goto?.stateNumber ?? -1)")
    }
}


public class AcceptState: FiniteStateMachineState {
    override func printOn() {
        print("Accept State \(self.stateNumber)")
    }
}
