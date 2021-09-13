//
//  Render.swift
//  UsingARenderPipelineToRenderPrimitives
//
//  Created by Huiping Guo on 2021/09/13.
//

import Foundation
import MetalKit



class Renderer: NSObject {
  private var device: MTLDevice!
  
  // The render pipeline generated from the vertex and fragment shaders in the .metal shader file.
  private var pipelineState: MTLRenderPipelineState!
  
  // The command queue used to pass commands to the device.
  private var commandQueue: MTLCommandQueue!
  
  // The current size of the view, used as an input to the vertex shader.
  private var viewportSize: simd_uint2!
  
  let triangleVertices: [(simd_float2,simd_float4)] = [
    // 2D positions,                  RGBA colors
    (simd_float2(250,  -250),simd_float4(1, 0, 0, 1) ),
    (simd_float2(-250,  -250),simd_float4(0, 1, 0, 1) ),
    (simd_float2(0,   250),simd_float4(0, 0, 1, 1) ),
  ]
  
  init?(mtkView: MTKView) {
    self.device = mtkView.device
    
    // Load all the shader files with a .metal file extension in the project.
    let defaultLibrary = device.makeDefaultLibrary()
    
    let vertexFunction = defaultLibrary?.makeFunction(name: "vertexShader")
    let fragmentFunction = defaultLibrary?.makeFunction(name: "fragmentShader")
    
    // Configure a pipeline descriptor that is used to create a pipeline state.
    let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
    pipelineStateDescriptor.label = "Simple Pipeline"
    pipelineStateDescriptor.vertexFunction = vertexFunction
    pipelineStateDescriptor.fragmentFunction = fragmentFunction
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
    
    do {
      self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
    } catch {
      // Pipeline State creation could fail if the pipeline descriptor isn't set up properly.
      //  If the Metal API validation is enabled, you can find out more information about what
      //  went wrong.  (Metal API validation is enabled by default when a debug build is run
      //  from Xcode.)
      print("Failed to create pipeline state: \(error)")
      return nil
    }
    
    // Create the command queue
    self.commandQueue = device.makeCommandQueue()
  }
  
}


extension Renderer: MTKViewDelegate {
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    viewportSize = simd_uint2(x: UInt32(size.width), y: UInt32(size.height))
  }
  
  func draw(in view: MTKView) {
    // Create a new command buffer for each render pass to the current drawable.
    guard let commmandBuffer = commandQueue.makeCommandBuffer() else { return }
    commmandBuffer.label = "MyCommand"
    
    // Obtain a renderPassDescriptor generated from the view's drawable textures.
    guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
    
    // Create a render command encoder.
    guard let renderEncoder = commmandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
    renderEncoder.label = "MyRenderEncoder"
    
    
    // Set the region of the drawable to draw into.
    renderEncoder.setViewport(MTLViewport(originX: 0, originY: 0, width: Double(viewportSize.x), height: Double(viewportSize.y), znear: 0, zfar: 1))
    
    
    renderEncoder.setRenderPipelineState(pipelineState)
    // Pass in the parameter data.
    renderEncoder.setVertexBytes(triangleVertices, length: triangleVertices.count * MemoryLayout<(simd_float2,simd_float4)>.size, index: 0)
    
    renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<simd_uint2>.size, index: 1)
    
    // Draw the triangle.
    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    renderEncoder.endEncoding()
    
    // Schedule a present once the framebuffer is complete using the current drawable.
    commmandBuffer.present(view.currentDrawable!)
    
    // Finalize rendering here & push the command buffer to the GPU.
    commmandBuffer.commit()
  }
  
}
