//
//  ViewController.swift
//  coreDataNeverCrash
//
//  Created by Jonathan Rose on 2/17/18.
//  Copyright © 2018 Jonathan Rose. All rights reserved.
//

import UIKit
import CoreData

extension Thing {
   
    
}

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, FetchedResultsControllerManagerDelegate {
    func managerDidChangeContent(_ controller: NSObject, change: FetchedResultsControllerManagerChange) {
        change.applyChanges(tableView)
    }
    

    @IBOutlet weak var tableView: UITableView!
    var manager:FetchedResultsControllerManager<Thing>?
    var timer:Timer?
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext {
            let r:NSFetchRequest<Thing> =  Thing.fetchRequest()
            r.sortDescriptors = [NSSortDescriptor.init(key: "createdAt", ascending: true)]
            
            self.manager = FetchedResultsControllerManager.init(fetchRequest: r, managedObjectContext: context, sectionNameKeyPath: "year", delegate: self)
            
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block:  { (timer) in
                if let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext {

//                if let persistentContainer = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer {
//                    persistentContainer.performBackgroundTask({ (context) in
                        do {
                            let numberToDelete = arc4random_uniform(4)
                            let numberToAdd = arc4random_uniform(10)
                            let numberToMove = arc4random_uniform(10)
                            let numberToUpdate = arc4random_uniform(10)
                            let r:NSFetchRequest<Thing> =  Thing.fetchRequest()
                            let array = try context.fetch(r)
                            for _ in 0...numberToDelete {
                                if let t = array.randomItem() {
                                    context.delete(t)
                                }
                            }
                            
                            for _ in 0...numberToAdd {
                                let t = Thing.init(entity: Thing.entity(), insertInto: context)
                                let date =  Randoms.randomDateWithinDaysBeforeToday(20000)
                                t.createdAt = date
                                t.year = String( Calendar.current.component(.year, from:date) )
                                t.updatedAt = t.createdAt
                                t.name = Lorem.fullName
                                t.email = Lorem.emailAddress
                            }
                            for _ in 0...numberToMove {
                                if let t = array.randomItem() {
                                    let date =  Randoms.randomDateWithinDaysBeforeToday(20000)
                                    t.createdAt = date
                                    t.year = String( Calendar.current.component(.year, from:date) )

                                }
                            }
                            
                            for _ in 0...numberToUpdate {
                                if let t = array.randomItem() {
                                    t.name = Lorem.fullName
                                }
                            }
                            
                            
                        }catch {
                            
                        }
                        
//                    });
                }
            })
        }
    }
    
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return (self.manager?.fetchedResultsController.sections?[section].objects?.first as? Thing)?.year ?? ""
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.manager?.fetchedResultsController.sections?.count ?? 0
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.manager?.fetchedResultsController.sections?[section].numberOfObjects ?? 0
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
        let thing = self.manager?.fetchedResultsController.object(at: indexPath)
        
        cell?.textLabel?.text = thing?.name
        cell?.detailTextLabel?.text = String.init(describing: thing?.updatedAt)

        return cell!
    }

    

}

