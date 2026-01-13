//
//  AppState.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/9/26.
//


import Foundation
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    enum Route: Hashable {
        case profile
        case allProjects
        case project(UUID)
        case planner
    }

    @Published var selection: Route? = .allProjects
}
