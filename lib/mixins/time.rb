class Time

  def review_time
    strftime('%d-%b-%y')
  end

  def review_ljust(size)
    to_s.review_ljust(size)
  end

end
