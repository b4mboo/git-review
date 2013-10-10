module Colorizable

  # Takes a color code (= an integer) and formats the Colorizable accordingly.
  def colorize(color_code)
    "\e[#{color_code}m#{self}\e[0m"
  end

  # A couple of presets to keep the code clean.

  def red
    colorize 31
  end

  def green
    colorize 32
  end

  def yellow
    colorize 33
  end

  def blue
    colorize 34
  end

  def pink
    colorize 35
  end

end
