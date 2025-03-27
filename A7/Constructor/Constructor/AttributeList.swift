//
//  AttributesList.swift
//  Constructor
//
//  Created by Kyle Aitken on 2025-02-06.
//


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
