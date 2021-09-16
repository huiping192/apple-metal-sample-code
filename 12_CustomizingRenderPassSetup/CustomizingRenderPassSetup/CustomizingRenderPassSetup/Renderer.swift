//
//  Renderer.swift
//  CustomizingRenderPassSetup
//
//  Created by Huiping Guo on 2021/09/15.
//

import Foundation
import MetalKit

class Renderer: NSObject {
  // Texture to render to and then sample from.
  private var renderTargetTexture: MTLTexture!

  // Render pass descriptor to draw to the texture
  private var renderToTextureRenderPassDescriptor: MTLRenderPassDescriptor!
  
  // A pipeline object to render to the offscreen texture.
  private var renderToTextureRenderPipeline: MTLRenderPipelineState!
  
  // A pipeline object to render to the screen.
  private var drawableRenderPipeline: MTLRenderPipelineState!

  // Ratio of width to height to scale positions in the vertex shader.
  private var aspectRatio: Float!

  private var device: MTLDevice!

  private var commandQueue: MTLCommandQueue!
  
  
  init(mtkView: MTKView) {
    mtkView.clearColor = MTLClearColorMake(1.0, 0.0, 0.0, 1.0)
  
    device = mtkView.device
    
    commandQueue = device.makeCommandQueue()
    
    // Set up a texture for rendering to and sampling from
    let texDesriptor = MTLTextureDescriptor.init()
    texDesriptor.textureType = .type2D
    texDesriptor.width = 512
    texDesriptor.height = 512
    texDesriptor.pixelFormat = .rgba8Unorm
    texDesriptor.usage = [.renderTarget, .shaderRead]
    
    self.renderTargetTexture = device.makeTexture(descriptor: texDesriptor)
    
    
    // Set up a render pass descriptor for the render pass to render into
    // _renderTargetTexture.

    renderToTextureRenderPassDescriptor = MTLRenderPassDescriptor.init()
    renderToTextureRenderPassDescriptor.colorAttachments[0].texture = renderTargetTexture
    
    renderToTextureRenderPassDescriptor.colorAttachments[0].loadAction = .clear
    renderToTextureRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1, 1, 1, 1)
    
    renderToTextureRenderPassDescriptor.colorAttachments[0].storeAction = .store
    
    
    let defaultLibrary = device.makeDefaultLibrary()
    
    let pipelineStateDescriptor = MTLRenderPipelineDescriptor.init()
    pipelineStateDescriptor.label = "Drawable Render Pipeline"
    pipelineStateDescriptor.sampleCount = mtkView.sampleCount
    pipelineStateDescriptor.vertexFunction = defaultLibrary?.makeFunction(name: "textureVertexShader")
    pipelineStateDescriptor.fragmentFunction = defaultLibrary?.makeFunction(name: "textureFragmentShader")
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
    pipelineStateDescriptor.vertexBuffers[0].mutability = .immutable
    
    do {
      self.drawableRenderPipeline = try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
    } catch {
      assert(false, "Failed to create pipeline state to render to screen: \(error)")
    }
        
    // Set up pipeline for rendering to the offscreen texture. Reuse the
    // descriptor and change properties that differ.
    pipelineStateDescriptor.label = "Offscreen Render Pipeline"
    pipelineStateDescriptor.sampleCount = 1
    pipelineStateDescriptor.vertexFunction = defaultLibrary?.makeFunction(name: "simpleVertexShader")
    pipelineStateDescriptor.fragmentFunction = defaultLibrary?.makeFunction(name: "simpleFragmentShader")
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = renderTargetTexture.pixelFormat
    do {
      self.renderToTextureRenderPipeline = try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
    } catch {
      assert(false, "Failed to create pipeline state to render to texture: \(error)")
    }
  }
  
}

extension Renderer: MTKViewDelegate {
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    aspectRatio = Float(size.height / size.width)
  }
  
  func draw(in view: MTKView) {
    let commandBuffer = commandQueue.makeCommandBuffer()
    commandBuffer?.label = "Command Buffer"
    
    let triVertices: [(simd_float2,simd_float4)] = [
      // Positions     ,  Colors
      (simd_float2(0.5, -0.5),simd_float4(1.0, 0.0, 0.0, 1.0)),
      (simd_float2(-0.5,  -0.5),simd_float4(0.0, 1.0, 0.0, 1.0)),
      (simd_float2(0.0,   0.5),simd_float4(0.0, 0.0, 1.0, 0.0)),
    ]
    
    
    let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderToTextureRenderPassDescriptor)
    renderEncoder?.label = "Offscreen Render Pass"
    renderEncoder?.setRenderPipelineState(renderToTextureRenderPipeline)
    
    renderEncoder?.setVertexBytes(triVertices, length: triVertices.count * MemoryLayout<(simd_float2,simd_float4)>.size, index: 0)
    
    renderEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    
    renderEncoder?.endEncoding()
 
    let drawableRenderPassDescriptor = view.currentRenderPassDescriptor
    if let drawableRenderPassDescriptor = drawableRenderPassDescriptor {
      let quadVertices: [(simd_float2,simd_float2)] = [
        // Positions     , Texture coordinates
        (simd_float2(0.5, -0.5),simd_float2(1.0, 1.0)),
        (simd_float2(-0.5,  -0.5),simd_float2(0.0, 1.0)),
        (simd_float2(-0.5,   0.5),simd_float2(0.0, 0.0)),
        
        (simd_float2(0.5,  -0.5),simd_float2(1.0, 1.0)),
        (simd_float2( -0.5,   0.5),simd_float2(0.0, 0.0)),
        (simd_float2( 0.5,   0.5),simd_float2(1.0, 0.0)),
      ]
      
      let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: drawableRenderPassDescriptor)
      renderEncoder?.label = "Drawable Render Pass"
      renderEncoder?.setRenderPipelineState(drawableRenderPipeline)
      
      renderEncoder?.setVertexBytes(quadVertices, length: quadVertices.count * MemoryLayout<(simd_float2,simd_float2)>.size, index: 0)

      renderEncoder?.setVertexBytes(&aspectRatio, length: MemoryLayout<Float>.size, index: 1)

      renderEncoder?.setFragmentTexture(renderTargetTexture, index: 0)
      
      renderEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
      renderEncoder?.endEncoding()
      
      commandBuffer?.present(view.currentDrawable!)
    }
    
    commandBuffer?.commit()
  }
  
  
}
