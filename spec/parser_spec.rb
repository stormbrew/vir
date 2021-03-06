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

	describe 'parses a variable reference' do
		it 'to the local scope' do
			parser.parse('$blah').should == {:statement=>{:local_var=>{:name=>'blah'}, :doc=>[]}}
		end

		it 'to self' do
			parser.parse('@').should == {:statement=>{:self=>'@', :doc=>[]}}
		end

		it 'to module self' do
			parser.parse('@@').should == {:statement=>{:mod_self=>'@@', :doc=>[]}}
		end

		it 'to instance scope' do
			parser.parse('@blah').should == {:statement=>{:instance_var=>{:name=>'blah'}, :doc=>[]}}
		end

		it 'to module (global) scope' do
			parser.parse('@@blah').should == {:statement=>{:module_var=>{:name=>'blah'}, :doc=>[]}}
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

		it 'to a variable' do
			parser.parse('$x(1,2,3)').should == {:statement=>{:call=>{:ref=>{:on=>{:local_var=>{:name=>"x"}}}, :args=>[{:integer=>"1"}, {:integer=>"2"}, {:integer=>"3"}], :blocks=>[]}, :doc=>[]}}
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

			it 'with an expression as a block name' do
				parser.parse('blah 1+1: {}').should == {:statement=>{:call=>{:ref=>{:name=>"blah"}, :blocks=>[{:block=>{:lines=>[], :name=>{:sum=>[{:integer=>"1"}, {:op=>"+", :integer=>"1"}]}}}]}, :doc=>[]}}
			end

			describe 'with a block argument list' do
				it 'that is empty' do
					parser.parse('blah do:() {}').should == {:statement=>{:doc=>[], :call=>{:ref=>{:name=>"blah"}, :blocks=>[{:block=>{:name=>{:symbol=>"do"}, :lines=>[], :args=>[]}}]}}}
				end
				it 'that has a single name in it' do
					parser.parse('blah do:(name1) {}').should == {:statement=>{:doc=>[], :call=>{:ref=>{:name=>"blah"}, :blocks=>[{:block=>{:name=>{:symbol=>"do"}, :lines=>[], :args=>[{:name=>"name1"}]}}]}}}
				end
				it 'that has multiple names in it' do
					parser.parse('blah do:(name1, name2) {}').should == {:statement=>{:doc=>[], :call=>{:ref=>{:name=>"blah"}, :blocks=>[{:block=>{:name=>{:symbol=>"do"}, :lines=>[], :args=>[{:name=>"name1"}, {:name=>"name2"}]}}]}}}
				end

				it 'that has an argument with a *prefix (splat)' do
					parser.parse('blah do:(*splat) {}').should == {:statement=>{:doc=>[], :call=>{:ref=>{:name=>"blah"}, :blocks=>[{:block=>{:name=>{:symbol=>"do"}, :lines=>[], :args=>[{:prefix=>'*', :name=>"splat"}]}}]}}}
				end
				it 'that has an argument with a **prefix (hashsplat)' do
					parser.parse('blah do:(**hashsplat) {}').should == {:statement=>{:doc=>[], :call=>{:ref=>{:name=>"blah"}, :blocks=>[{:block=>{:name=>{:symbol=>"do"}, :lines=>[], :args=>[{:prefix=>'**', :name=>"hashsplat"}]}}]}}}
				end
				it 'that has an argument with a &prefix (messagesplat)' do
					parser.parse('blah do:(&msg) {}').should == {:statement=>{:doc=>[], :call=>{:ref=>{:name=>"blah"}, :blocks=>[{:block=>{:name=>{:symbol=>"do"}, :lines=>[], :args=>[{:prefix=>'&', :name=>"msg"}]}}]}}}
				end

				it 'that has an argument with a default value' do
					parser.parse('blah do:(arg: 10) {}').should == {:statement=>{:doc=>[], :call=>{:ref=>{:name=>"blah"}, :blocks=>[{:block=>{:name=>{:symbol=>"do"}, :lines=>[], :args=>[{:default=>{:integer=>"10"}, :name=>"arg"}]}}]}}}
				end

				it 'that has an argument with a typespec' do
					parser.parse('blah do:(arg as integer) {}').should == {:statement=>{:doc=>[], :call=>{:ref=>{:name=>"blah"}, :blocks=>[{:block=>{:name=>{:symbol=>"do"}, :lines=>[], :args=>[{:type=>{:symbol=>"integer"}, :name=>"arg"}]}}]}}}
				end

				it 'that has an argument with a default value and typespec' do
					parser.parse('blah do:(arg:10 as integer) {}').should == {:statement=>{:doc=>[], :call=>{:ref=>{:name=>"blah"}, :blocks=>[{:block=>{:name=>{:symbol=>"do"}, :args=>[{:name=>"arg", :default=>{:integer=>"10"}, :type=>{:symbol=>"integer"}}], :lines=>[]}}]}}}
				end
			end

			it 'with statements within the block' do
				parser.parse('blah do: { stuff }').should == {:statement=>{:call=>{:ref=>{:name=>"blah"}, :blocks=>[{:block=>{:lines=>[{:statement=>{:doc=>[], :symbol=>"stuff"}}], :name=>{:symbol=>"do"}}}]}, :doc=>[]}}
			end

			it 'with multiple statements within the block separated by semicolon' do
				parser.parse('blah do: { stuff; more_stuff }').should == {:statement=>{:call=>{:ref=>{:name=>"blah"}, :blocks=>[{:block=>{:lines=>[{:statement=>{:doc=>[], :symbol=>"stuff"}}, {:statement=>{:doc=>[], :symbol=>"more_stuff"}}], :name=>{:symbol=>"do"}}}]}, :doc=>[]}}
			end

			it 'with a statement within the block but on different lines' do
				parser.parse('blah do: {
				stuff
				}').should == {:statement=>{:call=>{:ref=>{:name=>"blah"}, :blocks=>[{:block=>{:lines=>[{:statement=>{:doc=>[], :symbol=>"stuff"}}], :name=>{:symbol=>"do"}}}]}, :doc=>[]}}
			end

			it 'with multiple statements on separate lines' do
				parser.parse('blah do: {
				stuff
				more_stuff
				}').should == {:statement=>{:call=>{:ref=>{:name=>"blah"}, :blocks=>[{:block=>{:lines=>[{:statement=>{:doc=>[], :symbol=>"stuff"}}, {:statement=>{:doc=>[], :symbol=>"more_stuff"}}], :name=>{:symbol=>"do"}}}]}, :doc=>[]}}
			end

			it 'with multiple statements on separate lines ignores empty lines' do
				parser.parse('blah do: {
				stuff

				more_stuff
				}').should == {:statement=>{:call=>{:ref=>{:name=>"blah"}, :blocks=>[{:block=>{:lines=>[{:statement=>{:doc=>[], :symbol=>"stuff"}}, {:statement=>{:doc=>[], :symbol=>"more_stuff"}}], :name=>{:symbol=>"do"}}}]}, :doc=>[]}}
			end

			it 'with a value expression as the "block"' do
				parser.parse('if do: true').should == {:statement=>{:doc=>[], :call=>{:ref=>{:name=>"if"}, :blocks=>[{:block=>{:value=>{:true=>"true"}, :name=>{:symbol=>"do"}}}]}}}
			end
			it 'with multiple blocks that are value expressions' do
				parser.parse('if do: true else: false').should == {:statement=>{:doc=>[], :call=>{:ref=>{:name=>"if"}, :blocks=>[{:block=>{:value=>{:true=>"true"}, :name=>{:symbol=>"do"}}}, {:block=>{:value=>{:false=>"false"}, :name=>{:symbol=>"else"}}}]}}}
			end
			it 'with a value expression prefixed by an ampersand' do
				parser.parse('if do: &true').should == {:statement=>{:doc=>[], :call=>{:ref=>{:name=>"if"}, :blocks=>[{:block=>{:value=>{:true=>"true"}, :name=>{:symbol=>"do"}}}]}}}
			end
			it 'with a hash value expression prefixed by an ampersand' do
				parser.parse('if do: &{a:b}').should == {:statement=>{:doc=>[], :call=>{:ref=>{:name=>"if"}, :blocks=>[{:block=>{:value=>{:map=>{:entries=>[{:key=>{:symbol=>"a"}, :value=>{:symbol=>"b"}}]}}, :name=>{:symbol=>"do"}}}]}}}
			end
		end
	end

	describe 'parses comments' do
		describe 'that start with #' do
			it 'before a statement as documentation for that statement' do
				parser.parse('#blah
				blorp').should == {:statement=>{:doc=>[{:text=>"blah"}], :symbol=>"blorp"}}
			end

			it 'within a statement as inline comments as part of that statement' do
				parser.parse('blorp + #blah
				zoop').should == {:statement=>{:doc=>[], :sum=>[{:symbol=>"blorp"}, {:op=>"+"}, {:inline_doc=>{:text=>"blah"}}, {:symbol=>"zoop"}]}}
			end
		end

		describe 'that start with //' do
			it 'before a statement as documentation for that statement' do
				parser.parse('//blah
				blorp').should == {:statement=>{:doc=>[{:text=>"blah"}], :symbol=>"blorp"}}
			end

			it 'within a statement as inline comments as part of that statement' do
				parser.parse('blorp + //blah
				zoop').should == {:statement=>{:doc=>[], :sum=>[{:symbol=>"blorp"}, {:op=>"+"}, {:inline_doc=>{:text=>"blah"}}, {:symbol=>"zoop"}]}}
			end
		end

		describe 'that start with /*' do
			it 'before a statement as documentation for that statement' do
				parser.parse('/*blah*/
				blorp').should == {:statement=>{:doc=>[{:text=>"blah"}], :symbol=>"blorp"}}
			end
			it 'before a statement that is on multiple lines as documentation for that statement' do
				parser.parse('/*blah
				blorp
				zoop */
				blorp').should == {:statement=>{:doc=>[{:text=>"blah\n\t\t\t\tblorp\n\t\t\t\tzoop "}], :symbol=>"blorp"}}
			end

			it 'within a statement as inline comments as part of that statement' do
				parser.parse('blorp + /*blah*/ zoop').should == {:statement=>{:doc=>[], :sum=>[{:symbol=>"blorp"}, {:op=>"+"}, {:inline_doc=>{:text=>"blah"}}, {:symbol=>"zoop"}]}}
				parser.parse('blorp + /*blah*/
				zoop').should == {:statement=>{:doc=>[], :sum=>[{:symbol=>"blorp"}, {:op=>"+"}, {:inline_doc=>{:text=>"blah"}}, {:symbol=>"zoop"}]}}
			end
			it 'within a statement on multiple lines as inline comments as part of that statement' do
				parser.parse('blorp + /*blah
				blorp*/ zoop').should == {:statement=>{:doc=>[], :sum=>[{:symbol=>"blorp"}, {:op=>"+"}, {:inline_doc=>{:text=>"blah\n\t\t\t\tblorp"}}, {:symbol=>"zoop"}]}}
			end
		end

		it 'multiple times before a statement as documentation for that statement' do
			parser.parse('#blah
			//zoop
			/*doop*/
			blorp').should == {:statement=>{:doc=>[{:text=>"blah"}, {:text=>"zoop"}, {:text=>'doop'}], :symbol=>"blorp"}}
		end
	end
end