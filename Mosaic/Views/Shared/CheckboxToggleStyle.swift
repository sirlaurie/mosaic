
//
//  CheckboxToggleStyle.swift
//  Mosaic
//
//  Created by Gemini on 2025/10/25.
//

import SwiftUI

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            Image(systemName: configuration.isOn ? "checkmark.square" : "square")
                .resizable()
                .frame(width: 22, height: 22)
                .onTapGesture {
                    configuration.isOn.toggle()
                }
        }
    }
}
