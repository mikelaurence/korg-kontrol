class ColoredButtonCell < NSCell
  
  TOGGLE_FLAGS = 262401   # ( ctrl key )
  
  def drawInteriorWithFrame(frame, inView:view)
    #puts "val: #{objectValue}"
    fr = NSMakeRect(frame.origin.x, frame.origin.y, frame.size.width - 2, frame.size.height - 2)
    color = (objectValue[1] || NSColor.whiteColor)
    (objectValue[0] == 0 ? color : color.shadowWithLevel(0.2)).set
    NSRectFill fr
  end
  
  def startTrackingAt(startPoint, inView:controlView)
    # Toggle between "on" and "off" state
    objectValue[0] += 1
    objectValue[0] = 0 if objectValue[0] > 1

    puts "cell mousedown #{objectValue}"
    controlView.target.send controlView.action, controlView, objectValue[0] == 1
    true
  end
  
  def stopTracking(lastPoint, at:stopPoint, inView:controlView, mouseIsUp:mouseIsUp)
    unless mouseDownFlags == TOGGLE_FLAGS
      objectValue[0] = 0  # Mouse-up always sets "off" state

      puts "cell mouseup #{objectValue}"
      controlView.target.send controlView.action, controlView, false
    end
  end
  
end