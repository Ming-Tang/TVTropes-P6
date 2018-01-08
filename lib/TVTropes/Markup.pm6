use v6;

role MarkupElem {}
class Link does MarkupElem { has Str $.link; }
class NL does MarkupElem {}
class Escape does MarkupElem { has Str $.str; }

class PreTag does MarkupElem {
  has Str @.pretag;
  has Bool $.slash;

  method tag returns Str { @.pretag[0]; }
  method params returns List:D { @.pretag[1..*]; }
}

class BTag does MarkupElem {
  has Any $.pretag;
  has Str $.url;

  method tag returns Str { $.pretag ?? $.pretag.tag !! (Str); }
  method is-trivial returns Bool:D { return so none($.pretag.defined, $.url.defined); }
}

class ETag does MarkupElem {}
class Leading does MarkupElem { has Str $.lead; }
class Trailing does MarkupElem { has Int $.reps; }

# TODO comment syntax
grammar TVTropesMarkup::Grammar {
  token TOP { ^ <doc> $ }
  token doc { <tok>* }
  token tok { $<t> = <element> || $<t> = <escape> || $<t> = <other> }
  token other {
    [
    || <!before \n> <:Ll+:N+[\s , . ? !]>
    || <!before <prefix>> .
    ]+
  }

  token element {
    || [$<t> = <leading> | $<t> = <newline> | $<t> = <trailing>]
    || $<t> = <link>
    || $<t> = <begintag>
    || $<t> = <endtag>
  }

  token escape {
    "[="
    $<s> = [.*?]
    "=]"
  }

  token leading {
    <newline>
    $<ind> = [<!before \n> \s*]
    $<lead> = [
    || '*'+ # bulleted list
    || '#'+ # numbered list
    || '!'+ # heading
    || [ '-' ** 4..* | '-'+ <[\<\>]>] || <[:\ ]>+] # indents
  }

  token trailing { $<t> = ['\\'+] <newline> }

  token newline { \n }

  token prefix {
    ['[[' <!before '['> ] || ']]' || '[=' || <trailing> || <newline> || <link>
  }

  token link {
    $<t> = <slashlink>
    || $<t> = <linkword>
  }

  token slashlink {
    [<word> ['/' || '.'] || '\\'? $<at> = ['@'] '/'] <linkword>
  }

  token linkword {
    [ $<ln> = <wikiword> || '{{' $<ln> = <bracebody> '}}' ]
  }

  token bracebody {
    [ <[ \/ \| \' \- \# \@ \  ] + :Ll + :Lu + :N > || ' ' ]+
  }

  token wikiword {
    [ <:Lu>+ <:Ll+:N>*
      <?before [ <:Lu>+ <:Ll+:N> | <:Ll+:N> <:Lu> ] >
      <:Lu+:Ll+:N>*
    || <:Lu> <:Lu>+ <:Ll>+
    || <:Lu>+ <:Ll+:N>* <:Lu>+ <:Lu+:Ll+:N>* ]
    <!before <:Lu+:Ll+:N> >
  }

  token word {
    [ <:Lu>+ <:Ll+:N>* <:Lu+:Ll+:N>* ]
  }

  token begintag { $<t> = ['[[' \s*] <pretag>? <url>? }
  token endtag { ']]' }

  token url {
    'http' 's'? '://' <-[\]\ ]>+
  }

  token pretag {
    $<slash> = ['/']?
    [
      [
        <!before <url>>
        $<part> = [<:Ll+:Lu> [<:Ll+:Lu+:N>|| '-']* || <:N>+ || <link>]
      ]+ %% ':'
    ]
    [':' || <?before \s* ']]'>]
  }
}

class TVTropesMarkup::Actions {
  method TOP($/ --> List) { make $<doc>.made; }
  method doc($/) { make $<tok>>>.made; }

  method tok($/) { make $<t>.made; }
  method other($/) { make ~$/; }

  method element($/) { make $<t>.made; }
  method escape($/) { make Escape.new(:str(~$<s>)); }

  method leading($/) { make Leading.new(:lead(~$<lead>)); }
  method trailing($/) { make Trailing.new(:reps($<t>.chars)); }
  method newline($/) { make NL.new; }
  method link($/) { make Link.new(:link($<t>.made)); }

  method begintag($/) { make BTag.new(pretag => $<pretag>.made, url => $<url>.made); }
  method endtag($/) { make ETag.new; }
  method pretag($/) { make PreTag.new(pretag => $<part>>>.Str, slash => so ~$<slash>); }
  method url($/) { make ~$/; }

  method slashlink($/) { make ($<word> ?? $<word>.made !! ~$<at>) ~ "/" ~ $<linkword>.made; }

  method bracebody($/) { make ~$/; }
  method linkword($/) { make $<ln>.made; }
  method wikiword($/) { make ~$/; }
  method word($/) { make ~$/; }
}

