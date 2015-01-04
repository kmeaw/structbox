class Pipeline
  def << x
    raise UnimplementedError
  end

  def >> x
    raise UnimplementedError
  end

  def initialize
  end
end

class InternalPipeline < Pipeline
end

class ExternalPipeline < Pipeline
end
