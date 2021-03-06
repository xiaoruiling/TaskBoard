//
//  AutoScrollManager.swift
//  iOS_TaskBoard_test
//
//  Created by darui on 16/8/20.
//  Copyright © 2016年 Worktile. All rights reserved.
//

import UIKit

/// 用来实现ScrollView自动滚动
///
/// 参数: scrollViewRect: ScrollView的范围, touchRect: 手指拖动的范围，
///   根据touchRect超出scrollViewRect的多少决定速度的大小
///
/// @since 1.0.0
/// @author darui
class AutoScrollManager {

  //MARK: - Public
  
  var scrollViewRect: CGRect = CGRect.zero
  var touchRect: CGRect = CGRect(x: 0, y: 0, width: 44, height: 44) {
    didSet {
      if _displayLink == nil {
        _displayLink = CADisplayLink(target: self, selector: #selector(_scrollSpeedDidChanged))
        _displayLink?.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSRunLoopCommonModes)
      }
    }
  }
  
  /// 触控点超出了范围，可以开始滚动了
  var shouldScroll: ((distance: CGFloat, direction: ScrollDirection) -> Void)?
  
  /**
   停止自动滚动
   */
  func stopAutoScroll() {
    _displayLink?.invalidate()
    _displayLink = nil
  }

  //MARK: - Commons
  
  enum ScrollDirection {
    case vertical
    case horizontal
  }
  
  
  //MARK: - Property
  
  private var _displayLink: CADisplayLink?
  private var _speedRate: CGFloat = 0.1
  
  //MARK: - Lifecycle
  
  deinit {
    _displayLink?.invalidate()
    _displayLink = nil
  }
}

extension AutoScrollManager {
  
  //MARK: - Private
  
  @objc
  private func _scrollSpeedDidChanged() {
    let leftInset = scrollViewRect.minX - touchRect.minX
    let rightInset = scrollViewRect.maxX - touchRect.maxX
    
    let topInset = scrollViewRect.minY - touchRect.minY
    let bottomInset = scrollViewRect.maxY - touchRect.maxY
    
    // Horizontal scrolling
    if leftInset > 0 || -rightInset > 0 {
      if leftInset > -rightInset { // scroll to the left
        shouldScroll?(distance: leftInset * _speedRate, direction: .horizontal)
      } else if leftInset < -rightInset { // scroll to the right
        shouldScroll?(distance: rightInset * _speedRate, direction: .horizontal)
      }
    }
    
    // Vertical scrolling
    if topInset > 0 || -bottomInset > 0 {
      if topInset > -bottomInset { // scroll to the top
        shouldScroll?(distance: topInset * _speedRate, direction: .vertical)
      } else if topInset < -bottomInset { // scroll to the bootom
        shouldScroll?(distance: bottomInset * _speedRate, direction: .vertical)
      }
    }
  }
}
