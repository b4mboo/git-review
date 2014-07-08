class String

  include Colorizable

  def review_time
    Time.parse(self).review_time
  end

  def review_ljust(size)
    gsub("\n", ' ')[0, size-1].ljust(size)
  end

end
