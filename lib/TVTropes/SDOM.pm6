use v6;

use TVTropes::Markup;

role SDOM::Node {}

role SDOM::HasChildren { method Bool { @.children.Bool; } }

role SDOM::HasBody { method Bool { $.body.Bool; } }

role SDOM::InlineNode does SDOM::Node {}

class SDOM::Doc does SDOM::HasBody {
  has SDOM::Node @.body;
}

class SDOM::Text does SDOM::InlineNode {
  has Str $.text;
  has Bool $.is-escape;
}

class SDOM::Trailing does SDOM::InlineNode { has Int $.reps; }

class SDOM::Para does SDOM::Node does SDOM::HasChildren {
  has SDOM::InlineNode @.children;
}

role SDOM::InternalLink does SDOM::InlineNode { has Str $.link; }

class SDOM::Link does SDOM::InternalLink {}

class SDOM::LinkWithText does SDOM::InternalLink does SDOM::HasBody {
  has SDOM::Para $.body;
}

class SDOM::ExternalLink does SDOM::InlineNode does SDOM::HasBody {
  has Str $.url;
  has SDOM::Para $.body;
}

class SDOM::Tagged does SDOM::InlineNode does SDOM::HasChildren {
  has Str $.tag;
  has Str @.params;
  has Bool $.is-complex;
  has SDOM::InlineNode @.children;
}

class SDOM::OtherTagged does SDOM::InlineNode does SDOM::HasChildren {
  has SDOM::Node @.children;
}

class SDOM::ParaGroup does SDOM::Node does SDOM::HasChildren {
  has SDOM::Para @.children;
}

class SDOM::WithLead does SDOM::Node does SDOM::HasBody {
  has Str $.lead;
  has SDOM::Para $.body;

  method level { $.body ~ /^ [('*'*) || ('-'*) '>'?] $/; $0.chars.return; }
}

class SDOM::LeadGroup does SDOM::Node does SDOM::HasChildren {
  has SDOM::WithLead @.children;
}

class SDOM::NL does SDOM::InlineNode {}

class SDOM::Skipped does SDOM::Node { has Any $.token; has Str $.scode; }

grammar SCode::Grammar {
  token TOP { ^ <main> $ }

  token main {
    <doc>
    [$<skipped> = [.] $<remaining> = [.*]]?
  }

  token doc { [<block>]* }

  token block { <paras> || <list> }

  token invalid { . }

  token paras { <para>+ %% <newline> }

  token list { <list-item>+ <newline>? }

  token para { [$<t> = <inline> || $<t> = <trailing>]+ }

  token tagged { <btag> ~ <etag> [$<t> = <inline> || $<t> = <newline> || $<t> = <trailing>]* }

  token inline { $<t> = <text> || $<t> = <link> || $<t> = <tagged> || $<t> = <escape> }

  token list-item { <leading> <para>? }

  token newline { '|'+ }
  token leading { '-' }
  token trailing { '=' }
  token btag { '[' }
  token etag { ']' }
  token link { '*' }
  token text { '.' }
  token escape { '^' }
}

sub do-parse(Str $str, $actions) {
  return SCode::Grammar.parse($str, actions => $actions);
}

class SCode::Actions {
  has @.ts;

  method TOP($/) { make $<main>.made; }

  method main($/) {
    if $<skipped> {
      my $skipped-t = @.ts[$<skipped>.from];
      warn "Skipping token: " ~ ~$<skipped> ~ " : " ~ $skipped-t;
      my @xs1 = $<doc>.made.body;
      my @ts1 = @.ts[($<skipped>.from + 1) .. (@.ts.Int - 1)];
      my $actions = SCode::Actions.new(ts => @ts1);
      my @xs2 = do-parse(~$<remaining>, $actions).made.body;
      my $skipped = SDOM::Skipped.new(token => $skipped-t, scode => ~$<skipped>);

      make SDOM::Doc.new(body => [|@xs1, $skipped, |@xs2]);
      return;
    }
    make $<doc>.made;
  }

  method doc($/) { make SDOM::Doc.new(body => $<block>>>.made); }

  method block($/) { make ($<paras> ?? $<paras>.made !! $<list>.made); }

  method error($/) { fail "error token encountered."; make $<btag>.made; }

  method paras($/) { make SDOM::ParaGroup.new(children => $<para>>>.made); }

  method list($/) { make SDOM::LeadGroup.new(children => $<list-item>>>.made); }

  method para($/) { make SDOM::Para.new(children => $<t>>>.made); }

  method tagged($/) {
    my @xs = [$<btag>.made, |$<t>>>.made, $<etag>.made];
    make classify-tag(@xs);
  }

  method inline($/) { make $<t>.made; }

  method list-item($/) {
    make SDOM::WithLead.new(
      lead => $<leading>.made,
      body => ($<para> ?? $<para>.made !! SDOM::Para.new(children => [])));
  }

  method newline($/) { make SDOM::NL.new; }
  method leading($/) { make @.ts[$/.from].lead; }
  method trailing($/) { make SDOM::Trailing.new(reps => @.ts[$/.from].reps); }
  method btag($/) { make @.ts[$/.from]; }
  method etag($/) { make @.ts[$/.from]; }
  method link($/) { make SDOM::Link.new(link => @.ts[$/.from].link); }
  method text($/) { make SDOM::Text.new(text => @.ts[$/.from], is-escape => False); }
  method escape($/) { make SDOM::Text.new(text => @.ts[$/.from].str, is-escape => True); }
}

sub matching-pairs(@ts, $open, $close --> Hash) is export {
  my Int $n = @ts.Int;
  my @stack;
  my %matches;

  for 0..^$n -> $i {
    my $t = @ts[$i];
    given $t {
      when $open { @stack.push: ($i, $t); }
      when $close {
        fail "unbalanced: too many closes" if @stack.Int == 0;
        my ($i0, $open) = @stack.pop;
        %matches{$i0} = $i;
      }
    }
  }
  fail "unbalanced: too many opens" if @stack.Int > 0;

  %matches.return;
}

sub scode($t --> Str:D) is export {
  return: given $t {
    when Link { "*" }
    when NL { "|" }
    when BTag { "[" }
    when ETag { "]" }
    when Leading { "-" }
    when Trailing { "=" }
    when Escape { "^" }
    when Str { "."; }
    default { fail $t.WHO; }
  }
}

sub make-scode(@ts --> Str:D) is export {
  return [~] (@ts.map: {scode $_});
}

our @complex-tags = <folder quoteblock note labelnote>;

sub classify-tag(@elems) is export {
  my Int $n = @elems.Int;
  my $close = @elems[$n - 1];
  my ($open, $next, *@mid) = @elems[0..^$n - 1];
  my Bool $is-trivial = $open.is-trivial;

  if ($open.is-trivial) {
    if ($next ~~ SDOM::Link) {
      return SDOM::LinkWithText.new(
        link => $next.link,
        body => SDOM::Para.new(children => @mid));
    }
    else {
      warn "classify-tag: Invalid open: " ~ @elems.perl;
      return SDOM::OtherTagged.new(children => @mid);
    }
  } elsif ($open.url.defined) {
    return SDOM::ExternalLink.new(
      url => $open.url, body => SDOM::Para.new(children => @mid));
  }

  if ($open.tag) {
    return SDOM::Tagged.new(
      :tag($open.tag),
      :is-complex(so $open.tag eq any @complex-tags),
      :params($open.pretag.params),
      :children(@elems[1..^$n - 1])
    );
  }

  say @elems;
  fail "classify-tag: Unknown.";
  #return ($open, $next, @mid, $close);
}

