//
//  BaseViewModel.swift
//  MovocashIOS
//
//  Created by Movo Developer on 13/03/26.
//

import Foundation
import Combine

// MARK: - ViewState

enum ViewState: Equatable {
    case idle
    case loading
    case success
}

// MARK: - ViewModel Error

enum ModelError: LocalizedError {
    case alreadyLoading
    case deallocated

    var errorDescription: String? {
        switch self {
        case .alreadyLoading: return "A request is already in progress."
        case .deallocated:    return "The view model was deallocated."
        }
    }
}

// MARK: - BaseViewModel

@MainActor
class BaseViewModel: ObservableObject {

    @Published private(set) var state: ViewState = .idle

    private let alertManager: AlertManagerProtocol
    private var activeTasks: [Task<Void, Never>] = []

    init(alertManager: AlertManagerProtocol) {
        self.alertManager = alertManager
    }

    // MARK: - Perform

    func perform<T: Sendable>(_ operation: () async throws -> T) async throws -> T {
        guard state != .loading else { throw ModelError.alreadyLoading }
        state = .loading
        do {
            let result = try await operation()
            state = .success
            defer { state = .idle }
            return result
        } catch is CancellationError {
            state = .idle
            throw CancellationError()
        } catch {
            state = .idle
            if error.shouldShowUserFacingToast {
                ToastManager.shared.show(error.localizedDescription, style: .error, position: .bottom)
            }
            throw error
        }
    }

    // MARK: - Task Management
    // viewModel.performTask { await callmethods } not used Task { }

    @discardableResult
    func performTask(_ operation: @escaping @Sendable () async -> Void) -> Task<Void, Never> {
        activeTasks = activeTasks.filter { !$0.isCancelled }
        let task = Task { @MainActor in await operation() }
        activeTasks.append(task)
        return task
    }

    func cancelAllTasks() {
        activeTasks.forEach { $0.cancel() }
        activeTasks.removeAll()
    }
}
