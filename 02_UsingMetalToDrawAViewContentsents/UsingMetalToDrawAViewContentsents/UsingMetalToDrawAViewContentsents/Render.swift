/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of a platform independent renderer class, which performs Metal setup and per frame rendering
*/

import Foundation
import MetalKit

// Main class performing the rendering
class Render: NSObject {
  private let device: MTLDevice
  private let commandQueue: MTLCommandQueue
    
  init(view: MTKView) {
    device = view.device!
    
    // The command queue used to pass commands to the device.
    commandQueue = device.makeCommandQueue()!
  }
}


extension Render: MTKViewDelegate {
  
  /// Called whenever the view needs to render a frame.
  func draw(in view: MTKView) {
    // The render pass descriptor references the texture into which Metal should draw
    guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
    
    guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
    
    // Create a render pass and immediately end encoding, causing the drawable to be cleared
    guard let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
    
    commandEncoder.endEncoding()
    
    // Get the drawable that will be presented at the end of the frame
    guard let drawable = view.currentDrawable else { return }
    
    // Request that the drawable texture be presented by the windowing system once drawing is done
    commandBuffer.present(drawable)
    
    commandBuffer.commit()
  }
  
  /// Called whenever view changes orientation or is resized
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    
  }

}
