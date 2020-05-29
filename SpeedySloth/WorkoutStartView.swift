/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Description about what the file includes goes here.
*/

import UIKit
import HealthKit

class WorkoutStartView: UIViewController {

    @IBOutlet weak var ISFField: UITextField!
    @IBOutlet weak var ESFField: UITextField!
    
    let defaults = UserDefaults.standard
    
    struct Keys {
        static let ISFF = "ISF"
        
    }
    
    
    
    
    let healthStore = HKHealthStore()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Exercising in the Loop"
        navigationController?.navigationBar.prefersLargeTitles = true
        checkForSavedISF()
        
        let typesToShare: Set = [
            HKQuantityType.workoutType()
        ]
        
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!,
            HKQuantityType.quantityType(forIdentifier: .insulinDelivery)!
        ]
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { (success, error) in
            // Handle error

        }
    }
 
    
    
    @IBAction func tapButton(_ sender: Any) {
    saveISF()
    
    }
    
    
    func saveISF() {
        
        defaults.set(ISFField.text!, forKey: Keys.ISFF)
    }
    func checkForSavedISF(){
        let ISF = defaults.value(forKey: Keys.ISFF) as? String ?? ""
        ISFField.text = ISF
    }
}

