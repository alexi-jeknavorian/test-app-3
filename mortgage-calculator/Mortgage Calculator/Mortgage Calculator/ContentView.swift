import SwiftUI

// MARK: - Data Structures
struct PaymentBreakdown {
    let principal: Double
    let interest: Double
    let totalPayment: Double
}

struct AmortizationEntry {
    let paymentNumber: Int
    let payment: Double
    let principalPaid: Double
    let interestPaid: Double
    let remainingBalance: Double
}

struct MortgageInputs {
    var propertyPrice: String = ""
    var downPaymentPercentage: String = ""
    var interestRate: String = ""
    var amortizationYears: Int = 25
    var interpretedPrice: Double = 0.0
    var monthlyPayment: Double = 0.0
    var totalInterest: Double = 0.0
    var amortizationEntries: [AmortizationEntry] = []
}

// MARK: - Amortization Schedule View
struct AmortizationScheduleView: View {
    let entries: [AmortizationEntry]
    
    var body: some View {
        List {
            ForEach(0..<entries.count, id: \.self) { index in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Payment \(entries[index].paymentNumber)")
                        .font(.headline)
                    Text("Principal: \(entries[index].principalPaid, specifier: "$%.2f")")
                    Text("Interest: \(entries[index].interestPaid, specifier: "$%.2f")")
                    Text("Remaining: \(entries[index].remainingBalance, specifier: "$%.2f")")
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Amortization Schedule")
    }
}

// MARK: - Main View
struct ContentView: View {
    @State private var mortgageData = MortgageInputs()
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    
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
                    
                    Picker("Amortization Period", selection: $mortgageData.amortizationYears) {
                        ForEach(yearOptions, id: \.self) { year in
                            Text("\(year) years")
                        }
                    }
                }
                
                if mortgageData.monthlyPayment > 0 {
                    Section(header: Text("Payment Summary")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Monthly Payment: \(formatCurrency(mortgageData.monthlyPayment))")
                            Text("Total Interest: \(formatCurrency(mortgageData.totalInterest))")
                            Text("Total Cost: \(formatCurrency(mortgageData.monthlyPayment * Double(mortgageData.amortizationYears * 12)))")
                        }
                    }
                    
                    Section {
                        NavigationLink("View Amortization Schedule", destination: AmortizationScheduleView(entries: mortgageData.amortizationEntries))
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
            .navigationTitle("Mortgage Body")
            .alert(isPresented: $showError) {
                Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
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
            }
            else if inputValue >= 100 && inputValue < 1000 {
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
    
    private func validateInputs() -> Bool {
        guard let _ = Double(mortgageData.propertyPrice),
              let downPaymentPercent = Double(mortgageData.downPaymentPercentage),
              let interest = Double(mortgageData.interestRate) else {
            errorMessage = "Please enter valid numbers for all fields"
            showError = true
            return false
        }
        
        if downPaymentPercent <= 0 || downPaymentPercent >= 100 {
            errorMessage = "Down payment must be between 0 and 100%"
            showError = true
            return false
        }
        
        if interest <= 0 || interest >= 100 {
            errorMessage = "Interest rate must be between 0 and 100%"
            showError = true
            return false
        }
        
        return true
    }
    
    private func calculateMortgage() {
        guard validateInputs() else { return }
        
        let price = mortgageData.interpretedPrice
        let downPaymentPercent = Double(mortgageData.downPaymentPercentage)!
        let interest = Double(mortgageData.interestRate)!
        
        // Calculate loan amount
        let downPayment = price * (downPaymentPercent / 100)
        let principal = price - downPayment
        
        // Convert annual interest rate to monthly
        let monthlyInterest = (interest / 100) / 12
        
        // Calculate total number of payments
        let numberOfPayments = Double(mortgageData.amortizationYears * 12)
        
        // Calculate monthly payment
        let temp = pow(1 + monthlyInterest, numberOfPayments)
        mortgageData.monthlyPayment = principal * (monthlyInterest * temp) / (temp - 1)
        
        // Generate amortization schedule
        generateAmortizationSchedule(principal: principal, monthlyInterest: monthlyInterest, numberOfPayments: Int(numberOfPayments))
        
        // Calculate total interest
        mortgageData.totalInterest = (mortgageData.monthlyPayment * numberOfPayments) - principal
    }
    
    private func generateAmortizationSchedule(principal: Double, monthlyInterest: Double, numberOfPayments: Int) {
        var remainingBalance = principal
        mortgageData.amortizationEntries = []
        
        for paymentNumber in 1...numberOfPayments {
            let interestPayment = remainingBalance * monthlyInterest
            let principalPayment = mortgageData.monthlyPayment - interestPayment
            remainingBalance -= principalPayment
            
            let entry = AmortizationEntry(
                paymentNumber: paymentNumber,
                payment: mortgageData.monthlyPayment,
                principalPaid: principalPayment,
                interestPaid: interestPayment,
                remainingBalance: remainingBalance
            )
            mortgageData.amortizationEntries.append(entry)
        }
    }
}

// MARK: - Comparison View
struct ComparisonView: View {
    @State private var scenarioA = MortgageInputs()
    @State private var scenarioB = MortgageInputs()
    let yearOptions = [5, 10, 15, 20, 25, 30]
    
    var body: some View {
        HStack(spacing: 0) {
            // Scenario A
            VStack {
                Form {
                    Section(header: Text("Scenario A")) {
                        TextField("Property Price", text: $scenarioA.propertyPrice)
                            .keyboardType(.decimalPad)
                            .onChange(of: scenarioA.propertyPrice) { oldValue, newValue in
                                interpretPrice(for: &scenarioA)
                            }
                        
                        if scenarioA.interpretedPrice > 0 {
                            Text("Price: \(formatCurrency(scenarioA.interpretedPrice))")
                                .font(.subheadline)
                        }
                        
                        TextField("Down Payment %", text: $scenarioA.downPaymentPercentage)
                            .keyboardType(.decimalPad)
                        TextField("Interest Rate %", text: $scenarioA.interestRate)
                            .keyboardType(.decimalPad)
                        
                        Picker("Term", selection: $scenarioA.amortizationYears) {
                            ForEach(yearOptions, id: \.self) { year in
                                Text("\(year)y")
                            }
                        }
                        
                        if scenarioA.monthlyPayment > 0 {
                            VStack(alignment: .leading) {
                                Text("Monthly: \(formatCurrency(scenarioA.monthlyPayment))")
                                Text("Interest: \(formatCurrency(scenarioA.totalInterest))")
                                Text("Total: \(formatCurrency(scenarioA.monthlyPayment * Double(scenarioA.amortizationYears * 12)))")
                            }
                        }
                        
                        Button("Calculate A") {
                            calculateMortgage(for: &scenarioA)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            
            Divider()
                .background(Color.gray)
                .frame(width: 2)
            
            // Scenario B
            VStack {
                Form {
                    Section(header: Text("Scenario B")) {
                        TextField("Property Price", text: $scenarioB.propertyPrice)
                            .keyboardType(.decimalPad)
                            .onChange(of: scenarioB.propertyPrice) { oldValue, newValue in
                                interpretPrice(for: &scenarioB)
                            }
                        
                        if scenarioB.interpretedPrice > 0 {
                            Text("Price: \(formatCurrency(scenarioB.interpretedPrice))")
                                .font(.subheadline)
                        }
                        
                        TextField("Down Payment %", text: $scenarioB.downPaymentPercentage)
                            .keyboardType(.decimalPad)
                        TextField("Interest Rate %", text: $scenarioB.interestRate)
                            .keyboardType(.decimalPad)
                        
                        Picker("Term", selection: $scenarioB.amortizationYears) {
                            ForEach(yearOptions, id: \.self) { year in
                                Text("\(year)y")
                            }
                        }
                        
                        if scenarioB.monthlyPayment > 0 {
                            VStack(alignment: .leading) {
                                Text("Monthly: \(formatCurrency(scenarioB.monthlyPayment))")
                                Text("Interest: \(formatCurrency(scenarioB.totalInterest))")
                                Text("Total: \(formatCurrency(scenarioB.monthlyPayment * Double(scenarioB.amortizationYears * 12)))")
                            }
                        }
                        
                        Button("Calculate B") {
                            calculateMortgage(for: &scenarioB)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Compare Scenarios")
    }
    
    // MARK: - Helper Functions for Comparison View
    private func interpretPrice(for scenario: inout MortgageInputs) {
        guard let inputValue = Double(scenario.propertyPrice) else {
            scenario.interpretedPrice = 0.0
            return
        }
        
        if inputValue < 1000 {
            if scenario.propertyPrice.contains(".") {
                scenario.interpretedPrice = inputValue * 1_000_000
            }
            else if inputValue >= 100 && inputValue < 1000 {
                scenario.interpretedPrice = inputValue * 1_000
            } else {
                scenario.interpretedPrice = inputValue
            }
        } else {
            scenario.interpretedPrice = inputValue
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
    
    private func calculateMortgage(for scenario: inout MortgageInputs) {
        guard let downPaymentPercent = Double(scenario.downPaymentPercentage),
              let interest = Double(scenario.interestRate) else {
            return
        }
        
        let price = scenario.interpretedPrice
        let downPayment = price * (downPaymentPercent / 100)
        let principal = price - downPayment
        let monthlyInterest = (interest / 100) / 12
        let numberOfPayments = Double(scenario.amortizationYears * 12)
        
        let temp = pow(1 + monthlyInterest, numberOfPayments)
        scenario.monthlyPayment = principal * (monthlyInterest * temp) / (temp - 1)
        scenario.totalInterest = (scenario.monthlyPayment * numberOfPayments) - principal
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
