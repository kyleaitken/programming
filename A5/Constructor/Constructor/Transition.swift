//
//  Transition.swift
//  Constructor
//
//  Created by Kyle Aitken on 2025-02-06.
//

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
        print("\(label!.printOn()) goto State \(goto?.stateNumber ?? -1)")
    }
    
    public var description: String {
        var transitionDescription = label?.printOn() ?? ""
        
        if let stateNumber = goto?.stateNumber {
            transitionDescription += " goto State \(stateNumber)"
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

