require "set.rb"

Token = Struct.new(:symbol, :lexeme, :line_number)
LR0_Item = Struct.new(:lhs, :rhs, :dpos)

class Production
	attr_reader :lhs
	attr_reader :rhs
	def initialize(lhs, rhs)
		@lhs = lhs
		@rhs = Set.new(rhs.split(/\s*\|\s*/))
	end
	
	def add_rhs(stuff)
		@rhs.merge(stuff)
	end
end

class DFA_State
	attr_reader :transition
	attr_reader :label
	attr_reader :id
	
	def initialize(label, id)
		@label = label #set of LR0 items
		@id = id
		@transition = {} #key = symbol(string), value =  DFA_State
	end
	
	def add_transition(sym, q)
		if @transition.has_key?(sym)
			raise "poopy"
		end
		@transition[sym] = q
	end
	
	def label_name
		label = ""
		@label.each do |item|
			dpos = item.rhs.clone.insert(item.dpos, "*").join(" ")
			dpos.gsub!(/lambda|epsilon|λ/i, "")
			label += sprintf("%s -> %s\n", item.lhs, dpos)
		end
		return label
	end
	
end

class Parse_Tree
	attr_accessor :root
	attr_reader :node_labels
	
	def initialize()
		@root = nil
		@node_labels = {}
	end
	
	def export_dot
		tree = File.open("tree.dot", "w")
		tree.puts("digraph G {")
		@node_labels.each do |id, label|
			tree.puts(sprintf("%i [label=\"%s\"]", id, label))
		end
		tree.puts("\n")
		tree.puts(@root.get_dot_info)
		tree.puts("}")
		puts "Outputted LR parse tree to tree.dot"
		tree.close
	end
end

class Tree_Node
	attr_reader :label
	attr_reader :children
	attr_reader :id
	attr_reader :type
	
	def initialize(label, type, id)
		@label = label
		@type = type
		@id = id
		@children = []
	end
	
	def graft(child)
		@children.push(child)
	end
	
	def dot_label
		" [label=\"" + @label + "\"]"
	end
	
	def get_production
		p = @label + " ->"
		@children.reverse.each do |child|
			p <<= " " << child.label
		end
		return p
	end
	
	def get_dot_info(depth = 0)
		#dot_info = depth == 0 ? "" : dot_label
		#dot_info = depth == 0 ? "" : @id.to_s
		dot_info = ""
		#dot_info = "\"" + @label + "\""
		#dot_info = dot_info + "\"[label="+dot_info+"]"
		#dot_info <<= "->"
		@children.reverse.each do |child|
			dot_info <<= @id.to_s#dot_label
			dot_info <<= "->"
			dot_info <<= child.id.to_s + ";\n"
			#break if depth > 0
			dot_info <<= child.get_dot_info(depth+1)
			#dot_info <<= ";\n"
			#dot_info <<= child.get_dot_info
		end
		#dot_info <<= ";"
		return dot_info
	end
end

class Tokenizer
	attr_reader :nullables
	attr_reader :tokens
	attr_reader :first
	attr_reader :follow
	attr_reader :lr0_dfa
	attr_reader :lr0_table
	attr_reader :parse_tree

	def parse_grammar(grammar_file)
		file = File.open(grammar_file, "r")
		file_data = file.read.force_encoding("λ".encoding)
		file.close
		data = file_data.split(/\n\n+/)
		token_data = data[0]
		production_data = data[1]
		
		#note: don't use a set or dictionary for tokens. tokenization order DOES matter
		@tokens = [[:whitespace, "(\s|\n)+"]]
		replacements = []
		token_data = token_data.split(/\n+/)
		token_data.each do |line|
			token = line.split(/\s*->\s*/)
			if @tokens.include?(token[0])
				puts "\nMultiple token definition error"
				return false
			end
			@tokens.push([token[0], token[1]])
		end
		#@tokens.push(["EOF", "\$"])
		
		@productions = Set.new
		production_data = production_data.split(/\n+/)
		production_data.each do |line|
			p = line.split(/\s*->\s*/)
			production = Production.new(p[0], p[1])
			repeat = false
			@productions.each do |p|
				if p.lhs == production.lhs
					p.add_rhs(production.rhs)
					repeat = true
					break
				end
			end
			@start_symbol = production.lhs unless @start_symbol
			@productions.add(production) unless repeat
		end
		return true
	end
	
	def tokenize_file(input_file)
		file = File.open(input_file, "r")
		@input = file.read#.downcase #lazy, should have regex ignore case #+ "$"
		@input.gsub!(/#[^#]*#/, "")
		file.close
		token_output = []
		
		i = 0
		line_number = 0
		original_i = 0
		while(i < @input.length)
			if original_i == -1
				break
			end
			original_i = i
			@tokens.each {|token|
				sym = token[0]
				regex = Regexp.new(token[1], Regexp::IGNORECASE)
				m = regex.match(@input, i)
				
				if m != nil #&& m.start == i
					if m.begin(0) == i
						token_output.push(Token.new(sym, m[0], line_number)) unless sym == :whitespace
						line_number += m[0].count("\n")
						i += m[0].length
						break
					else
						next
					end
				else
					next
					#error?
				end
			}
			if original_i == i
				puts "\nError: Cannot tokenize. Error at line " + line_number.to_s
				return false
			end
		end
		return token_output
	end
	
	def get_nullables
		@nullables = Set.new
		loop do
			new_nullables = false
			@productions.each do |prod|
				prod.rhs.each do |p|
					unless nullable?(prod.lhs)
						if empty_string?(p)
							@nullables.add(prod.lhs)
							new_nullables = true
							break
						elsif p.split(/\s+/).all? {|sp| nullable?(sp)}
							@nullables.add(prod.lhs)
							new_nullables = true
							break
						end
					end
				end
			end
			break unless new_nullables
		end
		return true
	end
	
	def get_first
		get_nullables unless @nullables
		@first = {}
		@first["λ"] = Set.new
		@first["lambda"] = Set.new
		@first["epsilon"] = Set.new
		@tokens.each {|t| @first[t[0]] = Set.new([t[0]])}
		@productions.each {|p| @first[p.lhs] = Set.new}
		loop do
			new_first = false
			@productions.each do |production|
				production.rhs.each do |prod|
					prod.split(/\s+/).each do |p| #fix this?
						l = @first[production.lhs].size
						#@first[production.lhs] = @first[production.lhs] | @first[p]
						@first[production.lhs].merge(@first[p]) unless @first[p].nil?
						new_first ||= @first[production.lhs].size > l
						break unless nullable?(p)
					end
				end
			end
			break unless new_first
		end
		@tokens.each {|t| @first.delete(t[0])} #so only nonterminals
		@first.delete("λ")
		@first.delete("lambda")
		@first.delete("epsilon")
		@first.delete(:whitespace)
		return @first
	end
	
	def get_follow
		get_first unless @first
		@follow = {}
		@tokens.each {|t| @follow[t[0]] = Set.new}
		@productions.each {|p| @follow[p.lhs] = Set.new}
		@follow[@start_symbol] = Set.new(["$"])
		loop do
			new_follow = false
			@productions.each do |n|
				n.rhs.each do |prod|
					p = prod.split(/\s+/) #fix this?
					for i in 0..p.size-1
						x = p[i]
						if !terminal?(x)
							broke_out = false
							l = @follow[x].size
							if i < p.size
								for y in p[i+1..-1]
									if !terminal?(y)
										@follow[x].merge(@first[y])
									elsif y != "$"
										@follow[x].add(y)
									end
									if !nullable?(y)
										broke_out = true
										break
									end
								end
								if !broke_out
									#puts x, n.inspect
									@follow[x].merge(@follow[n.lhs])
								end
							end
							new_follow |= @follow[x].size > l
						end
					end
				end
			end
			break unless new_follow
		end
		@tokens.each {|t| @follow.delete(t[0])} #so only nonterminals
		@follow.delete(:whitespace)
		return @follow
	end
	
	def build_ll1_parse_table
		get_follow unless @follow
		#return false if cannot tokenize
		@table = {}
		@productions.each do |p|
			columns = {}
			@tokens.each do |t|
				next if t[0] == :whitespace
				columns[t[0]] = nil
			end
			columns["$"] = nil
			@table[p.lhs] = columns
		end
		puts ""
		@productions.each do |production|
			symbol = production.lhs
			production.rhs.each do |p|
				find_first(p, @follow[symbol]).each do |s|
					#return false if this cell has something in it
					unless @table[symbol][s].nil? || @table[symbol][s] == p
						puts "table[" + symbol.to_s + "][" + s.to_s + "] contains \"" + @table[symbol][s] + "\", tried to add \"" + p + "\""
						return false
					end
					@table[symbol][s] = p
				end
				if all_nullable?(p)
					@follow[symbol].each do |s|
						#return false if this cell has something in it
						unless @table[symbol][s].nil? || @table[symbol][s] == p
							puts "table[" + symbol.to_s + "][" + s.to_s + "] contains " + @table[symbol][s] + ", tried to add " + p
							return false
						end
						@table[symbol][s] = p
					end
				end
			end
		end
		return true
	end
	
	def ll1_parse(tokens)
		build_ll1_parse_table unless @table
		stack = []
		stack.push(@start_symbol)
		tokens.push(Token.new("$", "$", -1))
		tid = 0
		#puts stack.to_s
		loop do
			s = stack[-1] rescue nil
			type = tokens[tid].symbol rescue nil
			return false if type.nil?
			
			if terminal?(s) && s == type #s is a terminal and s == t
				#Option 1
				#puts s + " is a terminal and matches " + type + ", so we pop the stack"
				stack.pop
				#puts stack.to_s
				tid += 1
			elsif terminal?(s) #s is a terminal and s != t
				#Option 2
				puts "LL(1) parse error: Expected " + s + ", got " + type
				return false
			elsif @table[s][type].nil? #s is a nonterminal and table[s][t] is empty
				#Option 3
				puts "LL(1) parse error: " + s + " cannot possibly lead to " + type
				return false
			else #s is a nonterminal and table[s][t] is non-empty
				#Option 4
				#puts s + " is a nonterminal, so we push " + @table[s][type] + " onto the stack"
				stack.pop
				unless empty_string?(@table[s][type])
					@table[s][type].split(/\s+/).reverse.each do |symbol|
						stack.push(symbol)
					end
					#puts stack.to_s
				end
			end
			break if stack.empty?
		end
		return tid == tokens.length-1
	end
	
	def build_lr0_dfa
		l = Set.new
		l.add(LR0_Item.new("S'", [@start_symbol], 0))
		@follow["S'"] = Set.new(["$"])
		compute_closure(l)
		@lr0_dfa = {}
		@state_num = -1
		@lr0_start_state = DFA_State.new(l, @state_num += 1)
		to_do = [@lr0_start_state]
		@lr0_dfa[l] = @lr0_start_state

		while !to_do.empty?
			q = to_do.pop
			a = {}
			q.label.each do |item|
				if item.dpos < item.rhs.length #not at end of production rhs
					sym = item.rhs[item.dpos] #thing after the dot
					#outgoing edge labeled with sym
					item2 = LR0_Item.new(item.lhs, item.rhs, item.dpos+1)
					a[sym] = Set.new() unless a.has_key?(sym)
					a[sym].add(item2)
					# s = Set.new()
					# s.add(item2)
					# compute_closure(s)
					# q2 = DFA_State.new(s)
					# to_do.push(q2)
					# start.add_transition(sym, q2)
				end
			end
			a.each do |k, v|
				next if empty_string?(k) #don't need lambda transitions and states
				compute_closure(v)
				unless @lr0_dfa.has_key?(v)
					q2 = DFA_State.new(v, @state_num += 1)
					@lr0_dfa[v] = q2
					to_do.push(q2)
				end
				q.add_transition(k, @lr0_dfa[v])
			end
		end
		return @lr0_dfa
	end
	
	def build_lr0_table #actually slr(0)
		build_lr0_dfa unless @lr0_dfa
		@lr0_table = {}
		@html_table = {}
		table_rows = ["$"]
		@tokens.each do |token|
			next if token[0] == :whitespace
			table_rows.push(token[0])
		end
		@productions.each do |p|
			table_rows.push(p.lhs)
		end
		
		puts ""
		@lr0_dfa.values.each do |state|
			columns = {}
			table_rows.each do |row|
				columns[row] = :empty
			end
			@lr0_table[state.id] = columns
		end
		@lr0_dfa.values.each do |state|
			state.label.each do |item|
				entry = [:reduce, item.rhs.length, item.lhs]
				entry[1] = 0 if empty_string?(item.rhs[0])
				if item.dpos == item.rhs.length || empty_string?(item.rhs[0])
					table_rows.each do |symbol|
						next unless terminal?(symbol) && @follow[item.lhs].include?(symbol)
						if @lr0_table[state.id][symbol] != :empty
							puts sprintf("Encountered a reduce-reduce conflict at table[%i][%s]", state.id, symbol)							
							@lr0_table[state.id][symbol].push(entry)
						else
							@lr0_table[state.id][symbol] = [entry]
						end
					end
				end
			end
			state.transition.each do |label, state2|
				if @lr0_table[state.id][label] != :empty
					puts sprintf("Encountered a shift-reduce conflict at table[%i][%s]", state.id, label)
					@lr0_table[state.id][label].push([:shift, state2.id])
				else
					@lr0_table[state.id][label] = terminal?(label) ? [[:shift, state2.id]] : [[:transition, state2.id]]
				end
			end
		end
		return true
	end
	
	def lr_parse(parse_table, tokens)
		if parse_table.nil?
			@lr_table = @lr0_table
		else
			f = File.open(parse_table, "r")
			table = f.read
			f.close
			line_num = 1
			@lr_table = {}
			
			table_rows = ["$"]
			@tokens.each do |token|
				next if token[0] == :whitespace
				table_rows.push(token[0])
			end
			@productions.each do |p|
				table_rows.push(p.lhs)
			end
			
			@lr0_dfa.values.each do |state|
				columns = {}
				table_rows.each do |row|
					columns[row] = :empty
				end
				@lr_table[state.id] = columns
			end
			
			table.split(/\n/).each do |line|
				if line =~ /(\d+)\s+(\S+)\s+([ST])\s+(\d+)/i #shift or transition
					state_number = $1.to_i
					symbol = $2
					operation = $3 == "S" ? :shift : :transition
					state_going_to = $4.to_i
					if @lr_table[state_number][symbol] == :empty
						@lr_table[state_number][symbol] = [[operation, state_going_to]]
					else
						if @lr_table[state_number][symbol].any?{|e| e[0] == :reduce}
							puts sprintf("Encountered a shift-reduce conflict at table[%i][%s]", state_number, symbol)
						end
						@lr_table[state_number][symbol].push([operation, state_going_to])
					end
					#if transition, symbol MUST be a state. if shift, symbol MUST be a token
				elsif line =~ /(\d+)\s+(\S+)\s+R\s+(\d+)\s+((\w|')+)/i #reduce
					state_number = $1.to_i
					symbol = $2
					operation = :reduce
					num_to_reduce = $3.to_i
					state_reducing_to = $4
					#@lr_table[state_number][symbol] = [operation, num_to_reduce, state_reducing_to]
					if @lr_table[state_number][symbol] == :empty
						@lr_table[state_number][symbol] = [[operation, num_to_reduce, state_reducing_to]]
					else
						if @lr_table[state_number][symbol].any?{|e| e[0] == :shift}
							puts sprintf("Encountered a shift-reduce conflict at table[%i][%s]", state_number, symbol)
						elsif @lr_table[state_number][symbol].any?{|e| e[0] == :reduce}
							raise sprintf("Reduce-reduce conflict at table[%i][%s]", state_number, symbol)
						end
						@lr_table[state_number][symbol].push([operation, num_to_reduce, state_reducing_to])
					end
				else
					raise sprintf("Line %i in table does not match specification", line_num)
				end
				line_num += 1
			end
		end
		#puts @lr_table.inspect
		stack = [@lr0_start_state.id] #assuming start state. probably always 0
		node_id = 0
		tree_stack = [nil]
		@parse_tree = Parse_Tree.new
		loop do
			sym = tokens[0].symbol rescue "$"
			row = stack[-1]
			#puts "Looking in table[" + row.to_s + "][" + sym + "].."
			raise sprintf("Empty table entry table[%i][%s]", row, sym) if @lr_table[row][sym] == :empty
			entry = @lr_table[row][sym]
			if entry.any? {|e| e[0] == :shift}
				entry = entry.find{|e| e[0] == :shift} #prefer shifts in conflicts
			else
				entry = entry[0]
			end
			
			case entry[0]
			when :transition #same as shift but not consuming input
				stack.push(entry[1])
			when :shift
				t = tokens.shift
				node = Tree_Node.new(t.lexeme, t.symbol, node_id += 1)
				@parse_tree.node_labels[node_id] = node.label
				stack.push(entry[1])
				tree_stack.push(node)
			when :reduce
				num_to_pop = entry[1]
				lhs = entry[2]
				node = Tree_Node.new(lhs, nil, node_id += 1)
				@parse_tree.node_labels[node_id] = node.label
				num_to_pop.times do |i|
					stack.pop
					node.graft(tree_stack.pop)
				end
				
				#q = parse_table.nil? ? @lr_table[stack[-1]][lhs][0][1] : @lr_table[stack[-1]][lhs][1]
				q =@lr_table[stack[-1]][lhs][0][1]
				stack.push(q)
				tree_stack.push(node)
				if lhs == @start_symbol #accept!
					#if num_to_pop == 0 #if got here by a reduce of 0
						tree_stack.pop
						until tree_stack[-1].nil?
							node.graft(tree_stack.pop)
						end
					#end
					@parse_tree.root = node
					break
				end
			else
				raise "Unknown parse table operation " + entry[0].to_s
			end
		end
	end
	
	def interpret_wiseau #not truly possible irl
		@variables = {}
		@current_variable = nil #whatever tommy is thinking about
		walk_wiseau(@parse_tree.root)
		return true
	end
	
	def walk_wiseau(node)
		params = node.children.reverse
		case node.label
		when "S"
			if node.children.size == 2 #anything theEnd
				walk_wiseau(params[0])
				walk_wiseau(params[1])
			else #lambda
				return true
			end
		when "anything" #declareVar anything | setVar anything | print anything | incrementVar anything | randomizeVar anything | lambda
			if node.children.size == 2 #actual stuff
				walk_wiseau(params[0])
				walk_wiseau(params[1])
			else #lambda
				return true
			end
		when "declareVar" #declareVar -> HI optionalComma NAME PERIOD | OHI optionalComma NAME PERIOD | USED_TO_KNOW NAME PERIOD
			var_name = node.children.size == 3 ? params[1].label : params[2].label
			@variables[var_name] = rand(2004) unless @variables[var_name]
			@current_variable = var_name
		when "setVar" #NAME optionalComma NUMBER IS GREAT_BUT NUMBER IS A_CROWD PERIOD | SHE_HAD NUMBER GUYS_OR_GALS PERIOD
			if node.children.size == 4
				@variables[@current_variable] = params[1].label.to_i
			else
				get_variable(params[0].label)
				@variables[params[0].label] = params[5].label.to_i
				@current_variable = params[0].label
			end
		when "incrementVar" #HAH PERIOD
			get_variable(@current_variable)
			@variables[@current_variable] += params[0].label.count("a")
		when "decrementVar" #CHEEPS PERIOD
			get_variable(@current_variable)
			@variables[@current_variable] -= params[0].label.count("p")
		when "randomizeVar" #PEOPLE_ARE_STRANGE PERIOD | NAME IS_STRANGE PERIOD
			if node.children.size == 2 #PEOPLE_ARE_STRANGE PERIOD
				@variables[@current_variable] = rand()
			else #NAME IS_STRANGE PERIOD
				get_variable(params[0].label)
				@variables[@params[0].label] = rand()
			end
		when "getInput" #NO_SECRETS PERIOD
			puts params[0].label
			@variables[@current_variable] = gets.chomp
		when "print" #printVar | printString
			walk_wiseau(params[0])
		when "printVar" #YOU_KNOW_WHAT_THEY_SAY COMMA NAME IS_BLIND PERIOD | WHAT_A_STORY optionalComma NAME PERIOD | ANYWAY_HOW_IS_YOUR_SEX_LIFE QUESTION
			if node.children.size == 2 #WHAT_A_STORY optionalComma NAME PERIOD
				puts @variables[@current_variable]
			else
				puts @variables[params[2].label]
				@current_variable = params[2].label
			end
		when "printString" #YOU_KNOW_WHAT_THEY_SAY COMMA QUOTE PERIOD
			puts params[2].label.tr("\"","") #need a better way of doing this
		when "theEnd"
			return true
		else
			puts "Unknown node type " + node.label
		end
	end
	
	def get_variable(v)
		raise "Undefined variable " + v unless @variables.has_key?(v)
		raise "Uninitialized variable " + v if @variables[v] == :uninitialized
		return v
	end
	
	def compute_closure(s)
		#input: set of LR0 Items + nonterminals + their productions
		#output: set of LR0 Items: the closure
		loop do
			flag = false
			#see if we can expand s
			s2 = s.clone
			s2.each do |item|
				#does item give rise to more stuff?
				if item.dpos < item.rhs.length
					sym = item.rhs[item.dpos]
					#if thing after item's bullet is nonterminal
					iter = @productions.find{|pp| pp.lhs == sym}.rhs rescue []
					iter.each do |p|
						rhs = p.split(/\s+/)
						unless (s.any?{|i| i.lhs == sym && i.rhs == rhs && i.dpos == 0})#== item.dpos})
							flag = true
							s.add(LR0_Item.new(sym, rhs, 0))
						end
					end
				end
			end
			break unless flag
		end
	end
	
	def find_first(production, extra)
		s = Set.new
		production.split(/\s+/).each do |p| #fix this?
			if !terminal?(p)
				s.merge(@first[p])
			else
				s.add(p)
			end
			return s unless nullable?(p)
		end
		return s.merge(extra)
	end
	
	def all_nullable?(production)
		production.split(/\s+/).each do |p|
			return false unless nullable?(p)
		end
		return true
	end
	
	def nullable?(t)
		return true if empty_string?(t)
		return @nullables.include?(t)
	end
	
	def empty_string?(t)
		#lambda = [206, 187]
		return true if t == "λ"
		return true if t == "lambda"
		return t == "epsilon"
	end
	
	def get_token_value(t)
		@tokens.each do |token|
			if token[0] == t
				return Regexp.new(token[1])
			end
		end
	end
	
	def terminal?(symbol)
		!(@productions.any? {|p| p.lhs == symbol})
	end
	
end #tokenizer class

grammar = ARGV[0] rescue nil
input_file = ARGV[1] rescue nil

raise "Grammar not specified" if grammar.nil?
raise "Input file not specified" if input_file.nil?

tokenizer = Tokenizer.new
return unless tokenizer.parse_grammar(grammar)
tokenizer.get_nullables
tokenizer.get_first
tokenizer.get_follow
tokenizer.build_lr0_dfa
tokens = tokenizer.tokenize_file(input_file)
if tokens
	tokenizer.build_lr0_table
	tokenizer.lr_parse(nil, tokens)
	#tokenizer.parse_tree.export_dot
	tokenizer.interpret_wiseau
end