defmodule Predicates.Utils do
  @doc """
  Tries to call a function (given as a function ref or `{Module, :name}` tuple) with as many arguments from `args` as
  possible, retrying with fewer arguments if the function call fails.

  The `min_args` argument specifies the minimum number of arguments that must be used.

  If a function is used, the call can fail with `BadArityError` if the function cannot be called with the minimum number
  of arguments.

  When using Module + function atoms, the call can fail with `UndefinedFunctionError` if the function does not exist or
  `FunctionClauseError` if the function exists but cannot be called with the minimum number of given arguments.
  """
  def safe_call(fun, args, min_args \\ 0)

  def safe_call(fun, args, min_args) when is_function(fun) do
    apply(fun, args)
  rescue
    # Retrying at FunctionClauseErrors is not a thing since anonymous function can't have mixed-arity clauses.
    error in BadArityError ->
      # Retry while at least `min_args` will be passed on the *next* invocation.
      if Enum.count(args) > min_args do
        safe_call(fun, Enum.drop(args, -1), min_args)
      else
        reraise error, __STACKTRACE__
      end
  end

  def safe_call({module, function}, args, min_args) when is_atom(module) and is_atom(function) do
    apply(module, function, args)
  rescue
    # Methods can be defined with multiple clauses where a higher arity version might exist but not be defined for the
    # given arguments.
    error in [UndefinedFunctionError, FunctionClauseError] ->
      # Retry while at least `min_args` will be passed on the *next* invocation.
      if Enum.count(args) > min_args do
        safe_call({module, function}, Enum.drop(args, -1), min_args)
      else
        reraise error, __STACKTRACE__
      end
  end
end
