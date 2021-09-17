//
//  Render.swift
//  ProcessingATextureInAComputeFunction
//
//  Created by Huiping Guo on 2021/09/16.
//

import Foundation
import MetalKit

class Renderer: NSObject {
  
  // The device object (aka GPU) used to process images.
  private var device: MTLDevice!
  
  private var computePipelineState: MTLComputePipelineState!
  private var renderPipelineState: MTLRenderPipelineState!
  
  // Texture object that serves as the source for image processing.
  private var inputTexture: MTLTexture!
  
  // Texture object that serves as the output for image processing.
  private var outputTexture: MTLTexture!
  
  // The current size of the viewport, used in the render pipeline.
  private var viewportSize: vector_uint2 =  vector_uint2(x: 0, y: 0)
  
  private var commandQueue: MTLCommandQueue!
  
  // Compute kernel dispatch parameters
  private var threadgroupSize: MTLSize!
  private var threadgroupCount: MTLSize!
  
  init(mtkView: MTKView) {
    
    device = mtkView.device
    
    mtkView.colorPixelFormat = .bgra8Unorm_srgb
        
    // Load all the shader files with a .metal file extension in the project.
    let defaultLibrary = device.makeDefaultLibrary()!
    
    // Load the image processing function from the library and create a pipeline from it.
    let kernelFunction = defaultLibrary.makeFunction(name: "grayscaleKernel")!
    do {
      self.computePipelineState = try device.makeComputePipelineState(function: kernelFunction)
    } catch {
      // Compute pipeline state creation could fail if kernelFunction failed to load from
      // the library. If the Metal API validation is enabled, you automatically get more
      // information about what went wrong. (Metal API validation is enabled by default
      // when you run a debug build from Xcode.)
      assert(false, "Failed to create compute pipeline state:: \(error)")
    }
    
    
    // Load the vertex and fragment functions, and use them to configure a render
    // pipeline.
    let vertexFunction = defaultLibrary.makeFunction(name: "vertexShader")
    let fragmentFunction = defaultLibrary.makeFunction(name: "samplingShader")
    
    let pipelineStateDescriptor = MTLRenderPipelineDescriptor.init()
    pipelineStateDescriptor.label = "Simple Render Pipeline"
    pipelineStateDescriptor.vertexFunction = vertexFunction
    pipelineStateDescriptor.fragmentFunction = fragmentFunction
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
    
    do {
      self.renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
    } catch {
      assert(false, "Failed to create render pipeline state: \(error)")
    }
  

    guard let imageFileLocation = Bundle.main.url(forResource: "Image", withExtension: "tga") else {
      return
    }
    guard let image = AAPLImage(tgaFileAtLocation: imageFileLocation) else {
      return
    }
    
    let textureDescriptor = MTLTextureDescriptor.init()
    textureDescriptor.textureType = .type2D
    // Indicate that each pixel has a Blue, Green, Red, and Alpha channel,
    //   each in an 8-bit unnormalized value (0 maps to 0.0, while 255 maps to 1.0)
    textureDescriptor.pixelFormat = .rgba8Unorm
    textureDescriptor.width = Int(image.width)
    textureDescriptor.height = Int(image.height)

    // The image kernel only needs to read the incoming image data.
    textureDescriptor.usage = [.shaderRead]
    let inputTexture = device.makeTexture(descriptor: textureDescriptor)

    // The output texture needs to be written by the image kernel and sampled
    // by the rendering code.
    textureDescriptor.usage = [.shaderWrite, .shaderRead]
    self.outputTexture = device.makeTexture(descriptor: textureDescriptor)

    let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: textureDescriptor.width, height: textureDescriptor.height, depth: 1))

    // Calculate the size of each texel times the width of the textures.
    let bytesPerRow: Int = 4 * textureDescriptor.width

    // Copy the bytes from the data object into the texture.
    let bytes = (image.data as NSData).bytes
    inputTexture?.replace(region: region, mipmapLevel: 0, withBytes: bytes, bytesPerRow: bytesPerRow)

    assert(inputTexture != nil, "Failed to create inpute texture")
    self.inputTexture = inputTexture

    // Set the compute kernel's threadgroup size to 16 x 16.
    self.threadgroupSize = MTLSizeMake(16, 16, 1)

    // Calculate the number of rows and columns of threadgroups given the size of the
    // input image. Ensure that the grid covers the entire image (or more).
    self.threadgroupCount = MTLSizeMake(0, 0, 0)
    threadgroupCount.width  = (inputTexture!.width  + threadgroupSize.width -  1) / threadgroupSize.width
    threadgroupCount.height = (inputTexture!.height + threadgroupSize.height - 1) / threadgroupSize.height
    // The image data is 2D, so set depth to 1.
    threadgroupCount.depth = 1;

    // Create the command queue.
    commandQueue = device.makeCommandQueue()
  }
}



extension Renderer: MTKViewDelegate {
  /// The system calls this method whenever the view changes orientation or size.
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    // Save the size of the drawable to pass to the render pipeline.
    viewportSize.x = UInt32(size.width)
    viewportSize.y = UInt32(size.height)
  }
  
  
  /// The system calls this method whenever the view needs to render a frame.
  /// Called whenever the view needs to render a frame
  func draw(in view: MTKView) {
    let quadVertices: [(simd_float2,simd_float2)] = [
        // Pixel positions, Texture coordinates
            (simd_float2( 250,  -250),simd_float2(1.0, 1.0)),
            (simd_float2(-250,  -250),simd_float2(0.0, 1.0)),
            (simd_float2( -250,   250),simd_float2(0.0, 0.0)),
            
            (simd_float2(250,  -250),simd_float2(1.0, 1.0)),
            (simd_float2(-250,   250),simd_float2(0.0, 0.0)),
            (simd_float2( 250,   250),simd_float2(1.0, 0.0)),
          ]
    
    // Create a new command buffer for each frame.
    let commandBuffer = commandQueue.makeCommandBuffer()
       commandBuffer?.label = "MyCommand"
    
    // Process the input image.
    let computeEncoder = commandBuffer?.makeComputeCommandEncoder()

    computeEncoder?.setComputePipelineState(computePipelineState)
    computeEncoder?.setTexture(inputTexture, index: 0)
    computeEncoder?.setTexture(outputTexture, index: 1)

    computeEncoder?.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
    
    computeEncoder?.endEncoding()
    
    // Use the output image to draw to the view's drawable texture.
    if let renderPassDescriptor = view.currentRenderPassDescriptor {
      
      let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
      renderEncoder?.label = "MyRenderEncoder"
      
      // Set the region of the drawable to draw into.
      renderEncoder?.setViewport(MTLViewport(originX: 0, originY: 0, width: Double(viewportSize.x), height: Double(viewportSize.y), znear: -1.0, zfar: 1.0))
      
      renderEncoder?.setRenderPipelineState(renderPipelineState)

      // Encode the vertex data.
      renderEncoder?.setVertexBytes(quadVertices, length: quadVertices.count * MemoryLayout<(simd_float2,simd_float2)>.size, index: 0)

      // Encode the viewport data.
      renderEncoder?.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.size, index: 1)

      // Encode the output texture from the previous stage.
      renderEncoder?.setFragmentTexture(outputTexture, index: 0)
      
      // Draw the quad.
      renderEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
      renderEncoder?.endEncoding()
      
      commandBuffer?.present(view.currentDrawable!)
    }
    commandBuffer?.commit()
  }
}
