class Kontrol49ViewController < NSViewController  

  attr_accessor :kontroller  
  
  def awakeFromNib
    super
    
    # Create pad matrix
    cell = ColoredButtonCell.new
    @padMatrix = NSMatrix.alloc.initWithFrame(padMatrixFrame, mode:NSTrackModeMatrix, prototype:cell, numberOfRows:4, numberOfColumns:4)
    @padMatrix.cellSize = padCellSize
    @padMatrix.target = self
    @padMatrix.action = :clickedPad
    @padMatrix.cells.each { |cell| cell.objectValue = NSColor.grayColor }
    view.addSubview @padMatrix
    
    @colors = {
      :red => NSColor.redColor,
      :orange => NSColor.orangeColor,
      :green => NSColor.greenColor
    }
  end
  
  def padMatrixFrame
    NSMakeRect 0, 0, view.frame.size.height, view.frame.size.height
  end
  
  def padCellSize
    NSMakeSize view.frame.size.height / 4.0, view.frame.size.height / 4.0
  end
  
  # Kontrol actions
  
  def led(pad, state, color = :red)
    color = state == :off ? NSColor.grayColor : @colors[color]
    @padMatrix.cellAtRow((pad - 1) / 4, column:(pad - 1) % 4).objectValue = color
  end
  
  def lcd(index, text, color = :red, justification = :centered)
    
  end
  
  
  # View actions
  
  def clickedPad
    puts "Clicked pad: #{@padMatrix.selectedColumn}, #{@padMatrix.selectedRow}"
  end
  
end
