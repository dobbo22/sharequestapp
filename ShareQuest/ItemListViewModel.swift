//
//  ItemListViewModel.swift
//  ShareQuest
//
//  Created by MartinD on 12/03/2026.
//

import Foundation
import SwiftUI
import Combine

/// View model for managing items list
@MainActor
class ItemListViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    private let apiService = APIService.shared
    
    // MARK: - Fetch Items
    
    func fetchItems() async {
        isLoading = true
        errorMessage = nil
        
        do {
            items = try await apiService.fetchItems()
            // Sort by timestamp (newest first)
            items.sort { $0.timestamp > $1.timestamp }
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    // MARK: - Create Item
    
    func addItem(title: String, details: String?, priority: Int = 0) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let newItem = try await apiService.createItem(title: title, details: details, priority: priority)
            items.insert(newItem, at: 0)
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    // MARK: - Update Item
    
    func updateItem(_ item: Item) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let updatedItem = try await apiService.updateItem(
                id: item.id,
                title: item.title,
                details: item.details,
                isCompleted: item.isCompleted,
                priority: item.priority
            )
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index] = updatedItem
            }
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    // MARK: - Toggle Completion
    
    func toggleCompletion(for item: Item) async {
        var updatedItem = item
        updatedItem.isCompleted.toggle()
        await updateItem(updatedItem)
    }
    
    // MARK: - Delete Item
    
    func deleteItem(_ item: Item) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await apiService.deleteItem(id: item.id)
            items.removeAll { $0.id == item.id }
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    func deleteItems(at offsets: IndexSet) {
        Task {
            for index in offsets {
                await deleteItem(items[index])
            }
        }
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error) {
        if let apiError = error as? APIError {
            errorMessage = apiError.errorDescription
        } else {
            errorMessage = error.localizedDescription
        }
        showError = true
    }
}
