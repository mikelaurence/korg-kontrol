class ColoredButtonCell < NSCell
  
  TOGGLE_FLAGS = 262401   # ( ctrl key )
  
  def drawInteriorWithFrame(frame, inView:view)
    fr = NSMakeRect(frame.origin.x, frame.origin.y, frame.size.width - 2, frame.size.height - 2)
    (objectValue and objectValue.is_a?(NSColor) ? objectValue : NSColor.whiteColor).set
    NSRectFill fr
  end
  
  def startTrackingAt(startPoint, inView:controlView)
    puts "start"
    puts state
    state = state == NSOnState ? NSOffState : NSOnState
    puts state
    puts '--'
    controlView.target.send controlView.action, controlView, state == NSOnState
    true
  end
  
  def stopTracking(lastPoint, at:stopPoint, inView:controlView, mouseIsUp:mouseIsUp)
    unless mouseDownFlags == TOGGLE_FLAGS
      puts "stop"
      puts state
      state = NSOffState
      puts state
      puts '--'
      controlView.target.send controlView.action, controlView, false
    end
  end
  
end