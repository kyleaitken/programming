//
//  FSMLibrary.swift
//  Constructor
//
//  Created by Wilf Lalonde on 2023-01-24.
//

import Foundation

public class FiniteStateMachine {
    var states: Array<FiniteStateMachineState>
    
    init () {states = []}
    
    public var description: String {
        var string: String = "\n"
        for state in states {
            string += state.description
        }
        return string
    }

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
    
//    func initialStatesDo<T>(closure: (FiniteStateMachineState) -> [T]) -> [T] {
//        // Apply the closure to each initial state, and gather the results into a single array
//        return self.states.filter { $0.isInitial }.flatMap { closure($0) }
//    }
//    
    func initialStatesDo(closure: (FiniteStateMachineState) -> Void) {
        for state in states where state.isInitial {
            closure(state)
        }
    }
    
    func allStatesDo<T>(closure: (FiniteStateMachineState) -> [T]) -> [T] {
        // Apply the closure to each initial state, and gather the results into a single array
        return self.states.flatMap { closure($0) }
    }
    
    func transitionsDo(closure: (Transition) -> Void) {
        for state in states {
            for transition in state.transitions {
                closure(transition)
            }
        }
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
        return fromTransitions([transition])
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
                transition.label = Label(String(char.asciiValue!), Grammar.defaultsFor(String(char)))
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
        let transition = Transition()
        transition.label = Label(symbol, Grammar.defaultsFor(symbol))
        return fromTransitions([transition])

    }
    
    static func forAction(_ parameters: Array<Any>, isRootBuilding: Bool, actionName: String) -> FiniteStateMachine {
        let transition = Transition ()
        transition.label = Label(actionName, parameters, isRootBuilding)
        return fromTransitions([transition])
    }
    
    static func forIdentifier(_ fsm: FiniteStateMachine) -> FiniteStateMachine {
        return copyFSM(fsm)
    }
    
    static func copyFSM(_ fsm: FiniteStateMachine) -> FiniteStateMachine {
        // make a copy
        let newFSM = FiniteStateMachine ()
        fsm.renumber()

        // make new states for each existing state and add to the state dict
        var copiedStates: [FiniteStateMachineState] = []
        for state in fsm.states {
            let newFSMState = FiniteStateMachineState ()
            newFSMState.stateNumber = state.stateNumber
            newFSMState.isFinal = state.isFinal
            newFSMState.isInitial = state.isInitial
            copiedStates.append(newFSMState)
        }
        
        for (index, state) in fsm.states.enumerated() {
            let copiedState = copiedStates[index]
            for transition in state.transitions {
                let newTransition = transition.copy()
                
                // Update the 'goto' state to refer to the new state
                if let gotoState = transition.goto {
                    newTransition.goto = copiedStates[gotoState.stateNumber - 1]
                }
                copiedState.transitions.append(newTransition)
            }
        }

        newFSM.states.append(contentsOf: copiedStates)
        return newFSM
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
