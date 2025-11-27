defmodule Predicates.JSONSchemas do
  @moduledoc false

  def predicate() do
    %{
      "type" => "object",
      "anyOf" => [
        generic_comparators(),
        numeric_comparators(),
        string_comparators(),
        list_comparators(),
        contains_comparator(),
        negation_operator(),
        conjunction_operators(),
        quantor_operator(),
        plain_value_predicate()
      ],
      "description" => "A predicate object defining a condition to be evaluated."
    }
  end

  def generic_comparators() do
    %{
      "type" => "object",
      "properties" => %{
        "op" => %{
          "type" => "string",
          "enum" => ["eq", "not_eq"],
          "description" =>
            "Evaluates to true if the stored value exactly matches/doesn't match the provided argument"
        },
        "path" => %{
          "type" => "string",
          "description" => "The field name or the path."
        },
        "arg" => %{
          "type" => ["string", "number", "boolean", "null"],
          "description" => "The value to compare the stored data against."
        }
      },
      "required" => ["op", "path", "arg"],
      "additionalProperties" => false
    }
  end

  def numeric_comparators() do
    %{
      "type" => "object",
      "properties" => %{
        "op" => %{
          "type" => "string",
          "enum" => ["gt", "ge", "lt", "le"],
          "description" => """
          Evaluates to true if the stored value is greater than (`gt`)/greater than or equal (`ge`)/less than (`lt`)/less than or
          equal (`le`) the provided argument.

          The comparator uses the database's comparators `<`, `<=`, `>` & `>=`.
          """
        },
        "path" => %{
          "type" => "string",
          "description" => "The field name or the path."
        },
        "arg" => %{
          "type" => "number",
          "description" => "The numeric value to compare the stored data against."
        }
      },
      "required" => ["op", "path", "arg"],
      "additionalProperties" => false
    }
  end

  def string_comparators() do
    %{
      "type" => "object",
      "properties" => %{
        "op" => %{
          "type" => "string",
          "enum" => ["like", "ilike", "starts_with", "ends_with"],
          "description" => """
          Evaluates to true if the stored string contains (`like`)/contains ignoring casing (`ilike`)/starts with
          (`starts_with`)/ends with `ends_with` the provided argument.
          """
        },
        "path" => %{
          "type" => "string",
          "description" => "The field name or the path."
        },
        "arg" => %{
          "type" => "string",
          "description" => "The string value to compare the stored data against."
        }
      },
      "required" => ["op", "path", "arg"],
      "additionalProperties" => false
    }
  end

  def list_comparators() do
    %{
      "type" => "object",
      "properties" => %{
        "op" => %{
          "type" => "string",
          "enum" => ["in", "not_in"],
          "description" => """
          Evaluates to true if the stored value is included in (`in`)/is not included in (`not_in`) the list of provided
          arguments.
          """
        },
        "path" => %{
          "type" => "string",
          "description" => "The field name or the path."
        },
        "arg" => %{
          "oneOf" => [
            %{
              "type" => ["string", "number", "boolean", "null"],
              "description" =>
                "The list of values to test against the stored value. Non-list arg values are wrapped automatically."
            },
            %{
              "type" => "array",
              "items" => [
                %{
                  "type" => ["string", "number", "boolean", "null"]
                }
              ],
              "description" => "The list of values to test against the stored value."
            }
          ]
        }
      },
      "required" => ["op", "path", "arg"],
      "additionalProperties" => false
    }
  end

  def contains_comparator() do
    %{
      "type" => "object",
      "properties" => %{
        "op" => %{
          "type" => "string",
          "enum" => ["contains"],
          "description" => """
          Compare operation to check if a stored value or a list of values contains a single or a list of values. In case of a
          simple stored value it'll fallback to a basic string comparator. If the stored value is a json the postgres [containment
          operators](https://www.postgresql.org/docs/current/datatype-json.html#JSON-CONTAINMENT) are applied.
          """
        },
        "path" => %{
          "type" => "string",
          "description" => "The field name or the path."
        },
        "arg" => %{
          "type" => "array",
          "items" => [%{"type" => "string"}],
          "description" => " The list of values to test against the stored value."
        }
      },
      "required" => ["op", "path", "arg"],
      "additionalProperties" => false
    }
  end

  def negation_operator() do
    %{
      "type" => "object",
      "properties" => %{
        "op" => %{
          "type" => "string",
          "enum" => ["not"],
          "description" => "Evaluates to true if the sub-predicate evaluates to false."
        },
        "arg" => predicate()
      },
      "required" => ["op", "arg"],
      "additionalProperties" => false
    }
  end

  def conjunction_operators() do
    %{
      "type" => "object",
      "properties" => %{
        "op" => %{
          "type" => "string",
          "enum" => ["and", "or"],
          "description" => """
          Evaluates to true when all (`and`)/any (`or`) sub-predicates are true.

          When given an empty list for `args`, `and` evaluates to true, while `or` evaluates to false.
          """
        },
        "args" => %{
          "type" => "array",
          "items" => predicate(),
          "description" => "An array of predicate objects to be evaluated."
        }
      },
      "required" => ["op", "args"],
      "additionalProperties" => false
    }
  end

  def quantor_operator() do
    %{
      "type" => "object",
      "properties" => %{
        "op" => %{
          "type" => "string",
          "enum" => ["any"],
          "description" => """
          Evaluates to true if the sub-predicate is true for any of the associated entities. The `any` operator is also implicitly
          introduced when walking a 1-to-many association using `.`-path notation.

          The sub-predicate is evaluated within the scope of the target entity, meaning that a path of `""` targets the
          relationship destination itself, and `"id"` targets the `id` column of the related entity.
          """
        },
        "path" => %{
          "type" => "string",
          "description" => "The field name holding the associated data."
        },
        "arg" => %{
          "type" => "object",
          "description" => "A sub-predicate to process against the associated data",
          "properties" => predicate()
        }
      },
      "required" => ["op", "path", "arg"],
      "additionalProperties" => false
    }
  end

  def plain_value_predicate() do
    %{
      "type" => "object",
      "description" => "These special predicates always evaluate to true or false",
      "properties" => %{
        "arg" => %{
          "type" => "boolean",
          "description" => "A boolean value that the predicate always evaluates to."
        }
      },
      "required" => ["arg"],
      "additionalProperties" => false
    }
  end
end
