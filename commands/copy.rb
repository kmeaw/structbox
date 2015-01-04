class Copy < Command
  INPUT = {pipe: TPipe.new(TAny.new)}

  def output
    @arg[:pipe]
  end
end
