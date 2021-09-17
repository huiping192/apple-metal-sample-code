//
//  ViewController.swift
//  CreatingAndSamplingTextures
//
//  Created by Huiping Guo on 2021/09/18.
//

import Cocoa
import MetalKit

class ViewController: NSViewController {
  private var renderer: Renderer!

  override func viewDidLoad() {
    super.viewDidLoad()

    // Do any additional setup after loading the view.
    let mtkView = self.view as! MTKView
    mtkView.device = MTLCreateSystemDefaultDevice()
    
    assert(mtkView.device != nil, "Metal is not supported on this device")
    
    renderer = Renderer(mtkView: mtkView)
    
    assert(renderer != nil , "Renderer failed initialization")
    
    renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)
    
    mtkView.delegate = renderer
  }

  override var representedObject: Any? {
    didSet {
    // Update the view, if already loaded.
    }
  }


}

