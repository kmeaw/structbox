require './pipe'

class TAny
  REQ = nil

  def <=(x)
    true
  end

  def inspect
    "*"
  end

  def self.[](obj)
    raise TypeError, "#{obj.inspect} is a type" if obj.is_a? TAny

    self.descendants.each do |kls|
      begin
	cons = kls[obj]
	return cons
      rescue TypeError => te
	nil
      end
    end

    if [TAny, TType].include? self
      raise TypeError, "TAny.[]: no descendant (of #{descendants.inspect}) has accepted #{obj.inspect}"
    end

    unless self::REQ.nil? or obj.is_a?( self::REQ )
      raise TypeError, "#{obj.inspect} is not a #{self::REQ}"
    end

    if self.instance_method(:initialize).arity == 0
      self.new
    elsif self.instance_method(:initialize).arity == 1
      if obj.respond_to? :kind
	self.new(obj.kind)
      else
	raise TypeError, "#{self.name}: cannot extract kind information from #{obj.inspect}"
      end
    else
      raise TypeError, "do not know how to construct #{self.name} instances"
    end
  end

  def self.descendants
    ObjectSpace.each_object(::Class).select{|kls| kls < self}
  end

  def instantiate
    raise TypeError, "#{self.class.name} cannot be instantiated"
  end
end

class TType < TAny
  def inspect
    self.class.name.to_s[1..-1]
  end

  def to_s
    self.inspect
  end

  def <=(x)
    raise TypeError, "#{self.class.name}: #{x.inspect} is not a type" unless x.is_a? TAny
    x.class.ancestors.include? self.class
  end

  def validate(v)
    unless self.class::REQ.nil? or v.is_a?( self.class::REQ )
      raise TypeError, "#{v.inspect} is not a #{self.class::REQ}"
    end
  end
end

class TNil < TType
  REQ = NilClass

  def instantiate
    nil
  end
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

  def instantiate
    Pipe.new(@kind)
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

  def inspect
    "List<*>"
  end

  def self.[](obj)
    raise TypeError, "attempted to construct from a non-empty list" unless obj == []
    self.new
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

  def initialize(kind)
    @kind = kind
  end

  def self.[](obj)
    raise TypeError, "#{obj.inspect} is not a list" unless obj.is_a? Array
    classes = obj.map(&:class).uniq
    raise TypeError, "#{obj.inspect} is a non-uniform list" unless classes.size == 1
    self.new(TAny[obj.first])
  end
end

class TFlags < TType
  attr_reader :flags
  REQ = Hash

  def initialize(flags = {})
    @flags = flags
  end

  def inspect
    "Flags<#{@flags.map{|k,v| "#{k}=#{v}"}.join(', ')}>"
  end

  def <=(t)
    super(t) and @flags.all?{|k,v| t.flags[k] and t.flags[k] <= v}
  end

  def validate(v)
    super(v)
    @flags.each{|k,t| t.validate v[k]}
    v.keys.each do |k|
      next if @flags[k]
      raise TypeError, "#{self.class.name}: #{v.inspect} has an extra flag #{k}: #{v[k].inspect}"
    end
  end
end

class TString < TType
  REQ = String
end

class TInteger < TType
  REQ = Integer
end

class Command
  attr_reader :manifest, :args, :arg, :argtypes # FIXME: debug only

  INPUT = {}
  OUTPUT = TNil.new

  def initialize(*args)
    @args = args
    @arg = {}
    @argtypes = {}
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
      @argtypes[@manifest.keys[i]] = TAny[v]
    end
  end

  def validate
    raise ArgumentError, "#{self.class.name} got #{@args.size} instead of #{@manifest.size}" unless @args.size == @manifest.size
    @manifest.each do |k,v|
      @argtypes[k].validate @arg[k]
    end
  end
end

class FlagCommand < Command
  FLAGS = {}

  def initialize(flags, *args)
    @flags = flags
    @args = args
    @arg = {}
    @argtypes = {}
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
  puts "OK"
  cpy = Copy.new(sel.output.instantiate)
  p cpy.input
  p cpy.output
  p cpy.arg
end
