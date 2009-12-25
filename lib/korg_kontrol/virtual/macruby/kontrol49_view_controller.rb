class Kontrol49ViewController < NSViewController  

  include KorgKontrol

  attr_accessor :controller
  
  def awakeFromNib
    super
    
    # Create matrices
    cell = ColoredButtonCell.new
    colors = { 1 => NSColor.grayColor, 2 => NSColor.redColor, 3 => NSColor.greenColor, 4 => NSColor.orangeColor }
    colors.each_pair{ |value, color| colors[value * -1] = color.shadowWithLevel(0.2) }
    
    @switchMatrix = VirtualButtonMatrix.alloc.initWithFrame(switchMatrixFrame, mode:NSTrackModeMatrix, prototype:cell, numberOfRows:1, numberOfColumns:2)
    @switchMatrix.colors = colors
    @switchMatrix.cellSize = switchCellSize
    @switchMatrix.target = self
    @switchMatrix.action = :clickedMatrix
    @switchMatrix.cells.each { |cell| cell.objectValue = [0, NSColor.grayColor] }
    view.addSubview @switchMatrix
    
    @padMatrix = VirtualButtonMatrix.alloc.initWithFrame(padMatrixFrame, mode:NSTrackModeMatrix, prototype:cell, numberOfRows:4, numberOfColumns:4)
    @padMatrix.colors = colors
    @padMatrix.cellSize = padCellSize
    @padMatrix.target = self
    @padMatrix.action = :clickedMatrix
    @padMatrix.cells.each { |cell| cell.objectValue = [0, NSColor.grayColor] }
    view.addSubview @padMatrix
    
    @buttonMatrix = VirtualButtonMatrix.alloc.initWithFrame(buttonMatrixFrame, mode:NSTrackModeMatrix, prototype:cell, numberOfRows:4, numberOfColumns:2)
    @buttonMatrix.colors = colors
    @buttonMatrix.cellSize = buttonMatrixSize
    @buttonMatrix.target = self
    @buttonMatrix.action = :clickedMatrix
    @buttonMatrix.cells.each { |cell| cell.objectValue = [0, NSColor.grayColor] }
    view.addSubview @buttonMatrix
    
    @matrices = {
      @switchMatrix => { :eventClass => SwitchEvent, :types => [:sw1, :sw2] },
      @padMatrix => { :eventClass => PadEvent },
      @buttonMatrix => { :eventClass => SwitchEvent, :types => [:setting, :message, :scene, :exit, :hex_lock, :enter, :previous, :next] }
    }
    
    @leds = {
      :sw1 => [@switchMatrix, 0, 0],
      :sw2 => [@switchMatrix, 0, 1],
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

    @colors = {
      :red => NSColor.redColor,
      :orange => NSColor.orangeColor,
      :green => NSColor.greenColor
    }
  end
  
  def viewHeight
    view.frame.size.height
  end
  
  def switchMatrixFrame
    NSMakeRect 0, viewHeight * 0.5, viewHeight * 0.5, viewHeight * 0.125
  end
  
  def switchCellSize
    NSMakeSize viewHeight * 0.25, viewHeight * 0.25
  end
  
  def padMatrixFrame
    NSMakeRect viewHeight * 0.5 + 10.0, 0, viewHeight, viewHeight
  end
  
  def padCellSize
    NSMakeSize viewHeight * 0.25, viewHeight * 0.25
  end
  
  def buttonMatrixFrame
    NSMakeRect viewHeight * 1.5 + 20.0, 0, viewHeight * 0.5, viewHeight * 0.5
  end
  
  def buttonMatrixSize
    NSMakeSize viewHeight * 0.25, viewHeight * 0.125
  end
  
  
  # Kontrol actions
  
  def led(pad, state, color = :red)
    pad_config = @leds[pad]
    matrix = pad_config[0]
    cell = matrix.cellAtRow(pad_config[1], column:pad_config[2])
    cell.objectValue = [cell.objectValue[0], (state != :off ? @colors[color] : NSColor.grayColor)]
  end
  
  def lcd(index, text, color = :red, justification = :centered)
    
  end
  
  
  # View actions 
  # Note: these are using a stupid hack to avoid double action on mouse-up ("return if down.is_a?(NSMatrix)"). Not sure where it's
  # coming from; overriding mouseDown in the custom NSMatrix and doing nothing causes no actions, but sending a trackMouse message
  # to the clicked cell brings it back.
  
  def clickedMatrix(matrix = nil, down = false)
    return if down.is_a?(NSMatrix)
    idx = matrix.selectedRow * matrix.numberOfColumns + matrix.selectedColumn
    if @controller and idx >= 0
      eventClass = @matrices[matrix][:eventClass]
      types = @matrices[matrix][:types]
      event = eventClass.new types ?
        { :type => types[idx], :state => down } :
        { :index => idx, :state => down, :velocity => 127 }
      puts "#{event}"
      @controller.capture_event event
    end
  end
  
end
