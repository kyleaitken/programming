//
//  main.swift
//  RelationBuilder
//
//  Created by Kyle Aitken on 2025-01-18.
//

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
    
    let tupleArr1 = [(2, "G", 3), (7, "A", 7), (6, "C", 7), (7, "a", 8), (1, "d", 2)]
    let tupleArr2 = [(2, "G", 5), (7, "A", 10), (6, "C", 11), (7, "a", 12), (1, "d", 6)]

    init() {
        self.right = Relation.init(tuples: tupleArr1)
        self.down = Relation.init(tuples: tupleArr2)
    }
        
    func example1() -> Void {
        // right relationsDo
        print("\n\nRight relations from {2, 7}:")
        right.from([2, 7]) { relationship, subrelation in
            print("\nThere is a relationsip \(relationship) with subrelation")
            subrelation.do { triple in
                print("\n     \(triple)")
            }
        }
        
        // different from sets
        for fromCollection in [[2, 1, 6], [1, 7], [2], [7]] {
            print("\n\nRight relations from set \(fromCollection):")
            right.from(fromCollection) { relationship, subrelation in
                print("\nThere is a relationship \(relationship) with subrelation")
                subrelation.do { triple in
                    print("\n     \(triple)")
                }
            }
        }
        
        // down relationsDo
        print("\n\nDown relations from {2, 7}:")
        down.from([2, 7]) { relationship, subrelation in
            print("\nThere is a relationsip \(relationship) with subrelation")
            subrelation.do { triple in
                print("\n     \(triple)")
            }
        }
        
        // different from sets
        for fromCollection in [[2, 1, 6], [1, 7], [2], [7]] {
            print("\n\nDown relations from set \(fromCollection):")
            down.from(fromCollection) { relationship, subrelation in
                print("\nThere is a relationship \(relationship) with subrelation")
                subrelation.do { triple in
                    print("\n     \(triple)")
                }
            }
        }

    }
}

let relationBuilder = RelationBuilder()
relationBuilder.example1()
