//
//  Romberg.swift
//  Numerical
//
//  Created by Adam Roberts on 4/27/20.
//

import Foundation

/// Integration of a function by Romberg's Method
///
/// Romberg's Method applies Richardson extrapolation on top of the trapezoidal rule. Integrates
/// the functions on the interval [a,b]. Like the trapezoidal rule the points of integration are evenly
/// spaced and each iteration nests its new points at the midpoints of the last iteration. The step
/// size of iteration i is: hᵢ = 2⁻ⁱ (b - a).
///
/// R₀ ₀ = h₁ (f(b) - f(a)), same as first round of trapezoidal
///
/// Rⱼ ₀ = Rⱼ₋₁ ₒ / 2 + hⱼΣi=1...2^j-1 f(a + (2i - 1) hⱼ, same as jth round of trapezoidal
///
/// Rⱼᵢ = (4ⁱ Rⱼᵢ₋₁ - Rⱼ₋₁ ᵢ₋₁) / (4ⁱ - 1)
///
/// https://en.wikipedia.org/wiki/Romberg%27s_method
public func romberg(range: ClosedRange<Double>, maxIter: Int = 10, f rawF: @escaping (Double) -> Double) -> ConvergenceValue<Double>? {
    let f = CountedFunction(f: rawF)
    
    // extract end points from Range
    let a = range.lowerBound
    let b = range.upperBound

    // initial interval is just the full interval
    let Δx₀: Double = (b - a)

    // initial estimate (same as trapezoidal rule)
    let R₀₀: Double = 0.5 * Δx₀ * (f(a) + f(b))

    let n: Int = 1
    
    let seq = sequence(first: (Δx: Δx₀, R: [R₀₀], n: n)) { accum in
        let (Δxⱼ₋₁,Rⱼ₋₁,nⱼ₋₁): (Double, [Double], Int) = accum

        // bisect the interval
        let Δxⱼ = 0.5 * Δxⱼ₋₁

        // double the number of intervals
        let nⱼ = nⱼ₋₁ * 2

        // Σf(xᵢ), i odd. Evaluate at the points nested within previous round
        let sum = (1...nⱼ₋₁).map { f(a + (2 * Double($0) - 1) * Δxⱼ) }.sumKBN()
        
        // new trapezoidal estimate is half the previous (since now
        // intervals are half as wide) plus ∆xⱼ Σf(xᵢ), i odd. The previous
        // trapezoidal estimate is the first entry in the previous R vector
        let Rⱼ₀ = Δxⱼ * sum + 0.5 * Rⱼ₋₁[0]
        
        // Richardson extrapolation
        let Rⱼ = Rⱼ₋₁.scann((Rⱼᵢ: Rⱼ₀, p4ⁱ: 1.0)) { accum, Rⱼ₋₁ᵢ₋₁ in
            let (Rⱼᵢ₋₁,p4ⁱ⁻¹) = accum
            let p4ⁱ = p4ⁱ⁻¹ * 4.0
            let Rⱼᵢ = (p4ⁱ * Rⱼᵢ₋₁ - Rⱼ₋₁ᵢ₋₁) / (p4ⁱ - 1)
            return (Rⱼᵢ, p4ⁱ)
        }.map { $0.Rⱼᵢ }
        
        return (Δxⱼ,Rⱼ,nⱼ)
    }
    // iteratively bisect the interval until we get desired convergence
    let q = seq.until2(minIter: 3, maxIter: maxIter) { a, b in
        b.R.last!.isApprox(.maybeZero(a.R.last!), tolerance: .strict)
    }
    
    guard let quad = q else { return nil }
    
    switch quad {
    case .exhaustedInput: return nil
    case .exceededMax: return .didNotConverge(work: UInt(f.count), estimate: quad.value.R.last!)
    case .success: return .converged(work: UInt(f.count), estimate: quad.value.R.last!)
    }
}
