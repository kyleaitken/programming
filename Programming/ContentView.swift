//
//  ContentView.swift
//  SampleTranslator
//
//  Created by Wilf Lalonde on 2022-12-27.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            let compile = false
            let text = "a*b where a = 2-1; b = 10+20;"
            let translator = SampleTranslator ()
            let string = "\(compile ? "Compile: " : "Evaluate: ")  \"\(text)\""
            Text(string)
            let result: String = compile
                ? translator.compile (text: text)
                : translator.evaluate (text: text) as! String
            
            Text (result)
       
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
