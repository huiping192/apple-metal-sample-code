//
//  Renderer.swift
//  CreatingAndSamplingTextures
//
//  Created by Huiping Guo on 2021/09/18.
//

import Foundation
import MetalKit
import Cocoa

class Renderer: NSObject {
  
  
  // The device (aka GPU) used to render
  private var device: MTLDevice!
  
  // A pipeline object to render to the screen.
  private var drawableRenderPipeline: MTLRenderPipelineState!
  
  // The command Queue used to submit commands.
  private var commandQueue: MTLCommandQueue!
  
  // The Metal texture object
  private var texture: MTLTexture!
  
  // The Metal buffer that holds the vertex data.
  private var vertices: MTLBuffer!
  
  // The number of vertices in the vertex buffer.
  private var numVertices: Int!
  
  // The current size of the view.
  private var viewportSize: vector_uint2 =  vector_uint2(x: 0, y: 0)
  
  
  private func loadTextureUsingAAPLImage(url: URL) -> MTLTexture? {
    guard let image = AAPLImage(tgaFileAtLocation: url) else {
      return nil
    }
        
    let textureDescriptor = MTLTextureDescriptor.init()
    
    // Indicate that each pixel has a blue, green, red, and alpha channel, where each channel is
    // an 8-bit unsigned normalized value (i.e. 0 maps to 0.0 and 255 maps to 1.0)
    textureDescriptor.pixelFormat = .bgra8Unorm
    
    // Set the pixel dimensions of the texture
    textureDescriptor.width = Int(image.width)
    textureDescriptor.height = Int(image.height)
        
    // Create the texture from the device by using the descriptor
    let inputTexture = device.makeTexture(descriptor: textureDescriptor)
        
    // Calculate the number of bytes per row in the image.
    let bytesPerRow: Int = Int(4 * image.width)
    
    let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: textureDescriptor.width, height: textureDescriptor.height, depth: 1))
    
    // Copy the bytes from the data object into the texture
    let bytes = (image.data as NSData).bytes
    inputTexture?.replace(region: region, mipmapLevel: 0, withBytes: bytes, bytesPerRow: bytesPerRow)
    
    return inputTexture
  }
  
  init(mtkView: MTKView) {
    
    super.init()
    
    device = mtkView.device
    
    guard let imageFileLocation = Bundle.main.url(forResource: "Image", withExtension: "tga") else {
      return
    }
    
    texture = self.loadTextureUsingAAPLImage(url: imageFileLocation)
    
    // Set up a simple MTLBuffer with vertices which include texture coordinates
    let quadVertices: [(simd_float2,simd_float2)] = [
           // Pixel positions, Texture coordinates
               (simd_float2( 250,  -250),simd_float2(1.0, 1.0)),
               (simd_float2(-250,  -250),simd_float2(0.0, 1.0)),
               (simd_float2( -250,   250),simd_float2(0.0, 0.0)),
               
               (simd_float2(250,  -250),simd_float2(1.0, 1.0)),
               (simd_float2(-250,   250),simd_float2(0.0, 0.0)),
               (simd_float2( 250,   250),simd_float2(1.0, 0.0)),
             ]
    
    // Create a vertex buffer, and initialize it with the quadVertices array
    self.vertices = device.makeBuffer(bytes: quadVertices, length: quadVertices.count * MemoryLayout<(simd_float2,simd_float2)>.size, options: .storageModeShared)
    
    // Calculate the number of vertices by dividing the byte length by the size of each vertex
    numVertices = quadVertices.count
    
    
    /// Create the render pipeline.
    
    // Load the shaders from the default library
    let defaultLibrary = device.makeDefaultLibrary()
    
    
    // Set up a descriptor for creating a pipeline state object
    let pipelineStateDescriptor = MTLRenderPipelineDescriptor.init()
    pipelineStateDescriptor.label = "Texturing Pipeline"
    pipelineStateDescriptor.vertexFunction = defaultLibrary?.makeFunction(name: "vertexShader")
    pipelineStateDescriptor.fragmentFunction = defaultLibrary?.makeFunction(name: "samplingShader")
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
    
    do {
      self.drawableRenderPipeline = try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
    } catch {
      assert(false, "Failed to create pipeline state to render to screen: \(error)")
    }
    
    commandQueue = device.makeCommandQueue()
  }
  
}

extension Renderer: MTKViewDelegate {
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    // Save the size of the drawable to pass to the vertex shader.
    viewportSize.x = UInt32(size.width)
    viewportSize.y = UInt32(size.height)
  }
  
  func draw(in view: MTKView) {
    let commandBuffer = commandQueue.makeCommandBuffer()
    commandBuffer?.label = "Command Buffer"
    
    let drawableRenderPassDescriptor = view.currentRenderPassDescriptor!
    
    let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: drawableRenderPassDescriptor)
    renderEncoder?.label = "Drawable Render Pass"
    
    // Set the region of the drawable to draw into.
    renderEncoder?.setViewport(MTLViewport(originX: 0, originY: 0, width: Double(viewportSize.x), height: Double(viewportSize.y), znear: -1.0, zfar: 1.0))

    renderEncoder?.setRenderPipelineState(drawableRenderPipeline)
    
    renderEncoder?.setVertexBuffer(vertices, offset: 0, index: 0)
    renderEncoder?.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.size, index: 1)
    
    // Set the texture object.  The AAPLTextureIndexBaseColor enum value corresponds
    ///  to the 'colorMap' argument in the 'samplingShader' function because its
    //   texture attribute qualifier also uses AAPLTextureIndexBaseColor for its index.
    renderEncoder?.setFragmentTexture(texture, index: 0)
    
    // Draw the triangles.
    renderEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: numVertices)
    renderEncoder?.endEncoding()
    
    // Schedule a present once the framebuffer is complete using the current drawable
    commandBuffer?.present(view.currentDrawable!)
    
    // Finalize rendering here & push the command buffer to the GPU
    commandBuffer?.commit()
  }
  
  
}
