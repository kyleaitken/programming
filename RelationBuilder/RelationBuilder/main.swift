//
//  main.swift
//  RelationBuilder
//
//  Created by Kyle Aitken on 2025-01-18.
//
extension Array where Element: Equatable {
    mutating func appendIfAbsent(_ object: Element) {
        for element in self {
            if element == object {
                return
            }
        }
        self.append(object)
    }

   mutating func appendIfAbsent(_ collection: any Collection<Element>) {
        for element in collection {
            var present = false
            for item in self {
                if element == item {
                    present = true
                    break
                }
            }
            if (!present) {
                self.append(element)
            }
        }
    }

    mutating func appendIfAbsent(_ object: Element, closure: () -> Void) {
        if !self.contains(object) {
            self.append(object)
            closure()
        }
    }
}

class Utilities {
    static func className(_ element: Any?) -> String {
        if let element = element {
            return String(describing: type(of: element))
        } else {
            return "nil"
        }
    }
}

struct Triple<Item: Relatable, Relationship: Relatable>: Hashable {
    let from: Item
    let relationship: Relationship
    let to: Item

    var description: String {
        return "(\(from.terseDescription) \(relationship.terseDescription) \(to.terseDescription))"
    }
}

protocol Relatable: Hashable, Comparable, CustomStringConvertible {
    var terseDescription: String { get }
}

extension Relatable {
    var terseDescription: String { return description }
}

extension Int: Relatable {
    var terseDescription: String {
        return "\(self)"
    }
}

extension String: Relatable {
    var terseDescription: String {
        return self
    }
}

extension Collection {

    // Generic collect method
    func collect<T>(_ transform: (Element) -> T) -> [T] {
        var result: [T] = []
        for item in self {
            result.append(transform(item))
        }
        return result
    }
    
    // Generic select method
    func select(_ predicate: (Element) -> Bool) -> [Element] {
        var result: [Element] = []
        for item in self {
            if predicate(item) {
                result.append(item)
            }
        }
        return result
    }

}


class Relation<Item: Relatable, Relationship: Relatable>: CustomStringConvertible {
    var triples: Set<Triple<Item, Relationship>>

    var description: String {
        let triplesDescription = triples.map { $0.description }
        return "Relation(from: [\(triplesDescription.joined(separator: ", "))])"
    }

    init () {
        self.triples = Set()
    }

    init (triples: Set<Triple<Item, Relationship>>) {
        self.triples = triples
    }
    
    init(tuples: [(Item, Relationship, Item)]) {//Array of tuples
        self.triples = Set()
        for tuple in tuples {
            add(tuple: tuple)
        }
    }

    func add(from: Item, relationship: Relationship, to: Item) {
        let triple = Triple(from: from, relationship: relationship, to: to)
        triples.insert(triple)
    }
    
    func add(tuple: (Item, Relationship, Item)) {
        let (a, b, c) = tuple
        let triple = Triple(from: a, relationship: b, to: c)
        triples.insert(triple)
    }

    func add(_ triple: Triple<Item, Relationship>) -> Void {
        triples.insert(triple)
    }
    
    // Method to get all "to" items in the relation
    func allTo() -> [Item] {
        let toItems = triples.map { $0.to }
        return Array(Set(toItems))
    }
    
//    func performStar(items: [Item]) -> [Item] {
//        var result = items
//        var index = 0
//        
//        // loop over result, get all relationships with 'from' for that item, add the 'to' to the set if not there
//        while (index < result.count) {//
//            let item = result[index]
//            self.from([item], itemsDo: { _, moreItems in
//                for moreItem in moreItems {
//                    result.appendIfAbsent(moreItem)
//                }
//            })
//            index += 1
//        }
//        
//        return result.sorted()
//    }
    
    func performStar(items: [Item]) -> [Item] {
        var result = Set(items)
        var itemsToProcess = Set(items)
        
        while !itemsToProcess.isEmpty {
            let item = itemsToProcess.popFirst()!
            
            // get all to's for the item, add them if absent
            self.from([item], itemsDo: { _, moreItems in
                for moreItem in moreItems {
                    if !result.contains(moreItem) {
                        result.insert(moreItem)
                        itemsToProcess.insert(moreItem)
                    }
                }
            })
        }
        
        return result.sorted()
    }

    func from(_ froms: [Item], relationsDo: (Relationship, Relation) -> Void) {
        // filter triples where triple.from is in the froms array
        let filteredTriples = triples.filter { froms.contains($0.from) }
        for triple in filteredTriples {
            print("    \(triple.description)")
        }

        // partition triples based on relationship
        let partitionedTriples = Dictionary(grouping: filteredTriples, by: { $0.relationship })
        
        for (relationship, relatedTriples) in partitionedTriples {
            for triple in relatedTriples {
                print("        \(triple.description)")
            }
        }

        // create subrelations based on triples with shared relationship types and pass to closure
        for (relationship, relatedTriples) in partitionedTriples {
            let subrelation = Relation(triples: Set(relatedTriples))
            relationsDo(relationship, subrelation)
        }
    }
    
    func from(_ froms: [Item], itemsDo: (Relationship, [Item]) -> Void) {
        self.from(froms) { relationship, subrelation in
            // Extract all to's from the subrelation and pass to itemsDo
            let items = subrelation.allTo()
            itemsDo(relationship, items)
        }
    }

    func to(_ tos: [Item], relationsDo: (Relationship, Relation) -> Void) {
        // filter triples where triple.from is in the froms array
        let filteredTriples: Set<Triple<Item, Relationship>> = triples.filter { tos.contains($0.to) }

        // partition triples based on relationship
        let partitionedTriples = Dictionary(grouping: filteredTriples, by: { $0.relationship })

        // create subrelations based on triples with shared relationship types and pass to closure
        for (relationship, relatedTriples) in partitionedTriples {
            let subrelation = Relation(triples: Set(relatedTriples))
            relationsDo(relationship, subrelation)
        }
    }

    func allRelationships(_ relationships: [Relationship], relationsDo: (Relationship, Relation) -> Void) {
        let filteredTriples: Set<Triple<Item, Relationship>> = triples.filter { relationships.contains($0.relationship) }
        let partitionedTriples = Dictionary(grouping: filteredTriples, by: { $0.relationship })
        for (relationship, relatedTriples) in partitionedTriples {
            let subrelation = Relation(triples: Set(relatedTriples))
            relationsDo(relationship, subrelation)
        }
    }

    func `do` (closure: (Item, Relationship, Item) -> Void) {
        for triple in triples {
            closure(triple.from, triple.relationship, triple.to)
        }
    }

    func `do`(closure: ((Item, Relationship, Item)) -> Void) {
        for triple in triples {
            closure((triple.from, triple.relationship, triple.to)) // pass a tuple instead of Triple
        }
    }

    static func example1() -> Void {
        // Create relation
        let triples: Set<Triple<Int, String>> = [
            Triple(from: 2, relationship: "<", to: 3),
            Triple(from: 1, relationship: "=", to: 1),
            Triple(from: 3, relationship: ">", to: 1),
            Triple(from: 2, relationship: "<", to: 4),
            Triple(from: 1, relationship: "<", to: 5),
            Triple(from: 5, relationship: "<", to: 6),
            Triple(from: 2, relationship: "<", to: 5)
        ]
        let relation = Relation<Int, String>(triples: triples)

        // Print relation
        print("\nLet relation = \(relation)")

        // 3 param do
        print("\nOne triple per line, version1 of relation is")
        relation.do {a, b, c in
            print("\n(\(a.terseDescription) \(b.terseDescription) \(c.terseDescription))")
        }

        print("\nOne triple per line, version2 of relation is")
        relation.do { (from, relationship, to) in
            print("\n(\(from.terseDescription) \(relationship.terseDescription) \(to.terseDescription))")
        }
    }

    static func example2 () -> Void {
        // Create relation
        let triples: Set<Triple<Int, String>> = [
            Triple(from: 2, relationship: "<", to: 3),
            Triple(from: 1, relationship: "=", to: 1),
            Triple(from: 3, relationship: ">", to: 1),
            Triple(from: 2, relationship: "<", to: 4),
            Triple(from: 1, relationship: "<", to: 5),
            Triple(from: 5, relationship: "<", to: 6),
            Triple(from: 2, relationship: "<", to: 5),
            Triple(from: 1, relationship: "<", to: 6),
            Triple(from: 1, relationship: "<", to: 7)
        ]
        let relation = Relation<Int, String>(triples: triples)

        // Print relation
        print("\nLet relation = \(relation)")

        // relationsDo
        print("\nStarting from {1, 2, 3}:")
        relation.from([1, 2, 3]) { relationship, subrelation in
            print("\nThe class of the subrelation is \(Utilities.className(subrelation))")
            print("\nThere is a relationsip \(relationship) with subrelation")
            subrelation.do { triple in
                print("\n     \(triple)")
            }
        }

        // different from sets
        for fromCollection in [[1, 2, 3], [1, 2], [2], []] {
            relation.from(fromCollection) { relationship, subrelation in
                print("\nThere is a relationship \(relationship) with subrelation")
                subrelation.do { triple in
                    print("\n     \(triple)")
                }
            }
        }
    }

}


class RelationBuilder {
    var right: Relation<Int, String>
    var down: Relation<Int, String>
    
    let tupleArr1 = [(2, "G", 3), (3, "G", 4), (7, "A", 7), (6, "C", 7), (7, "a", 8), (1, "d", 2)]
    let tupleArr2 = [(2, "G", 5), (7, "A", 10), (6, "C", 11), (7, "a", 12), (1, "d", 6)]
    let tupleArr3 = [
        (2, "G", 3),  // From 2, relationship "G", to 3
        (3, "G", 4),  // From 3, relationship "G", to 4
        (7, "A", 7),  // From 7, relationship "A", to 7
        (6, "C", 7),  // From 6, relationship "C", to 7
        (7, "a", 8),  // From 7, relationship "a", to 8
        (1, "d", 2),  // From 1, relationship "d", to 2
        (3, "G", 5),  // From 3, relationship "G", to 5
        (6, "C", 8),  // From 6, relationship "C", to 8
        (7, "A", 9),  // From 7, relationship "A", to 9
        (5, "A", 7),  // From 5, relationship "A", to 7
        (7, "b", 6),  // From 7, relationship "b", to 6
        (2, "G", 9),  // From 2, relationship "G", to 9
        (1, "a", 2)   // From 1, relationship "a", to 2
    ]
    
    let tupleArr4 = [
        (2, "G", 5),  // From 2, relationship "G", to 3
        (2, "G", 6),
        (5, "A", 7),
        (5, "A", 8),
        (5, "A", 9),
        (6, "B", 10),
        (4, "C", 5),
        (4, "E", 9),
        (4, "F", 7),
        (7, "G", 9)
    ]

    init() {
        self.right = Relation.init(tuples: tupleArr3)
        self.down = Relation.init(tuples: tupleArr4)
    }
        
    func example1() -> Void {
        // right relationsDo
//        print("\n\nRight relations from {2, 7}:")
//        right.from([2, 3]) { relationship, subrelation in
//            print("\nThere is a relationsip \(relationship) with subrelation")
//            subrelation.do { triple in
//                print("\n     \(triple)")
//            }
//        }
        
//        right.from([1, 2, 3, 6, 7], itemsDo: { relationship, items in
//            print("Relationship: \(relationship), Items: \(items)")
//        })
        
        let result = down.performStar(items: [2, 4])
        print("performan start result: ", result)
        
        // different from sets
//        for fromCollection in [[2, 1, 6], [1, 7], [2], [7]] {
//            print("\n\nRight relations from set \(fromCollection):")
//            right.from(fromCollection) { relationship, subrelation in
//                print("\nThere is a relationship \(relationship) with subrelation")
//                subrelation.do { triple in
//                    print("\n     \(triple)")
//                }
//            }
//        }
        
        // down relationsDo
//        print("\n\nDown relations from {2, 7}:")
//        down.from([2, 7]) { relationship, subrelation in
//            print("\nThere is a relationsip \(relationship) with subrelation")
//            subrelation.do { triple in
//                print("\n     \(triple)")
//            }
//        }
        
        // different from sets
//        for fromCollection in [[2, 1, 6], [1, 7], [2], [7]] {
//            print("\n\nDown relations from set \(fromCollection):")
//            down.from(fromCollection) { relationship, subrelation in
//                print("\nThere is a relationship \(relationship) with subrelation")
//                subrelation.do { triple in
//                    print("\n     \(triple)")
//                }
//            }
//        }

    }
}

let relationBuilder = RelationBuilder()
relationBuilder.example1()
