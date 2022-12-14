//
//  LSTMNeuralNetwork.swift
//  AIToolbox
//
//  Created by Kevin Coble on 5/20/16.
//  Copyright Β© 2016 Kevin Coble. All rights reserved.
//

import Foundation
#if os(Linux)
#else
import Accelerate
#endif


final class LSTMNeuralNode {
    //  Activation function
    let activation : NeuralActivationFunction
    let numInputs : Int
    let numFeedback : Int
    
    //  Weights
    let numWeights : Int        //  This includes weights from inputs and from feedback for input, forget, cell, and output
    var Wi : [Double]
    var Ui : [Double]
    var Wf : [Double]
    var Uf : [Double]
    var Wc : [Double]
    var Uc : [Double]
    var Wo : [Double]
    var Uo : [Double]

    var h : Double //  Last result calculated
    var outputHistory : [Double] //  History of output for the sequence
    var lastCellState : Double //  Last cell state calculated
    var cellStateHistory : [Double] //  History of cell state for the sequence
    var ho : Double //  Last output gate calculated
    var outputGateHistory : [Double] //  History of output gate result for the sequence
    var hc : Double
    var memoryCellHistory : [Double] //  History of cell activation result for the sequence
    var hi : Double //  Last input gate calculated
    var inputGateHistory : [Double] //  History of input gate result for the sequence
    var hf : Double //  Last forget gate calculated
    var forgetGateHistory : [Double] //  History of forget gate result for the sequence
    var πEπh : Double       //  Gradient in error with respect to output of this node for this time step plus future time steps
    var πEπzo : Double      //  Gradient in error with respect to weighted sum of the output gate
    var πEπzi : Double      //  Gradient in error with respect to weighted sum of the input gate
    var πEπzf : Double      //  Gradient in error with respect to weighted sum of the forget gate
    var πEπzc : Double      //  Gradient in error with respect to weighted sum of the memory cell
    var πEπcellState : Double      //  Gradient in error with respect to state of the memory cell
    var πEπWi : [Double]
    var πEπUi : [Double]
    var πEπWf : [Double]
    var πEπUf : [Double]
    var πEπWc : [Double]
    var πEπUc : [Double]
    var πEπWo : [Double]
    var πEπUo : [Double]
    var weightUpdateMethod = NeuralWeightUpdateMethod.normal
    var weightUpdateParameter : Double?      //  Decay rate for rms prop weight updates
    var WiWeightUpdateData : [Double] = []    //  Array of running average for rmsprop
    var UiWeightUpdateData : [Double] = []    //  Array of running average for rmsprop
    var WfWeightUpdateData : [Double] = []    //  Array of running average for rmsprop
    var UfWeightUpdateData : [Double] = []    //  Array of running average for rmsprop
    var WcWeightUpdateData : [Double] = []    //  Array of running average for rmsprop
    var UcWeightUpdateData : [Double] = []    //  Array of running average for rmsprop
    var WoWeightUpdateData : [Double] = []    //  Array of running average for rmsprop
    var UoWeightUpdateData : [Double] = []    //  Array of running average for rmsprop

    ///  Create the LSTM neural network node with a set activation function
    init(numInputs : Int, numFeedbacks : Int,  activationFunction: NeuralActivationFunction)
    {
        activation = activationFunction
        self.numInputs = numInputs + 1        //  Add one weight for the bias term
        self.numFeedback = numFeedbacks
        
        //  Weights
        numWeights = (self.numInputs + self.numFeedback) * 4  //  input, forget, cell and output all have weights
        Wi = []
        Ui = []
        Wf = []
        Uf = []
        Wc = []
        Uc = []
        Wo = []
        Uo = []
        
        h = 0.0
        outputHistory = []
        lastCellState = 0.0
        cellStateHistory = []
        ho = 0.0
        outputGateHistory = []
        hc = 0.0
        memoryCellHistory = []
        hi = 0.0
        inputGateHistory = []
        hf = 0.0
        forgetGateHistory = []
        
        πEπh = 0.0
        πEπzo = 0.0
        πEπzi = 0.0
        πEπzf = 0.0
        πEπzc = 0.0
        πEπcellState = 0.0
        
        πEπWi = []
        πEπUi = []
        πEπWf = []
        πEπUf = []
        πEπWc = []
        πEπUc = []
        πEπWo = []
        πEπUo = []
    }
    
    //  Initialize the weights
    func initWeights(_ startWeights: [Double]!)
    {
        if let startWeights = startWeights {
            if (startWeights.count == 1) {
                Wi = [Double](repeating: startWeights[0], count: numInputs)
                Ui = [Double](repeating: startWeights[0], count: numFeedback)
                Wf = [Double](repeating: startWeights[0], count: numInputs)
                Uf = [Double](repeating: startWeights[0], count: numFeedback)
                Wc = [Double](repeating: startWeights[0], count: numInputs)
                Uc = [Double](repeating: startWeights[0], count: numFeedback)
                Wo = [Double](repeating: startWeights[0], count: numInputs)
                Uo = [Double](repeating: startWeights[0], count: numFeedback)
            }
            else if (startWeights.count == (numInputs+numFeedback) * 4) {
                //  Full weight array, just split into the eight weight arrays
                var index = 0
                Wi = Array(startWeights[index..<index+numInputs])
                index += numInputs
                Ui = Array(startWeights[index..<index+numFeedback])
                index += numFeedback
                Wf = Array(startWeights[index..<index+numInputs])
                index += numInputs
                Uf = Array(startWeights[index..<index+numFeedback])
                index += numFeedback
                Wc = Array(startWeights[index..<index+numInputs])
                index += numInputs
                Uc = Array(startWeights[index..<index+numFeedback])
                index += numFeedback
                Wo = Array(startWeights[index..<index+numInputs])
                index += numInputs
                Uo = Array(startWeights[index..<index+numFeedback])
                index += numFeedback
            }
            else {
                //  Get the weights and bias start indices
                let numValues = startWeights.count
                var inputStart : Int
                var forgetStart : Int
                var cellStart : Int
                var outputStart : Int
                var sectionLength : Int
                if ((numValues % 4) == 0) {
                    //  Evenly divisible by 4, pass each quarter
                    sectionLength = numValues / 4
                    inputStart = 0
                    forgetStart = sectionLength
                    cellStart = sectionLength * 2
                    outputStart = sectionLength * 3
                }
                else {
                    //  Use the values for all sections
                    inputStart = 0
                    forgetStart = 0
                    cellStart = 0
                    outputStart = 0
                    sectionLength = numValues
                }
                
                Wi = []
                var index = inputStart //  Last number (if more than 1) goes into the bias weight, then repeat the initial
                for _ in 0..<numInputs-1  {
                    if (index >= sectionLength-1) { index = inputStart }      //  Wrap if necessary
                    Wi.append(startWeights[index])
                    index += 1
                }
                Wi.append(startWeights[inputStart + sectionLength -  1])     //  Add the bias term
                
                Ui = []
                for _ in 0..<numFeedback  {
                    if (index >= sectionLength-1) { index = inputStart }      //  Wrap if necessary
                    Ui.append(startWeights[index])
                    index += 1
                }
                
                index = forgetStart
                Wf = []
                for _ in 0..<numInputs-1  {
                    if (index >= sectionLength-1) { index = forgetStart }      //  Wrap if necessary
                    Wi.append(startWeights[index])
                    index += 1
                }
                Wf.append(startWeights[forgetStart + sectionLength -  1])     //  Add the bias term
                
                Uf = []
                for _ in 0..<numFeedback  {
                    if (index >= sectionLength-1) { index = forgetStart }      //  Wrap if necessary
                    Uf.append(startWeights[index])
                    index += 1
                }
                
                index = cellStart
                Wc = []
                for _ in 0..<numInputs-1  {
                    if (index >= sectionLength-1) { index = cellStart }      //  Wrap if necessary
                    Wc.append(startWeights[index])
                    index += 1
                }
                Wc.append(startWeights[cellStart + sectionLength -  1])     //  Add the bias term
                
                Uc = []
                for _ in 0..<numFeedback  {
                    if (index >= sectionLength-1) { index = cellStart }      //  Wrap if necessary
                    Uc.append(startWeights[index])
                    index += 1
                }
                
                index = outputStart
                Wo = []
                for _ in 0..<numInputs-1  {
                    if (index >= sectionLength-1) { index = outputStart }      //  Wrap if necessary
                    Wo.append(startWeights[index])
                    index += 1
                }
                Wo.append(startWeights[outputStart + sectionLength -  1])     //  Add the bias term
                
                Uo = []
                for _ in 0..<numFeedback  {
                    if (index >= sectionLength-1) { index = outputStart }      //  Wrap if necessary
                    Uo.append(startWeights[index])
                    index += 1
                }
            }
        }
        else {
            Wi = []
            for _ in 0..<numInputs-1  {
                Wi.append(Gaussian.gaussianRandom(0.0, standardDeviation: 1.0 / Double(numInputs-1)))    //  input weights - Initialize to a random number to break initial symmetry of the network, scaled to the inputs
            }
            Wi.append(Gaussian.gaussianRandom(-2.0, standardDeviation:1.0))    //  Bias weight - Initialize to a negative number to have inputs learn to feed in
            
            Ui = []
            for _ in 0..<numFeedback  {
                Ui.append(Gaussian.gaussianRandom(0.0, standardDeviation: 1.0 / Double(numFeedback)))    //  feedback weights - Initialize to a random number to break initial symmetry of the network, scaled to the inputs
            }

            Wf = []
            for _ in 0..<numInputs-1  {
                Wf.append(Gaussian.gaussianRandom(0.0, standardDeviation: 1.0 / Double(numInputs-1)))    //  input weights - Initialize to a random number to break initial symmetry of the network, scaled to the inputs
            }
            Wf.append(Gaussian.gaussianRandom(2.0, standardDeviation:1.0))    //  Bias weight - Initialize to a positive number to turn off forget (output close to 1) until it 'learns' to forget
            
            Uf = []
            for _ in 0..<numFeedback  {
                Uf.append(Gaussian.gaussianRandom(0.0, standardDeviation: 1.0 / Double(numFeedback)))    //  feedback weights - Initialize to a random number to break initial symmetry of the network, scaled to the inputs
            }
            
            Wc = []
            for _ in 0..<numInputs-1  {
                Wc.append(Gaussian.gaussianRandom(0.0, standardDeviation: 1.0 / Double(numInputs-1)))    //  input weights - Initialize to a random number to break initial symmetry of the network, scaled to the inputs
            }
            Wc.append(Gaussian.gaussianRandom(0.0, standardDeviation:1.0))    //  Bias weight - Initialize to a random number to break initial symmetry of the network
            
            Uc = []
            for _ in 0..<numFeedback  {
                Uc.append(Gaussian.gaussianRandom(0.0, standardDeviation: 1.0 / Double(numFeedback)))    //  feedback weights - Initialize to a random number to break initial symmetry of the network, scaled to the inputs
            }
            
            Wo = []
            for _ in 0..<numInputs-1  {
                Wo.append(Gaussian.gaussianRandom(0.0, standardDeviation: 1.0 / Double(numInputs-1)))    //  input weights - Initialize to a random number to break initial symmetry of the network, scaled to the inputs
            }
            Wo.append(Gaussian.gaussianRandom(-2.0, standardDeviation:1.0))    //  Bias weight - Initialize to a negative number to limit output until network learns when output is needed
            
            Uo = []
            for _ in 0..<numFeedback  {
                Uo.append(Gaussian.gaussianRandom(0.0, standardDeviation: 1.0 / Double(numFeedback)))    //  feedback weights - Initialize to a random number to break initial symmetry of the network, scaled to the inputs
            }
        }
        
        //  If rmsprop update, allocate the momentum storage array
        if (weightUpdateMethod == .rmsProp) {
            WiWeightUpdateData = [Double](repeating: 0.0, count: numInputs)
            UiWeightUpdateData = [Double](repeating: 0.0, count: numFeedback)
            WfWeightUpdateData = [Double](repeating: 0.0, count: numInputs)
            UfWeightUpdateData = [Double](repeating: 0.0, count: numFeedback)
            WcWeightUpdateData = [Double](repeating: 0.0, count: numInputs)
            UcWeightUpdateData = [Double](repeating: 0.0, count: numFeedback)
            WoWeightUpdateData = [Double](repeating: 0.0, count: numInputs)
            UoWeightUpdateData = [Double](repeating: 0.0, count: numFeedback)
        }
    }
    
    func setNeuralWeightUpdateMethod(_ method: NeuralWeightUpdateMethod, _ parameter: Double?)
    {
        weightUpdateMethod = method
        weightUpdateParameter = parameter
    }
    
    func feedForward(_ x: [Double], hPrev: [Double]) -> Double
    {
        //  Get the input gate value
        var zi = 0.0
        var sum = 0.0
        vDSP_dotprD(Wi, 1, x, 1, &zi, vDSP_Length(numInputs))
        vDSP_dotprD(Ui, 1, hPrev, 1, &sum, vDSP_Length(numFeedback))
        zi += sum
        hi = 1.0 / (1.0 + exp(-zi))
        
        //  Get the forget gate value
        var zf = 0.0
        vDSP_dotprD(Wf, 1, x, 1, &zf, vDSP_Length(numInputs))
        vDSP_dotprD(Uf, 1, hPrev, 1, &sum, vDSP_Length(numFeedback))
        zf += sum
        hf = 1.0 / (1.0 + exp(-zf))
        
        //  Get the output gate value
        var zo = 0.0
        vDSP_dotprD(Wo, 1, x, 1, &zo, vDSP_Length(numInputs))
        vDSP_dotprD(Uo, 1, hPrev, 1, &sum, vDSP_Length(numFeedback))
        zo += sum
        ho = 1.0 / (1.0 + exp(-zo))
        
        //  Get the memory cell z sumation
        var zc = 0.0
        vDSP_dotprD(Wc, 1, x, 1, &zc, vDSP_Length(numInputs))
        vDSP_dotprD(Uc, 1, hPrev, 1, &sum, vDSP_Length(numFeedback))
        zc += sum
        
        //  Use the activation function function for the nonlinearity
        switch (activation) {
        case .none:
            hc = zc
            break
        case .hyperbolicTangent:
            hc = tanh(zc)
            break
        case .sigmoidWithCrossEntropy:
            fallthrough
        case .sigmoid:
            hc = 1.0 / (1.0 + exp(-zc))
            break
        case .rectifiedLinear:
            hc = zc
            if (zc < 0) { hc = 0.0 }
            break
        case .softSign:
            hc = zc / (1.0 + abs(zc))
            break
        case .softMax:
            hc = exp(zc)
            break
        }
        
        //  Combine the forget and input gates into the cell summation
        lastCellState = lastCellState * hf + hc * hi
        
        //  Use the activation function function for the nonlinearity
        let squashedCellState = getSquashedCellState()
        
        //  Multiply the cell value by the output gate value to get the final result
        h = squashedCellState * ho
        
        return h
    }
    
    func getSquashedCellState() -> Double
    {
        
        //  Use the activation function function for the nonlinearity
        var squashedCellState : Double
        switch (activation) {
        case .none:
            squashedCellState = lastCellState
            break
        case .hyperbolicTangent:
            squashedCellState = tanh(lastCellState)
            break
        case .sigmoidWithCrossEntropy:
            fallthrough
        case .sigmoid:
            squashedCellState = 1.0 / (1.0 + exp(-lastCellState))
            break
        case .rectifiedLinear:
            squashedCellState = lastCellState
            if (lastCellState < 0) { squashedCellState = 0.0 }
            break
        case .softSign:
            squashedCellState = lastCellState / (1.0 + abs(lastCellState))
            break
        case .softMax:
            squashedCellState = exp(lastCellState)
            break
        }
        
        return squashedCellState
    }
    
    //  Get the partial derivitive of the error with respect to the weighted sum
    func getFinalNodeπEπzs(_ πEπh: Double)
    {
        //  Store πE/πh, set initial future error contributions to zero, and have the hidden layer routine do the work
        self.πEπh = πEπh
        getπEπzs()
    }
    
    func resetπEπhs()
    {
        πEπh = 0.0
    }
    
    func addToπEπhs(_ addition: Double)
    {
        πEπh += addition
    }
    
    func getWeightTimesπEπzs(_ weightIndex: Int) ->Double
    {
        var sum = Wo[weightIndex] * πEπzo
        sum += Wf[weightIndex] * πEπzf
        sum += Wc[weightIndex] * πEπzc
        sum += Wi[weightIndex] * πEπzi
        
        return sum
    }
    
    func getFeedbackWeightTimesπEπzs(_ weightIndex: Int) ->Double
    {
        var sum = Uo[weightIndex] * πEπzo
        sum += Uf[weightIndex] * πEπzf
        sum += Uc[weightIndex] * πEπzc
        sum += Ui[weightIndex] * πEπzi
        
        return sum
    }
    
    func getπEπzs()
    {
        //  πEπh contains πE/πh for the current time step plus all future time steps.
        
        //  h = ho * squashedCellState   -->
        //    πE/πzo = πE/πh β πh/πho β πho/πzo = πE/πh β squashedCellState β (ho - hoΒ²)
        //    πE/πcellState = πE/πh β πh/πsquashedCellState β πsquashedCellState/πcellState
        //              = πE/πh β ho β act'(cellState) + πE_future/πcellState (from previous backpropogation step)
        πEπzo = πEπh * getSquashedCellState() * (ho - ho * ho)
        πEπcellState = πEπh * ho * getActPrime(getSquashedCellState()) + πEπcellState
        
        //  cellState = prevCellState * hf + hc * hi   -->
        //    πE/πzf = πEπcellState β πcellState/πhf β πhf/πzf = πEπcellState β prevCellState β (hf - hfΒ²)
        //    πE/πzc = πEπcellState β πcellState/πhc β πhc/πzc = πEπcellState β hi β act'(zc)
        //    πE/πzi = πEπcellState β πcellState/πhi β πhi/πzi = πEπcellState β hc β (hi - hiΒ²)
        πEπzf = πEπcellState * getPreviousCellState() * (hf - hf * hf)
        πEπzc = πEπcellState * hi * getActPrime(hc)
        πEπzi = πEπcellState * hc * (hi - hi * hi)

    }
    
    func getActPrime(_ h: Double) -> Double
    {
        //  derivitive of the non-linearity: tanh' -> 1 - result^2, sigmoid -> result - result^2, rectlinear -> 0 if result<0 else 1
        var actPrime = 0.0
        switch (activation) {
        case .none:
            break
        case .hyperbolicTangent:
            actPrime = (1 - h * h)
            break
        case .sigmoidWithCrossEntropy:
            fallthrough
        case .sigmoid:
            actPrime = (h - h * h)
            break
        case .rectifiedLinear:
            actPrime = h <= 0.0 ? 0.0 : 1.0
            break
        case .softSign:
            //  Reconstitute z from h
            var z : Double
            if (h < 0) {        //  Negative z
                z = h / (1.0 + h)
                actPrime = -1.0 / ((1.0 + z) * (1.0 + z))
            }
            else {              //  Positive z
                z = h / (1.0 - h)
                actPrime = 1.0 / ((1.0 + z) * (1.0 + z))
            }
            break
        case .softMax:
            //  Should not get here - SoftMax is only valid on output layer
            break
        }
        
        return actPrime
    }

    func getPreviousCellState() -> Double
    {
        let prevValue = cellStateHistory.last
        if (prevValue == nil) { return 0.0 }
        return prevValue!
    }

    func clearWeightChanges()
    {
        πEπWi = [Double](repeating: 0.0, count: numInputs)
        πEπUi = [Double](repeating: 0.0, count: numFeedback)
        πEπWf = [Double](repeating: 0.0, count: numInputs)
        πEπUf = [Double](repeating: 0.0, count: numFeedback)
        πEπWc = [Double](repeating: 0.0, count: numInputs)
        πEπUc = [Double](repeating: 0.0, count: numFeedback)
        πEπWo = [Double](repeating: 0.0, count: numInputs)
        πEπUo = [Double](repeating: 0.0, count: numFeedback)
    }
    
    func appendWeightChanges(_ x: [Double], hPrev: [Double]) -> Double
    {
        //  Update each weight accumulation
        
        //  With πE/πzo, we can get πE/πWo.  zo = Woβx + Uoβh(t-1)).  πzo/πWo = x --> πE/πWo = πE/πzo β πzo/πWo = πE/πzo β x
        vDSP_vsmaD(x, 1, &πEπzo, πEπWo, 1, &πEπWo, 1, vDSP_Length(numInputs))
        //  πE/πUo.  zo = Woβx + Uoβh(t-1).  πzo/πUo = h(t-1) --> πE/πUo = πE/πzo β πzo/πUo = πE/πzo β h(t-1)
        vDSP_vsmaD(hPrev, 1, &πEπzo, πEπUo, 1, &πEπUo, 1, vDSP_Length(numFeedback))

        //  With πE/πzi, we can get πE/πWi.  zi = Wiβx + Uiβh(t-1).  πzi/πWi = x --> πE/πWi = πE/πzi β πzi/πWi = πE/πzi β x
        vDSP_vsmaD(x, 1, &πEπzi, πEπWi, 1, &πEπWi, 1, vDSP_Length(numInputs))
        //  πE/πUi.  i = Wiβx + Uiβh(t-1).  πzi/πUi = h(t-1) --> πE/πUi = πE/πzi β πzi/πUi = πE/πzi β h(t-1)
        vDSP_vsmaD(hPrev, 1, &πEπzi, πEπUi, 1, &πEπUi, 1, vDSP_Length(numFeedback))
        
        //  With πE/πzf, we can get πE/πWf.  zf = Wfβx + Ufβh(t-1).  πzf/πWf = x --> πE/πWf = πE/πzf β πzf/πWf = πE/πzf β x
        vDSP_vsmaD(x, 1, &πEπzf, πEπWf, 1, &πEπWf, 1, vDSP_Length(numInputs))
        //  πE/πUf.  f = Wfβx + Ufβh(t-1).  πzf/πUf = h(t-1) --> πE/πUf = πE/πzf β πzf/πUf = πE/πzf β h(t-1)
        vDSP_vsmaD(hPrev, 1, &πEπzf, πEπUf, 1, &πEπUf, 1, vDSP_Length(numFeedback))
        
        //  With πE/πzc, we can get πE/πWc.  za = Wcβx + Ucβh(t-1).  πza/πWa = x --> πE/πWc = πE/πzc β πzc/πWc = πE/πzc β x
        vDSP_vsmaD(x, 1, &πEπzc, πEπWc, 1, &πEπWc, 1, vDSP_Length(numInputs))
        //  πE/πUa.  f = Wcβx + Ucβh(t-1).  πzc/πUc = h(t-1) --> πE/πUc = πE/πzc β πzc/πUc = πE/πzc β h(t-1)
        vDSP_vsmaD(hPrev, 1, &πEπzc, πEπUc, 1, &πEπUc, 1, vDSP_Length(numFeedback))
        
        return h
    }
    
    func updateWeightsFromAccumulations(_ averageTrainingRate: Double)
    {
        //  Update the weights from the accumulations
        switch weightUpdateMethod {
        case .normal:
            //  weights -= accumulation * averageTrainingRate
            var Ξ· = -averageTrainingRate
            vDSP_vsmaD(πEπWi, 1, &Ξ·, Wi, 1, &Wi, 1, vDSP_Length(numInputs))
            vDSP_vsmaD(πEπUi, 1, &Ξ·, Ui, 1, &Ui, 1, vDSP_Length(numFeedback))
            vDSP_vsmaD(πEπWf, 1, &Ξ·, Wf, 1, &Wf, 1, vDSP_Length(numInputs))
            vDSP_vsmaD(πEπUf, 1, &Ξ·, Uf, 1, &Uf, 1, vDSP_Length(numFeedback))
            vDSP_vsmaD(πEπWc, 1, &Ξ·, Wc, 1, &Wc, 1, vDSP_Length(numInputs))
            vDSP_vsmaD(πEπUc, 1, &Ξ·, Uc, 1, &Uc, 1, vDSP_Length(numFeedback))
            vDSP_vsmaD(πEπWo, 1, &Ξ·, Wo, 1, &Wo, 1, vDSP_Length(numInputs))
            vDSP_vsmaD(πEπUo, 1, &Ξ·, Uo, 1, &Uo, 1, vDSP_Length(numFeedback))
        case .rmsProp:
            //  Update the rmsProp cache for Wi --> rmsprop_cache = decay_rate * rmsprop_cache + (1 - decay_rate) * gradientΒ²
            var gradSquared = [Double](repeating: 0.0, count: numInputs)
            vDSP_vsqD(πEπWi, 1, &gradSquared, 1, vDSP_Length(numInputs))  //  Get the gradient squared
            var decay = 1.0 - weightUpdateParameter!
            vDSP_vsmulD(gradSquared, 1, &decay, &gradSquared, 1, vDSP_Length(numInputs))   //  (1 - decay_rate) * gradientΒ²
            decay = weightUpdateParameter!
            vDSP_vsmaD(WiWeightUpdateData, 1, &decay, gradSquared, 1, &WiWeightUpdateData, 1, vDSP_Length(numInputs))
            //  Update the weights --> weight += learning_rate * gradient / (sqrt(rmsprop_cache) + 1e-5)
            for i in 0..<numInputs { gradSquared[i] = sqrt(WiWeightUpdateData[i]) }      //  Re-use gradSquared for efficiency
            var small = 1.0e-05     //  Small offset to make sure we are not dividing by zero
            vDSP_vsaddD(gradSquared, 1, &small, &gradSquared, 1, vDSP_Length(numInputs))       //  (sqrt(rmsprop_cache) + 1e-5)
            var Ξ· = -averageTrainingRate     //  Needed for unsafe pointer conversion - negate for multiply-and-add vector operation
            vDSP_svdivD(&Ξ·, gradSquared, 1, &gradSquared, 1, vDSP_Length(numInputs))
            vDSP_vmaD(πEπWi, 1, gradSquared, 1, Wi, 1, &Wi, 1, vDSP_Length(numInputs))
            
            //  Update the rmsProp cache for Ui --> rmsprop_cache = decay_rate * rmsprop_cache + (1 - decay_rate) * gradientΒ²
            gradSquared = [Double](repeating: 0.0, count: numFeedback)
            vDSP_vsqD(πEπUi, 1, &gradSquared, 1, vDSP_Length(numFeedback))  //  Get the gradient squared
            decay = 1.0 - weightUpdateParameter!
            vDSP_vsmulD(gradSquared, 1, &decay, &gradSquared, 1, vDSP_Length(numFeedback))   //  (1 - decay_rate) * gradientΒ²
            decay = weightUpdateParameter!
            vDSP_vsmaD(UiWeightUpdateData, 1, &decay, gradSquared, 1, &UiWeightUpdateData, 1, vDSP_Length(numFeedback))
            //  Update the weights --> weight += learning_rate * gradient / (sqrt(rmsprop_cache) + 1e-5)
            for i in 0..<numFeedback { gradSquared[i] = sqrt(UiWeightUpdateData[i]) }      //  Re-use gradSquared for efficiency
            small = 1.0e-05     //  Small offset to make sure we are not dividing by zero
            vDSP_vsaddD(gradSquared, 1, &small, &gradSquared, 1, vDSP_Length(numFeedback))       //  (sqrt(rmsprop_cache) + 1e-5)
            Ξ· = -averageTrainingRate     //  Needed for unsafe pointer conversion - negate for multiply-and-add vector operation
            vDSP_svdivD(&Ξ·, gradSquared, 1, &gradSquared, 1, vDSP_Length(numFeedback))
            vDSP_vmaD(πEπUi, 1, gradSquared, 1, Ui, 1, &Ui, 1, vDSP_Length(numFeedback))
            
            //  Update the rmsProp cache for Wf --> rmsprop_cache = decay_rate * rmsprop_cache + (1 - decay_rate) * gradientΒ²
            gradSquared = [Double](repeating: 0.0, count: numInputs)
            vDSP_vsqD(πEπWf, 1, &gradSquared, 1, vDSP_Length(numInputs))  //  Get the gradient squared
            decay = 1.0 - weightUpdateParameter!
            vDSP_vsmulD(gradSquared, 1, &decay, &gradSquared, 1, vDSP_Length(numInputs))   //  (1 - decay_rate) * gradientΒ²
            decay = weightUpdateParameter!
            vDSP_vsmaD(WfWeightUpdateData, 1, &decay, gradSquared, 1, &WfWeightUpdateData, 1, vDSP_Length(numInputs))
            //  Update the weights --> weight += learning_rate * gradient / (sqrt(rmsprop_cache) + 1e-5)
            for i in 0..<numInputs { gradSquared[i] = sqrt(WfWeightUpdateData[i]) }      //  Re-use gradSquared for efficiency
            small = 1.0e-05     //  Small offset to make sure we are not dividing by zero
            vDSP_vsaddD(gradSquared, 1, &small, &gradSquared, 1, vDSP_Length(numInputs))       //  (sqrt(rmsprop_cache) + 1e-5)
            Ξ· = -averageTrainingRate     //  Needed for unsafe pointer conversion - negate for multiply-and-add vector operation
            vDSP_svdivD(&Ξ·, gradSquared, 1, &gradSquared, 1, vDSP_Length(numInputs))
            vDSP_vmaD(πEπWf, 1, gradSquared, 1, Wf, 1, &Wf, 1, vDSP_Length(numInputs))
            
            //  Update the rmsProp cache for Uf --> rmsprop_cache = decay_rate * rmsprop_cache + (1 - decay_rate) * gradientΒ²
            gradSquared = [Double](repeating: 0.0, count: numFeedback)
            vDSP_vsqD(πEπUf, 1, &gradSquared, 1, vDSP_Length(numFeedback))  //  Get the gradient squared
            decay = 1.0 - weightUpdateParameter!
            vDSP_vsmulD(gradSquared, 1, &decay, &gradSquared, 1, vDSP_Length(numFeedback))   //  (1 - decay_rate) * gradientΒ²
            decay = weightUpdateParameter!
            vDSP_vsmaD(UfWeightUpdateData, 1, &decay, gradSquared, 1, &UfWeightUpdateData, 1, vDSP_Length(numFeedback))
            //  Update the weights --> weight += learning_rate * gradient / (sqrt(rmsprop_cache) + 1e-5)
            for i in 0..<numFeedback { gradSquared[i] = sqrt(UfWeightUpdateData[i]) }      //  Re-use gradSquared for efficiency
            small = 1.0e-05     //  Small offset to make sure we are not dividing by zero
            vDSP_vsaddD(gradSquared, 1, &small, &gradSquared, 1, vDSP_Length(numFeedback))       //  (sqrt(rmsprop_cache) + 1e-5)
            Ξ· = -averageTrainingRate     //  Needed for unsafe pointer conversion - negate for multiply-and-add vector operation
            vDSP_svdivD(&Ξ·, gradSquared, 1, &gradSquared, 1, vDSP_Length(numFeedback))
            vDSP_vmaD(πEπUf, 1, gradSquared, 1, Uf, 1, &Uf, 1, vDSP_Length(numFeedback))
            
            //  Update the rmsProp cache for Wc --> rmsprop_cache = decay_rate * rmsprop_cache + (1 - decay_rate) * gradientΒ²
            gradSquared = [Double](repeating: 0.0, count: numInputs)
            vDSP_vsqD(πEπWc, 1, &gradSquared, 1, vDSP_Length(numInputs))  //  Get the gradient squared
            decay = 1.0 - weightUpdateParameter!
            vDSP_vsmulD(gradSquared, 1, &decay, &gradSquared, 1, vDSP_Length(numInputs))   //  (1 - decay_rate) * gradientΒ²
            decay = weightUpdateParameter!
            vDSP_vsmaD(WcWeightUpdateData, 1, &decay, gradSquared, 1, &WcWeightUpdateData, 1, vDSP_Length(numInputs))
            //  Update the weights --> weight += learning_rate * gradient / (sqrt(rmsprop_cache) + 1e-5)
            for i in 0..<numInputs { gradSquared[i] = sqrt(WcWeightUpdateData[i]) }      //  Re-use gradSquared for efficiency
            small = 1.0e-05     //  Small offset to make sure we are not dividing by zero
            vDSP_vsaddD(gradSquared, 1, &small, &gradSquared, 1, vDSP_Length(numInputs))       //  (sqrt(rmsprop_cache) + 1e-5)
            Ξ· = -averageTrainingRate     //  Needed for unsafe pointer conversion - negate for multiply-and-add vector operation
            vDSP_svdivD(&Ξ·, gradSquared, 1, &gradSquared, 1, vDSP_Length(numInputs))
            vDSP_vmaD(πEπWc, 1, gradSquared, 1, Wc, 1, &Wc, 1, vDSP_Length(numInputs))
            
            //  Update the rmsProp cache for Uc --> rmsprop_cache = decay_rate * rmsprop_cache + (1 - decay_rate) * gradientΒ²
            gradSquared = [Double](repeating: 0.0, count: numFeedback)
            vDSP_vsqD(πEπUc, 1, &gradSquared, 1, vDSP_Length(numFeedback))  //  Get the gradient squared
            decay = 1.0 - weightUpdateParameter!
            vDSP_vsmulD(gradSquared, 1, &decay, &gradSquared, 1, vDSP_Length(numFeedback))   //  (1 - decay_rate) * gradientΒ²
            decay = weightUpdateParameter!
            vDSP_vsmaD(UcWeightUpdateData, 1, &decay, gradSquared, 1, &UcWeightUpdateData, 1, vDSP_Length(numFeedback))
            //  Update the weights --> weight += learning_rate * gradient / (sqrt(rmsprop_cache) + 1e-5)
            for i in 0..<numFeedback { gradSquared[i] = sqrt(UcWeightUpdateData[i]) }      //  Re-use gradSquared for efficiency
            small = 1.0e-05     //  Small offset to make sure we are not dividing by zero
            vDSP_vsaddD(gradSquared, 1, &small, &gradSquared, 1, vDSP_Length(numFeedback))       //  (sqrt(rmsprop_cache) + 1e-5)
            Ξ· = -averageTrainingRate     //  Needed for unsafe pointer conversion - negate for multiply-and-add vector operation
            vDSP_svdivD(&Ξ·, gradSquared, 1, &gradSquared, 1, vDSP_Length(numFeedback))
            vDSP_vmaD(πEπUc, 1, gradSquared, 1, Uc, 1, &Uc, 1, vDSP_Length(numFeedback))
            
            //  Update the rmsProp cache for Wo --> rmsprop_cache = decay_rate * rmsprop_cache + (1 - decay_rate) * gradientΒ²
            gradSquared = [Double](repeating: 0.0, count: numInputs)
            vDSP_vsqD(πEπWo, 1, &gradSquared, 1, vDSP_Length(numInputs))  //  Get the gradient squared
            decay = 1.0 - weightUpdateParameter!
            vDSP_vsmulD(gradSquared, 1, &decay, &gradSquared, 1, vDSP_Length(numInputs))   //  (1 - decay_rate) * gradientΒ²
            decay = weightUpdateParameter!
            vDSP_vsmaD(WoWeightUpdateData, 1, &decay, gradSquared, 1, &WoWeightUpdateData, 1, vDSP_Length(numInputs))
            //  Update the weights --> weight += learning_rate * gradient / (sqrt(rmsprop_cache) + 1e-5)
            for i in 0..<numInputs { gradSquared[i] = sqrt(WoWeightUpdateData[i]) }      //  Re-use gradSquared for efficiency
            small = 1.0e-05     //  Small offset to make sure we are not dividing by zero
            vDSP_vsaddD(gradSquared, 1, &small, &gradSquared, 1, vDSP_Length(numInputs))       //  (sqrt(rmsprop_cache) + 1e-5)
            Ξ· = -averageTrainingRate     //  Needed for unsafe pointer conversion - negate for multiply-and-add vector operation
            vDSP_svdivD(&Ξ·, gradSquared, 1, &gradSquared, 1, vDSP_Length(numInputs))
            vDSP_vmaD(πEπWo, 1, gradSquared, 1, Wo, 1, &Wo, 1, vDSP_Length(numInputs))
            
            //  Update the rmsProp cache for Uo --> rmsprop_cache = decay_rate * rmsprop_cache + (1 - decay_rate) * gradientΒ²
            gradSquared = [Double](repeating: 0.0, count: numFeedback)
            vDSP_vsqD(πEπUo, 1, &gradSquared, 1, vDSP_Length(numFeedback))  //  Get the gradient squared
            decay = 1.0 - weightUpdateParameter!
            vDSP_vsmulD(gradSquared, 1, &decay, &gradSquared, 1, vDSP_Length(numFeedback))   //  (1 - decay_rate) * gradientΒ²
            decay = weightUpdateParameter!
            vDSP_vsmaD(UoWeightUpdateData, 1, &decay, gradSquared, 1, &UoWeightUpdateData, 1, vDSP_Length(numFeedback))
            //  Update the weights --> weight += learning_rate * gradient / (sqrt(rmsprop_cache) + 1e-5)
            for i in 0..<numFeedback { gradSquared[i] = sqrt(UoWeightUpdateData[i]) }      //  Re-use gradSquared for efficiency
            small = 1.0e-05     //  Small offset to make sure we are not dividing by zero
            vDSP_vsaddD(gradSquared, 1, &small, &gradSquared, 1, vDSP_Length(numFeedback))       //  (sqrt(rmsprop_cache) + 1e-5)
            Ξ· = -averageTrainingRate     //  Needed for unsafe pointer conversion - negate for multiply-and-add vector operation
            vDSP_svdivD(&Ξ·, gradSquared, 1, &gradSquared, 1, vDSP_Length(numFeedback))
            vDSP_vmaD(πEπUo, 1, gradSquared, 1, Uo, 1, &Uo, 1, vDSP_Length(numFeedback))
        }
    }
    
    func decayWeights(_ decayFactor : Double)
    {
        var Ξ» = decayFactor     //  Needed for unsafe pointer conversion
        vDSP_vsmulD(Wi, 1, &Ξ», &Wi, 1, vDSP_Length(numInputs-1))
        vDSP_vsmulD(Ui, 1, &Ξ», &Ui, 1, vDSP_Length(numFeedback))
        vDSP_vsmulD(Wf, 1, &Ξ», &Wf, 1, vDSP_Length(numInputs-1))
        vDSP_vsmulD(Uf, 1, &Ξ», &Uf, 1, vDSP_Length(numFeedback))
        vDSP_vsmulD(Wc, 1, &Ξ», &Wc, 1, vDSP_Length(numInputs-1))
        vDSP_vsmulD(Uc, 1, &Ξ», &Uc, 1, vDSP_Length(numFeedback))
        vDSP_vsmulD(Wo, 1, &Ξ», &Wo, 1, vDSP_Length(numInputs-1))
        vDSP_vsmulD(Uo, 1, &Ξ», &Uo, 1, vDSP_Length(numFeedback))
    }
    
    func resetSequence()
    {
        h = 0.0
        lastCellState = 0.0
        ho = 0.0
        hc = 0.0
        hi = 0.0
        hf = 0.0
        πEπzo = 0.0
        πEπzi = 0.0
        πEπzf = 0.0
        πEπzc = 0.0
        πEπcellState = 0.0
        outputHistory = [0.0]       //  first 'previous' value is zero
        cellStateHistory = [0.0]       //  first 'previous' value is zero
        outputGateHistory = [0.0]       //  first 'previous' value is zero
        memoryCellHistory = [0.0]       //  first 'previous' value is zero
        inputGateHistory = [0.0]       //  first 'previous' value is zero
        forgetGateHistory = [0.0]       //  first 'previous' value is zero
    }
    
    func storeRecurrentValues()
    {
        outputHistory.append(h)
        cellStateHistory.append(lastCellState)
        outputGateHistory.append(ho)
        memoryCellHistory.append(hc)
        inputGateHistory.append(hi)
        forgetGateHistory.append(hf)
    }
    
    func getLastRecurrentValue()
    {
        h = outputHistory.removeLast()
        lastCellState = cellStateHistory.removeLast()
        ho = outputGateHistory.removeLast()
        hc = memoryCellHistory.removeLast()
        hi = inputGateHistory.removeLast()
        hf = forgetGateHistory.removeLast()
    }
    
    func getPreviousOutputValue() -> Double
    {
        let prevValue = outputHistory.last
        if (prevValue == nil) { return 0.0 }
        return prevValue!
    }
}

final class LSTMNeuralLayer: NeuralLayer {
    //  Nodes
    var nodes : [LSTMNeuralNode]
    var dataSet : DataSet?              //  Sequence data set (inputs and outputs)
    
    ///  Create the neural network layer based on a tuple (number of nodes, activation function)
    init(numInputs : Int, layerDefinition: (layerType: NeuronLayerType, numNodes: Int, activation: NeuralActivationFunction, auxiliaryData: AnyObject?))
    {
        nodes = []
        for _ in 0..<layerDefinition.numNodes {
            nodes.append(LSTMNeuralNode(numInputs: numInputs, numFeedbacks: layerDefinition.numNodes, activationFunction: layerDefinition.activation))
        }
    }
    
    //  Initialize the weights
    func initWeights(_ startWeights: [Double]!)
    {
        if let startWeights = startWeights {
            if (startWeights.count >= nodes.count * nodes[0].numWeights) {
                //  If there are enough weights for all nodes, split the weights and initialize
                var startIndex = 0
                for node in nodes {
                    let subArray = Array(startWeights[startIndex...(startIndex+node.numWeights-1)])
                    node.initWeights(subArray)
                    startIndex += node.numWeights
                }
            }
            else {
                //  If there are not enough weights for all nodes, initialize each node with the set given
                for node in nodes {
                    node.initWeights(startWeights)
                }
            }
        }
        else {
            //  No specified weights - just initialize normally
            for node in nodes {
                node.initWeights(nil)
            }
        }
    }
    
    func getWeights() -> [Double]
    {
        var weights: [Double] = []
        for node in nodes {
            weights += node.Wi
            weights += node.Ui
            weights += node.Wf
            weights += node.Uf
            weights += node.Wc
            weights += node.Uc
            weights += node.Wo
            weights += node.Uo
        }
        return weights
    }
    
    func setNeuralWeightUpdateMethod(_ method: NeuralWeightUpdateMethod, _ parameter: Double?)
    {
        for node in nodes {
            node.setNeuralWeightUpdateMethod(method, parameter)
        }
    }
    
    func getLastOutput() -> [Double]
    {
        var h: [Double] = []
        for node in nodes {
            h.append(node.h)
        }
        return h
    }
   
    func getNodeCount() -> Int
    {
        return nodes.count
    }
    
    func getWeightsPerNode()-> Int
    {
        return nodes[0].numWeights
    }
    
    func getActivation()-> NeuralActivationFunction
    {
        return nodes[0].activation
    }
    
    func feedForward(_ x: [Double]) -> [Double]
    {
        //  Gather the previous outputs for the feedback
        var hPrev : [Double] = []
        for node in nodes {
            hPrev.append(node.getPreviousOutputValue())
        }
        
        var outputs : [Double] = []
        //  Assume input array already has bias constant 1.0 appended
        //  Fully-connected nodes means all nodes get the same input array
        if (nodes[0].activation == .softMax) {
            var sum = 0.0
            for node in nodes {     //  Sum each output
                sum += node.feedForward(x, hPrev: hPrev)
            }
            let scale = 1.0 / sum       //  Do division once for efficiency
            for node in nodes {     //  Get the outputs scaled by the sum to give the probability distribuition for the output
                node.h *= scale
                outputs.append(node.h)
            }
        }
        else {
            for node in nodes {
                outputs.append(node.feedForward(x, hPrev: hPrev))
            }
        }
        
        return outputs
    }
    
    func getFinalLayerπEπzs(_ πEπh: [Double])
    {
        for nNodeIndex in 0..<nodes.count {
            //  Start with the portion from the squared error term
            nodes[nNodeIndex].getFinalNodeπEπzs(πEπh[nNodeIndex])
        }
    }
    
    func getLayerπEπzs(_ nextLayer: NeuralLayer)
    {
        //  Get πE/πh
        for nNodeIndex in 0..<nodes.count {
            //  Reset the πE/πh total
            nodes[nNodeIndex].resetπEπhs()
            
            //  Add each portion from the nodes in the next forward layer
            nodes[nNodeIndex].addToπEπhs(nextLayer.getπEπhForNodeInPreviousLayer(nNodeIndex))
            
            //  Add each portion from the nodes in this layer, using the feedback weights.  This adds πEfuture/πh
            for node in nodes {
                nodes[nNodeIndex].addToπEπhs(node.getFeedbackWeightTimesπEπzs(nNodeIndex))
            }
        }
        
        //  Calculate πE/πzs for this time step from πE/πh
        for node in nodes {
            node.getπEπzs()
        }
    }
    
    func getπEπhForNodeInPreviousLayer(_ inputIndex: Int) ->Double
    {
        var sum = 0.0
        for node in nodes {
            sum += node.getWeightTimesπEπzs(inputIndex)
        }
        return sum
    }
    
    func clearWeightChanges()
    {
        for node in nodes {
            node.clearWeightChanges()
        }
    }
    
    func appendWeightChanges(_ x: [Double]) -> [Double]
    {
        //  Gather the previous outputs for the feedback
        var hPrev : [Double] = []
        for node in nodes {
            hPrev.append(node.getPreviousOutputValue())
        }
        
        var outputs : [Double] = []
        //  Assume input array already has bias constant 1.0 appended
        //  Fully-connected nodes means all nodes get the same input array
        for node in nodes {
            outputs.append(node.appendWeightChanges(x, hPrev: hPrev))
        }
        
        return outputs
    }
    
    func updateWeightsFromAccumulations(_ averageTrainingRate: Double, weightDecay: Double)
    {
        //  Have each node update it's weights from the accumulations
        for node in nodes {
            if (weightDecay < 1) { node.decayWeights(weightDecay) }
            node.updateWeightsFromAccumulations(averageTrainingRate)
        }
    }
    
    func decayWeights(_ decayFactor : Double)
    {
        for node in nodes {
            node.decayWeights(decayFactor)
        }
    }
    
    func getSingleNodeClassifyValue() -> Double
    {
        let activation = nodes[0].activation
        if (activation == .hyperbolicTangent || activation == .rectifiedLinear) { return 0.0 }
        return 0.5
    }
    
    func resetSequence()
    {
        for node in nodes {
            node.resetSequence()
        }
    }
    
    func storeRecurrentValues()
    {
        for node in nodes {
            node.storeRecurrentValues()
        }
    }
    
    func retrieveRecurrentValues(_ sequenceIndex: Int)
    {
        //  Set the last recurrent value in the history array to the last output
        for node in nodes {
            node.getLastRecurrentValue()
        }
    }
    
    func gradientCheck(x: [Double], Ξ΅: Double, Ξ: Double, network: NeuralNetwork)  -> Bool
    {
        //!!
        return true
    }
}
