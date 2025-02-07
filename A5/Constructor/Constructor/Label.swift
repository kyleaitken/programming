//
//  Label.swift
//  Constructor
//
//  Created by Kyle Aitken on 2025-02-06.
//


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
                    if intSymbol == 32 {
                        nameToPrint = "\" \""
                    } else {
                        nameToPrint = String(Character(UnicodeScalar(intSymbol)!))
                    }
                }
            }
        }
           
        return ("\t\(nameToPrint) \"\(attributes.description)\"")
     }
    
    public var description: String {
        return "Label \(name) \(hasAction() ? "(action)" : "")"
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
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(action)
        hasher.combine(isRootBuilding)
    }
    
    public static func < (lhs: Label, rhs: Label) -> Bool {
        return lhs.name < rhs.name
    }
}
