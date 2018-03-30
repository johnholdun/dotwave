class Friday
  def self.for(date)
    friday_offset =
      case date.wday
      when 0 then -2
      when 1 then -3
      when 2 then -4
      when 3 then -5
      when 4 then -6
      when 5 then 0
      when 6 then -1
      end

    date + friday_offset
  end
end
