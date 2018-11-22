//
//  FetchedResultsControllerManager.swift
//  coreDataNeverCrash
//
//  Created by Jonathan Rose on 2/17/18.
//  Copyright (c) 2018 Jonathan Rose. All rights reserved.
//

import UIKit
import CoreData

extension IndexSet {
    func toArray() -> [Int] {
        let indexes: [Int] = self.enumerated().map {$0.element}
        return indexes
    }
}

protocol FetchedResultsControllerManagerChange {
    func applyChanges(tableView: UITableView)
    func applyChanges(tableView: UITableView, with animation: UITableViewRowAnimation)
    func applyChanges(collectionView: UICollectionView)
    func shiftIndexSections(by: Int)
    var insertedRows: [IndexPath] { get }
    var deletedRows: [IndexPath] { get }
    var updatedRows: [IndexPath] { get }
    var insertedSections: IndexSet { get }
    var deletedSections: IndexSet { get }

}

protocol FetchedResultsControllerManagerDelegate : class {
    func managerDidChangeContent(_ controller: NSObject, change: FetchedResultsControllerManagerChange)
} 

class FetchedResultsControllerManager<ResultType> : NSObject, NSFetchedResultsControllerDelegate  where ResultType : NSFetchRequestResult {
    class Section {
        var items: [ResultType] = []
        init(_ i: [ResultType]) {
            items = i
        }
    }
    class Change: NSObject, FetchedResultsControllerManagerChange {
        var insertedSections: IndexSet = []
        var deletedSections: IndexSet = []
        var insertedRows: [IndexPath] {
            return insertedElements.map{ $0.index }
        }
        var deletedRows: [IndexPath] {
            return deletedElements.map{ $0.index }
        }
        var updatedRows: [IndexPath] {
            return updatedElements.map{ $0.index }
        }
        
        var insertedElements: [(index: IndexPath, element: ResultType)] = []
        var deletedElements: [(index: IndexPath, element: ResultType)] = []
        var updatedElements: [(index: IndexPath, element: ResultType)] = []
        
        
        func applyChanges(tableView: UITableView) {
            applyChanges(tableView: tableView, with: .none)
        }
        
        func applyChanges(tableView: UITableView, with animation: UITableViewRowAnimation) {
            tableView.beginUpdates()
            tableView.deleteRows(at: deletedRows, with: animation)
            tableView.deleteSections(deletedSections, with: animation)
            tableView.insertSections(insertedSections, with: animation)
            tableView.insertRows(at: insertedRows, with: animation)
            tableView.endUpdates()
            
            tableView.reloadRows(at: updatedRows, with: animation)
        }
        
        func applyChanges(collectionView: UICollectionView) {
            collectionView.performBatchUpdates({
                collectionView.deleteItems(at: deletedRows)
                collectionView.deleteSections(deletedSections)
                collectionView.insertSections(insertedSections)
                collectionView.insertItems(at: insertedRows)
            })
            
            let indexPathsForSelectedItems = collectionView.indexPathsForSelectedItems
            
            collectionView.reloadItems(at: self.updatedRows)
            
            if let indexPathsForSelectedItems = indexPathsForSelectedItems {
                for index in indexPathsForSelectedItems {
                    if let cell = collectionView.cellForItem(at: index) {
                        cell.isSelected = true
                    }
                    collectionView.selectItem(at: index, animated: false, scrollPosition: [])
                }
            }
        }
        
        override var description: String {
            return "insertedSections:\(insertedSections.toArray()), deletedSections:\(deletedSections.toArray()), insertedRows:\(insertedRows), deletedRows:\(deletedRows), updatedRows:\(updatedRows)"
        }
        func shiftIndexSections(by: Int) {
            insertedSections = IndexSet(insertedSections.map { $0 + by })
            deletedSections = IndexSet(deletedSections.map { $0 + by })
            insertedElements = insertedElements.map { (IndexPath(row: $0.row, section: ($0.section + by)), $1 ) }
            deletedElements = deletedElements.map { (IndexPath(row: $0.row, section: ($0.section + by)), $1 ) }
            updatedElements = updatedElements.map { (IndexPath(row: $0.row, section: ($0.section + by)), $1 ) }
        }
    }
    
    
    private var fetchedResultsController: NSFetchedResultsController<ResultType>
    private var currentChange: Change?
    weak var delegate: FetchedResultsControllerManagerDelegate?
    var arrayOfArrays: [Section] = []
    
    
    func numberOfSections() -> Int {
        return arrayOfArrays.count
    }
    var fetchedObjectsCount: Int {
        return self.arrayOfArrays.reduce(0, {$0 + $1.items.count})
    }
    var first: ResultType? {
        return self.arrayOfArrays.first?.items.first
    }
    
    var fetchedObjects: [ResultType] {
        return arrayOfArrays.flatMap {$0.items}
    }
    
    // TODO: Remove after all uses removed. You should never need to look up an indexPath for an object.
    func indexPath(forObject: ResultType) -> IndexPath? {
        for (section, sectionInfo) in arrayOfArrays.enumerated() {
            for (row, object) in sectionInfo.items.enumerated() {
                if forObject.isEqual(object) {
                    return IndexPath(row: row, section: section)
                }
            }

        }
        return nil
    }
    
    func numberOfItems(in section: Int) -> Int {
        return self.arrayOfArrays[section].items.count
    }
    func object(at indexPath: IndexPath) -> ResultType {
        return self.arrayOfArrays[indexPath.section].items[indexPath.row]
    }
    
    public init(fetchRequest: NSFetchRequest<ResultType>, managedObjectContext context: NSManagedObjectContext, sectionNameKeyPath: String?, delegate:FetchedResultsControllerManagerDelegate?){
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: sectionNameKeyPath, cacheName: nil)
        
        super.init()
        fetchedResultsController.delegate = self
        self.delegate = delegate
        do {
            try self.fetchedResultsController.performFetch()
        }catch{
            DataModel.sharedInstance.receivedCoreDataError(error: error)
            print("Failed to fetch in fetchedResultsControllerManager from core data:\(error)")
        }
        self.arrayOfArrays = self.fetchedResultsController.sections?.compactMap({$0.objects as? [ResultType]}).compactMap {Section($0)} ?? []
    }
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.currentChange = Change()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            self.currentChange?.insertedSections.insert(sectionIndex)
        case .delete:
            self.currentChange?.deletedSections.insert(sectionIndex)
        default:
            //shouldn't happen
            print("FetchedResultsControllerManager didChange atSectionIndex:\(sectionIndex) unknown type:\(type.rawValue)")
            return
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        if let anObject = anObject as? ResultType {
            switch type {
            case .insert:
                if let i = newIndexPath {
                    self.currentChange?.insertedElements.append((i, anObject))
                }
            case .delete:
                if let i = indexPath {
                    self.currentChange?.deletedElements.append((i, anObject))
                }
            case .update:
                if let i = indexPath {
                    self.currentChange?.updatedElements.append((i, anObject))
                }
                
            case .move:
                if let i = indexPath {
                    self.currentChange?.deletedElements.append((i, anObject))
                }
                if let i = newIndexPath {
                    self.currentChange?.insertedElements.append((i, anObject))
                }
            }
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        guard let change = self.currentChange else {
            return
        }
        change.insertedElements.sort { $0.index < $1.index }
        change.deletedElements.sort { $0.index > $1.index }
        
        change.updatedElements.forEach { (index, element) in
            arrayOfArrays[index.section].items[index.row] = element
        }
        let updateOnlyChange = Change()
        updateOnlyChange.updatedElements = change.updatedElements
        if updateOnlyChange.updatedElements.count > 0 {
            self.delegate?.managerDidChangeContent(self, change:updateOnlyChange)
        }
        
        change.deletedElements.forEach { (indexPath, _) in
            arrayOfArrays[indexPath.section].items.remove(at: indexPath.row)
        }
        change.deletedSections.reversed().forEach { (index) in
            arrayOfArrays.remove(at: index)
        }
        change.insertedSections.forEach { (index) in
            arrayOfArrays.insert(Section([]), at: index)
        }
        change.insertedElements.forEach { (index, element) in
            arrayOfArrays[index.section].items.insert(element, at: index.row)
        }
        change.updatedElements = []
        if change.deletedRows.count > 0 || change.deletedSections.count > 0 ||  change.insertedSections.count > 0 || change.insertedElements.count > 0 {
            self.delegate?.managerDidChangeContent(self, change: change)
        }

        self.currentChange = nil
    }
}
