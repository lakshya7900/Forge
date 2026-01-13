//
//  EmptyStateView.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/8/26.
//


import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Welcome to Roadmate")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Start by creating a profile or a project.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView()
}
