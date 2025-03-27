//
//  Transition.swift
//  Constructor
//
//  Created by Kyle Aitken on 2025-02-06.
//

public class Transition: Equatable {
    var goto: FiniteStateMachineState?
    var label: Label?
    var pairingLabel: Pairing?

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
    
    
    init(_ pairingLabel: Pairing, _ goto: FiniteStateMachineState) {
        self.pairingLabel = pairingLabel
        self.goto = goto
    }
    
    func hasPairing() -> Bool {
        return pairingLabel != nil
    }
    
    func printOn() {
        if hasPairing() {
            let item1 = pairingLabel!.item1 as! Label
            print("(\(pairingLabel!.description), \"\(item1.attributes.description)\", \(goto!.stateNumber))")
        } else {
            print("(\(label!.printOn()), \(goto!.stateNumber))")
        }
    }
    
//    public var description: String {
//        var transitionDescription = label?.printOn() ?? ""
//        let isReadahead = goto?.isReadahead()
//
//        if let stateNumber = goto?.stateNumber {
//            transitionDescription += " goto \(isReadahead ? "Readahead" : "Right part") State \(stateNumber)"
//        }
//        return transitionDescription
//    }
    
    public var description: String {
        var transitionDescription = label?.printOn() ?? ""
        
        if let stateNumber = goto?.stateNumber {
            let gotoStateType = (goto?.isReadback())! ? "Readback" : (goto?.isReadahead())! ? "Readahead" : ""
            transitionDescription += " goto \(gotoStateType) State \(stateNumber)"
        }
        
        return transitionDescription
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

