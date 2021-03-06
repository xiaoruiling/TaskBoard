//
//  ViewController.swift
//  iOS_TaskBoard_test
//
//  Created by darui on 16/8/10.
//  Copyright © 2016年 Worktile. All rights reserved.
//

import UIKit
import SnapKit
import YYKeyboardManager
import KeyboardMan

struct Task {
  var title: String
  var hidden: Bool = false
}

struct TaskList {
  let name: String
  let listID: String
  let isAddingTask: Bool
  let scrollPosition: CGFloat
  var hidden: Bool = false
  var tasks: [Task]
}

let kTaskTableViewShouldStopAutoScrollNotification: String = "TaskTableViewShouldStopAutoScrollNotification"

/// 任务面板视图
///
/// 参数: 无
///
/// @since 1.0.0
/// @author darui
class TaskBoardViewController: UIViewController {
  
  //MARK: - Public
  
  var lineSpacing: CGFloat = 13
  var margin: CGFloat      = 14
  var top: CGFloat         = 10
  var bootom: CGFloat      = 20
  var canAddList: Bool = true
  
  //MARK: - Commons
  
  private let kScreenWidth = UIScreen.mainScreen().bounds.width
  private let kScreenHeight = UIScreen.mainScreen().bounds.height
  
  private let kTaskListCellID: String    = "tsak_list_cell"
  private let kAddTaskListCellID: String = "add_task_list_cell"
  
  private enum ScreenDirection {
    case vertical
    case horizontal
  }
  
  private let kZoomScale: CGFloat = 0.5
  
  
  //MARK: - Property
  
  private var _containerScrollView: UIScrollView!
  private var _collectionView: TaskBoardCollectionView!
  private var _collectionViewFlowLayout: UICollectionViewFlowLayout!
  private var _screenDirection: ScreenDirection = .vertical
  private var _itemHeight: CGFloat {
    switch _screenDirection {
    case .vertical:
      return (kScreenHeight - top - bootom - _navigationBarHight) * (_isZooming ? 1 / kZoomScale : 1 )
    case .horizontal:
      return (kScreenWidth - top - bootom - _navigationBarHight) * (_isZooming ? 1 / kZoomScale : 1 )
    }
  }
  private var _keyboardHeight: CGFloat = 0
  
  private var _pageScrollView: UIScrollView!
  
  private var _snapshotView: UIView?
  private var _draggingTaskCell: TaskTableViewCell?
  private var _draggingListCell: TasksCollectionViewCell?
  
  private var _lastDragging: (listIndexPath: NSIndexPath, taskIndexPath: NSIndexPath)?
  
  private var _taskLists: [TaskList] = []
  
  private var _keyboardMan: KeyboardMan?
  private var _isZooming: Bool = false
  private var _isZoomForDragList: Bool = false
  
  private var _draggingOffset: CGPoint = CGPoint.zero
  
  private var _itemWidth: CGFloat {
    if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
      return 375 - 2 * (margin + lineSpacing)
    }
    return kScreenWidth - 2 * (margin + lineSpacing)
  }
  private var _pageWidth: CGFloat {
    if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
      return 375 - 2 * margin - lineSpacing
    }
    return kScreenWidth - 2 * margin - lineSpacing
  }
  private var _navigationBarHight: CGFloat {
    if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
      return 64
    }
    
    switch _screenDirection {
    case .vertical:
      return 64
    case .horizontal:
      return 32
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    for index in 0..<8 {
      var numbers = 0
      
      if index == 0 {
        numbers = 3
      } else if index == 1 {
        numbers = 32
      } else if index == 2 || index == 6 {
        numbers = 10
      } else if index == 3 || index == 4 {
        numbers == 1
      } else {
        numbers = 5
      }
      var tasks: [Task] = []
      
      
      for number in 0...numbers {
        let task = Task(title: "\(number)", hidden: false)
        tasks.append(task)
      }
      
      _taskLists.append(TaskList(name: "新建任务\(index)", listID: "", isAddingTask: false, scrollPosition: 0, hidden: false, tasks: tasks))
    }
    
    let horizontalInset = margin + lineSpacing
    
    _collectionViewFlowLayout = UICollectionViewFlowLayout()
    _collectionViewFlowLayout.itemSize = CGSize(width: _itemWidth, height: _itemHeight)
    _collectionViewFlowLayout.scrollDirection = .Horizontal
    _collectionViewFlowLayout.minimumLineSpacing = lineSpacing
    _collectionViewFlowLayout.sectionInset = UIEdgeInsets(top: top, left: horizontalInset, bottom: bootom, right: horizontalInset)
    
    _collectionView = TaskBoardCollectionView(frame: view.bounds, collectionViewLayout: _collectionViewFlowLayout)
    _collectionView.dataSource = self
    _collectionView.delegate = self
    _collectionView.registerClass(TasksCollectionViewCell.self, forCellWithReuseIdentifier: kTaskListCellID)
    _collectionView.registerClass(AddTaskListCollectionViewCell.self, forCellWithReuseIdentifier: kAddTaskListCellID)
    _collectionView.backgroundColor = UIColor.whiteColor()
    automaticallyAdjustsScrollViewInsets = false
    
    view.addSubview(_collectionView)
    _collectionView.frame = view.bounds
    _collectionView.frame.size.height -= _navigationBarHight
    _collectionView.frame.origin.y += _navigationBarHight
    _collectionView.backgroundColor = UIColor.cyanColor()
    
    _screenDirection = kScreenWidth < kScreenHeight ? .vertical : .horizontal
    
    _pageScrollView = UIScrollView(frame: CGRect(x: margin + lineSpacing, y: 64, width: _pageWidth, height: 10))
    _pageScrollView.contentSize = CGSize(width: CGFloat(_collectionView.numberOfItemsInSection(0)) * _pageWidth, height: 0.1)
    _pageScrollView.pagingEnabled = true
    _pageScrollView.delegate = self
    
//    _collectionView.frame.size.width = _pageScrollView.contentSize.width + 2 * margin + lineSpacing
//    _collectionView.contentSize.width = _pageScrollView.contentSize.width + 2 * margin + lineSpacing
    
//    _collectionView.frame.size.width /= kZoomScale
    
    _collectionView.panGestureRecognizer.enabled = false
    _collectionView.addGestureRecognizer(_pageScrollView.panGestureRecognizer)
    
    view.addSubview(_pageScrollView)
    _pageScrollView.backgroundColor = UIColor.yellowColor()
    
    _setPageable(true)
    
    let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(_collectionViewDidLongPressed(_:)))
    longPressGesture.minimumPressDuration = 0.25
    _collectionView.addGestureRecognizer(longPressGesture)
    
    let tapPressGesture = UITapGestureRecognizer(target: self, action: #selector(_collectionViewDidTapped(_:)))
    tapPressGesture.numberOfTapsRequired = 2
    _collectionView.addGestureRecognizer(tapPressGesture)
    
    _keyboardMan = KeyboardMan()
    _keyboardMan?.animateWhenKeyboardAppear = { [weak self] appearPostIndex, keyboardHeight, keyboardHeightIncrement in
      guard let weakSelf = self else { return }
      
      var keyboardHeight = keyboardHeight - weakSelf.bootom
      if weakSelf._isZooming {
        keyboardHeight = keyboardHeight / weakSelf.kZoomScale
      }
      weakSelf._keyboardHeight = keyboardHeight
      NSNotificationCenter.defaultCenter().postNotificationName(kTaskListHeightDidChangedNotification, object: nil, userInfo: [kTaskViewHeightNotigicationKey: weakSelf._itemHeight - keyboardHeight, kTaskSuperViewHeightNotigicationKey: weakSelf._itemHeight])
    }
    
    _keyboardMan?.animateWhenKeyboardDisappear = { [weak self] keyboardHeight in
      guard let weakSelf = self else { return }
      
      weakSelf._keyboardHeight = 0
      NSNotificationCenter.defaultCenter().postNotificationName(kTaskListHeightDidChangedNotification, object: nil, userInfo: [kTaskViewHeightNotigicationKey: weakSelf._itemHeight, kTaskSuperViewHeightNotigicationKey: weakSelf._itemHeight])
    }
  }
}

extension TaskBoardViewController {
  
  //MARK: - Override
  
  override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
    _screenDirection = size.width < size.height ? .vertical : .horizontal

    if _screenDirection == .vertical {
      _scrollToCorrectPage(atPosition: _collectionView.contentOffset.x)
    }
    
    _setPageable(_screenDirection == .vertical && !_isZooming)
    
    UIView.animateWithDuration(coordinator.transitionDuration()) {
      
      let y: CGFloat = self._navigationBarHight
      let width: CGFloat
      let height: CGFloat
      switch self._screenDirection {
      case.vertical:
        width = self.kScreenWidth
        height = self.kScreenHeight - y
      case .horizontal:
        width = self.kScreenHeight
        height = self.kScreenWidth - y
      }

      self._collectionView.frame.origin.y = y
      self._collectionView.frame.size.width = width
      self._collectionView.frame.size.height = height
    }
    self._collectionViewFlowLayout.itemSize.height = self._itemHeight
    self._collectionView.collectionViewLayout.invalidateLayout()
//    self._collectionView.reloadData()
    NSNotificationCenter.defaultCenter().postNotificationName(kTaskListHeightDidChangedNotification, object: nil, userInfo: [kTaskViewHeightNotigicationKey: _itemHeight, kTaskSuperViewHeightNotigicationKey: _itemHeight])
    
//    _pageScrollView.contentSize.width = _pageWidth * CGFloat(_collectionView.numberOfItemsInSection(0))
  }
}

extension TaskBoardViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
  
  //MARK: - UICollectionViewDataSource
  
  func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return _taskLists.count + (canAddList ? 1 : 0)
  }
  
  func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
    debugPrint("cellForItemAtIndexPath \(indexPath.item)" )
    
    if canAddList && indexPath.item == collectionView.numberOfItemsInSection(0) - 1 {
      let cell = collectionView.dequeueReusableCellWithReuseIdentifier(kAddTaskListCellID, forIndexPath: indexPath) as! AddTaskListCollectionViewCell
      cell.saveNewTaskListsClosure = { (taskListsTitle: String) in
        self._saveNewTaskLists(taskListsTitle)
      }
      return cell
    }
    
    let cell = collectionView.dequeueReusableCellWithReuseIdentifier(kTaskListCellID, forIndexPath: indexPath) as! TasksCollectionViewCell
    cell.backgroundColor = UIColor.redColor()
    cell.contentView.hidden = _taskLists[indexPath.item].hidden
    
    if cell.tasksViewController == nil {
      cell.tasksViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("TasksViewController") as? TasksViewController
    }
    cell.tasksViewController?.setupData(_taskLists[indexPath.item].tasks, maxHeight: _itemHeight - _keyboardHeight, superViewHeight: _itemHeight)
    cell.tasksViewController?.listHeaderViewLongPressActionClosure = { [weak self](longPressGuesture: UILongPressGestureRecognizer) in
      self?._listHeadViewLongPressGuestureAction(longPressGuesture)
    }
    cell.tasksViewController?.saveTaskClosure = { (taskTitle: String) in
      self._saveNewtask(taskTitle)
    }
    return cell
  }
  
  func collectionView(collectionView: UICollectionView, canMoveItemAtIndexPath indexPath: NSIndexPath) -> Bool {
    return true
  }
}

extension TaskBoardViewController: UIScrollViewDelegate {
  
  //MARK: - UIScrollViewDelegate
  
  func scrollViewDidScroll(scrollView: UIScrollView) {
    if scrollView == _pageScrollView { //ignore collection view scrolling callbacks
      _collectionView.contentOffset.x = scrollView.contentOffset.x
      
      debugPrint("************************** \(_collectionView.contentOffset.x)")
    }
  }
}

extension TaskBoardViewController {
  
  //MARK: - Private
  
  @objc
  private func _saveNewTaskLists(taskListsTitle: String) {
    debugPrint("create TaskLists: \(taskListsTitle)")
  }
  
  @objc
  private func _saveNewtask(taskTitle: String) {
    debugPrint("create Task: \(taskTitle)")
  }
  
  @objc
  private func _collectionViewDidLongPressed(gestureRecognizer: UILongPressGestureRecognizer) {
    switch gestureRecognizer.state {
    case .Began:
      guard let (listIndexPath, taskIndexPath) = _taskIndexPath(atPoint: gestureRecognizer.locationInView(_collectionView)) else { return }
      
      debugPrint("======  listIndexPath: \(listIndexPath.item)")
      
      guard let tasksCell = _collectionView.cellForItemAtIndexPath(listIndexPath) as? TasksCollectionViewCell else { return }
      guard let tasksTableView = tasksCell.tasksViewController?.tasksTableView else { return }
      guard let taskCell = tasksTableView.cellForRowAtIndexPath(taskIndexPath) as? TaskTableViewCell else { return }
      
      taskCell.contentView.hidden = true
      _draggingTaskCell = taskCell
      
      _snapshotView = taskCell.contentView.snapshotViewAfterScreenUpdates(false)
      
      guard let snapshotView = _snapshotView else { return }
      
      snapshotView.backgroundColor = UIColor.orangeColor()
      view.addSubview(snapshotView)
      
      let touchPoint = gestureRecognizer.locationInView(view)
      let taskCellCenter = view.convertPoint(taskCell.center, fromView: tasksTableView)
      _draggingOffset = CGPoint(x: taskCellCenter.x - touchPoint.x, y: taskCellCenter.y - touchPoint.y)
      
      if _isZooming {
        snapshotView.frame.size.width *= kZoomScale
        snapshotView.frame.size.height *= kZoomScale
      }
      snapshotView.center = taskCellCenter

      UIView.animateWithDuration(0.25, animations: {
        snapshotView.transform = CGAffineTransformMakeRotation(0.05)
      })
      
      _lastDragging = (listIndexPath, taskIndexPath)
      
      _setPageable(false)
      
      debugPrint("BEGAN....")
    case .Changed:
      debugPrint("CHANGE....")
      
      guard let snapshotView = _snapshotView else { return }
      snapshotView.center.x = gestureRecognizer.locationInView(view).x + _draggingOffset.x
      snapshotView.center.y = gestureRecognizer.locationInView(view).y + _draggingOffset.y
      
      _collectionView.touchRectDidChanged(snapshotView.frame)

      guard let (listIndexPath, taskIndexPath) = _taskIndexPath(atPoint: gestureRecognizer.locationInView(_collectionView)) else { return }
      guard let tasksCell = _collectionView.cellForItemAtIndexPath(listIndexPath) as? TasksCollectionViewCell else { return }
      guard let tasksViewController = tasksCell.tasksViewController else { return }

      
      if _lastDragging?.listIndexPath == listIndexPath && _lastDragging?.taskIndexPath == taskIndexPath {
        return
      }
      
      guard let oldListIndexPath = _lastDragging?.listIndexPath else { return }
      guard let oldTaskIndexPath = _lastDragging?.taskIndexPath else { return }
      
      if _lastDragging?.listIndexPath == listIndexPath { // 同一列表
        guard var tasksTableView = tasksViewController.tasksTableView else {
          return
        }
        
        let covertFrame = view.convertRect(snapshotView.frame, toView: tasksViewController.view)
        tasksTableView.touchRectDidChanged(covertFrame)
        
        guard tasksTableView.cellForRowAtIndexPath(taskIndexPath) != nil else { return }

        swap(&_taskLists[oldListIndexPath.item].tasks[oldTaskIndexPath.row], &_taskLists[listIndexPath.item].tasks[taskIndexPath.row])
        tasksViewController.moveTask(atIndexPath: taskIndexPath, toIndexPath: oldTaskIndexPath)
        
        debugPrint("moving....................")
      } else { // 跨列表
        guard let oldTasksCell = _collectionView.cellForItemAtIndexPath(oldListIndexPath) as? TasksCollectionViewCell else { return }
        guard let oldTasksVirewController = oldTasksCell.tasksViewController else { return }
        
        var draggingData = _taskLists[oldListIndexPath.item].tasks[oldTaskIndexPath.row]
        draggingData.hidden = true
        
        _taskLists[oldListIndexPath.item].tasks.removeAtIndex(oldTaskIndexPath.row)
        oldTasksVirewController.removeTask(atIndexPath: oldTaskIndexPath)
        oldTasksVirewController.updateTableViewHeight(true, additionHeight: -(_draggingTaskCell?.bounds.height ?? 0), maxHeight: _itemHeight - _keyboardHeight, superViewHeight: _itemHeight)
        
        let tempTasksList: [Task] = _taskLists[listIndexPath.item].tasks
        if tempTasksList.count == 0 || (taskIndexPath.row >= tempTasksList.count) {
          _taskLists[listIndexPath.item].tasks.append(draggingData)
        } else {
          _taskLists[listIndexPath.item].tasks.insert(draggingData, atIndex: taskIndexPath.row)
        }
        
        tasksViewController.insertTask(draggingData, atIndexPath: taskIndexPath)
        tasksViewController.updateTableViewHeight(true, additionHeight: _draggingTaskCell?.bounds.height ?? 0, maxHeight: _itemHeight - _keyboardHeight, superViewHeight: _itemHeight)
        
        // 防止因为cell复用导致的自动滚动的问题
        oldTasksVirewController.tasksTableView.stopAutoScroll()
        tasksViewController.tasksTableView.stopAutoScroll()
      }
      _lastDragging = (listIndexPath, taskIndexPath)
    case .Failed, .Cancelled, .Ended:
      debugPrint("END....")
      
      if _snapshotView == nil { return }
      
      NSNotificationCenter.defaultCenter().postNotificationName(kTaskTableViewShouldStopAutoScrollNotification, object: self, userInfo: nil)
      _collectionView.stopAutoScroll()
      if _screenDirection == .vertical && !_isZooming {
        _scrollToCorrectPage(atPosition: _collectionView.contentOffset.x)
      }
      _setPageable(!_isZooming)
      
      _snapshotView?.removeFromSuperview()
      _snapshotView = nil
      
      _draggingTaskCell?.contentView.hidden = false
      
      guard let oldTasksCell = _collectionView.cellForItemAtIndexPath(_lastDragging!.listIndexPath) as? TasksCollectionViewCell else { return }
      guard let oldTasksVirewController = oldTasksCell.tasksViewController else { return }
      guard let reloadListIndexPath = _lastDragging?.listIndexPath else { return }
      guard let reloadTaskIndexPath = _lastDragging?.taskIndexPath else { return }
      _taskLists[reloadListIndexPath.item].tasks[reloadTaskIndexPath.row].hidden = false
      oldTasksVirewController.reloadTask(_taskLists[reloadListIndexPath.item].tasks[reloadTaskIndexPath.row], atIndexPath: reloadTaskIndexPath)
      
    case .Possible:
      fatalError("Should rollback to origin status as failed or ended")
    }
  }
  
  @objc
  private func _listHeadViewLongPressGuestureAction(longPressGuesture: UILongPressGestureRecognizer) {
    switch longPressGuesture.state {
    case .Began:
      guard let (listIndexPath, taskIndexPath) = _taskIndexPath(atPoint: longPressGuesture.locationInView(_collectionView)) else { return }
      
      func beginDragging() {
        guard let tasksCell = _collectionView.cellForItemAtIndexPath(listIndexPath) as? TasksCollectionViewCell else { return }
        tasksCell.contentView.hidden = true
        
        _taskLists[listIndexPath.item].hidden = true
        
        _snapshotView = tasksCell.contentView.snapshotViewAfterScreenUpdates(false)
        guard let snapshotView = _snapshotView else { return }
        
        _collectionView.scrollsToTop = false
//        _draggingListCell = tasksCell
        snapshotView.backgroundColor = UIColor.orangeColor()
        view.addSubview(snapshotView)
       
        let touchPoint = longPressGuesture.locationInView(view)
        let taskListCenter = view.convertPoint(tasksCell.center, fromView: _collectionView)
        _draggingOffset = CGPoint(x: taskListCenter.x - touchPoint.x, y: taskListCenter.y - touchPoint.y)
        
        snapshotView.frame.size.width *= kZoomScale
        snapshotView.frame.size.height *= kZoomScale
        snapshotView.center = taskListCenter

        UIView.animateWithDuration(0.25, animations: {
          snapshotView.transform = CGAffineTransformMakeRotation(0.05) //使用它时，不能改变frame, 只能通过center 来改变平移时的位置
        })

        _lastDragging = (listIndexPath, taskIndexPath)
      }
      
      if !_isZooming {
        _isZoomForDragList = true
        var currentContentOffset = _collectionView.contentOffset
        if currentContentOffset.x > 0 && currentContentOffset.x < _collectionView.contentSize.width {
          currentContentOffset = CGPointMake(currentContentOffset.x - _itemWidth / 2 - (margin + lineSpacing), 0)
        }
        _zoomCollectionView(touchAt: currentContentOffset, completion: {
          beginDragging()
        })
      } else {
        beginDragging()
      }
    case .Changed:
      debugPrint("0000")
      guard let snapshotView = _snapshotView else { return }
      
      _collectionView.touchRectDidChanged(snapshotView.frame)
      let touchPoint = longPressGuesture.locationInView(view)
      
      snapshotView.center.x = touchPoint.x + _draggingOffset.x
      snapshotView.center.y = touchPoint.y + _draggingOffset.y
      guard let oldListIndexPath = _lastDragging?.listIndexPath else { return }
      guard let collectionIndexPath = _collectionView.indexPathForItemAtPoint(longPressGuesture.locationInView(_collectionView)) else { return }
      if oldListIndexPath.isEqual(collectionIndexPath) { return }
      if collectionIndexPath.item >= _taskLists.count { return }
      
      swap(&_taskLists[oldListIndexPath.item], &_taskLists[collectionIndexPath.item])
      _collectionView.moveItemAtIndexPath(collectionIndexPath, toIndexPath: oldListIndexPath)
      _collectionView.reloadItemsAtIndexPaths([collectionIndexPath])
      _lastDragging = (collectionIndexPath, NSIndexPath(forRow: 0, inSection: 0))
    case .Failed, .Cancelled, .Ended:
      
      func endDragging() {
//        _draggingListCell?.contentView.hidden = false
//        _draggingListCell = nil
        _collectionView.stopAutoScroll()
        
        _snapshotView?.transform = CGAffineTransformIdentity
        _snapshotView?.removeFromSuperview()
        _snapshotView = nil
        guard let finalListIndexPath = _lastDragging?.listIndexPath else { return }
        _taskLists[finalListIndexPath.item].hidden = false
        _collectionView.reloadItemsAtIndexPaths([finalListIndexPath])
      }
      
      endDragging()
      let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(0.25 * Double(NSEC_PER_SEC)))
      dispatch_after(delayTime, dispatch_get_main_queue(), {
        if self._snapshotView != nil {
          endDragging()
        }
      })
      if _isZoomForDragList {
        let touchPoint = longPressGuesture.locationInView(_collectionView)
        _zoomCollectionView(touchAt: CGPoint(x: touchPoint.x * kZoomScale, y: touchPoint.y * kZoomScale))
        _isZoomForDragList = false
      }
      
    default:
      fatalError("Should rollback to origin status as failed or ended")
    }
  }
  
  /**
   CollectionView tapGesture event
   
   - parameter gestureRecognizer:
   */
  @objc
  private func _collectionViewDidTapped(gestureRecognizer: UITapGestureRecognizer) {
    _zoomCollectionView(touchAt: gestureRecognizer.locationInView(_collectionView))
  }
  
  /**
   CollectionView Zooming event
   
   - parameter touchAt: touch point on collectionView
   */
  private func _zoomCollectionView(touchAt touchPoint: CGPoint=CGPoint.zero, completion: (() -> Void)?=nil) {
    if _isZooming { // Back to origin state
      self._isZooming = false
      
      let page: Int? = _taskListIndexPath(atPoint: touchPoint)?.item
      
      NSNotificationCenter.defaultCenter().postNotificationName(kTaskListHeightDidChangedNotification, object: nil, userInfo: [kTaskViewHeightNotigicationKey: _itemHeight, kTaskSuperViewHeightNotigicationKey: _itemHeight])
      
      _collectionViewFlowLayout.itemSize.height = self._itemHeight
      _collectionView.collectionViewLayout.invalidateLayout()

      UIView.animateWithDuration(0.25, delay: 0, options: .CurveEaseInOut, animations: {
        self._collectionView.transform = CGAffineTransformIdentity

        self._collectionView.frame.origin.x += self._collectionView.frame.width * self.kZoomScale * self.kZoomScale
        self._collectionView.frame.origin.y += self._collectionView.frame.height * self.kZoomScale * self.kZoomScale

        self._collectionView.frame.size.width *= self.kZoomScale
        self._collectionView.frame.size.height *= self.kZoomScale

        if self._screenDirection == .vertical {
          self._scrollToCorrectPage(atPosition: self._collectionView.contentOffset.x / self.kZoomScale, page: page)
        }
        
      }) { (finished: Bool) in
        self._setPageable(self._screenDirection == .vertical)
        completion?()
      }
    } else { // Zooming
      self._isZooming = true
      
      NSNotificationCenter.defaultCenter().postNotificationName(kTaskListHeightDidChangedNotification, object: nil, userInfo: [kTaskViewHeightNotigicationKey: _itemHeight, kTaskSuperViewHeightNotigicationKey: _itemHeight])
      _collectionViewFlowLayout.itemSize.height = self._itemHeight
      _collectionViewFlowLayout.invalidateLayout()
      
      UIView.animateWithDuration(0.25, delay: 0, options: .CurveEaseInOut, animations: {
        self._collectionView.transform = CGAffineTransformMakeScale(self.kZoomScale, self.kZoomScale)

        self._collectionView.frame.origin.x -= self._collectionView.frame.width * self.kZoomScale
        self._collectionView.frame.origin.y -= self._collectionView.frame.height * self.kZoomScale

        self._collectionView.frame.size.width /= self.kZoomScale
        self._collectionView.frame.size.height /= self.kZoomScale
        
        let screenWidth = self.kScreenWidth * self.kZoomScale
        if self._collectionView.contentOffset.x - screenWidth > 0 {
          self._collectionView.contentOffset.x -= screenWidth
        }
        
      }) { (finished:Bool) in
        self._setPageable(false)
        completion?()
      }
    }
  }
  
  /**
   List indexPath and task indexPath for touch point
   
   - parameter point: touch point
   
   - returns: (list indexPath on collecitonView, task indexPath on tableView)
   */
  private func _taskIndexPath(atPoint point: CGPoint) -> (listIndexPath: NSIndexPath, taskIndexPath: NSIndexPath)? {
    guard let listIndexPath = _collectionView.indexPathForItemAtPoint(point) else { return nil }
    guard let tasksCell = _collectionView.cellForItemAtIndexPath(listIndexPath) as? TasksCollectionViewCell else {
      guard let collectionIndexPath = _collectionView.indexPathForItemAtPoint(point) else { return  nil}
      return (collectionIndexPath, NSIndexPath(forRow: 0, inSection: 0))
   }
    
    guard let tasksViewController = tasksCell.tasksViewController else { return nil }
    guard let tasksTableView = tasksCell.tasksViewController?.tasksTableView else { return nil }
    guard let listHeaderView = tasksCell.tasksViewController?.listHeaderView else { return nil}
    guard let listFooterView = tasksCell.tasksViewController?.listFooterView else { return nil}
    
    let tableViewPoint = _collectionView.convertPoint(point, toView: tasksTableView)
    let taskViewControllerPoint = _collectionView.convertPoint(point, toView: tasksViewController.view)
    
    if listHeaderView.frame.contains(taskViewControllerPoint) {
      return (listIndexPath, NSIndexPath(forRow: 0, inSection: 0))
    } else if listFooterView.frame.contains(taskViewControllerPoint) {
      let row = tasksTableView.numberOfRowsInSection(0)
      return (listIndexPath, NSIndexPath(forRow: row, inSection: 0))
    } else {
      guard let taskIndexPath = tasksTableView.indexPathForRowAtPoint(tableViewPoint) else {
        return nil
      }
      return (listIndexPath, taskIndexPath)
    }
  }
  
  private func _taskListIndexPath(atPoint point: CGPoint) -> NSIndexPath? {
    return _collectionView.indexPathForItemAtPoint(point)
  }
  
  private func _setPageable(pageable: Bool) {
    var pageable = pageable
    if UIDevice.currentDevice().userInterfaceIdiom == .Pad || _screenDirection == .horizontal || _isZooming {
      pageable = false
    }
    
//    _pageScrollView.pagingEnabled = pageable
//    _setPageScrollViewContentSize()
    
    if pageable {
      _collectionView.addGestureRecognizer(_pageScrollView.panGestureRecognizer)
    } else {
      _collectionView.removeGestureRecognizer(_pageScrollView.panGestureRecognizer)
    }
    
    _collectionView.panGestureRecognizer.enabled = !pageable
    _collectionView.showsHorizontalScrollIndicator = !pageable
  }
  
  private func _scrollToCorrectPage(atPosition targetOffsetX: CGFloat, page: Int?=nil) {
    if UIDevice.currentDevice().userInterfaceIdiom == .Pad || _isZooming { return }

    var correctPage: Int = 0
    if page != nil {
      correctPage = page!
    } else {
      correctPage = Int(round(_collectionView.contentOffset.x / _pageScrollView.bounds.width))
    }
    
    let contentOffsetX = CGFloat(correctPage) * _pageScrollView.bounds.width
    _pageScrollView.contentOffset.x = contentOffsetX
    
    UIView.animateWithDuration(0.25) { 
      self._collectionView.contentOffset.x = contentOffsetX
    }
  }
  
//  private func _setPageScrollViewContentSize() {
//    let originContentWidth = _pageScrollView.frame.width * CGFloat(_collectionView.numberOfItemsInSection(0))
//    let contentOffsetX = _pageScrollView.contentOffset.x
//    
//    if _isZooming || _screenDirection == .horizontal {
//      let screenWidth: CGFloat
//      switch _screenDirection {
//      case .horizontal:
//        screenWidth = kScreenHeight
//      case .vertical:
//        screenWidth = kScreenWidth
//      }
//      _pageScrollView.contentSize.width = originContentWidth - (screenWidth / _collectionView.transform.a - _pageScrollView.frame.width - margin - 2 * lineSpacing)
//    } else {
//      _pageScrollView.contentSize.width = originContentWidth
//    }
//    
//    _pageScrollView.contentOffset.x = min(contentOffsetX, _pageScrollView.contentSize.width)
//    _collectionView.contentOffset.x = min(contentOffsetX, _pageScrollView.contentSize.width)
//  }
}