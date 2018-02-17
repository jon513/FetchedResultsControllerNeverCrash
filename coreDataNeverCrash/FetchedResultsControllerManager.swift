//
//  FetchedResultsControllerManager.swift
//  coreDataNeverCrash
//
//  Created by Jonathan Rose on 2/17/18.
//  Copyright © 2018 Jonathan Rose. All rights reserved.
//

import UIKit
import CoreData


class FetchedResultsControllerManagerChange: NSObject {
    var insertedSections:IndexSet = []
    var deleteddSections:IndexSet = []
    var insertedRows:[IndexPath] = []
    var deletedRows:[IndexPath] = []
    var updatedRows:[IndexPath] = []
    
    func applyChanges(_ tableView:UITableView){
        tableView.performBatchUpdates({
            tableView.deleteSections(deleteddSections, with: .automatic)
            tableView.deleteRows(at: deletedRows, with: .automatic)
            tableView.insertSections(insertedSections, with: .automatic)
            tableView.insertRows(at: insertedRows, with: .automatic)
        }) { (completed) in
            
        }
    }
    func applyChanges(_ collectionView:UICollectionView){
        collectionView.performBatchUpdates({
            collectionView.deleteSections(deleteddSections)
            collectionView.deleteItems(at: deletedRows)
            collectionView.insertSections(insertedSections)
            collectionView.insertItems(at: insertedRows)
        }) { (completed) in
            
            
        }
    }
    
}

protocol FetchedResultsControllerManagerDelegate : NSObjectProtocol{
    func managerDidChangeContent(_ controller:NSObject, change:FetchedResultsControllerManagerChange)
}

class FetchedResultsControllerManager<ResultType> : NSObject, NSFetchedResultsControllerDelegate  where ResultType : NSFetchRequestResult {

    var fetchedResultsController:NSFetchedResultsController<ResultType>
    
    var currentChange:FetchedResultsControllerManagerChange?
    
    weak var delegate:FetchedResultsControllerManagerDelegate?
    
    public init(fetchRequest: NSFetchRequest<ResultType>, managedObjectContext context: NSManagedObjectContext, sectionNameKeyPath: String?, delegate:FetchedResultsControllerManagerDelegate?){
        fetchedResultsController = NSFetchedResultsController.init(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: sectionNameKeyPath, cacheName: nil)

        super.init()
        
        fetchedResultsController.delegate = self
        self.delegate = delegate
        do {
         try self.fetchedResultsController.performFetch()
        }catch{
            
        }
    }
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.currentChange = FetchedResultsControllerManagerChange.init()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            self.currentChange?.insertedSections.insert(sectionIndex)
        case .delete:
            self.currentChange?.deleteddSections.insert(sectionIndex)
        default:
            //shouldn't happen
            return
        }
    }
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            if let i = newIndexPath {
            self.currentChange?.insertedRows.append(i)
            }
        case .delete:
            if let i = indexPath {
            self.currentChange?.deletedRows.append(i)
            }
        case .update:
            if let i = newIndexPath {
                self.currentChange?.updatedRows.append(i)
            }

        case .move:
            if let i = indexPath {
                self.currentChange?.deletedRows.append(i)
            }
            if let i = newIndexPath {
                self.currentChange?.insertedRows.append(i)
            }
        }
    }
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.currentChange?.insertedRows.sort(by:  { $0 < $1 } )
        self.currentChange?.deletedRows.sort(by:  { $0 > $1 } )

        self.delegate?.managerDidChangeContent(self, change: self.currentChange!)
        
    }
    
    
    
    
}
