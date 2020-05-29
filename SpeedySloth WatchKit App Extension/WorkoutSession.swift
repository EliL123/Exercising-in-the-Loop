/*
See LICENSE folder for this sample’s licensing information.

Abstract:
THe workout session interface controller.
*/

import WatchKit
import Foundation
import HealthKit

class WorkoutSession: WKInterfaceController, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    
    @IBOutlet weak var timer: WKInterfaceTimer!
    
    @IBOutlet weak var activeCaloriesLabel: WKInterfaceLabel!
    @IBOutlet weak var heartRateLabel: WKInterfaceLabel!
    @IBOutlet weak var bloodGlucoseLabel: WKInterfaceLabel!
    @IBOutlet weak var distanceLabel: WKInterfaceLabel!
    
    let defaults = UserDefaults.standard
    
    var healthStore: HKHealthStore!
    var configuration: HKWorkoutConfiguration!
    
    var session: HKWorkoutSession!
    var builder: HKLiveWorkoutBuilder!
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        setupWorkoutSessionInterface(with: context)
        
        // Create the session and obtain the workout builder.
        /// - Tag: CreateWorkout
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session.associatedWorkoutBuilder()
        } catch {
            dismiss()
            return
        }
        
        // Setup session and builder.
        session.delegate = self
        builder.delegate = self
        
        /// Set the workout builder's data source.
        /// - Tag: SetDataSource
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore,
                                                     workoutConfiguration: configuration)
        
        // Start the workout session and begin data collection.
        /// - Tag: StartSession
        session.startActivity(with: Date())
        builder.beginCollection(withStart: Date()) { (success, error) in
            self.setDurationTimerDate(.running)
        }
    }
    
    // Track elapsed time.
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Retreive the workout event.
        guard let workoutEventType = workoutBuilder.workoutEvents.last?.type else { return }
        
        // Update the timer based on the event received.
        switch workoutEventType {
        case .pause: // The user paused the workout.
            setDurationTimerDate(.paused)
        case .resume: // The user resumed the workout.
            setDurationTimerDate(.running)
        default:
            return
            
        }
    }
    
    func setDurationTimerDate(_ sessionState: HKWorkoutSessionState) {
        /// Obtain the elapsed time from the workout builder.
        /// - Tag: ObtainElapsedTime
        let timerDate = Date(timeInterval: -self.builder.elapsedTime, since: Date())
        
        // Dispatch to main, because we are updating the interface.
        DispatchQueue.main.async {
            self.timer.setDate(timerDate)
        }
        
        // Dispatch to main, because we are updating the interface.
        DispatchQueue.main.async {
            /// Update the timer based on the state we are in.
            /// - Tag: UpdateTimer
            sessionState == .running ? self.timer.start() : self.timer.stop()
        }
    }
    
    // MARK: - HKLiveWorkoutBuilderDelegate
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else {
                return // Nothing to do.
            }
            
            /// - Tag: GetStatistics
            let statistics = workoutBuilder.statistics(for: quantityType)
            let label = labelForQuantityType(quantityType)
            
            updateLabel(label, withStatistics: statistics)
        }
    }
    
    // MARK: - State Control
    func pauseWorkout() {
        session.pause()
    }
    
    func resumeWorkout() {
        session.resume()
    }
    
    func endWorkout() {
        /// Update the timer based on the state we are in.
        /// - Tag: SaveWorkout
        session.end()
        builder.endCollection(withEnd: Date()) { (success, error) in
            self.builder.finishWorkout { (workout, error) in
                // Dispatch to main, because we are updating the interface.
                DispatchQueue.main.async() {
                    self.dismiss()
                }
            }
        }
    }
    
    func setupWorkoutSessionInterface(with context: Any?) {
        guard let context = context as? WorkoutSessionContext else {
            dismiss()
            return
        }
        
        healthStore = context.healthStore
        configuration = context.configuration
        
        setupMenuItemsForWorkoutSessionState(.running)
    }
    
    /// Set up the contextual menu based on the workout session state.
    func setupMenuItemsForWorkoutSessionState(_ state: HKWorkoutSessionState) {
        clearAllMenuItems()
        if state == .running {
            addMenuItem(with: .pause, title: "Pause", action: #selector(pauseWorkoutAction))
        } else if state == .paused {
            addMenuItem(with: .resume, title: "Resume", action: #selector(resumeWorkoutAction))
        }
        addMenuItem(with: .decline, title: "End", action: #selector(endWorkoutAction))
    }
    
    /// Action for the "Pause" menu item.
    @objc
    func pauseWorkoutAction() {
        pauseWorkout()
    }
    
    /// Action for the "Resume" menu item.
    @objc
    func resumeWorkoutAction() {
        resumeWorkout()
    }
    
    /// Action for the "End" menu item.
    @objc
    func endWorkoutAction() {
        endWorkout()
    }
    
    // MARK: - HKWorkoutSessionDelegate
    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        // Dispatch to main, because we are updating the interface.
        DispatchQueue.main.async {
            self.setupMenuItemsForWorkoutSessionState(toState)
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        // No error handling in this sample project.
    }
    
    // MARK: - Update the interface
    
    /// Retreive the WKInterfaceLabel object for the quantity types we are observing.
    func labelForQuantityType(_ type: HKQuantityType) -> WKInterfaceLabel? {
        switch type {
        case HKQuantityType.quantityType(forIdentifier: .heartRate):
            return heartRateLabel
        case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
            return activeCaloriesLabel
        case HKQuantityType.quantityType(forIdentifier: .bloodGlucose):
            return bloodGlucoseLabel
        case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning):
            return distanceLabel
        default:
            return nil
        }
    }
    
    //START OF MAIN EDITS
    
    //**BG collection function
    func getBG(completion: @escaping (Double) -> Void) {
        let bloodGlucoseUnitString = "mg/dL"
        let bloodGlucoseUnit : HKUnit
        bloodGlucoseUnit = HKUnit(from: bloodGlucoseUnitString)

        
                 let quantityType = HKObjectType.quantityType(forIdentifier:(HKQuantityTypeIdentifier.bloodGlucose))
                 let mostRecentPredicate = HKQuery.predicateForSamples(withStart: Date.distantPast,
                                                                       end: Date(),
                                                                       options: .strictEndDate)
                     
                 let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate,
                                                       ascending: false)
                     
                 let limit = 1
                     
                 let sampleQuery = HKSampleQuery(sampleType: quantityType!,
                                                 predicate: mostRecentPredicate,
                                                 limit: limit,
                                                 sortDescriptors: [sortDescriptor]) { (query, samples, error) in
                                                    var initBG = 0.0
            
        let sample = samples?.first as? HKQuantitySample
                    // let initBG = HKQuantity(unit: bloodGlucoseUnit, doubleValue: sample)
                                                    initBG = sample!.quantity.doubleValue(for: bloodGlucoseUnit)
                                                             
                //        return initBG
                                                    
                            DispatchQueue.main.async {
                                completion(initBG)
                                                    }
                                                    
    
            }
                   
                                                    HKHealthStore().execute(sampleQuery)
        
                                                    }
    
    //**IOB collection function
    func IOBcollection(forPast hours: Int, completion: @escaping (Double) -> Void) {
        guard let insulinDeliveryType = HKObjectType.quantityType(forIdentifier: .insulinDelivery) else {
            fatalError("*** Unable to get the insulin delivery type ***")
        }

        let now = Date()
        let startDate = Calendar.current.date(byAdding: DateComponents(hour: -hours), to: now)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: insulinDeliveryType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            guard let result = result, let sum = result.sumQuantity() else {
                completion(0.0)
                return
            }
            completion(sum.doubleValue(for: HKUnit.internationalUnit()))
        }
        HKHealthStore().execute(query)
    }
    
    var totBolus = 0.00 //**Store of total stored "fake" insulin
    
    //**Insulin Bolus Function
        func saveInsulin(insulin: Double, date: Date) {
    
            
            
            guard let insulinDeliveryType = HKObjectType.quantityType(forIdentifier: .insulinDelivery) else {
              fatalError("Insulin Type is no longer available in HealthKit")
            }
            var newBoluss = Double(insulin) - Double(self.totBolus) //**Prevents double counting
            if (newBoluss >= 0.05){ //**If greater than 0.05
            var newBolu = round(100 * newBoluss) / 100
        var newBolusQuantity = HKQuantity(unit: HKUnit.internationalUnit(), doubleValue: Double(newBolu))
            var newBolus = HKQuantitySample(type: insulinDeliveryType, quantity: newBolusQuantity, start: Date(), end: Date(), metadata: [
                HKMetadataKeyInsulinDeliveryReason: HKInsulinDeliveryReason.bolus.rawValue
            ])
        HKHealthStore().save(newBolus) { (success, error) in
                   
                   if let error = error {
                       print("Error Saving Insulin Sample: \(error.localizedDescription)")
                   } else {
                 //   completion(Double(newBoluss))
                       print("*** Bolused \(newBolu) U ***")
                   }
               }
                self.totBolus = Double(self.totBolus) + Double(newBoluss) //**Save new bolus to the total bolus store
    }
            else{
                return
            }
    }
    
    //**/ Update the WKInterfaceLabels with new data. Where we do calculations too
    func updateLabel(_ label: WKInterfaceLabel?, withStatistics statistics: HKStatistics?) {
        // Make sure we got non `nil` parameters.
        guard let label = label, let statistics = statistics else {
            return
        }
        
        // Dispatch to main, because we are updating the interface.
        DispatchQueue.main.async {
            switch statistics.quantityType {
            case HKQuantityType.quantityType(forIdentifier: .heartRate):
                /// - Tag: SetLabel
                let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                let value = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit)
                let roundedValue = Double( round( 1 * value! ) / 1 )
                label.setText("\(roundedValue) BPM")
            case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                let energyUnit = HKUnit.kilocalorie()
                let value = statistics.sumQuantity()?.doubleValue(for: energyUnit)
                let roundedValue = Double( round( 1 * value! ) / 1 )
               
                
                //kinda arbitrary, but lets say I did 100 cals and dropped 100 pts, EST = BG drop / active calories
             //   let initBG = Double(146)
                self.getBG(){initBGG in
                let initBG = round(initBGG)
                //self.IOBcollection(){IOBB in
                    //**Left Riemann sum to find IOB based on the decreasing effect of insulin over time
                self.IOBcollection(forPast: 3) { IOBB6 in
                self.IOBcollection(forPast: Int(2.5)) { IOBB5 in
                self.IOBcollection(forPast: 2) { IOBB4 in
                self.IOBcollection(forPast: Int(1.5)) { IOBB3 in
                self.IOBcollection(forPast: 1) { IOBB2 in
                self.IOBcollection(forPast: Int(0.5)) { IOBB1 in
                let IOBBB = IOBB1 + ((5/6)*(IOBB2-IOBB1)) + ((2/3)*(IOBB3-IOBB2)) + ((1/2)*(IOBB4-IOBB3)) + ((1/3)*(IOBB5-IOBB4)) + ((1/6)*(IOBB6-IOBB5))
                let IOBEffect = Double(1 + (1/2 * IOBBB))
                    let ESF = Double(0.125)
                let TotBGChg = -1 * ESF * IOBEffect * roundedValue
                //let IOBB = round(100 * IOBBB) / 100
                let finBGG = initBG + TotBGChg //**Calculation of total BG change
                let finBG = round(finBGG)
                    let ISF = Double(75)
                   // let ISF = Double(20)
                    var insulin = Double((-1*TotBGChg))/ISF
                 //   var insulin = value!/ISF
                    self.saveInsulin(insulin: insulin, date: Date())
                    
                    let ISFnum = UserDefaults.standard.string(forKey: "ISF") ?? ""
                    
                    let ISF2 = Int(ISFnum) ?? 0
                    print("ISF is \(ISF2)")
                    
                   var roundTotIns = (round(100 * self.totBolus) / 100)
                var IOBBBBB = (round(100 * IOBBB) / 100)
                    
            /*        print("Total calories is \(roundedValue) kcal")
                    print("Current BG is \(initBG) md/dL")
                    print("Future BG is \(finBG) mg/dL")
                    print("IOB is \(IOBBBBB) U")
                    print("Total insulin bolused is \(roundTotIns) U")
                    print("––––––––––––––––––––––––––––––––––––––––")
              */
                    label.setText("\(roundedValue) cal\nC: \(initBG) mg/dL\nF: \(finBG) mg/dL")
}}}}}}}
                
                    return
                                                    
/*            case HKQuantityType.quantityType(forIdentifier: .bloodGlucose):
                let value2 = statistics.mostRecentQuantity()
                let ESF = 0.125
                let TotBGChg = ESF * value
                let NewBG = value - TotBGChg
 */
//            case HKQuantityType.quantityType(forIdentifier: .bloodGlucose):
//                let currentBG = statistics.mostRecentQuantity()?.doubleValue
 //               label.setText("\(currentBG) mg/dL")
            default:
                return
    }
    
}
}
}
