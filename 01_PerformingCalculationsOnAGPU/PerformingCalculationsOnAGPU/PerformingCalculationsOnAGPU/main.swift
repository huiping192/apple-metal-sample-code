//
//  main.swift
//  PerformingCalculationsOnAGPU
//
//  Created by Huiping Guo on 2021/08/07.
//

import Foundation
import MetalKit

let device = MTLCreateSystemDefaultDevice()!
guard let adder = MetalAdder(device: device) else {
  fatalError("adder is il")
}

adder.prepareData()

adder.sendComputeCommand()
