import SwiftUI
import Charts

// Shared Data Model
class WeightData: ObservableObject {
    @Published var weights: [WeightEntry] = [] // Tracks weight entries (date + weight)

    func addWeight(date: Date, weight: Double) {
        if let index = weights.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            weights[index].weight = weight // Update existing entry
        } else {
            weights.append(WeightEntry(date: date, weight: weight)) // Add new entry
            weights.sort { $0.date < $1.date } // Keep entries sorted by date
        }
    }
}

struct WeightEntry: Identifiable {
    let id = UUID()
    var date: Date
    var weight: Double
}

// Content View
struct ContentView: View {
    @StateObject var weightData = WeightData() // Initialize shared state

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Welcome Message
                    Text("Welxcome Chris")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)

                    // Current Date
                    Text("Today's Date: \(Date(), formatter: DateFormatter.shortDate)")
                        .font(.headline)

                    // Scheduled Workout
                    Text("Today's Workout: Push Day")
                        .font(.headline)
                        .foregroundColor(.blue)

                    // Graph: Body Weight Over Last 30 Days
                    LineGraphView(data: weightData.weights)
                        .frame(height: 200)
                        .padding(.vertical)

                    // Begin Workout Button
                    NavigationLink(destination: WorkoutPage()) {
                        Text("Begin Workout")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.blue)
                            .cornerRadius(10)
                            .padding(.top)
                    }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
        }
        .environmentObject(weightData) // Share state with subviews
    }
}

// Line Graph Component
struct LineGraphView: View {
    var data: [WeightEntry]

    var body: some View {
        NavigationLink(destination: LogWeightPage()) {
            LineGraph(data: data)
                .frame(maxWidth: .infinity, minHeight: 200)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding()
        }
        .buttonStyle(PlainButtonStyle()) // Removes default button styling
    }
}

// Custom Line Graph Implementation
struct LineGraph: View {
    var data: [WeightEntry]

    var body: some View {
        Chart {
            ForEach(data) { entry in
                LineMark(
                    x: .value("Date", entry.date, unit: .day),
                    y: .value("Weight", entry.weight)
                )
            }
        }
        .chartYAxis {
            if let latestWeight = data.last?.weight {
                AxisMarks(position: .leading, values: Array(stride(from: latestWeight - 20, through: latestWeight + 20, by: 5)))
            } else {
                AxisMarks()
            }
        }
        .chartXAxis {
            AxisMarks(format: .dateTime.month().day())
        }
    }
}

// Log Weight Page
struct LogWeightPage: View {
    @EnvironmentObject var weightData: WeightData // Access shared state
    @State private var selectedDate: Date = Date() // Default to today
    @State private var weight: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Log Your Weight")
                .font(.title)
                .fontWeight(.bold)

            // Date Picker for selecting past dates
            DatePicker("Select Date", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(GraphicalDatePickerStyle())
                .padding()

            // Text Field for entering weight
            TextField("Enter weight (lb)", text: $weight)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.decimalPad)
                .padding()

            // Save Button
            Button(action: {
                if let weightValue = Double(weight) {
                    weightData.addWeight(date: selectedDate, weight: weightValue) // Add or update weight
                    weight = "" // Clear input field
                }
            }) {
                Text("Save")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top)

            // Line Graph for Reference
            LineGraphView(data: weightData.weights)
                .frame(height: 200)
                .padding()

            Spacer()
        }
        .padding()
        .navigationTitle("Log Weight")
    }
}

// Workout Page Placeholder
struct WorkoutPage: View {
    var body: some View {
        Text("Workout Page")
            .font(.title)
    }
}

// Date Formatter Extension
extension DateFormatter {
    static var shortDate: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
}

// Previews
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
