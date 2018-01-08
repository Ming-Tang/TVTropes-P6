
class TVTropesBackup {
  has IO::Path $.root;
  has IO::Path @!dirs;

  method page-path(Str:D $namespace, Str:D $page) {
    my @dirs = self.dirs;
    my Str $fn = "$namespace.$page@action=source";
    @!dirs.map(*.child($fn)).grep(*.e)[0].return;
  }

  method get-page(Str:D $namespace, Str:D $page) {
    process-page(self.page-path($namespace, $page).IO.slurp(enc => 'iso-8859-1')).return;
  }

  method dirs {
    return @!dirs if @!dirs;
    my @dirs1 = $.root.dir.grep(*.d);
    @!dirs = |@dirs1, |@dirs1.map(*.IO.dir.grep(*.d)).flat.List unless @!dirs;
    return @!dirs;
  }

  method all-pages returns Seq:D {
    return gather for self.dirs {
      for .dir {
        take (~$0, ~$1) if /^ .* '/' (.*?) '.' (.*?) '@action=source' $/;
      }
    }
  }
}

sub process-page(Str:D $page --> Str:D) is export {
  $_ = $page;
  m|'<body>' \n (.*) \n '</body>'|;
  $_ = ~$0;
  s:g|'<' \s* 'br' \s* '/'? '>'|\n|;
  s:g/'&lt;'/</;
  s:g/'&gt;'/>/;
  s:g/'&amp;'/&/;
  s:g/'&quot;'/'/;
  .return();
}

