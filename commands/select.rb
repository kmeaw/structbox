class Select < FlagCommand
  INPUT = {names: TList.new(TString.new), pipe: TPipe.new(TAnyStruct.new)} # stub input type

  def input
    @manifest = self.class::INPUT
    self.populate
    self.validate
    {names: TList.new(TString.new), pipe: TPipe.new(TStruct.new(Hash[@arg[:names].map{|k| [k.to_sym, @arg[:pipe].kind.kinds[k.to_sym]]}]))}
  end

  def output
    TPipe.new(TStruct.new(Hash[@arg[:names].map{|k| [k.to_sym, @arg[:pipe].kind.kinds[k.to_sym]]}]))
  end
end
