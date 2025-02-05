//
//  FSMLibrary.swift
//  FSMBuilder
//
//  Created by Wilf Lalonde on 2023-01-24.
//

import Foundation

public class FiniteStateMachine {
    var states: Array<FiniteStateMachineState>
    
    init () {states = []}

    func override (_ attributes: Array<String>) {
        for state in states {
            for transition in state.transitions {
                transition.override (attributes)
            }
        }
    }
    
    static func empty() -> FiniteStateMachine {
        let fsm = FiniteStateMachine()
        let fsmState = FiniteStateMachineState()
        fsmState.isInitial = true
        fsmState.isFinal = true
        fsm.states.append(fsmState)
        fsm.renumber()
        return fsm
    }
    
    func or(otherFSM: FiniteStateMachine) -> FiniteStateMachine {
        self.addAll(fsm: otherFSM)
        self.renumber()
        return self
    }
    
    func addAll(fsm: FiniteStateMachine) {
        // Copy all the states and append them to the current FSM's states
        let fsmCopy = FiniteStateMachine.copyFSM(fsm)
        for state in fsmCopy.states {
            self.states.append(state)
        }
    }
    
    func addAll(fsmStates: [DualFiniteStateMachineState]) {
        for state in fsmStates {
            self.states.append(state)
        }
    }
    
    func plus() -> FiniteStateMachine {
        let initialTransitions = self.getInitialTransitions()
        
        // Call finalStatesDo and pass the initial transitions as an argument
        self.finalStatesDo(closure: addAllIfAbsent, initialTransitions: initialTransitions)
        return self
    }
    
    func addAllIfAbsent(state: FiniteStateMachineState, initialTransitions: [Transition]) {
        // Add the initial transitions to the final state if not already present
        for transition in initialTransitions {
            if !state.transitions.contains(where: { $0 == (transition) }) {
                state.transitions.append(transition)
            }
        }
    }
    
    func addIfAbsent(state: FiniteStateMachineState, transitionToAdd: Transition) {
        if !state.transitions.contains(where: { $0 == (transitionToAdd) }) {
            state.transitions.append(transitionToAdd)
        }
    }
    
    func getInitialTransitions() -> [Transition] {
        var transitions: [Transition] = []
        for state in self.states {
            if state.isInitial {
                transitions.append(contentsOf: state.transitions)
            }
        }
        return transitions
    }
    
    // Add all the transitions from final states if they are not already present
    func finalStatesDo(closure: (FiniteStateMachineState, [Transition]) -> Void, initialTransitions: [Transition]) {
        for state in self.states {
            if state.isFinal {
                closure(state, initialTransitions)
            }
        }
    }
    
    func initialStatesDo<T>(closure: (FiniteStateMachineState) -> [T]) -> [T] {
        // Apply the closure to each initial state, and gather the results into a single array
        return self.states.filter { $0.isInitial }.flatMap { closure($0) }
    }
    
    func allStatesDo<T>(closure: (FiniteStateMachineState) -> [T]) -> [T] {
        // Apply the closure to each initial state, and gather the results into a single array
        return self.states.flatMap { closure($0) }
    }
    
    func statesDo(closure: (FiniteStateMachineState) -> Void) {
        for state in self.states {
            closure(state)
        }
    }
    
    func canRecognizeE() -> Bool {
        for state in self.states {
            if (state.isInitial && state.isFinal) {
                return true
            }
        }
        return false
    }
    
    func concatenate(otherFSM: FiniteStateMachine) -> FiniteStateMachine {
        // check if the FSMs recognize E
        let fsm1RecognizesE = self.canRecognizeE()
        let fsm2RecognizesE = otherFSM.canRecognizeE()
        
        /*
         Copy ITs from FSM2 states into final states of FSM1 if they're not present
         Get ITs from FSM2. finalStatesDo on FSM1 to addIfAbsent
         */
        self.finalStatesDo(closure: addAllIfAbsent, initialTransitions: otherFSM.getInitialTransitions())
        
        //  If fsm2 does not recognize e, make all final states of fsm1 non-final
        if !fsm2RecognizesE {
            statesDo { state in
                state.isFinal = false
            }
        }
        
        // If fsm1 does not recognize e, make all initial states in fsm2 non initial
        if !fsm1RecognizesE {
            otherFSM.statesDo { state in
                state.isInitial = false
            }
        }

        // Put all states of FSM2 into FSM1
        self.states.append(contentsOf: otherFSM.states)
        
        // reduce FSM1 (remove useless states)
        self.reduce()
        self.renumber()
        return self
    }
    
    func allTriplesDo(closure: (FiniteStateMachineState, Label, FiniteStateMachineState) -> Void) {
        for state in self.states {
            for transition in state.transitions {
                if let label = transition.label, let goto = transition.goto {
                    closure(state, label, goto)
                }
            }
        }
    }
    
    func reduce () {
        // Get a set of all successors of initial states in FSM
        let initialReachableStates = allStatesReachable(isFinal: false)

        // Get a set of pre-decessors from final states in FSM (final states do)
        let finalReachableStates = allStatesReachable(isFinal: true)
        
        // get intersection of the two (useful states)
        let usefulStates = initialReachableStates.intersection(finalReachableStates)
        
        // loop thru fsm states and if that state is in useful states collection, keep it, otherwise discard
        self.states = self.states.filter { usefulStates.contains($0)}
        
        // loop thru the transitions of the fsm's states (now only useful) and only keep the transition if the goto is to another useful state
        for state in self.states {
            state.transitions = state.transitions.filter { transition in
                if let gotoState = transition.goto {
                    return usefulStates.contains(gotoState)
                }
                return false
            }
        }
    }
    
    static func orAll(FSMCollection: [FiniteStateMachine]) -> FiniteStateMachine {
        guard !FSMCollection.isEmpty else {
               fatalError("Can't combine an empty collection of FSMs")
       }
        let resultFSM = FSMCollection.first!
        for fsm in FSMCollection.dropFirst() {
            resultFSM.addAll(fsm: fsm)
        }
        resultFSM.renumber()
        return resultFSM
    }
    
    static func concatenateAll(fsms: [FiniteStateMachine]) -> FiniteStateMachine {
        guard !fsms.isEmpty else {
               fatalError("Can't concatenate an empty collection of FSMs")
        }
        var concatenatedFSM = fsms[0]
        for i in 1..<fsms.count {
            concatenatedFSM = concatenatedFSM.concatenate(otherFSM: fsms[i])
        }
        return concatenatedFSM
    }
    
    func getInitialStates() -> [FiniteStateMachineState] {
        return self.states.filter { $0.isInitial }
    }
    
    func getFinalStates() -> [FiniteStateMachineState] {
        return self.states.filter { $0.isFinal }
    }
    
    func allStatesReachable (isFinal: Bool) -> Set<FiniteStateMachineState> {
        let relation = Relation<FiniteStateMachineState, Label>()
        // if isFinal, then we're making an inverse relation, where the state of the triples is the goto and vice versa
        self.allTriplesDo { state, label, goto in
            let triple = isFinal ? Triple(from: goto, relationship: label, to: state)
            : Triple(from: state, relationship: label, to: goto)
            relation.add(triple)
        }
        let fromStates = isFinal ? self.getFinalStates() : self.getInitialStates()
        
        // pass from states (either final or initial) to performStar to get the successor/predecessor states
        return Set(relation.performStar(items: fromStates))
    }

    func renumber () {
       for (index, state) in states.enumerated() {
           state.stateNumber = index + 1
       }
    }
    
    func printOn() {
        for state in states {
            state.printOn()
        }
        print("End")
    }
    
    static func forCharacter(_ symbol: String) -> FiniteStateMachine {
        let transition = Transition()
        var labelName = symbol
        
        if ((Grammar.activeGrammar?.isScanner()) == true) {
            // store character as ASCII int
            if let asciiValue = symbol.first?.asciiValue {
                labelName = "\(asciiValue)"
            } else {
                print("Error: No ASCII value for symbol: \(symbol)")
                labelName = symbol
            }
        }
        
        transition.label = Label(labelName, Grammar.defaultsFor(symbol))
        return fromTransition(transition)
    }
    
    static func forCharacters(_ start: String, _ end: String) -> FiniteStateMachine {
        var transitions: [Transition] = []
        
        guard let startChar = start.first, let endChar = end.first else {
            fatalError("Invalid characters for range: \(start) to \(end)")
        }
        
        for charCode in startChar.asciiValue!...endChar.asciiValue! {
            let symbol = String(charCode)
            let transition = Transition()
            transition.label = Label(symbol, Grammar.defaultsFor(symbol))
            if !transitions.contains(where: { $0 == (transition) }) {
                transitions.append(transition)
            }
        }
        
        return fromTransitions(transitions)
    }
    
    static func forIntegers(_ start: String, _ end: String) -> FiniteStateMachine {
        var transitions: [Transition] = []
        
        guard let startValue = Int(start), let endValue = Int(end) else {
            print("Error: Invalid integer range \(start) to \(end)")
            return FiniteStateMachine()  // Return an empty FSM in case of error
        }
        
        for value in startValue...endValue {
            var labelSymbol: String
            
            if Grammar.isPrintable(value) {
                // If the value is printable, convert to the corresponding ASCII character
                labelSymbol = String(Character(UnicodeScalar(value)!))
            } else {
                // Otherwise, use the integer value as the label
                labelSymbol = "\(value)"
            }

            let transition = Transition()
            transition.label = Label(labelSymbol, Grammar.defaultsFor(labelSymbol))
            transitions.append(transition)
        }
        
        return fromTransitions(transitions)
    }
    
    static func forString(_ symbol: String) -> FiniteStateMachine {
        var transitions: [Transition] = []
        if Grammar.activeGrammar?.isScanner() == true {
            // make transitions for each char in the string
            for char in symbol {
                let transition = Transition()
                transition.label = Label(String(char), Grammar.defaultsFor(String(char)))
                transitions.append(transition)
            }
        } else {
            let transition = Transition ()
            transition.label = Label(symbol, Grammar.defaultsFor(symbol))
            transitions.append(transition)
        }
        return fromTransitions(transitions)
    }
    
    static func forInteger(_ symbol: String) -> FiniteStateMachine {
        let value = Int(symbol)
        var labelSymbol: String
        
        if Grammar.isPrintable(value!) {
            labelSymbol = String(Character(UnicodeScalar(value!)!))
        } else {
            labelSymbol = "\(value)"
        }
    
        let transition = Transition()
        transition.label = Label(labelSymbol, Grammar.defaultsFor(labelSymbol))
        return fromTransition(transition)
    }
    
    static func forAction(_ parameters: Array<Any>, isRootBuilding: Bool, actionName: String) -> FiniteStateMachine {
        let transition = Transition ()
        transition.label = Label(actionName, parameters, isRootBuilding)
        return fromTransition(transition)
    }
    
    static func forIdentifier(_ fsm: FiniteStateMachine) -> FiniteStateMachine {
        return copyFSM(fsm)
    }
    
    static func copyFSM(_ fsm: FiniteStateMachine) -> FiniteStateMachine {
        // make a copy
        let newFSM = FiniteStateMachine ()
        
        // make new states for each existing state and add to the state dict
        var copiedStates: [Int: FiniteStateMachineState] = [:]
        for state in fsm.states {
            let newFSMState = FiniteStateMachineState ()
            newFSMState.stateNumber = state.stateNumber
            newFSMState.isFinal = state.isFinal
            newFSMState.isInitial = state.isInitial
            copiedStates[state.stateNumber] = newFSMState
        }
                
        // copy transitions and add to new states
        for state in fsm.states {
            let copiedState = copiedStates[state.stateNumber]!
            for transition in state.transitions {
                let newTransition = transition.copy()
                
                // Update the 'goto' state to refer to the new state
                if let gotoState = transition.goto {
                    newTransition.goto = copiedStates[gotoState.stateNumber]
                }
                copiedState.transitions.append(newTransition)
            }
        }
        
        // Sort states by their stateNumber before adding them to newFSM
        let sortedStates = copiedStates.values.sorted { $0.stateNumber < $1.stateNumber }
        newFSM.states.append(contentsOf: sortedStates)
        
        return newFSM
    }
        
    static func fromTransition(_ transition: Transition) -> FiniteStateMachine {
        let fsm = FiniteStateMachine()
        
        // create initial state
        let initialState = FiniteStateMachineState()
        initialState.isInitial = true
        fsm.states.append(initialState)
        
        // create final state
        let finalState = FiniteStateMachineState ()
        finalState.isFinal = true
        fsm.states.append(finalState)
        
        // set the transition
        transition.goto = finalState
        initialState.transitions.append(transition)
        
        // Number the states
        fsm.renumber()
        
        return fsm
    }
    
    static func fromTransitions(_ transitions: [Transition]) -> FiniteStateMachine {
        let fsm = FiniteStateMachine()
        
        // create initial state
        let initialState = FiniteStateMachineState()
        initialState.isInitial = true
        fsm.states.append(initialState)
        
        // create final state
        let finalState = FiniteStateMachineState ()
        finalState.isFinal = true
        fsm.states.append(finalState)
        
        // set the transition
        for transition in transitions {
            transition.goto = finalState
            initialState.transitions.append(transition)
        }
        
        // Number the states
        fsm.renumber()
        
        return fsm
    }
    
    func minusAnFSM(otherFSM: FiniteStateMachine) -> FiniteStateMachine {
        let fsm1 = self
        let fsm2 = otherFSM
        let newFSM = DualFiniteStateMachineState.dualFSMFor(fsm1, fsm2)

        // Figure out final states
        for state in newFSM.states {
            if let dualState = state as? DualFiniteStateMachineState {
                let stateSet1HasFinal = dualState.stateSet1.contains { $0.isFinal }
                let stateSet2HasFinal = dualState.stateSet2.contains { $0.isFinal }
                
                if stateSet1HasFinal != stateSet2HasFinal {
                    dualState.isFinal = true
                } else {
                    dualState.isFinal = false
                }
            }
        }
        newFSM.reduce()
        newFSM.renumber()
        return newFSM
    }
    
    func andAnFSM(otherFSM: FiniteStateMachine) -> FiniteStateMachine {
        let fsm1 = self
        let fsm2 = otherFSM
        let newFSM = DualFiniteStateMachineState.dualFSMFor(fsm1, fsm2)
        
        // figure out final states
        for state in newFSM.states {
            if let dualState = state as? DualFiniteStateMachineState {
                let stateSet1HasFinal = dualState.stateSet1.contains { $0.isFinal }
                let stateSet2HasFinal = dualState.stateSet2.contains { $0.isFinal }
                
                if stateSet1HasFinal && stateSet2HasFinal {
                    dualState.isFinal = true
                } else {
                    dualState.isFinal = false
                }
            }
        }
        newFSM.reduce()
        newFSM.renumber()
        return newFSM
    }
}

public class FiniteStateMachineState: Relatable {
    var stateNumber: Int = 0
    var isInitial: Bool = false
    var isFinal: Bool = false
    var transitions: Array<Transition>
    
    init () {transitions = []}
    
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
    
    // Conformance to CustomStringConvertible for the `description` property
    public var description: String {
        var stateDescription = "State \(stateNumber)"
        if isInitial {
            stateDescription += " (initial)"
        }
        if isFinal {
            stateDescription += " (final)"
        }
        return stateDescription
    }
    
    // Conformance to Hashable
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
        
        // Loop over dual states
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

public class Transition: Equatable {
    var goto: FiniteStateMachineState?
    var label: Label?

    func override (_ attributes: Array<String>) {
        if self.label!.hasAction () {return}
        self.label!.override(attributes)
    }
    
    init(){
        self.label = Label ()
    }
    
    init(_ label: Label, _ goto: FiniteStateMachineState) {
        self.label = label
        self.goto = goto
    }
    
    func printOn() {
        print("\(label!.printOn()) goto \(goto?.stateNumber ?? -1)")
    }

    func copy() -> Transition {
        let newTransition = Transition()
        newTransition.label! = label!.copy()
        newTransition.goto = self.goto
        return newTransition
    }
    
    func getLabel() -> Label {
        return self.label!
    }
    
    func setLabel(label: Label) {
        self.label = label
    }
    
    // Overriding == operator for Label
    public static func ==(lhs: Transition, rhs: Transition) -> Bool {
        return lhs.label! == rhs.label! && lhs.goto === rhs.goto
    }
}

public class Label: Relatable {
    var name: String = ""
    var attributes: AttributeList = AttributeList ().set (["look", "noStack", "noKeep", "noNode"])
    var action: String = ""
    var parameters: Array<Any> = []
    var isRootBuilding: Bool = false
    
    init() {}
    
    func hasAttributes () -> Bool {return name != ""}
    func hasAction () -> Bool {return action != ""}
    
    func override(_ attributes: Array<String>) {
        if self.hasAction() { return }
        self.attributes.override(attributes)
    }
    
    init (_ name: String, _ attributes: AttributeList) {self.name = name; self.attributes = attributes}
    init (_ action: String, _ parameters: [Any], _ isRootBuilding: Bool) {self.action = action; self.parameters = parameters; self.isRootBuilding = isRootBuilding}
    
    func printOn() -> String {
        if (hasAction()) {
            return ("\t\(action) \(parameters) rootBuilding: \(isRootBuilding)")
        }
        var nameToPrint = name
        
        // if it's a scanner, see if char/int is printable
        if (Grammar.activeGrammar?.isScanner() == true) {
            if let intSymbol = Int(name) {
                if Grammar.isPrintable(intSymbol) {
                    let asciiChar = Character(UnicodeScalar(intSymbol)!)
                    nameToPrint = String(asciiChar)
                }
            }
        }
           
        return ("\t\(nameToPrint) \"\(attributes.description)\"")
     }
    
    func copy() -> Label {
        let newLabel = Label()
        newLabel.name = self.name
        newLabel.attributes = self.attributes.copy()
        newLabel.action = self.action
        newLabel.parameters = self.parameters
        newLabel.isRootBuilding = self.isRootBuilding
        return newLabel
    }
    
    public static func ==(lhs: Label, rhs: Label) -> Bool {
        return lhs.name == rhs.name && lhs.attributes == rhs.attributes && lhs.action == rhs.action
    }
    
    var terseDescription: String {
        return "Label \(name) \(hasAction() ? "(action)" : "")"
    }
    
    public var description: String {
        var description = "Label \(name)"
        if hasAction() {
            description += " - Action: \(action) with parameters: \(parameters)"
        }
        description += " with attributes: \(attributes.description)"
        return description
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(action)
        hasher.combine(isRootBuilding)
    }
    
    public static func < (lhs: Label, rhs: Label) -> Bool {
        return lhs.name < rhs.name
    }
}


public class AttributeList {
    var isRead: Bool = false
    var isStack: Bool = false
    var isKeep: Bool = false
    var isNode: Bool = false
    
    func set (_ attributes: Array<String>) -> AttributeList {
        for string in attributes {
            
            if (string == "read") {isRead = true;}
            if (string == "look") {isRead = false;}
            if (string == "stack") {isStack = true;}
            if (string == "noStack") {isStack = false;}
            if (string == "keep") {isKeep = true;}
            if (string == "noKeep") {isKeep = false;}
            if (string == "node") {isNode = true;}
            if (string == "noNode") {isNode = false;}
        }
        return self
    }

    static func fromString (_ string: String) -> AttributeList {
	//Convert from the description notation below to an attribute list.
        let attributeList = AttributeList ();
        attributeList.isRead = string.contains("R") //"R" versus "L"
        attributeList.isStack = string.contains("S") //"S" versus no "S"
        attributeList.isKeep = string.contains("K") //"K" versus no "K"
        attributeList.isNode = string.contains("N")  //"N" versus no "N"
        
        return attributeList
    }
	
    public var description: String {
        if (!isRead) {
            return "L"
        } else {
            return ("R") + (isStack ? "S" : "") + (isKeep ? "K" : "") + (isNode ? "N" : "")
        }
    }

    public func override (_ attributes: Array<String>) {
        set (attributes)
    }
    
    func copy() -> AttributeList {
        let newAttributeList = AttributeList()
        newAttributeList.isRead = self.isRead
        newAttributeList.isStack = self.isStack
        newAttributeList.isKeep = self.isKeep
        newAttributeList.isNode = self.isNode
        return newAttributeList
    }
    
    public static func==(lhs: AttributeList, rhs: AttributeList) -> Bool {
        return lhs.isRead == rhs.isRead && lhs.isKeep == rhs.isKeep && lhs.isNode == rhs.isNode && lhs.isStack == rhs.isStack
    }
}
