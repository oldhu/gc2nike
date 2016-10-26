class SimpleSpliner
  def initialize(x, y)
    ensure_in_order(x)
    raise "x length is not equal to y length" unless x.length == y.length
    @x = x
    @y = y
    @last_index = 0
  end

  def ensure_in_order(x)
    prev = nil
    x.each do |v|
      if prev.nil? then
        prev = v
      else
        raise "x is not in order" unless v >= prev
        prev = v
      end
    end
  end

  def [](x)
    index = 0
    need_start_over = false
    if @last_index > 0 then
      index = @last_index
      need_start_over = true
    end
    while true
      if @x[index] == x then
        @last_index = index
        return @y[index] 
      end
      if index == @x.length then
        if need_start_over then
          index = 0
          next
        end
        return nil 
      end
      x1 = @x[index].to_i
      x2 = @x[index + 1].to_i
      if x > x1 and x <= x2 then
        y1 = @y[index].to_f
        y2 = @y[index + 1].to_f
        return y1 + (x - x1) * (y2 - y1) / (x2 - x1)
      end
      index += 1
    end
  end
end