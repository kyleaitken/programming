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

    func renumber () {
       for (index, state) in states.enumerated() {
           state.stateNumber = index // Maybe what this should do?
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
        let newFSM = FiniteStateMachine ()
        
        // make new states and add to the state dict
        var stateMap: [Int: FiniteStateMachineState] = [:]
        for state in fsm.states {
            let newFSMState = FiniteStateMachineState ()
            newFSMState.isFinal = state.isFinal
            newFSMState.isInitial = state.isInitial
            newFSMState.stateNumber = state.stateNumber
            stateMap[state.stateNumber] = newFSMState
        }
        
        // copy transitions and add to new states
        for state in fsm.states {
            let newState = stateMap[state.stateNumber]!
            for transition in state.transitions {
                let newTransition = transition.copy()
                
                // Update the 'goto' state to refer to the new state
                if let gotoState = transition.goto {
                    newTransition.goto = stateMap[gotoState.stateNumber]
                }
                newState.transitions.append(newTransition)
            }
        }
        
        // Sort states by their stateNumber before adding them to newFSM
        let sortedStates = stateMap.values.sorted { $0.stateNumber < $1.stateNumber }
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
        return newTransition
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
        var attributeList = AttributeList ();
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
}
