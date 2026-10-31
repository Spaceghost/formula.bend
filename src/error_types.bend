import Base

# Payloads stay generic so the evaluator can use its own value type without
# creating an import cycle between error types and message-formatting helpers.
type Description<-V: Data> is Data:
  Details{class_name: String, parents: List<&2, String>, reason: Maybe<&2, V>, meta: V, attributes: V, message: String, assigned_to: V}

def contains(names: List<&2, String>, +name: String) -> Bool:
  match names:
    case Nil{}:
      False{}
    case head <> rest:
      Bool.or(String.eq(head, name), contains(rest, name))

def is_a(-V: Data, error: Description<V>, +name: String) -> Bool:
  match error:
    case Details{label, ancestors, cause, payload, props, text, owner}:
      Bool.or(String.eq(label, name), contains(ancestors, name))

def with_message(-V: Data, error: Description<V>, message: String) -> Description<V>:
  match error:
    case Details{label, ancestors, cause, payload, props, previous, owner}:
      Details{label, ancestors, cause, payload, props, message, owner}

def with_assigned_to(-V: Data, error: Description<V>, assigned_to: V) -> Description<V>:
  match error:
    case Details{label, ancestors, cause, payload, props, text, previous}:
      Details{label, ancestors, cause, payload, props, text, assigned_to}

def message(-V: Data, error: Description<V>) -> String:
  match error:
    case Details{label, ancestors, cause, payload, props, text, owner}:
      text

def class_name(-V: Data, error: Description<V>) -> String:
  match error:
    case Details{label, ancestors, cause, payload, props, text, owner}:
      label

def attributes(-V: Data, error: Description<V>) -> V:
  match error:
    case Details{label, ancestors, cause, payload, props, text, owner}:
      props

def metadata(-V: Data, error: Description<V>) -> V:
  match error:
    case Details{label, ancestors, cause, payload, props, text, owner}:
      payload

def reason(-V: Data, error: Description<V>) -> Maybe<&2, V>:
  match error:
    case Details{label, ancestors, cause, payload, props, text, owner}:
      cause

def assigned_to(-V: Data, error: Description<V>) -> V:
  match error:
    case Details{label, ancestors, cause, payload, props, text, owner}:
      owner
