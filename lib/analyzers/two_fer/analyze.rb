module TwoFer

  MESSAGES = {
    no_module: "No module or class called TwoFer",
    no_method: "No method called two_fer",
    splat_args: "Rather than using *%s, how about acutally setting a paramater called 'name'?",
    missing_default_param: "There is not a correct default param - the tests will fail",
    incorrect_default_param: "You could set the default value to 'you' to avoid conditionals",
    string_building: "Rather than using string building, use interpolation",
    kernel_format: "Rather than using the format method, use interpolation",
    string_format: "Rather than using string's format/percentage method, use interpolation"
  }

  class Analyze < ExerciseAnalyzer
    include Mandate

    def analyze!
      # Note that all "check_...!" methods exit this method if the solution
      # is approved or disapproved, so each step is only called if the
      # previous one has not resolved what to do.

      # Firstly we want to check that the structure of this
      # solution is correct and that there is nothing structural
      # stopping it from passing the tests
      check_structure!

      # Now we want to ensure that the method signature
      # is sane and that it has valid arguments
      check_method_signature!

      # There is one optimal solution for two-fer which needs
      # no commnents and can just be approved. If we have it, then
      # let's just acknowledge it and get out of here.
      check_for_optimal_solution!

      # We often see solutions that are correct but use different
      # string concatenation options (e.g. string#+, String.format, etc)
      # We'll approve these but want to leave a comment that introduces
      # them to string interpolation in case they don't know about it.
      check_for_correct_solution_without_string_interpolaton!

      # The most common error in twofer is people using conditionals
      # to check where the value passed in is nil, rather than using a defaul
      # value. We want to check for conditionals and tell the user about the
      # default paramater if we see one.
      check_for_conditional_on_default_argument!

      # Sometiems people specify the names (if name == "Alice" ...). If we
      # do this, suggest using string interpolation to make us of the
      # paramter, rather than using a conditional on it.
      # check_for_names!

      # We don't have any idea about this solution, so let's refer it to a
      # mentor and get exit our analysis.
      refer_to_mentor!
    end

    # ###
    # Analysis functions
    # ###
    def check_structure!
      # First we check that there is a two-fer class or module
      # and that it contains a method called two-fer
      disapprove!(:no_module) unless two_fer_module
      disapprove!(:no_method) unless main_method
    end

    def check_method_signature!
      # If there is no parameter or it doesn't have a default value,
      # then this solution won't pass the tests.
      disapprove!(:missing_default_param) if paramaters.size != 1

      # If they provide a splat, the tests can pass but we
      # should suggest they use a real paramater
      disapprove!(:splat_args, first_paramater_name) if first_paramater.restarg_type?

      # If they don't provide an optional argument the tests will fail
      disapprove!(:missing_default_param) unless first_paramater.optarg_type?
    end

    def check_for_optimal_solution!
      # The optional solution looks like this:
      #
      # def self.two_fer(name="you")
      #   "One for #{name}, one for me."
      # end
      # 
      # The default argument must be 'you', and it must just be a single
      # statement using interpolation. Other solutions might be approved
      # but this is the only one that we would approve without comment.

      return unless default_argument_is_optimal?
      return unless one_line_solution?
      return unless using_string_interpolation?

      # If the interpolation has more than three components, then they've
      # done something weird, so let's get a mentor to look at it!
      refer_to_mentor! unless string_interpolation_has_three_components?

      approve!
    end

    def check_for_correct_solution_without_string_interpolaton!
      # If we don't have a correct default argugment or a one line
      # solution then let's just get out of here.
      return unless default_argument_is_optimal?
      return unless one_line_solution?

      loc = first_line_in_method(main_method)

      # In the case of:
      # "One for " + name + ", one for me."
      if loc.method_name == :+ &&
         loc.arguments[0].type == :str
        approve!(:string_building)
      end

      # In the case of:
      # format("One for %s, one for me.", name)
      if loc.method_name == :format &&
         loc.receiver == nil &&
         loc.arguments[0].type == :str &&
         loc.arguments[1].type == :lvar
        approve!(:kernel_format)
      end

      # In the case of:
      # "One for %s, one for me." % name
      if loc.method_name == :% &&
         loc.receiver.type == :str &&
         loc.arguments[0].type == :lvar
        approve!(:string_format)
      end

      # If we have a one-line method that passes the tests, then it's not
      # soemthing we've planned for, so let's refer it to a mentor
      return refer_to_mentor!
    end

    def check_for_conditional_on_default_argument!
      loc = first_line_in_method(main_method)

      # If we don't have a conditional, then let's get out of here.
      #
      # TODO: We might wnt to refactor this to extract a conditional from the
      # method rather than insist on it being the first line.
      return unless loc.type == :if

      # Get the clause of the conditional (ie the bit after the "if" keyword)
      conditional = extract_conditional_clause(loc)

      # Let's warn about using a better default if they `if name == nil`
      if is_lvar?(conditional.receiver, :name) &&
         conditional.first_argument == default_argument
        disapprove!(:incorrect_default_param)
      end

      # Same thing but if they do it the other way round, ie `if nil == name`
      if conditional.receiver == default_argument &&
         is_lvar?(conditional.first_argument, :name)
        disapprove!(:incorrect_default_param)
      end
    end

    # ###
    # Analysis helpers
    # ###
    def default_argument_is_optimal?
      default_argument_value == "you"
    end

    def one_line_solution?
      main_method.body.line_count == 1
    end

    def using_string_interpolation?
      main_method.body.dstr_type?
    end

    def string_interpolation_has_three_components?
      #main_method.body.pry
      main_method.body.children.size == 3
    end

    # ###
    # Static analysis helpers
    # ###
    def num_lines_in_method(method)
      method.body.child_nodes.size
    end

    def first_line_in_method(method)
      # A begin block signifies multiple lines
      # so we return the first line.
      method.body.children.first if main_method.body.type == :begin

      # Without a begin block we just have one line,
      # so we return the method body, which *is* the first line
      method.body
    end

    # Is this an lvar (local variable) with a given name?
    def is_lvar?(node, name)
      node.lvar_type? && node.children[0] == name
    end

    def extract_conditional_clause(loc)
      loc.children[0]
    end

    memoize
    def two_fer_module
      ExtractModuleOrClass.(root_node, "TwoFer")
    end

    memoize
    def main_method
      ExtractClassMethod.(two_fer_module, "two_fer")
    end

    memoize
    def paramaters
      main_method.arguments
    end

    memoize
    def first_paramater
      paramaters.first
    end

    def first_paramater_name
      first_paramater.children[0]
    end

    def default_argument
      first_paramater.children[1]
    end

    def default_argument_value
      default_argument.children[0]
    end


    # ###
    # Flow helpers
    #
    # These are totally generic to all exercises and
    # can probably be extracted to parent
    # ###
    def approve!(msg = nil)
      self.messages << MESSAGES[msg] if msg
      self.approve = true

      raise FinishedFlowControlException
    end

    def refer_to_mentor!
      self.refer_to_mentor = true

      # Refering to mentor is an explicit
      # command resulting from weirdness
      # and should override approving
      self.approve = false

      raise FinishedFlowControlException
    end

    def disapprove!(msg, *msg_args)
      self.messages << (MESSAGES[msg] % msg_args)
      self.approve = false

      raise FinishedFlowControlException
    end
  end
end