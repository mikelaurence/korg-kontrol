class ColoredButtonCell < NSActionCell

  # attr_accessor :colors
  # 
  # def currentColor
  #   puts "Color cell value #{integerValue}, colors: #{colors}"
  #   (colors || [])[self.integerValue] || NSColor.whiteColor
  # end
  
  def drawInteriorWithFrame(frame, inView:view)
    fr = NSMakeRect(frame.origin.x, frame.origin.y, frame.size.width - 2, frame.size.height - 2)
    (objectValue and objectValue.is_a?(NSColor) ? objectValue : NSColor.whiteColor).set
    NSRectFill fr
  end
  
end