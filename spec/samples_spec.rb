require 'yaml'

describe "Sample script:" do
  Dir["sample/*.vir"].each do |file|
    describe file do 
      it "parses to the correct parse tree" do
        parser = Vir::Parser.new
        out = parser.parse(File.read(file))
        out.should == YAML.load(File.read(file + ".parse"))
      end

      pending "transforms to the correct AST"
      pending "compiles to the correct bytecode"
      pending "gives the correct output"
    end
  end
end