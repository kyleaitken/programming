

//Start by creating a copy of Constructor and call it GrammarBuilder

//
// CODE YOU WILL HAVE TO ADD TO YOUR EXISTING CODE.
//


//import Foundation

//My code uses these routines.
//extension Array where Element: Equatable {
//    mutating func addIfAbsentAdded (_ object: Element) -> Bool {
//        if self.contains (object) {return false}
//        self.append (object)
//	return true
//    }
//    mutating func addAllIfAbsentAdded (_ collection: Element) -> Bool {
//        var changed: Bool = false
//        for item in collection {
//            if (addIfAbsentAdded (item)) {changed = true}
//        }
//        return changed
//    }
//}

                                                                                                                
      
//======================= THESE ARE CONSTRUCTOR WALK ROUTINES THAT MOSTLY DO NOTHING ====
//Only the first 2 do something. However, they must be in your constructor and in the 
//canPerformAction and performAction routines.
/*

func processAndDiscardDefaultsNow (_ tree: VirtualTree) {
    Pick up the tree just built containing either the attributes, keywords, optimize, and output tree,
    process it with walkTree, and remove it from the tree stack... by replacing the entry by nil..."
    var tree: Tree = parser.treeStack.last; self.walkTree (tree)
    parser.treeStack.removeLast; parser.treeStack.addLast: nil
}
 
 func walkKeywords (_ tree: VirtualTree) {
     "Note: This walk routine is initiated by #processAndDiscardDefaultsNow which subsequently
     //eliminates the tree to prevent generic tree walking later...|
     //All it does is give the grammar the keywords and prints them..."
     keywords := aTree children collect: [:child | child symbol].
     Grammar activeGrammar keywordsForParser: keywords.
  }

  
func walkAttributeTerminalDefaults (_ tree: VirtualTree) {
     //Note: This walk routine is initiated by #processAndDiscardDefaultsNow which subsequently
     //eliminates the tree to prevent generic tree walking later...
}

func walkAttributeNonterminalDefaults (_ tree: VirtualTree) {
    //Note: This walk routine is initiated by #processAndDiscardDefaultsNow which subsequently
    //eliminates the tree to prevent generic tree walking later...
 }

func walkOutput (_ tree: VirtualTree) {
    //Note: This walk routine is initiated by #processAndDiscardDefaultsNow which subsequently
    //eliminates the tree to prevent generic tree walking later...
    
    "All it does is print the output language. We commented out code that records the
    output language in the grammar since the student version will currently output
    in the format their tool is written in; i.e., Smalltalk for Smalltalk users versus
    Swift for Swift users."
 }
   
func walkAttributeDefaults (_ tree: VirtualTree) {
    //Note: This walk routine is initiated by #processAndDiscardDefaultsNow which subsequently
    //eliminates the tree to prevent generic tree walking later...
 }

func walkOptimize (_ tree: VirtualTree) {
    //Note: This walk routine is initiated by #processAndDiscardDefaultsNow which subsequently
    //eliminates the tree to prevent generic tree walking later...
    
    //All it does is allow 'chain reductions' and 'keep nonterminal transitions' to be used
    //by Wilf's parser constructor. It does so by telling the grammar what the optimization is
    //and the more advanced constructor he has to perform the optimizations. They are
    //of no concern to the student constructor... so that code is commented out..."
 }
 */


