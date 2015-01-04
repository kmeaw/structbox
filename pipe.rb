class Pipe
  attr_reader :kind

  def initialize(kind)
    @kind = kind
  end

  def inspect
    "<Pipe of #{@kind}>"
  end

  def to_s
    inspect
  end

  def << x
  end

  def >> x
  end
end
