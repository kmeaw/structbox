require './pipe'

class TType
  REQ = nil

  def inspect
    self.class.name.to_s[1..-1]
  end

  def to_s
    self.inspect
  end

  def <=(x)
    x.class.ancestors.include? self.class
  end

  def validate(v)
    unless self.class::REQ.nil? or v.is_a? self.class::REQ
      raise TypeError, "#{v.inspect} is not a #{self.class::REQ}"
    end
  end
end

class TNil < TType
  REQ = NilClass
end

class TPipe < TType
  attr_reader :kind

  REQ = Pipe

  def initialize(kind)
    @kind = kind
  end

  def inspect
    "Pipe<#{@kind}>"
  end

  def validate(v)
    super(v)
    raise TypeError, "#{v.kind.inspect} is not a #{@kind.inspect}" unless @kind <= v.kind
  end
end

class TAnyStruct < TType
  attr_reader :kinds
  def initialize(kindhash = {})
    @kinds = kindhash
  end

  def inspect
    "Struct<*>"
  end

  def validate(v)
    raise TypeError, "#{v.inspect} is not subclassed from Struct" unless x.superclass == Struct
  end
end

class TStruct < TAnyStruct
  def inspect
    "Struct<#{@kinds.map{|k,v| "#{k}=#{v}"}.join(', ')}>"
  end

  def validate(v)
    raise TypeError, "#{v.inspect} is not subclassed from Struct" unless x.superclass == Struct
    @kinds.each do |n,k|
      raise ArgumentError, "#{v} has no #{n}" unless v.members.include? n
      k.validate v[n]
    end
  end

  def <=(t)
    super(t) and (@kinds.all?{|k,v| t.kinds[k] and v <= t.kinds[k]})
  end
end

class TAnyList < TType
  attr_reader :kind

  def initialize(kind)
    @kind = kind
  end

  def inspect
    "List<*>"
  end
end

class TList < TAnyList
  REQ = Array

  def inspect
    "List<#{@kind}>"
  end

  def validate(v)
    super(v)
    v.all?{|x| @kind.validate x}
  end

  def <=(t)
    super(t) and (@kind <= t.kind)
  end
end

class TFlags < TType
  def initialize(flags = {})
    @flags = flags
  end

  def inspect
    "Flags<#{@flags.map{|k,v| "#{k}=#{v}"}.join(', ')}>"
  end

  def validate(v)
    super(v)
  end
end

class TString < TType
  REQ = String
end

class RawCommand
  attr_reader :manifest

  INPUT = {}
  OUTPUT = TNil.new

  def initialize(*args)
    @args = args
    @arg = {}
    @manifest = self.input
    self.populate
    self.validate
  end

  def output
    self.class::OUTPUT
  end

  def run
    raise NotImplementedError
  end

  def input
    self.class::INPUT
  end

  def populate
    @args.each_with_index do |v,i|
      @arg[@manifest.keys[i]] = v
    end
  end

  def validate
    raise ArgumentError, "#{self.class.name} got #{@args.size} instead of #{@manifest.size}" unless @args.size == @manifest.size
    @manifest.each do |k,v|
      v.validate @arg[k]
    end
  end
end

class Command < RawCommand
  FLAGS = {}

  def initialize(flags, *args)
    @flags = flags
    @args = args
    @arg = {}
    @manifest = self.input
    self.populate
    self.validate
  end

  def input
    {flags: TFlags.new(self.class::FLAGS)}.merge(self.class::INPUT)
  end

  def validate
    super
  end
end

Dir["./commands/*.rb"].each{|x| require x}

if $PROGRAM_NAME == __FILE__
  flow_in = Pipe.new(TStruct.new({:id => TString.new, :rss => TString.new}))
  sel = Select.new({:ignore_case => true}, ["rss"], flow_in)
  p sel.input
  p sel.output
end
