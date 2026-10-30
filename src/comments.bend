import Base

type CommentMode is Data:
  OutsideComment{}
  CommentSlash{}
  InsideComment{reversed: String}
  CommentStar{reversed: String}

def finish(mode: CommentMode, reversed: String) -> String:
  match mode:
    case OutsideComment{}:
      String.reverse(reversed)
    case CommentSlash{}:
      String.reverse(SCon{Chr{47}, reversed})
    case InsideComment{candidate}:
      String.reverse(candidate ++ reversed)
    case CommentStar{candidate}:
      String.reverse(candidate ++ reversed)

# Like Tokenizer.strip_comments, remove complete comments even inside quotes.
# Preserve an unfinished candidate verbatim. Recursion consumes the input only.
def scan(source: String, mode: CommentMode, reversed: String) -> String:
  match source mode:
    case SNil{} mode:
      finish(mode, reversed)
    case SCon{Chr{47}, rest} OutsideComment{}:
      scan(rest, CommentSlash{}, reversed)
    case SCon{c, rest} OutsideComment{}:
      scan(rest, OutsideComment{}, SCon{c, reversed})
    case SCon{Chr{42}, rest} CommentSlash{}:
      scan(rest, InsideComment{"*/"}, reversed)
    case SCon{Chr{47}, rest} CommentSlash{}:
      scan(rest, CommentSlash{}, SCon{Chr{47}, reversed})
    case SCon{c, rest} CommentSlash{}:
      scan(rest, OutsideComment{}, SCon{c, SCon{Chr{47}, reversed}})
    case SCon{Chr{42}, rest} InsideComment{candidate}:
      scan(rest, CommentStar{SCon{Chr{42}, candidate}}, reversed)
    case SCon{c, rest} InsideComment{candidate}:
      scan(rest, InsideComment{SCon{c, candidate}}, reversed)
    case SCon{Chr{47}, rest} CommentStar{candidate}:
      scan(rest, OutsideComment{}, reversed)
    case SCon{Chr{42}, rest} CommentStar{candidate}:
      scan(rest, CommentStar{SCon{Chr{42}, candidate}}, reversed)
    case SCon{c, rest} CommentStar{candidate}:
      scan(rest, InsideComment{SCon{c, candidate}}, reversed)

def strip_comments(source: String) -> String:
  scan(source, OutsideComment{}, SNil{})
