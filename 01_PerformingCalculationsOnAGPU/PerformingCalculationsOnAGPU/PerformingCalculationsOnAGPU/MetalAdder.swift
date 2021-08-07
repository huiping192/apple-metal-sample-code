import Foundation
import MetalKit


//const unsigned int bufferSize = arrayLength * sizeof(float);

// The number of floats in each array, and the size of the arrays in bytes.
let arrayLength: Int = 1 << 24
let bufferSize: Int = arrayLength * MemoryLayout<Float>.size

public class MetalAdder {
  private let device: MTLDevice
  
  // The compute pipeline generated from the compute kernel in the .metal shader file.
  private let addFunctionPSO: MTLComputePipelineState
  
  // The command queue used to pass commands to the device.
  private let commandQueue: MTLCommandQueue

  // Buffers to hold data.
  private var bufferA: MTLBuffer!
  private var bufferB: MTLBuffer!
  private var bufferResult: MTLBuffer!

  
  public init?(device: MTLDevice) {
    self.device = device
    
    // Load the shader files with a .metal file extension in the project
    let defaultLibrary = device.makeDefaultLibrary()
    if defaultLibrary == nil {
      print("Failed to find the default library.");
      return nil
    }
    
    guard let addFunction = defaultLibrary?.makeFunction(name: "add_arrays") else {
      print("Failed to find the adder function.")
      return nil
    }
    
    // Create a compute pipeline state object.
    do {
      self.addFunctionPSO = try device.makeComputePipelineState(function: addFunction)
    } catch {
      //  If the Metal API validation is enabled, you can find out more information about what
      //  went wrong.  (Metal API validation is enabled by default when a debug build is run
      //  from Xcode)
      print("Failed to created pipeline state object, error \(error).")
      return nil
    }
    
    guard let commandQueue = device.makeCommandQueue() else {
      print("Failed to find the command queue.")
      return nil
    }
    
    self.commandQueue = commandQueue
  }
  
  public func prepareData() {
    self.bufferA = device.makeBuffer(length: bufferSize, options: .storageModeShared)
    self.bufferB = device.makeBuffer(length: bufferSize, options: .storageModeShared)
    self.bufferResult = device.makeBuffer(length: bufferSize, options: .storageModeShared)

    generateRandomFloatData(buffer: bufferA)
    generateRandomFloatData(buffer: bufferB)
  }
  
  public func sendComputeCommand() {
    // Create a command buffer to hold commands.
    let commandBuffer = commandQueue.makeCommandBuffer()
    assert(commandBuffer != nil)
    
    // Start a compute pass.
    let computeEncoder = commandBuffer?.makeComputeCommandEncoder()
    assert(computeEncoder != nil)

    encodeAddCommand(computeEncoder: computeEncoder!)
    
    // End the compute pass.
    computeEncoder?.endEncoding()
    
    // Execute the command.
    commandBuffer?.commit()
    
    // Normally, you want to do other work in your app while the GPU is running,
    // but in this example, the code simply blocks until the calculation is complete.
    commandBuffer?.waitUntilCompleted()
    
    verifyResults()
  }
  
  private func encodeAddCommand(computeEncoder: MTLComputeCommandEncoder) {
    // Encode the pipeline state object and its parameters.
    computeEncoder.setComputePipelineState(addFunctionPSO)
    computeEncoder.setBuffer(bufferA, offset: 0, index: 0)
    computeEncoder.setBuffer(bufferB, offset: 0, index: 1)
    computeEncoder.setBuffer(bufferResult, offset: 0, index: 2)

    let gridSize = MTLSizeMake(arrayLength, 1, 1)
    
    // Calculate a threadgroup size.
    var threadGroupSize = addFunctionPSO.maxTotalThreadsPerThreadgroup
    if threadGroupSize > arrayLength {
      threadGroupSize = arrayLength
    }
    let threadgroupSize = MTLSizeMake(threadGroupSize, 1, 1)
    
    // Encode the compute command.
    computeEncoder .dispatchThreads(gridSize, threadsPerThreadgroup: threadgroupSize)
  }
  
  private func generateRandomFloatData(buffer: MTLBuffer) {
    let point = buffer.contents().bindMemory(to: Float.self, capacity: arrayLength)
    (0..<arrayLength).forEach { i in
      point[i] = Float.random(in: 0..<1)
    }
  }

  
  private func verifyResults() {
    let a = bufferA.contents().bindMemory(to: Float.self, capacity: arrayLength)
    let b = bufferB.contents().bindMemory(to: Float.self, capacity: arrayLength)
    let result = bufferResult.contents().bindMemory(to: Float.self, capacity: arrayLength)

    (0..<arrayLength).forEach { index in
      assert(result[index] == (a[index] + b[index]))
    }
    
    print("Compute results as expected!")
  }
}
