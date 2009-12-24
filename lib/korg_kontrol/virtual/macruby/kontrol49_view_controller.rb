class Kontrol49ViewController < NSViewController  

  include KorgKontrol

  attr_accessor :controller
  
  def awakeFromNib
    super
    
    # Create matrices
    cell = ColoredButtonCell.new
    
    @switchMatrix = NSMatrix.alloc.initWithFrame(switchMatrixFrame, mode:NSTrackModeMatrix, prototype:cell, numberOfRows:1, numberOfColumns:2)
    @switchMatrix.cellSize = switchCellSize
    @switchMatrix.target = self
    @switchMatrix.action = :clickedSwitch
    @switchMatrix.cells.each { |cell| cell.objectValue = NSColor.grayColor }
    view.addSubview @switchMatrix
    
    @padMatrix = NSMatrix.alloc.initWithFrame(padMatrixFrame, mode:NSTrackModeMatrix, prototype:cell, numberOfRows:4, numberOfColumns:4)
    @padMatrix.cellSize = padCellSize
    @padMatrix.target = self
    @padMatrix.action = :clickedPad
    @padMatrix.cells.each { |cell| cell.objectValue = NSColor.grayColor }
    view.addSubview @padMatrix
    
    @buttonMatrix = NSMatrix.alloc.initWithFrame(buttonMatrixFrame, mode:NSTrackModeMatrix, prototype:cell, numberOfRows:4, numberOfColumns:2)
    @buttonMatrix.cellSize = buttonMatrixSize
    @buttonMatrix.target = self
    @buttonMatrix.action = :clickedButton
    @buttonMatrix.cells.each { |cell| cell.objectValue = NSColor.grayColor }
    view.addSubview @buttonMatrix
    
    @leds = {
      :setting => [@buttonMatrix, 0, 0],
      :message => [@buttonMatrix, 0, 1],
      :scene => [@buttonMatrix, 1, 0],
      :exit => [@buttonMatrix, 1, 1],
      :hex_lock => [@buttonMatrix, 2, 0],
      :enter => [@buttonMatrix, 2, 1],
      :previous => [@buttonMatrix, 3, 0],
      :next => [@buttonMatrix, 3, 1]
    }.merge((1..16).inject({}) do |hash, pad| 
      idx = pad.to_i - 1
      hash[pad] = [@padMatrix, idx / 4, idx % 4]
      hash
    end)
    
    @buttons = [:setting, :message, :scene, :exit, :hex_lock, :enter, :previous, :next]
    
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
  
  def buttonMatrixFrame
    NSMakeRect view.frame.size.height + 10.0, 0, view.frame.size.height / 2.0, view.frame.size.height / 2.0
  end
  
  def buttonMatrixSize
    NSMakeSize view.frame.size.height / 4.0, view.frame.size.height / 8.0
  end
  
  
  # Kontrol actions
  
  def led(pad, state, color = :red)
    puts "virtual led: #{pad} #{state} #{color}"
    color = state == :off ? NSColor.grayColor : @colors[color]
    
    p = @leds[pad]
    puts "pad: #{pad} #{pad.class} #{p}"
    p[0].cellAtRow(p[1], column:p[2]).objectValue = color
  end
  
  def lcd(index, text, color = :red, justification = :centered)
    
  end
  
  
  # View actions
  
  def clickedPad
    @controller.capture_event PadEvent.new :index => @padMatrix.selectedRow * 4 + @padMatrix.selectedColumn, :state => :on, :velocity => 127 if @controller
  end
  
  def clickedButton
    @controller.capture_event SwitchEvent.new :type => @buttons[@buttonMatrix.selectedRow * 2 + @buttonMatrix.selectedColumn], :state => :on
  end
  
end
