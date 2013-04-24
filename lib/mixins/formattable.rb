module Formattable

  # Display helper to make output more configurable.
  def format_text(info, size)
    info.to_s.gsub("\n", ' ')[0, size-1].ljust(size)
  end


  # Display helper to unify time output.
  def format_time(time_string)
    Time.parse(time_string).strftime('%d-%b-%y')
  end

end
