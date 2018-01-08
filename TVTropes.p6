use v6;
use Data::Dump;
#use Grammar::Debugger;

use TVTropes::Markup;
use TVTropes::SDOM;
use TVTropes::DOM;
use TVTropes::Backup;

#say Dump(PageRef.new(page => "Test"));
#say Dump(PageRef.new(namespace => "WMG", title => "Title"));
#say Dump(PageRef.new(page => "WMG.Title"));
#exit;

sub parse-page(Str:D $page --> List) {
  return: TVTropesMarkup::Grammar.parse($page, actions => TVTropesMarkup::Actions).made;
}

sub dump-list(@xs) {
  say "-----";
  .perl.say for @xs;
  say "-----";
}

my TVTropesBackup $tvtropes = TVTropesBackup.new(
  root => "/Users/mingtang/Downloads/TVTropesBackup".IO);

if (True) {
  my Int $i0 = 0;
  my Int $i = 0;
  for $tvtropes.all-pages -> ($ns, $title) {
    if ($i < $i0) { $i++; next; }

    say "$i -> $ns.$title";
    my Str $page = $tvtropes.get-page($ns, $title);

    say ".P";
    my $t0 = now;
    my @parsed = parse-page($page);

    say ".S";
    my Str $scode = make-scode @parsed;
    my $actions = SCode::Actions.new(ts => @parsed);

    say ".P";
    my $m = SCode::Grammar.parse($scode, actions => $actions);

    say ".M";
    my $mm = $m.made;
    my $t1 = now;

    say ".";
    my $dt = $t1 - $t0;
    my Int $len = $page.chars;
    my $cps = $len / $dt;
    say "dt = $dt, n = $len, cps = $cps";
    #say $mm;
    #say Dump($mm, :skip-methods);
    say "---------";
    $i++;
    #exit;
  }
  exit;
}

my Str $page = $tvtropes.get-page("VideoGame", "MassEffect1");
say $page;
say "-----";
my @parsed = parse-page($page);
dump-list @parsed;

my Str $scode = make-scode @parsed;
say $scode;
my $actions = SCode::Actions.new(ts => @parsed);
my $m = SCode::Grammar.parse($scode, actions => $actions);
say ".";
say $m.made;
#say Dump($m.made, :skip-methods);

# sqlite> SELECT SUM(LENGTH(Contents)) FROM Page;
# 1466782876
# sqlite> SELECT COUNT(*) FROM Page;
# 176430

