//
//  AppState.swift
//  UDIE
//
//  Created by Ujjwal Singh on 12/02/26.
//



import Foundation

final class AppState: ObservableObject {
    @Published var filters = EventFilter()
}
