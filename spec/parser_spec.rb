require 'bundler/setup'
require 'vir/parser'

describe Vir::Parser do
	let(:parser) { Vir::Parser.new }
	it 'parses a simple numeric constant expression' do
		parser.parse("1").should == {:statement=>{:doc=>[], :integer=>"1"}}
	end
	it 'parses a simple symbolic constant expression' do
		parser.parse("boom").should == {:statement=>{:doc=>[], :symbol=>"boom"}}
	end
	it 'parses a simple string constant expression' do
		parser.parse('"boom"').should == {:statement=>{:doc=>[], :string=>'"boom"'}}
	end
	describe 'parses an array' do
		it 'that is empty' do
			parser.parse("[]").should == {:statement=>{:doc=>[], :list=>{:entries=>[]}}}
		end
		it 'that has one item' do
			parser.parse("[1]").should == {:statement=>{:doc=>[], :list=>{:entries=>[{:integer=>"1"}]}}}
		end
		it "that has many items" do
			parser.parse("[1,2,3]").should == {:statement=>{:doc=>[], :list=>{:entries=>[{:integer=>"1"},{:integer=>"2"},{:integer=>"3"}]}}}
		end
	end

	describe 'parses a call' do
		it 'that has no arguments and no target' do
			parser.parse('call()').should == {:statement=>{:call=>{:blocks=>[], :ref=>{:name=>"call"}}, :doc=>[]}}
		end
		it 'that has one argument and no target' do
			parser.parse('call(1)').should == {:statement=>{:call=>{:args=>{:integer=>"1"}, :blocks=>[], :ref=>{:name=>"call"}}, :doc=>[]}}
		end
		it 'that has many arguments and no target' do
			parser.parse('call(1,2,3)').should == {:statement=>{:call=>{:args=>[{:integer=>"1"},{:integer=>"2"},{:integer=>"3"}], :blocks=>[], :ref=>{:name=>"call"}}, :doc=>[]}}
		end

		it 'that has no arguments, no brackets, and a target' do
			parser.parse('blah.call').should == {:statement=>{:call=>{:ref=>{:on=>{:symbol=>"blah"}, :name=>"call"}}, :doc => []}}
		end
		it 'that has no arguments, brackets, and a target' do
			parser.parse('blah.call()').should == {:statement=>{:call=>{:blocks=>[], :ref=>{:on=>{:symbol=>'blah'}, :name=>"call"}}, :doc=>[]}}
		end
		it 'that has one argument and a target' do
			parser.parse('blah.call(1)').should == {:statement=>{:call=>{:args=>{:integer=>"1"}, :blocks=>[], :ref=>{:on=>{:symbol=>'blah'}, :name=>"call"}}, :doc=>[]}}
		end
		it 'that has many arguments and a target' do
			parser.parse('blah.call(1,2,3)').should == {:statement=>{:call=>{:ref=>{:on=>{:symbol=>"blah"}, :name=>"call"}, :args=>[{:integer=>"1"}, {:integer=>"2"}, {:integer=>"3"}], :blocks=>[]}, :doc=>[]}}
		end

		describe 'with a block' do
			it 'that takes no arguments, has no brackets' do
				parser.parse('blah do: {}').should == {:statement=>{:call=>{:ref=>{:name=>"blah"}, :blocks=>[{:block=>{:lines=>[], :name=>{:symbol=>"do"}}}]}, :doc=>[]}}
			end

			it 'that has an empty argument list' do
				parser.parse('blah() do: {}').should == {:statement=>{:call=>{:ref=>{:name=>"blah"}, :blocks=>[{:block=>{:lines=>[], :name=>{:symbol=>"do"}}}]}, :doc=>[]}}
			end

			it 'that takes an argument' do
				parser.parse('blah(1) do: {}').should == {:statement=>{:call=>{:ref=>{:name=>"blah"}, :args=>{:integer=>"1"}, :blocks=>[{:block=>{:lines=>[], :name=>{:symbol=>"do"}}}]}, :doc=>[]}}
			end

			it 'that has a target' do
				parser.parse('blah.blorp do: {}').should == {:statement=>{:call=>{:ref=>{:on=>{:symbol=>"blah"}, :name=>"blorp"}, :blocks=>[{:block=>{:lines=>[], :name=>{:symbol=>"do"}}}]}, :doc=>[]}}
			end

			it 'with more blocks' do
				parser.parse('blah do: {} else: {}').should == {:statement=>{:call=>{:ref=>{:name=>"blah"}, :blocks=>[{:block=>{:lines=>[], :name=>{:symbol=>"do"}}}, {:block=>{:lines=>[], :name=>{:symbol=>"else"}}}]}, :doc=>[]}}
			end

			it 'should allow for statements within the block' do
				parser.parse('blah do: { stuff }').should == {:statement=>{:call=>{:ref=>{:name=>"blah"}, :blocks=>[{:block=>{:lines=>[{:statement=>{:doc=>[], :symbol=>"stuff"}}], :name=>{:symbol=>"do"}}}]}, :doc=>[]}}
			end

			it 'should work with a multiline block' do
				parser.parse('blah do: {
				stuff
				}').should == {:statement=>{:call=>{:ref=>{:name=>"blah"}, :blocks=>[{:block=>{:lines=>[{:statement=>{:doc=>[], :symbol=>"stuff"}}], :name=>{:symbol=>"do"}}}]}, :doc=>[]}}
			end
		end
	end

end