//
//  ViewController.swift
//  UsingMetalToDrawAViewContentsents
//
//  Created by Huiping Guo on 2021/08/31.
//

import Cocoa
import MetalKit
 
class ViewController: NSViewController {

  private var metalView: MTKView?
  
  private var render: Render?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    metalView = self.view as? MTKView
    
    metalView?.enableSetNeedsDisplay = true
    metalView?.device = MTLCreateSystemDefaultDevice()
    metalView?.clearColor = MTLClearColorMake(0.0, 0.5, 1.0, 1.0)
    
    render = Render(view: metalView!)
    
    // Initialize the renderer with the view size.
    render?.mtkView(metalView!, drawableSizeWillChange: metalView!.drawableSize)
    
    metalView?.delegate = render
  }

  override var representedObject: Any? {
    didSet {
    // Update the view, if already loaded.
    }
  }


}

