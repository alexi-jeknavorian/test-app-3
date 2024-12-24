import SwiftUI
import Charts

// MARK: - Data Structures and Enums
enum PaymentFrequency: String, CaseIterable, Identifiable {
    case monthly = "Monthly"
    case biweekly = "Bi-weekly"
    case acceleratedBiweekly = "Accelerated Bi-weekly"
    case weekly = "Weekly"
    case acceleratedWeekly = "Accelerated Weekly"
    
    var id: String { self.rawValue }
    
    var paymentsPerYear: Int {
        switch self {
        case .monthly: return 12
        case .biweekly, .acceleratedBiweekly: return 26
        case .weekly, .acceleratedWeekly: return 52
        }
    }
}

enum MortgageValidationError: Error, LocalizedError {
    case invalidPrice(reason: String)
    case invalidDownPayment(reason: String)
    case invalidInterestRate(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidPrice(let reason):
            return "Invalid price: \(reason)"
        case .invalidDownPayment(let reason):
            return "Invalid down payment: \(reason)"
        case .invalidInterestRate(let reason):
            return "Invalid interest rate: \(reason)"
        }
    }
}

struct PaymentBreakdown {
    let principal: Double
    let interest: Double
    let propertyTax: Double
    let mortgageInsurance: Double
    let totalPayment: Double
    
    var totalMonthlyPayment: Double {
        return totalPayment + (propertyTax / 12) + mortgageInsurance
    }
}

struct AmortizationEntry: Identifiable {
    let id = UUID()
    let paymentNumber: Int
    let payment: Double
    let principalPaid: Double
    let interestPaid: Double
    let remainingBalance: Double
    let cumulativeInterest: Double
}

struct MortgageInputs {
    var propertyPrice: String = ""
    var downPaymentPercentage: String = ""
    var interestRate: String = ""
    var propertyTaxRate: String = ""
    var paymentFrequency: PaymentFrequency = .monthly
    var amortizationYears: Int = 25
    var interpretedPrice: Double = 0.0
    var monthlyPayment: Double = 0.0
    var totalInterest: Double = 0.0
    var mortgageInsuranceAmount: Double = 0.0
    var amortizationEntries: [AmortizationEntry] = []
}

// MARK: - Validation Helper
struct MortgageValidation {
    static func validateInputs(_ inputs: MortgageInputs) throws {
        // Validate price
        guard inputs.interpretedPrice >= 10_000 else {
            throw MortgageValidationError.invalidPrice(reason: "Price must be at least $10,000")
        }
        guard inputs.interpretedPrice <= 100_000_000 else {
            throw MortgageValidationError.invalidPrice(reason: "Price cannot exceed $100,000,000")
        }
        
        // Validate down payment
        guard let downPaymentPercent = Double(inputs.downPaymentPercentage) else {
            throw MortgageValidationError.invalidDownPayment(reason: "Invalid down payment percentage")
        }
        let minDownPayment = inputs.interpretedPrice >= 1_000_000 ? 20.0 : 5.0
        guard downPaymentPercent >= minDownPayment else {
            throw MortgageValidationError.invalidDownPayment(
                reason: "Minimum down payment is \(Int(minDownPayment))% for this price"
            )
        }
        
        // Validate interest rate
        guard let interestRate = Double(inputs.interestRate),
              interestRate > 0,
              interestRate < 30 else {
            throw MortgageValidationError.invalidInterestRate(reason: "Interest rate must be between 0% and 30%")
        }
    }
}

// MARK: - Payment Breakdown Chart
struct PaymentBreakdownChart: View {
    let principal: Double
    let totalInterest: Double
    let propertyTax: Double
    let mortgageInsurance: Double
    
    var data: [ChartData] {
        [
            ChartData(name: "Principal", value: principal, color: .blue),
            ChartData(name: "Interest", value: totalInterest, color: .red),
            ChartData(name: "Property Tax", value: propertyTax, color: .green),
            ChartData(name: "Insurance", value: mortgageInsurance, color: .orange)
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Payment Breakdown")
                .font(.headline)
            
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(data) { item in
                        let width = geometry.size.width * (item.value / data.map { $0.value }.reduce(0, +))
                        Rectangle()
                            .fill(item.color)
                            .frame(width: width)
                    }
                }
            }
            .frame(height: 20)
            
            HStack {
                ForEach(data) { item in
                    HStack {
                        Circle()
                            .fill(item.color)
                            .frame(width: 8, height: 8)
                        Text(item.name)
                            .font(.caption)
                        if let percentage = calculatePercentage(item.value) {
                            Text("(\(percentage)%)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    private func calculatePercentage(_ value: Double) -> Int? {
        let total = data.map { $0.value }.reduce(0, +)
        guard total > 0 else { return nil }
        return Int(round(value / total * 100))
    }
}

struct ChartData: Identifiable {
    let id = UUID()
    let name: String
    let value: Double
    let color: Color
}

// MARK: - Amortization Schedule View
struct AmortizationScheduleView: View {
    let entries: [AmortizationEntry]
    
    var body: some View {
        List {
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Payment \(entry.paymentNumber)")
                        .font(.headline)
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Principal: \(entry.principalPaid, specifier: "$%.2f")")
                            Text("Interest: \(entry.interestPaid, specifier: "$%.2f")")
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Balance: \(entry.remainingBalance, specifier: "$%.2f")")
                            Text("Total Interest: \(entry.cumulativeInterest, specifier: "$%.2f")")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Amortization Schedule")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: exportSchedule) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }
    
    private func exportSchedule() {
        var csv = "Payment Number,Principal,Interest,Remaining Balance,Cumulative Interest\n"
        entries.forEach { entry in
            csv += "\(entry.paymentNumber),\(entry.principalPaid),\(entry.interestPaid),\(entry.remainingBalance),\(entry.cumulativeInterest)\n"
        }
        // Handle export (e.g., share sheet)
    }
}

// MARK: - Main View
struct ContentView: View {
    @State private var mortgageData = MortgageInputs()
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    @State private var showingStressTest: Bool = false
    
    let yearOptions = [5, 10, 15, 20, 25, 30]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Property Details")) {
                    TextField("Property Price", text: $mortgageData.propertyPrice)
                        .keyboardType(.decimalPad)
                        .onChange(of: mortgageData.propertyPrice) { oldValue, newValue in
                            interpretPropertyPrice()
                        }
                    
                    if mortgageData.interpretedPrice > 0 {
                        Text("Interpreted Price: \(formatCurrency(mortgageData.interpretedPrice))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    TextField("Down Payment %", text: $mortgageData.downPaymentPercentage)
                        .keyboardType(.decimalPad)
                    
                    TextField("Interest Rate %", text: $mortgageData.interestRate)
                        .keyboardType(.decimalPad)
                    
                    TextField("Property Tax Rate %", text: $mortgageData.propertyTaxRate)
                        .keyboardType(.decimalPad)
                    
                    Picker("Payment Frequency", selection: $mortgageData.paymentFrequency) {
                        ForEach(PaymentFrequency.allCases) { frequency in
                            Text(frequency.rawValue).tag(frequency)
                        }
                    }
                    
                    Picker("Amortization Period", selection: $mortgageData.amortizationYears) {
                        ForEach(yearOptions, id: \.self) { year in
                            Text("\(year) years")
                        }
                    }
                }
                
                if mortgageData.monthlyPayment > 0 {
                    Section(header: Text("Payment Summary")) {
                        VStack(alignment: .leading, spacing: 8) {
                            PaymentBreakdownChart(
                                principal: mortgageData.interpretedPrice,
                                totalInterest: mortgageData.totalInterest,
                                propertyTax: Double(mortgageData.propertyTaxRate) ?? 0,
                                mortgageInsurance: mortgageData.mortgageInsuranceAmount
                            )
                            
                            Text("Monthly Payment: \(formatCurrency(mortgageData.monthlyPayment))")
                            Text("Total Interest: \(formatCurrency(mortgageData.totalInterest))")
                            if mortgageData.mortgageInsuranceAmount > 0 {
                                Text("Mortgage Insurance: \(formatCurrency(mortgageData.mortgageInsuranceAmount))")
                            }
                            Text("Total Cost: \(formatCurrency(mortgageData.monthlyPayment * Double(mortgageData.amortizationYears * 12)))")
                        }
                    }
                    
                    Section {
                        NavigationLink("View Amortization Schedule", destination: AmortizationScheduleView(entries: mortgageData.amortizationEntries))
                        Button("View Stress Test") {
                            showingStressTest = true
                        }
                    }
                }
                
                Section {
                    NavigationLink("Compare Scenarios", destination: ComparisonView())
                }
                
                Button(action: calculateMortgage) {
                    Text("Calculate")
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                }
                .listRowBackground(Color.blue)
            }
            .navigationTitle("Mortgage Calculator")
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingStressTest) {
                StressTestView(baseRate: Double(mortgageData.interestRate) ?? 0)
            }
        }
    }
    
    // MARK: - Helper Functions
    private func interpretPropertyPrice() {
        guard let inputValue = Double(mortgageData.propertyPrice) else {
            mortgageData.interpretedPrice = 0.0
            return
        }
        
        if inputValue < 1000 {
            if mortgageData.propertyPrice.contains(".") {
                mortgageData.interpretedPrice = inputValue * 1_000_000
            } else if inputValue >= 100 {
                mortgageData.interpretedPrice = inputValue * 1_000
            } else {
                mortgageData.interpretedPrice = inputValue
            }
        } else {
            mortgageData.interpretedPrice = inputValue
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
    
    private func calculateMortgage() {
        do {
            try MortgageValidation.validateInputs(mortgageData)
            
            let price = mortgageData.interpretedPrice
            let downPaymentPercent = Double(mortgageData.downPaymentPercentage)!
            let interest = Double(mortgageData.interestRate)!
            
            // Calculate loan amount and insurance
            let downPayment = price * (downPaymentPercent / 100)
            let principal = price - downPayment
            
            // Calculate mortgage insurance if down payment is less than 20%
            if downPaymentPercent < 20 {
                mortgageData.mortgageInsuranceAmount = calculateMortgageInsurance(price: price, downPaymentPercent: downPaymentPercent)
            } else {
                mortgageData.mortgageInsuranceAmount = 0
            }
            
            // Convert annual interest rate to payment period rate
            let periodicInterest = (interest / 100) / Double(mortgageData.paymentFrequency.paymentsPerYear)
            
            // Calculate total number of payments
            let numberOfPayments = Double(mortgageData.amortizationYears * mortgageData.paymentFrequency.paymentsPerYear)
            
            // Calculate payment
            let temp = pow(1 + periodicInterest, numberOfPayments)
            mortgageData.monthlyPayment = principal * (periodicInterest * temp) / (temp - 1)
            
            // Adjust payment for frequency
            switch mortgageData.paymentFrequency {
            case .acceleratedBiweekly:
                mortgageData.monthlyPayment = (mortgageData.monthlyPayment * 12) / 26
            case .acceleratedWeekly:
                mortgageData.monthlyPayment = (mortgageData.monthlyPayment * 12) / 52
            default:
                break
            }
            
            // Generate amortization schedule
            generateAmortizationSchedule(
                principal: principal,
                periodicInterest: periodicInterest,
                numberOfPayments: Int(numberOfPayments)
            )
            
            // Calculate total interest
            mortgageData.totalInterest = (mortgageData.monthlyPayment * numberOfPayments) - principal
            
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func calculateMortgageInsurance(price: Double, downPaymentPercent: Double) -> Double {
        let loanToValue = (100 - downPaymentPercent) / 100
        
        let insuranceRate: Double
        if downPaymentPercent >= 15 {
            insuranceRate = 0.028  // 2.8% for down payments of 15-19.99%
        } else if downPaymentPercent >= 10 {
            insuranceRate = 0.031  // 3.1% for down payments of 10-14.99%
        } else {
            insuranceRate = 0.04   // 4.0% for down payments of 5-9.99%
        }
        
        return price * loanToValue * insuranceRate
    }
    
    private func generateAmortizationSchedule(principal: Double, periodicInterest: Double, numberOfPayments: Int) {
        var remainingBalance = principal
        var cumulativeInterest = 0.0
        mortgageData.amortizationEntries = []
        
        for paymentNumber in 1...numberOfPayments {
            let interestPayment = remainingBalance * periodicInterest
            let principalPayment = mortgageData.monthlyPayment - interestPayment
            remainingBalance -= principalPayment
            cumulativeInterest += interestPayment
            
            let entry = AmortizationEntry(
                paymentNumber: paymentNumber,
                payment: mortgageData.monthlyPayment,
                principalPaid: principalPayment,
                interestPaid: interestPayment,
                remainingBalance: remainingBalance,
                cumulativeInterest: cumulativeInterest
            )
            mortgageData.amortizationEntries.append(entry)
        }
    }
}

// MARK: - Stress Test View
struct StressTestView: View {
    let baseRate: Double
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Interest Rate Scenarios")) {
                    StressTestRow(
                        scenario: "Current Rate",
                        rate: baseRate,
                        payment: calculatePayment(using: baseRate)
                    )
                    
                    StressTestRow(
                        scenario: "Stress Test Rate (+2%)",
                        rate: baseRate + 2,
                        payment: calculatePayment(using: baseRate + 2)
                    )
                    
                    StressTestRow(
                        scenario: "High Rate (+5%)",
                        rate: baseRate + 5,
                        payment: calculatePayment(using: baseRate + 5)
                    )
                }
            }
            .navigationTitle("Payment Stress Test")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func calculatePayment(using rate: Double) -> Double {
        // Implement payment calculation with the given rate
        return 0.0 // Placeholder
    }
}

struct StressTestRow: View {
    let scenario: String
    let rate: Double
    let payment: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(scenario)
                .font(.headline)
            HStack {
                Text("\(rate, specifier: "%.2f")%")
                    .foregroundColor(.secondary)
                Spacer()
                Text(payment, format: .currency(code: "USD"))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Comparison View
struct ComparisonView: View {
    @State private var scenarioA = MortgageInputs()
    @State private var scenarioB = MortgageInputs()
    
    var body: some View {
        HStack(spacing: 0) {
            ScenarioView(scenario: $scenarioA, title: "Scenario A")
            
            Divider()
                .background(Color.gray)
            
            ScenarioView(scenario: $scenarioB, title: "Scenario B")
        }
        .navigationTitle("Compare Scenarios")
    }
}

struct ScenarioView: View {
    @Binding var scenario: MortgageInputs
    let title: String
    let yearOptions = [5, 10, 15, 20, 25, 30]
    
    var body: some View {
        Form {
            Section(header: Text(title)) {
                TextField("Property Price", text: $scenario.propertyPrice)
                    .keyboardType(.decimalPad)
                
                TextField("Down Payment %", text: $scenario.downPaymentPercentage)
                    .keyboardType(.decimalPad)
                
                TextField("Interest Rate %", text: $scenario.interestRate)
                    .keyboardType(.decimalPad)
                
                Picker("Term", selection: $scenario.amortizationYears) {
                    ForEach(yearOptions, id: \.self) { year in
                        Text("\(year)y")
                    }
                }
                
                if scenario.monthlyPayment > 0 {
                    VStack(alignment: .leading) {
                        Text("Monthly: \(scenario.monthlyPayment, format: .currency(code: "USD"))")
                        Text("Total Interest: \(scenario.totalInterest, format: .currency(code: "USD"))")
                        Text("Total Cost: \(scenario.monthlyPayment * Double(scenario.amortizationYears * 12), format: .currency(code: "USD"))")
                    }
                }
                
                Button("Calculate") {
                    // Implement calculation
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
