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
    
    func plus() -> FiniteStateMachine {
        let initialTransitions = self.getInitialTransitions()
        
        // Call finalStatesDo and pass the initial transitions as an argument
        self.finalStatesDo(closure: addAllIfAbsent, initialTransitions: initialTransitions)
        return self
    }
    
    func addAllIfAbsent(finalState: FiniteStateMachineState, initialTransitions: [Transition]) {
        // Add the initial transitions to the final state if not already present
        for transition in initialTransitions {
            if !finalState.transitions.contains(where: { $0 == (transition) }) {
                finalState.transitions.append(transition)
            }
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
                // Instead of gathering the initial transitions here, just call the closure with what was passed
                closure(state, initialTransitions)
            }
        }
//        self.states.filter { $0.isFinal }.forEach { closure($0, initialTransitions) }
    }

    func renumber () {
       for (index, state) in states.enumerated() {
           state.stateNumber = index
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
        if ((Grammar.activeGrammar?.isScanner()) == true) {
            // store character as ASCII int
            if let asciiValue = symbol.first?.asciiValue {
                transition.label.name = "\(asciiValue)"
            }
        } else {
            transition.label.name = symbol
        }
        transition.label.attributes = Grammar.defaultsFor(symbol)
        
        return fromTransition(transition)
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
    
    static func forString(_ symbol: String) -> FiniteStateMachine {
        let transition = Transition ()
        transition.label.name = symbol
        transition.label.attributes = Grammar.defaultsFor(symbol)
        
        return fromTransition(transition)
    }
    
    static func forInteger(_ symbol: String) -> FiniteStateMachine {
        let transition = Transition()
        let intSymbol = Int(symbol)
        if Grammar.isPrintable(intSymbol!) {
            transition.label.name = String(Character(UnicodeScalar(intSymbol!)!))
        } else {
            transition.label.name = symbol
        }
        transition.label.attributes = Grammar.defaultsFor(symbol)
        
        return fromTransition(transition)
    }
    
    static func forAction(_ parameters: Array<Any>, isRootBuilding: Bool, actionName: String) -> FiniteStateMachine {
        let transition = Transition ()
        transition.label.parameters = parameters
        transition.label.isRootBuilding = isRootBuilding
        transition.label.action = actionName
        
        return fromTransition(transition)
    }
    
    static func forIdentifier(_ fsm: FiniteStateMachine) -> FiniteStateMachine {
        // make a copy
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
}

public class FiniteStateMachineState {
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

        // Print the transitions of the state
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
}

public class Transition {
    var goto: FiniteStateMachineState?
    var label: Label

    func override (_ attributes: Array<String>) {
        if self.label.hasAction () {return}
        self.label.override(attributes)
    }
    
    init(){
        self.label = Label ()
    }
    
    func printOn() {
        label.printOn()
        print("\tgoto \(goto?.stateNumber ?? -1)")
    }

    func copy() -> Transition {
        let newTransition = Transition()
        newTransition.label = label.copy()
        newTransition.goto = self.goto
        return newTransition
    }
    
    func getLabel() -> Label {
        return self.label
    }
    
    func setLabel(label: Label) {
        self.label = label
    }
    
    // Overriding == operator for Label
    public static func ==(lhs: Transition, rhs: Transition) -> Bool {
        return lhs.label == rhs.label && lhs.goto === rhs.goto
    }
}

public class Label {
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
    
    func printOn() {
        if (hasAction()) {
            print("\t\(action) \(parameters) rootBuilding: \(isRootBuilding)")
            return
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
           
        print("\t\(nameToPrint) \"\(attributes.description)\"")
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
