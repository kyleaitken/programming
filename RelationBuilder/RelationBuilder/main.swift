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

        // partition triples based on relationship
        let partitionedTriples = Dictionary(grouping: filteredTriples, by: { $0.relationship })

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


class RelationBuilder<Item: Relatable, Relationship: Relatable> {
    var right: Relation<Item, Relationship>
    var down: Relation<Item, Relationship>

    init() {
        // Provide default values for the relations
        self.right = Relation<Item, Relationship>(tuples: [])
        self.down = Relation<Item, Relationship>(tuples: [])
    }
        
    static func example1() -> Void {
        let relBuilder = RelationBuilder<Int, String>()
        
        let tuples1: [(Int, String, Int)] = [
            (2, "G", 3),
            (3, "G", 4),
            (7, "A", 7),
            (6, "C", 7),
            (7, "a", 8),
            (1, "d", 2),
            (3, "G", 5),
            (6, "C", 8),
            (7, "A", 9),
            (5, "A", 7),
            (2, "G", 9),
            (1, "a", 2)
        ]
        
        let tuples2: [(Int, String, Int)] = [
            (2, "G", 5),
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

        relBuilder.right = Relation<Int, String>(tuples: tuples1)
        relBuilder.down = Relation<Int, String>(tuples: tuples2)
        
        // Test itemsDo
        relBuilder.right.from([1, 3, 7], itemsDo: { relationship, items in
            print("Relationship: \(relationship), Items: \(items)")
        })
        relBuilder.down.from([2, 4], itemsDo: { relationship, items in
            print("Relationship: \(relationship), Items: \(items)")
        })
        
        // Test performStar
        let rightResult = relBuilder.right.performStar(items: [7])
        print("right performStar result: ", rightResult)
        // expected {7, 8, 9}
        
        let downResult = relBuilder.down.performStar(items: [2])
        print("down performStar result: ", downResult)
        // expected {2, 5, 6, 7, 8, 9, 10}

    }
}

RelationBuilder<Int,String>.example1()


// Un-used tests

// right relationsDo
//        print("\n\nRight relations from {2, 7}:")
//        right.from([2, 3]) { relationship, subrelation in
//            print("\nThere is a relationsip \(relationship) with subrelation")
//            subrelation.do { triple in
//                print("\n     \(triple)")
//            }
//        }

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
